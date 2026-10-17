package pk.gov.power.disco_meter_reader

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

private const val CHANNEL = "pk.gov.power.disco_meter_reader/meter_detector"
private const val TAG = "MainActivity"
private const val REQUEST_PICK_IMAGE = 1001
private const val REQUEST_CAPTURE_IMAGE = 1002

class MainActivity : FlutterActivity() {

    private var meterDetector: MeterDetector? = null
    private val backgroundExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var pendingImageCallback: MethodChannel.Result? = null
    private var cameraTempFile: File? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize MeterDetector once on startup on background thread and warm it up
        backgroundExecutor.execute {
            try {
                meterDetector = MeterDetector(applicationContext)
                Log.i(TAG, "MeterDetector instance ready in MainActivity")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize MeterDetector in background: ${e.message}", e)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "detectMeter" -> {
                    val imagePath = call.argument<String>("imagePath")
                    if (imagePath.isNullOrEmpty()) {
                        result.error("INVALID_ARG", "imagePath is required", null)
                        return@setMethodCallHandler
                    }
                    runDetectionAsync(imagePath, result)
                }
                "pickImage" -> {
                    pendingImageCallback = result
                    try {
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "image/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        startActivityForResult(
                            Intent.createChooser(intent, "Select Meter Photo"),
                            REQUEST_PICK_IMAGE
                        )
                    } catch (e: Exception) {
                        Log.e(TAG, "Error launching photo picker: ${e.message}", e)
                        pendingImageCallback = null
                        result.error("PICK_LAUNCH_ERROR", e.message, null)
                    }
                }
                "captureImage" -> {
                    pendingImageCallback = result
                    try {
                        val file = File(cacheDir, "camera_meter_${System.currentTimeMillis()}.jpg")
                        cameraTempFile = file
                        val uri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )
                        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                            putExtra(MediaStore.EXTRA_OUTPUT, uri)
                            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivityForResult(intent, REQUEST_CAPTURE_IMAGE)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error launching camera: ${e.message}", e)
                        pendingImageCallback = null
                        result.error("CAMERA_LAUNCH_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val callback = pendingImageCallback
        pendingImageCallback = null
        if (callback == null) return

        if (resultCode != RESULT_OK) {
            callback.success(null)
            return
        }

        when (requestCode) {
            REQUEST_PICK_IMAGE -> {
                val uri = data?.data
                if (uri != null) {
                    backgroundExecutor.execute {
                        try {
                            val tempFile = File(cacheDir, "picked_meter_${System.currentTimeMillis()}.jpg")
                            contentResolver.openInputStream(uri)?.use { input ->
                                FileOutputStream(tempFile).use { output ->
                                    input.copyTo(output)
                                }
                            }
                            mainHandler.post { callback.success(tempFile.absolutePath) }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error copying picked image: ${e.message}", e)
                            mainHandler.post { callback.error("PICK_ERROR", e.message, null) }
                        }
                    }
                } else {
                    callback.success(null)
                }
            }
            REQUEST_CAPTURE_IMAGE -> {
                val file = cameraTempFile
                if (file != null && file.exists() && file.length() > 0L) {
                    callback.success(file.absolutePath)
                } else {
                    callback.success(null)
                }
            }
        }
    }

    private fun decodeSafely(imagePath: String, maxDim: Int = 2560): Bitmap? {
        val file = File(imagePath)
        if (!file.exists() || file.length() == 0L) {
            Log.e(TAG, "Image file does not exist or is empty: $imagePath")
            return null
        }

        // Check image bounds first to prevent OutOfMemoryError on extreme resolution photos
        val boundsOptions = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(imagePath, boundsOptions)
        val origW = boundsOptions.outWidth
        val origH = boundsOptions.outHeight
        if (origW <= 0 || origH <= 0) {
            Log.e(TAG, "Invalid image dimensions decoded for file: $imagePath")
            return null
        }

        var inSampleSize = 1
        if (origW > maxDim || origH > maxDim) {
            val halfW = origW / 2
            val halfH = origH / 2
            while ((halfW / inSampleSize) >= maxDim || (halfH / inSampleSize) >= maxDim) {
                inSampleSize *= 2
            }
        }

        val decodeOptions = BitmapFactory.Options().apply {
            this.inSampleSize = inSampleSize
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val decoded = BitmapFactory.decodeFile(imagePath, decodeOptions) ?: return null
        return try {
            val exif = android.media.ExifInterface(imagePath)
            val orientation = exif.getAttributeInt(
                android.media.ExifInterface.TAG_ORIENTATION,
                android.media.ExifInterface.ORIENTATION_NORMAL
            )
            val rotationDegrees = when (orientation) {
                android.media.ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                android.media.ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                android.media.ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
            if (rotationDegrees != 0f) {
                val matrix = android.graphics.Matrix().apply { postRotate(rotationDegrees) }
                val rotated = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
                if (rotated != decoded) decoded.recycle()
                rotated
            } else {
                decoded
            }
        } catch (e: Exception) {
            Log.w(TAG, "EXIF rotation adjustment error (non-fatal): ${e.message}")
            decoded
        }
    }

    private fun runDetectionAsync(imagePath: String, result: MethodChannel.Result) {
        backgroundExecutor.execute {
            try {
                var detector = meterDetector
                if (detector == null) {
                    detector = MeterDetector(applicationContext)
                    meterDetector = detector
                }

                val originalBitmap = decodeSafely(imagePath)
                if (originalBitmap == null) {
                    mainHandler.post {
                        result.success(
                            mapOf(
                                "found" to false,
                                "decision" to "No meter found, retake",
                                "message" to "Unable to decode image safely. Please select or capture another photo."
                            )
                        )
                    }
                    return@execute
                }

                // Execute detection with confidence threshold 0.25 (to capture Uncertain cases per Section 7)
                val detection = detector.detect(originalBitmap, confThr = 0.25f, nmsThr = 0.45f)

                if (detection == null) {
                    originalBitmap.recycle()
                    mainHandler.post {
                        result.success(
                            mapOf(
                                "found" to false,
                                "decision" to "No meter found, retake",
                                "message" to "No display counter detected. Please ensure the meter is clearly visible and retake the photo."
                            )
                        )
                    }
                    return@execute
                }

                // 1. Perspective warp straight crop from original photo
                val cropBitmap = detector.warpCrop(originalBitmap, detection.corners)
                var cropFilePath: String? = null
                if (cropBitmap != null) {
                    val cropFile = File(cacheDir, "crop_${System.currentTimeMillis()}.png")
                    FileOutputStream(cropFile).use { out ->
                        cropBitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                    }
                    cropFilePath = cropFile.absolutePath
                    cropBitmap.recycle()
                }

                // 2. Draw annotated rotated bounding box overlay on copy of original
                val annotatedBitmap = detector.drawDetectionOverlay(originalBitmap, detection)
                val annotatedFile = File(cacheDir, "annotated_${System.currentTimeMillis()}.jpg")
                FileOutputStream(annotatedFile).use { out ->
                    annotatedBitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
                }
                val annotatedFilePath = annotatedFile.absolutePath

                annotatedBitmap.recycle()
                originalBitmap.recycle()

                val resultMap = mapOf(
                    "found" to true,
                    "cls" to detection.cls,
                    "className" to detection.className,
                    "conf" to detection.conf.toDouble(),
                    "decision" to detection.decision,
                    "inferenceTimeMs" to detection.inferenceTimeMs,
                    "numBoxesFound" to detection.numBoxesFound,
                    "annotatedImagePath" to annotatedFilePath,
                    "croppedImagePath" to cropFilePath,
                    "corners" to detection.corners.map { mapOf("x" to it.x.toDouble(), "y" to it.y.toDouble()) }
                )

                mainHandler.post { result.success(resultMap) }
            } catch (e: Exception) {
                Log.e(TAG, "Unexpected error in runDetectionAsync: ${e.message}", e)
                mainHandler.post {
                    result.success(
                        mapOf(
                            "found" to false,
                            "decision" to "No meter found, retake",
                            "error" to (e.message ?: "Unknown error occurred during detection")
                        )
                    )
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        meterDetector?.close()
        backgroundExecutor.shutdown()
    }
}
