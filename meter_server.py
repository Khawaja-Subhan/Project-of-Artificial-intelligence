import os
import time
import base64
import numpy as np
import cv2
import tensorflow as tf
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

MODEL_PATH = os.path.join(os.path.dirname(__file__), "android", "app", "src", "main", "assets", "best.tflite")
print(f"Loading YOLO11n-OBB TFLite model from: {MODEL_PATH}")

interpreter = tf.lite.Interpreter(model_path=MODEL_PATH, num_threads=4)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()[0]
output_details = interpreter.get_output_details()[0]

# Model Warmup
dummy = np.zeros((1, 3, 640, 640), dtype=np.float32)
interpreter.set_tensor(input_details["index"], dummy)
interpreter.invoke()
print("Model initialized and warmed up successfully.")

def run_detection(img_bgr, conf_thr=0.25, nms_thr=0.45, size=640):
    t0 = time.perf_counter()
    h, w = img_bgr.shape[:2]
    s = min(size / w, size / h)
    nw, nh = round(w * s), round(h * s)
    pw, ph = int((size - nw) / 2), int((size - nh) / 2)

    canvas = np.full((size, size, 3), 114, np.uint8)
    canvas[ph:ph + nh, pw:pw + nw] = cv2.resize(img_bgr, (nw, nh))

    x = canvas[:, :, ::-1].astype(np.float32) / 255.0  # RGB, 0-1
    x = np.transpose(x, (2, 0, 1))[None]               # NCHW (1,3,640,640)

    interpreter.set_tensor(input_details["index"], x)
    interpreter.invoke()
    o = interpreter.get_tensor(output_details["index"])[0]  # (7, 8400)

    # rows: 0=cx, 1=cy, 2=w, 3=h, 4=digital, 5=analog, 6=angle
    boxes = o[:4].T * size
    scores = o[4:6].T
    ang = o[6]

    cls = scores.argmax(1)
    conf = scores.max(1)

    k = conf >= conf_thr
    boxes, conf, cls, ang = boxes[k], conf[k], cls[k], ang[k]

    elapsed_ms = int((time.perf_counter() - t0) * 1000)

    if not len(conf):
        print(f"[MeterDetector] Inference: {elapsed_ms}ms | No boxes >= {conf_thr}")
        return {
            "found": False,
            "decision": "No meter found, retake",
            "message": "No meter counter detected in photo. Please ensure display is visible and retake.",
            "inferenceTimeMs": elapsed_ms
        }

    rects = [((float(b[0]), float(b[1])), (float(b[2]), float(b[3])), float(np.degrees(a)))
             for b, a in zip(boxes, ang)]
    keep = np.array(cv2.dnn.NMSBoxesRotated(rects, conf.tolist(), conf_thr, nms_thr)).flatten()

    if not len(keep):
        print(f"[MeterDetector] Inference: {elapsed_ms}ms | No boxes survived NMS")
        return {
            "found": False,
            "decision": "No meter found, retake",
            "message": "Detection below confidence threshold after NMS. Retake photo.",
            "inferenceTimeMs": elapsed_ms
        }

    i = int(keep[conf[keep].argmax()])
    best_conf = float(conf[i])
    best_cls = int(cls[i])
    class_name = "digital_display" if best_cls == 0 else "analog_display"

    cx, cy, bw, bh = boxes[i]
    a = ang[i]
    v1 = np.array([bw / 2 * np.cos(a), bw / 2 * np.sin(a)])
    v2 = np.array([-bh / 2 * np.sin(a), bh / 2 * np.cos(a)])
    c = np.array([cx, cy])

    # Ultralytics corner vertices
    pts = np.array([c + v1 + v2, c + v1 - v2, c - v1 - v2, c - v1 + v2])
    pts[:, 0] = np.clip((pts[:, 0] - pw) / s, 0, w)
    pts[:, 1] = np.clip((pts[:, 1] - ph) / s, 0, h)

    # Decision rule (Section 7)
    if best_conf >= 0.50:
        decision = "Accepted"
    elif best_conf >= 0.25:
        decision = "Uncertain, manual check"
    else:
        decision = "No meter found, retake"

    print(f"[MeterDetector] Inference: {elapsed_ms}ms | Class: {class_name}({best_cls}) | Conf: {best_conf:.4f} | Decision: '{decision}' | Surviving: {len(keep)}")

    # Perspective warp crop from original full-resolution photo (Section 5)
    outW, outH = 480, 140
    by_y = pts[pts[:, 1].argsort()]
    top = by_y[:2][by_y[:2][:, 0].argsort()]
    bot = by_y[2:][by_y[2:][:, 0].argsort()]

    # Swap outW and outH if detected box is taller than wide (Section 5 note)
    top_w = np.linalg.norm(top[1] - top[0])
    left_h = np.linalg.norm(bot[0] - top[0])
    if left_h > top_w * 1.25:
        outW, outH = outH, outW

    src_pts = np.float32([top[0], top[1], bot[1], bot[0]])
    dst_pts = np.float32([[0, 0], [outW, 0], [outW, outH], [0, outH]])
    M = cv2.getPerspectiveTransform(src_pts, dst_pts)
    crop = cv2.warpPerspective(img_bgr, M, (outW, outH))

    # Annotated image overlay
    annotated = img_bgr.copy()
    box_int = pts.astype(np.int32)
    stroke_col = (16, 185, 129) if decision == "Accepted" else ((11, 158, 245) if decision == "Uncertain, manual check" else (68, 68, 239))  # BGR
    cv2.polylines(annotated, [box_int], isClosed=True, color=stroke_col, thickness=max(3, int(w / 200)))
    for p in box_int:
        cv2.circle(annotated, tuple(p), max(5, int(w / 160)), (255, 255, 255), -1)
        cv2.circle(annotated, tuple(p), max(5, int(w / 160)), stroke_col, 2)

    # Class label and confidence banner
    label_txt = f"{class_name.upper().replace('_', ' ')}: {best_conf*100:.1f}% ({decision})"
    font_scale = max(0.55, min(1.2, w / 900.0))
    thickness = max(1, int(font_scale * 2))
    (tw, th), baseline = cv2.getTextSize(label_txt, cv2.FONT_HERSHEY_SIMPLEX, font_scale, thickness)
    tx = int(pts[:, 0].min())
    ty = max(th + 10, int(pts[:, 1].min()) - 12)
    cv2.rectangle(annotated, (tx, ty - th - 6), (tx + tw + 10, ty + baseline), (15, 23, 42), -1)
    cv2.putText(annotated, label_txt, (tx + 5, ty - 2), cv2.FONT_HERSHEY_SIMPLEX, font_scale, (255, 255, 255), thickness, cv2.LINE_AA)

    # Encode images to JPEG / PNG base64
    _, ann_buf = cv2.imencode(".jpg", annotated, [cv2.IMWRITE_JPEG_QUALITY, 90])
    ann_b64 = base64.b64encode(ann_buf).decode("utf-8")

    _, crop_buf = cv2.imencode(".png", crop)
    crop_b64 = base64.b64encode(crop_buf).decode("utf-8")

    corners_list = [{"x": float(p[0]), "y": float(p[1])} for p in pts]

    return {
        "found": True,
        "cls": best_cls,
        "className": class_name,
        "conf": best_conf,
        "decision": decision,
        "corners": corners_list,
        "numBoxesFound": int(len(keep)),
        "inferenceTimeMs": elapsed_ms,
        "annotatedImageBase64": ann_b64,
        "cropImageBase64": crop_b64
    }

@app.route("/detect", methods=["POST"])
def detect_endpoint():
    try:
        if "file" in request.files:
            file_bytes = request.files["file"].read()
        elif request.data:
            file_bytes = request.data
        elif request.json and "image" in request.json:
            b64_str = request.json["image"]
            if "," in b64_str:
                b64_str = b64_str.split(",")[1]
            file_bytes = base64.b64decode(b64_str)
        else:
            return jsonify({"found": False, "decision": "No meter found, retake", "message": "No image data sent"}), 400

        nparr = np.frombuffer(file_bytes, np.uint8)
        img_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img_bgr is None:
            return jsonify({"found": False, "decision": "No meter found, retake", "message": "Unable to decode image"}), 400

        conf_thr = float(request.args.get("conf", 0.25))
        result = run_detection(img_bgr, conf_thr=conf_thr)
        return jsonify(result)
    except Exception as e:
        print(f"Error in /detect: {e}")
        return jsonify({"found": False, "decision": "No meter found, retake", "error": str(e)}), 500

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ready", "model": "YOLO11n-OBB TFLite", "input": [1, 3, 640, 640], "classes": ["digital_display", "analog_display"]})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5050, debug=False)
