package pk.gov.power.disco_meter_reader

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.os.SystemClock
import android.util.Log
import org.opencv.android.OpenCVLoader
import org.opencv.android.Utils
import org.opencv.core.Mat
import org.opencv.core.MatOfPoint2f
import org.opencv.core.Point
import org.opencv.core.RotatedRect
import org.opencv.core.Size
import org.opencv.imgproc.Imgproc
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

const val MODEL_INPUT_SIZE = 640
const val NUM_ANCHORS = 8400
private const val TAG = "MeterDetector"

data class PointF(val x: Float, val y: Float)

data class Letterbox(
    val bmp: Bitmap,
    val scale: Float,
    val padX: Float,
    val padY: Float
)

data class Detection(
    val cls: Int,
    val className: String,
    val conf: Float,
    val corners: List<PointF>, // corners in ORIGINAL image pixels
    val decision: String,      // "Accepted", "Uncertain, manual check", or "No meter found, retake"
    val inferenceTimeMs: Long,
    val numBoxesFound: Int
)

class MeterDetector(private val context: Context) {

    private var interpreter: Interpreter? = null
    private var isInitialized = false

    init {
        try {
            initOpenCV()
            initInterpreter()
            warmup()
            isInitialized = true
            Log.i(TAG, "MeterDetector successfully initialized and warmed up.")
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing MeterDetector: ${e.message}", e)
        }
    }

    private fun initOpenCV() {
        if (!OpenCVLoader.initLocal()) {
            if (!OpenCVLoader.initDebug()) {
                Log.w(TAG, "OpenCV initialization failed via initDebug()")
            } else {
                Log.i(TAG, "OpenCV initialized successfully via initDebug()")
            }
        } else {
            Log.i(TAG, "OpenCV initialized successfully via initLocal()")
        }
    }

    private fun loadModelFile(): MappedByteBuffer {
        val fileDescriptor = context.assets.openFd("best.tflite")
        val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
        val fileChannel = inputStream.channel
        val startOffset = fileDescriptor.startOffset
        val declaredLength = fileDescriptor.declaredLength
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
    }

    private fun initInterpreter() {
        val options = Interpreter.Options().apply {
            setNumThreads(4)
            setUseXNNPACK(true)
        }
        val modelBuffer = loadModelFile()
        interpreter = Interpreter(modelBuffer, options)
    }

    private fun warmup() {
        try {
            val dummyInput = ByteBuffer.allocateDirect(4 * 3 * MODEL_INPUT_SIZE * MODEL_INPUT_SIZE)
                .order(ByteOrder.nativeOrder())
            val dummyOutput = Array(1) { Array(7) { FloatArray(NUM_ANCHORS) } }
            interpreter?.run(dummyInput, dummyOutput)
            Log.i(TAG, "Interpreter warmup inference completed successfully.")
        } catch (e: Exception) {
            Log.w(TAG, "Warmup inference error (non-fatal): ${e.message}")
        }
    }

    fun letterbox(src: Bitmap): Letterbox {
        val s = min(MODEL_INPUT_SIZE / src.width.toFloat(), MODEL_INPUT_SIZE / src.height.toFloat())
        val nw = (src.width * s).roundToInt()
        val nh = (src.height * s).roundToInt()
        val padX = ((MODEL_INPUT_SIZE - nw) / 2).toFloat()
        val padY = ((MODEL_INPUT_SIZE - nh) / 2).toFloat()

        val out = Bitmap.createBitmap(MODEL_INPUT_SIZE, MODEL_INPUT_SIZE, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        c.drawColor(Color.rgb(114, 114, 114))

        val scaledSrc = Bitmap.createScaledBitmap(src, nw, nh, true)
        c.drawBitmap(scaledSrc, padX, padY, null)
        if (scaledSrc != src) {
            scaledSrc.recycle()
        }
        return Letterbox(out, s, padX, padY)
    }

    // NCHW float buffer: all R values, then all G, then all B
    fun toInput(bmp: Bitmap): ByteBuffer {
        val buf = ByteBuffer.allocateDirect(4 * 3 * MODEL_INPUT_SIZE * MODEL_INPUT_SIZE)
            .order(ByteOrder.nativeOrder())
        val px = IntArray(MODEL_INPUT_SIZE * MODEL_INPUT_SIZE)
        bmp.getPixels(px, 0, MODEL_INPUT_SIZE, 0, 0, MODEL_INPUT_SIZE, MODEL_INPUT_SIZE)
        val fb = buf.asFloatBuffer()
        val totalPx = MODEL_INPUT_SIZE * MODEL_INPUT_SIZE

        for (i in 0 until totalPx) {
            fb.put(i, ((px[i] shr 16) and 0xFF) / 255f)                     // R
            fb.put(totalPx + i, ((px[i] shr 8) and 0xFF) / 255f)           // G
            fb.put(2 * totalPx + i, (px[i] and 0xFF) / 255f)               // B
        }
        buf.rewind()
        return buf
    }

    private fun calculateRotatedIoU(r1: RotatedRect, r2: RotatedRect): Float {
        try {
            val intersectingRegion = MatOfPoint2f()
            val res = Imgproc.rotatedRectangleIntersection(r1, r2, intersectingRegion)
            if (res == Imgproc.INTERSECT_NONE) {
                intersectingRegion.release()
                return 0f
            }
            val pts = intersectingRegion.toArray()
            if (pts.size < 3) {
                intersectingRegion.release()
                return 0f
            }
            val area1 = (r1.size.width * r1.size.height).toDouble()
            val area2 = (r2.size.width * r2.size.height).toDouble()
            val interArea = Imgproc.contourArea(intersectingRegion)
            intersectingRegion.release()

            val unionArea = area1 + area2 - interArea
            return if (unionArea <= 0.0) 0f else (interArea / unionArea).toFloat()
        } catch (t: Throwable) {
            // Robust axis-aligned bounding box IoU fallback
            val x1A = r1.center.x - r1.size.width / 2.0
            val y1A = r1.center.y - r1.size.height / 2.0
            val x2A = r1.center.x + r1.size.width / 2.0
            val y2A = r1.center.y + r1.size.height / 2.0

            val x1B = r2.center.x - r2.size.width / 2.0
            val y1B = r2.center.y - r2.size.height / 2.0
            val x2B = r2.center.x + r2.size.width / 2.0
            val y2B = r2.center.y + r2.size.height / 2.0

            val interLeft = max(x1A, x1B)
            val interTop = max(y1A, y1B)
            val interRight = min(x2A, x2B)
            val interBottom = min(y2A, y2B)

            val interW = max(0.0, interRight - interLeft)
            val interH = max(0.0, interBottom - interTop)
            val interArea = interW * interH
            val areaA = (x2A - x1A) * (y2A - y1A)
            val areaB = (x2B - x1B) * (y2B - y1B)
            val union = areaA + areaB - interArea
            return if (union <= 0.0) 0f else (interArea / union).toFloat()
        }
    }

    private fun rotatedNMS(
        rects: List<RotatedRect>,
        scores: List<Float>,
        nmsThr: Float
    ): List<Int> {
        val sortedIndices = scores.indices.sortedByDescending { scores[it] }.toMutableList()
        val keep = mutableListOf<Int>()
        while (sortedIndices.isNotEmpty()) {
            val current = sortedIndices.removeAt(0)
            keep.add(current)
            val it = sortedIndices.iterator()
            while (it.hasNext()) {
                val next = it.next()
                val iou = calculateRotatedIoU(rects[current], rects[next])
                if (iou > nmsThr) {
                    it.remove()
                }
            }
        }
        return keep
    }

    /**
     * Executes meter display detection on the original bitmap.
     * confThr is 0.25 to catch uncertain detections as requested by decision rules.
     */
    fun detect(
        original: Bitmap,
        confThr: Float = 0.25f,
        nmsThr: Float = 0.45f
    ): Detection? {
        val interp = interpreter ?: run {
            Log.e(TAG, "Interpreter is not initialized")
            return null
        }

        val startTime = SystemClock.elapsedRealtime()
        val lb = letterbox(original)
        val output = Array(1) { Array(7) { FloatArray(NUM_ANCHORS) } } // [1, 7, 8400]

        try {
            interp.run(toInput(lb.bmp), output)
        } catch (e: Exception) {
            Log.e(TAG, "Inference execution error: ${e.message}", e)
            lb.bmp.recycle()
            return null
        }
        val o = output[0]

        val rects = ArrayList<RotatedRect>()
        val scores = ArrayList<Float>()
        val classes = ArrayList<Int>()
        val params = ArrayList<FloatArray>() // cx, cy, w, h, angle (in 640 space)

        for (i in 0 until NUM_ANCHORS) {
            val s0 = o[4][i] // digital_display
            val s1 = o[5][i] // analog_display
            val conf = max(s0, s1)
            if (conf < confThr) continue

            val cx = o[0][i] * MODEL_INPUT_SIZE
            val cy = o[1][i] * MODEL_INPUT_SIZE
            val w = o[2][i] * MODEL_INPUT_SIZE
            val h = o[3][i] * MODEL_INPUT_SIZE
            val ang = o[6][i] // radians

            rects.add(
                RotatedRect(
                    Point(cx.toDouble(), cy.toDouble()),
                    Size(w.toDouble(), h.toDouble()),
                    Math.toDegrees(ang.toDouble())
                )
            )
            scores.add(conf)
            classes.add(if (s1 > s0) 1 else 0)
            params.add(floatArrayOf(cx, cy, w, h, ang))
        }

        // Clean up letterboxed bitmap
        lb.bmp.recycle()

        if (rects.isEmpty()) {
            val elapsed = SystemClock.elapsedRealtime() - startTime
            Log.i(TAG, "Detection completed in ${elapsed}ms: No boxes exceeded threshold $confThr. Decision: No meter found, retake")
            return null
        }

        val keep = rotatedNMS(rects, scores, nmsThr)
        if (keep.isEmpty()) {
            val elapsed = SystemClock.elapsedRealtime() - startTime
            Log.i(TAG, "Detection completed in ${elapsed}ms: No boxes survived NMS. Decision: No meter found, retake")
            return null
        }

        val best = keep.maxByOrNull { scores[it] }!!
        val bestScore = scores[best]
        val bestClass = classes[best]
        val className = if (bestClass == 0) "digital_display" else "analog_display"

        // Corners formula from Ultralytics xywhr2xyxyxyxy
        val (cx, cy, w, h, a) = params[best].let { listOf(it[0], it[1], it[2], it[3], it[4]) }
        val c = cos(a)
        val s = sin(a)
        val v1x = (w / 2) * c
        val v1y = (w / 2) * s
        val v2x = -(h / 2) * s
        val v2y = (h / 2) * c

        val box640 = listOf(
            PointF(cx + v1x + v2x, cy + v1y + v2y),
            PointF(cx + v1x - v2x, cy + v1y - v2y),
            PointF(cx - v1x - v2x, cy - v1y - v2y),
            PointF(cx - v1x + v2x, cy - v1y + v2y)
        )

        // Undo letterbox to original image pixels
        val corners = box640.map {
            PointF(
                ((it.x - lb.padX) / lb.scale).coerceIn(0f, original.width.toFloat()),
                ((it.y - lb.padY) / lb.scale).coerceIn(0f, original.height.toFloat())
            )
        }

        // Decision rule logic (Section 7)
        val decision = when {
            bestScore >= 0.50f -> "Accepted"
            bestScore >= 0.25f -> "Uncertain, manual check"
            else -> "No meter found, retake"
        }

        val elapsed = SystemClock.elapsedRealtime() - startTime
        Log.i(
            TAG,
            "Detection result: class=$className($bestClass), conf=${"%.4f".format(bestScore)}, decision='$decision', time=${elapsed}ms, survivingBoxes=${keep.size}, corners=[${corners.joinToString { "(${it.x.roundToInt()},${it.y.roundToInt()})" }}]"
        )

        return Detection(
            cls = bestClass,
            className = className,
            conf = bestScore,
            corners = corners,
            decision = decision,
            inferenceTimeMs = elapsed,
            numBoxesFound = keep.size
        )
    }

    /**
     * Perspective warp straight crop from the ORIGINAL full-resolution photo.
     */
    fun warpCrop(
        original: Bitmap,
        corners: List<PointF>,
        outW: Int = 480,
        outH: Int = 140
    ): Bitmap? {
        if (corners.size < 4) return null

        // Order corners: top-left, top-right, bottom-right, bottom-left
        val byY = corners.sortedBy { it.y }
        val top = byY.take(2).sortedBy { it.x }
        val bot = byY.takeLast(2).sortedBy { it.x }

        // Section 5 note: swap outW and outH when the detected box is taller than wide
        val topW = kotlin.math.hypot((top[1].x - top[0].x).toDouble(), (top[1].y - top[0].y).toDouble())
        val leftH = kotlin.math.hypot((bot[0].x - top[0].x).toDouble(), (bot[0].y - top[0].y).toDouble())
        val (finalW, finalH) = if (leftH > topW * 1.25) Pair(outH, outW) else Pair(outW, outH)

        try {
            val src = MatOfPoint2f(
                Point(top[0].x.toDouble(), top[0].y.toDouble()),
                Point(top[1].x.toDouble(), top[1].y.toDouble()),
                Point(bot[1].x.toDouble(), bot[1].y.toDouble()),
                Point(bot[0].x.toDouble(), bot[0].y.toDouble())
            )

            val dst = MatOfPoint2f(
                Point(0.0, 0.0),
                Point(finalW.toDouble(), 0.0),
                Point(finalW.toDouble(), finalH.toDouble()),
                Point(0.0, finalH.toDouble())
            )

            val m = Imgproc.getPerspectiveTransform(src, dst)
            val srcMat = Mat()
            Utils.bitmapToMat(original, srcMat)
            val outMat = Mat()
            Imgproc.warpPerspective(srcMat, outMat, m, Size(finalW.toDouble(), finalH.toDouble()))

            val out = Bitmap.createBitmap(finalW, finalH, Bitmap.Config.ARGB_8888)
            Utils.matToBitmap(outMat, out)

            src.release()
            dst.release()
            srcMat.release()
            outMat.release()
            m.release()

            return out
        } catch (e: Throwable) {
            Log.w(TAG, "OpenCV warpPerspective fallback to Android Matrix poly-to-poly: ${e.message}")
            return try {
                val matrix = android.graphics.Matrix()
                val srcPts = floatArrayOf(
                    top[0].x, top[0].y,
                    top[1].x, top[1].y,
                    bot[1].x, bot[1].y,
                    bot[0].x, bot[0].y
                )
                val dstPts = floatArrayOf(
                    0f, 0f,
                    finalW.toFloat(), 0f,
                    finalW.toFloat(), finalH.toFloat(),
                    0f, finalH.toFloat()
                )
                matrix.setPolyToPoly(srcPts, 0, dstPts, 0, 4)
                val out = Bitmap.createBitmap(finalW, finalH, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(out)
                val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
                canvas.drawBitmap(original, matrix, paint)
                out
            } catch (fallbackErr: Throwable) {
                Log.e(TAG, "Both OpenCV and Android Matrix warp failed: ${fallbackErr.message}", fallbackErr)
                null
            }
        }
    }

    /**
     * Creates an annotated copy of the bitmap with the detected rotated bounding box and tag.
     */
    fun drawDetectionOverlay(original: Bitmap, detection: Detection): Bitmap {
        val annotated = original.copy(Bitmap.Config.ARGB_8888, true)
        val canvas = Canvas(annotated)

        val strokeColor = when (detection.decision) {
            "Accepted" -> Color.rgb(16, 185, 129) // Emerald Green
            "Uncertain, manual check" -> Color.rgb(245, 158, 11) // Amber
            else -> Color.rgb(239, 68, 68) // Red
        }

        // Draw rotated box polygon
        val boxPaint = Paint().apply {
            color = strokeColor
            style = Paint.Style.STROKE
            strokeWidth = max(4f, original.width / 200f)
            isAntiAlias = true
        }

        val fillPaint = Paint().apply {
            color = Color.argb(40, Color.red(strokeColor), Color.green(strokeColor), Color.blue(strokeColor))
            style = Paint.Style.FILL
            isAntiAlias = true
        }

        val path = Path()
        val c = detection.corners
        if (c.size == 4) {
            path.moveTo(c[0].x, c[0].y)
            path.lineTo(c[1].x, c[1].y)
            path.lineTo(c[2].x, c[2].y)
            path.lineTo(c[3].x, c[3].y)
            path.close()
            canvas.drawPath(path, fillPaint)
            canvas.drawPath(path, boxPaint)

            // Draw corner vertex circles
            val cornerPaint = Paint().apply {
                color = Color.WHITE
                style = Paint.Style.FILL
                isAntiAlias = true
            }
            val cornerStroke = Paint().apply {
                color = strokeColor
                style = Paint.Style.STROKE
                strokeWidth = max(2f, original.width / 400f)
                isAntiAlias = true
            }
            val radius = max(6f, original.width / 150f)
            for (p in c) {
                canvas.drawCircle(p.x, p.y, radius, cornerPaint)
                canvas.drawCircle(p.x, p.y, radius, cornerStroke)
            }

            // Draw label pill near top-left corner
            val labelText = "${detection.className.replace("_", " ").uppercase()} ${(detection.conf * 100).roundToInt()}%"
            val textPaint = Paint().apply {
                color = Color.WHITE
                textSize = max(22f, original.width / 45f)
                isAntiAlias = true
                isFakeBoldText = true
            }
            val textBounds = android.graphics.Rect()
            textPaint.getTextBounds(labelText, 0, labelText.length, textBounds)

            val minX = c.minOf { it.x }
            val minY = c.minOf { it.y }
            val pillPad = 12f
            val pillLeft = max(8f, minX)
            val pillTop = max(8f, minY - textBounds.height() - pillPad * 2)
            val pillRight = pillLeft + textBounds.width() + pillPad * 2
            val pillBottom = pillTop + textBounds.height() + pillPad * 2

            val pillPaint = Paint().apply {
                color = strokeColor
                style = Paint.Style.FILL
                isAntiAlias = true
            }
            canvas.drawRoundRect(pillLeft, pillTop, pillRight, pillBottom, 12f, 12f, pillPaint)
            canvas.drawText(labelText, pillLeft + pillPad, pillBottom - pillPad, textPaint)
        }

        return annotated
    }

    fun close() {
        try {
            interpreter?.close()
            interpreter = null
        } catch (e: Exception) {
            Log.w(TAG, "Error closing interpreter: ${e.message}")
        }
    }
}
