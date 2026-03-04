"""
TrackNetV3 — Shuttlecock tracking using deep learning.
Architecture: U-Net encoder-decoder for heatmap-based ball detection.
Reference: https://github.com/qaz812345/TrackNetV3

Input: 3 consecutive RGB frames (9-channel, 512×288)
Output: Per-frame heatmap → (x, y) shuttlecock coordinates
"""

import os
import math
import cv2
import numpy as np
import torch
import torch.nn as nn

# ──────────────────────────────────────────────
# TrackNet Model Architecture (U-Net variant)
# ──────────────────────────────────────────────

def _conv_block(in_ch, out_ch, num_layers=2):
    layers = []
    for i in range(num_layers):
        layers.append(nn.Conv2d(in_ch if i == 0 else out_ch, out_ch, 3, padding=1))
        layers.append(nn.BatchNorm2d(out_ch))
        layers.append(nn.ReLU(inplace=True))
    return nn.Sequential(*layers)


class TrackNetModel(nn.Module):
    """
    TrackNet: U-Net based shuttlecock detector.
    Input: (B, 9, 288, 512) — 3 consecutive RGB frames concatenated
    Output: (B, 3, 288, 512) — heatmap for each frame
    """
    def __init__(self, in_channels=9, out_channels=3):
        super().__init__()
        # Encoder
        self.enc1 = _conv_block(in_channels, 64, 2)
        self.enc2 = _conv_block(64, 128, 2)
        self.enc3 = _conv_block(128, 256, 3)
        self.enc4 = _conv_block(256, 512, 3)

        self.pool = nn.MaxPool2d(2, 2)

        # Decoder
        self.up4 = nn.ConvTranspose2d(512, 256, 2, stride=2)
        self.dec4 = _conv_block(512, 256, 3)
        self.up3 = nn.ConvTranspose2d(256, 128, 2, stride=2)
        self.dec3 = _conv_block(256, 128, 2)
        self.up2 = nn.ConvTranspose2d(128, 64, 2, stride=2)
        self.dec2 = _conv_block(128, 64, 2)

        self.final = nn.Conv2d(64, out_channels, 1)
        self.sigmoid = nn.Sigmoid()

    def forward(self, x):
        e1 = self.enc1(x)
        e2 = self.enc2(self.pool(e1))
        e3 = self.enc3(self.pool(e2))
        e4 = self.enc4(self.pool(e3))

        d4 = self.dec4(torch.cat([self.up4(e4), e3], dim=1))
        d3 = self.dec3(torch.cat([self.up3(d4), e2], dim=1))
        d2 = self.dec2(torch.cat([self.up2(d3), e1], dim=1))

        return self.sigmoid(self.final(d2))


# ──────────────────────────────────────────────
# Inference Wrapper
# ──────────────────────────────────────────────

INPUT_HEIGHT = 288
INPUT_WIDTH = 512
HEATMAP_THRESHOLD = 0.5

_model = None
_device = None


def _load_model():
    """Load TrackNet model (singleton). Supports both custom and official weights."""
    global _model, _device

    if _model is not None:
        return _model

    _device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    # Check for pretrained weights
    weight_paths = [
        os.path.join(os.path.dirname(__file__), "..", "models", "TrackNet_best.pt"),
        os.path.join(os.path.dirname(__file__), "..", "ckpts", "TrackNet_best.pt"),
    ]

    model = TrackNetModel(in_channels=9, out_channels=3)

    for path in weight_paths:
        if os.path.exists(path):
            print(f"[TrackNet] Loading weights from {path}")
            state_dict = torch.load(path, map_location=_device, weights_only=True)
            # Handle different checkpoint formats
            if "model_state_dict" in state_dict:
                state_dict = state_dict["model_state_dict"]
            model.load_state_dict(state_dict, strict=False)
            break
    else:
        print("[TrackNet] WARNING: No pretrained weights found. Run scripts/download_models.sh")
        print("[TrackNet] Model will produce random outputs until weights are loaded.")

    model = model.to(_device)
    model.eval()
    _model = model
    print(f"[TrackNet] Model loaded on {_device}")
    return _model


def _preprocess_frames(frames):
    """Preprocess 3 consecutive frames for TrackNet input."""
    processed = []
    for frame in frames:
        resized = cv2.resize(frame, (INPUT_WIDTH, INPUT_HEIGHT))
        rgb = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)
        normalized = rgb.astype(np.float32) / 255.0
        processed.append(normalized)

    # Concatenate 3 frames along channel axis: (H, W, 9)
    concatenated = np.concatenate(processed, axis=2)
    # Convert to (1, 9, H, W)
    tensor = torch.from_numpy(concatenated).permute(2, 0, 1).unsqueeze(0)
    return tensor


def _heatmap_to_coordinate(heatmap, orig_w, orig_h):
    """Extract (x, y) from heatmap, scale to original resolution."""
    heatmap_np = heatmap.squeeze().cpu().numpy()

    if heatmap_np.max() < HEATMAP_THRESHOLD:
        return None, 0.0

    # Find peak location
    y_idx, x_idx = np.unravel_index(heatmap_np.argmax(), heatmap_np.shape)
    confidence = float(heatmap_np.max())

    # Scale to original resolution
    x = int(x_idx * orig_w / INPUT_WIDTH)
    y = int(y_idx * orig_h / INPUT_HEIGHT)

    return (x, y), confidence


def run_tracknet_v3(video_path: str) -> list:
    """
    Run TrackNetV3 shuttlecock tracking on a video.

    Args:
        video_path: Path to the video file

    Returns:
        List of dicts: [{"frame": int, "x": int, "y": int, "confidence": float}, ...]
        Empty list if tracking fails.
    """
    model = _load_model()

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"[TrackNet] Failed to open video: {video_path}")
        return []

    orig_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    orig_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    # Read all frames
    frames = []
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        frames.append(frame)
    cap.release()

    if len(frames) < 3:
        print("[TrackNet] Video too short (< 3 frames)")
        return []

    print(f"[TrackNet] Processing {len(frames)} frames...")

    results = []

    with torch.no_grad():
        for i in range(len(frames) - 2):
            # Take 3 consecutive frames
            triplet = [frames[i], frames[i + 1], frames[i + 2]]
            input_tensor = _preprocess_frames(triplet).to(_device)

            # Predict
            output = model(input_tensor)

            # Extract coordinates from the middle frame's heatmap (channel 1)
            heatmap = output[0, 1]  # Middle frame
            coord, conf = _heatmap_to_coordinate(heatmap, orig_w, orig_h)

            if coord is not None:
                results.append({
                    "frame": i + 1,
                    "x": coord[0],
                    "y": coord[1],
                    "confidence": round(conf, 3),
                })

            if (i + 1) % 50 == 0:
                print(f"[TrackNet] {i + 1}/{len(frames) - 2} frames processed")

    print(f"[TrackNet] Detected shuttlecock in {len(results)}/{len(frames)} frames")
    return results
