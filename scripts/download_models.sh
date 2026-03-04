#!/usr/bin/env bash
# ──────────────────────────────────────────────
# Download pretrained model weights for CV pipeline
# Usage: bash scripts/download_models.sh
# ──────────────────────────────────────────────
set -euo pipefail

MODEL_DIR="backend/models"
mkdir -p "$MODEL_DIR"

echo "=== Downloading model weights to $MODEL_DIR ==="

# ── 1. TrackNetV3 (shuttlecock tracking) ──
# Source: https://github.com/qaz812345/TrackNetV3
TRACKNET_URL="https://nycu1-my.sharepoint.com/:u:/g/personal/tik_m365_nycu_edu_tw/EXbKAOuVNKZPn1THOE6KNioBu-6NTCZ7D4E2LY82tMXc4g?download=1"
TRACKNET_FILE="$MODEL_DIR/TrackNet_best.pt"
if [ -f "$TRACKNET_FILE" ]; then
    echo "[TrackNetV3] Already exists: $TRACKNET_FILE"
else
    echo "[TrackNetV3] Downloading TrackNet_best.pt..."
    echo "[TrackNetV3] NOTE: Auto-download may not work for SharePoint links."
    echo "[TrackNetV3] Manual download: https://github.com/qaz812345/TrackNetV3#pre-trained-models"
    echo "[TrackNetV3] Place the file at: $TRACKNET_FILE"
    # Attempt download (may fail for SharePoint)
    curl -L -o "$TRACKNET_FILE" "$TRACKNET_URL" 2>/dev/null || \
        echo "[TrackNetV3] Download failed. Please download manually."
fi

# ── 2. YOLOv8m-Pose (player pose estimation) ──
# Source: https://docs.ultralytics.com/tasks/pose/
YOLO_FILE="$MODEL_DIR/yolov8m-pose.pt"
if [ -f "$YOLO_FILE" ]; then
    echo "[YOLOv8-Pose] Already exists: $YOLO_FILE"
else
    echo "[YOLOv8-Pose] Downloading yolov8m-pose.pt..."
    curl -L -o "$YOLO_FILE" \
        "https://github.com/ultralytics/assets/releases/download/v8.2.0/yolov8m-pose.pt"
    echo "[YOLOv8-Pose] Done: $YOLO_FILE"
fi

# ── 3. MotionAGFormer-XS (2D→3D pose lifting) ──
# Source: https://github.com/TaatiTeam/MotionAGFormer
MOTION_FILE="$MODEL_DIR/motionagformer_xs.pt"
if [ -f "$MOTION_FILE" ]; then
    echo "[MotionAGFormer] Already exists: $MOTION_FILE"
else
    echo "[MotionAGFormer] NOTE: Official weights require manual download."
    echo "[MotionAGFormer] Download from: https://github.com/TaatiTeam/MotionAGFormer#pretrained-models"
    echo "[MotionAGFormer] Place the file at: $MOTION_FILE"
    echo "[MotionAGFormer] The model will run with random weights until pretrained weights are provided."
fi

echo ""
echo "=== Model download complete ==="
echo ""
echo "Files in $MODEL_DIR:"
ls -lh "$MODEL_DIR/" 2>/dev/null || echo "(empty)"
echo ""
echo "Next steps:"
echo "  1. If any downloads failed, follow the manual download links above"
echo "  2. Build Docker image: cd backend && docker build -t minton-smash-cv:gpu ."
echo "  3. Deploy to Cloud Run: gcloud run deploy --gpu 1 --gpu-type nvidia-l4"
