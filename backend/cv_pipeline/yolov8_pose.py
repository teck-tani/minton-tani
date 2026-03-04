"""
YOLOv8-Pose — Badminton player pose estimation and swing detection.
Uses ultralytics YOLOv8-Pose for real-time 17-keypoint detection,
then analyzes arm motion to detect swing actions.

Reference: https://docs.ultralytics.com/tasks/pose/
"""

import os
import math
import cv2
import numpy as np

# Lazy import to avoid startup cost if not used
_model = None

# COCO 17-keypoint indices
NOSE = 0
LEFT_SHOULDER = 5
RIGHT_SHOULDER = 6
LEFT_ELBOW = 7
RIGHT_ELBOW = 8
LEFT_WRIST = 9
RIGHT_WRIST = 10
LEFT_HIP = 11
RIGHT_HIP = 12
LEFT_KNEE = 13
RIGHT_KNEE = 14
LEFT_ANKLE = 15
RIGHT_ANKLE = 16

# Swing detection thresholds
WRIST_VELOCITY_THRESHOLD = 30  # pixels/frame for swing start
ARM_RAISE_ANGLE_THRESHOLD = 100  # shoulder angle indicating overhead motion


def _load_model():
    """Load YOLOv8-Pose model (singleton)."""
    global _model
    if _model is not None:
        return _model

    from ultralytics import YOLO

    # Check for custom badminton-trained model first
    custom_paths = [
        os.path.join(os.path.dirname(__file__), "..", "models", "yolov8_badminton_pose.pt"),
        os.path.join(os.path.dirname(__file__), "..", "models", "yolov8m-pose.pt"),
    ]

    for path in custom_paths:
        if os.path.exists(path):
            print(f"[YOLOv8-Pose] Loading custom model: {path}")
            _model = YOLO(path)
            return _model

    # Fall back to pretrained YOLOv8m-pose (auto-downloads ~50MB)
    print("[YOLOv8-Pose] Loading pretrained yolov8m-pose.pt")
    _model = YOLO("yolov8m-pose.pt")
    return _model


def _calculate_angle(p1, p2, p3):
    """Calculate angle at p2 between p1-p2-p3."""
    v1 = (p1[0] - p2[0], p1[1] - p2[1])
    v2 = (p3[0] - p2[0], p3[1] - p2[1])
    dot = v1[0] * v2[0] + v1[1] * v2[1]
    mag1 = math.sqrt(v1[0]**2 + v1[1]**2)
    mag2 = math.sqrt(v2[0]**2 + v2[1]**2)
    if mag1 == 0 or mag2 == 0:
        return 0
    cos_a = max(-1.0, min(1.0, dot / (mag1 * mag2)))
    return math.acos(cos_a) * 180 / math.pi


def _detect_swing_phases(frame_keypoints: list) -> list:
    """
    Analyze keypoint sequences to detect swing action phases.
    A badminton smash swing has: preparation → backswing → forward swing → impact → follow-through

    Returns list of swing action dicts:
    [{"action": "swing", "start_frame": int, "end_frame": int,
      "confidence": float, "phase_frames": {...}}]
    """
    if len(frame_keypoints) < 5:
        return []

    # Track dominant wrist velocity across frames
    wrist_velocities = []
    shoulder_angles = []

    for i in range(1, len(frame_keypoints)):
        prev_kp = frame_keypoints[i - 1]
        curr_kp = frame_keypoints[i]
        if prev_kp is None or curr_kp is None:
            wrist_velocities.append(0)
            shoulder_angles.append(0)
            continue

        # Calculate wrist velocity (max of left/right)
        vel_left = 0
        vel_right = 0
        if prev_kp[LEFT_WRIST][2] > 0.3 and curr_kp[LEFT_WRIST][2] > 0.3:
            dx = curr_kp[LEFT_WRIST][0] - prev_kp[LEFT_WRIST][0]
            dy = curr_kp[LEFT_WRIST][1] - prev_kp[LEFT_WRIST][1]
            vel_left = math.sqrt(dx**2 + dy**2)
        if prev_kp[RIGHT_WRIST][2] > 0.3 and curr_kp[RIGHT_WRIST][2] > 0.3:
            dx = curr_kp[RIGHT_WRIST][0] - prev_kp[RIGHT_WRIST][0]
            dy = curr_kp[RIGHT_WRIST][1] - prev_kp[RIGHT_WRIST][1]
            vel_right = math.sqrt(dx**2 + dy**2)

        wrist_velocities.append(max(vel_left, vel_right))

        # Calculate shoulder angle (arm raise)
        kp = curr_kp
        angle = 0
        if kp[RIGHT_ELBOW][2] > 0.3 and kp[RIGHT_SHOULDER][2] > 0.3 and kp[RIGHT_HIP][2] > 0.3:
            angle = max(angle, _calculate_angle(
                kp[RIGHT_ELBOW][:2], kp[RIGHT_SHOULDER][:2], kp[RIGHT_HIP][:2]))
        if kp[LEFT_ELBOW][2] > 0.3 and kp[LEFT_SHOULDER][2] > 0.3 and kp[LEFT_HIP][2] > 0.3:
            angle = max(angle, _calculate_angle(
                kp[LEFT_ELBOW][:2], kp[LEFT_SHOULDER][:2], kp[LEFT_HIP][:2]))
        shoulder_angles.append(angle)

    # Find swing events: high wrist velocity + arm raised
    swings = []
    in_swing = False
    swing_start = 0

    for i in range(len(wrist_velocities)):
        is_active = (wrist_velocities[i] > WRIST_VELOCITY_THRESHOLD and
                     shoulder_angles[i] > ARM_RAISE_ANGLE_THRESHOLD)

        if is_active and not in_swing:
            # Look back for preparation phase (arm starting to raise)
            swing_start = i
            for j in range(max(0, i - 10), i):
                if shoulder_angles[j] > 60:
                    swing_start = j
                    break
            in_swing = True

        elif not is_active and in_swing:
            # End of swing — add follow-through frames
            swing_end = min(i + 5, len(wrist_velocities))

            # Find peak velocity frame (impact)
            peak_frame = swing_start + np.argmax(wrist_velocities[swing_start:swing_end])
            peak_vel = wrist_velocities[peak_frame] if peak_frame < len(wrist_velocities) else 0

            swings.append({
                "action": "swing",
                "start_frame": swing_start + 1,  # +1 because velocities are offset by 1
                "end_frame": swing_end + 1,
                "confidence": round(min(1.0, peak_vel / 60), 2),
                "peak_frame": peak_frame + 1,
                "peak_wrist_velocity": round(peak_vel, 1),
            })
            in_swing = False

    # Handle case where swing continues to end of video
    if in_swing:
        swing_end = len(wrist_velocities)
        peak_frame = swing_start + np.argmax(wrist_velocities[swing_start:swing_end])
        peak_vel = wrist_velocities[peak_frame] if peak_frame < len(wrist_velocities) else 0
        swings.append({
            "action": "swing",
            "start_frame": swing_start + 1,
            "end_frame": swing_end + 1,
            "confidence": round(min(1.0, peak_vel / 60), 2),
            "peak_frame": peak_frame + 1,
            "peak_wrist_velocity": round(peak_vel, 1),
        })

    return swings


def run_yolov8_pose(video_path: str) -> dict:
    """
    Run YOLOv8-Pose on a video to detect player keypoints and swing actions.

    Args:
        video_path: Path to the video file

    Returns:
        Dict with:
        - "swings": list of detected swing actions
        - "keypoints_per_frame": list of 17-keypoint arrays per frame
        - "keypoints_2d": numpy array (N, 17, 2) for 3D lifting input
    """
    model = _load_model()

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"[YOLOv8-Pose] Failed to open video: {video_path}")
        return {"swings": [], "keypoints_per_frame": [], "keypoints_2d": None}

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    frame_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    frame_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    frame_keypoints = []
    frame_idx = 0

    print(f"[YOLOv8-Pose] Processing {total_frames} frames...")

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        # Run YOLO pose estimation
        results = model(frame, verbose=False)

        if results and len(results[0].keypoints) > 0:
            # Take the person with highest confidence (main player)
            kp_data = results[0].keypoints.data  # (num_persons, 17, 3)
            if len(kp_data) > 0:
                # Pick person closest to center or with highest score
                best_idx = 0
                if len(kp_data) > 1:
                    # Choose person with highest average keypoint confidence
                    avg_confs = [kp[:, 2].mean().item() for kp in kp_data]
                    best_idx = int(np.argmax(avg_confs))

                kp = kp_data[best_idx].cpu().numpy()  # (17, 3) — x, y, confidence
                frame_keypoints.append(kp)
            else:
                frame_keypoints.append(None)
        else:
            frame_keypoints.append(None)

        frame_idx += 1
        if frame_idx % 50 == 0:
            print(f"[YOLOv8-Pose] {frame_idx}/{total_frames} frames")

    cap.release()
    print(f"[YOLOv8-Pose] Processed {frame_idx} frames, "
          f"{sum(1 for k in frame_keypoints if k is not None)} with detections")

    # Detect swing phases from keypoint sequence
    swings = _detect_swing_phases(frame_keypoints)
    print(f"[YOLOv8-Pose] Detected {len(swings)} swing actions")

    # Build normalized 2D keypoints array for 3D lifting
    # Normalize to [-1, 1] range centered on frame
    keypoints_2d = []
    for kp in frame_keypoints:
        if kp is not None:
            normalized = np.zeros((17, 2), dtype=np.float32)
            normalized[:, 0] = (kp[:, 0] / frame_w) * 2 - 1  # x: [-1, 1]
            normalized[:, 1] = (kp[:, 1] / frame_h) * 2 - 1  # y: [-1, 1]
            keypoints_2d.append(normalized)
        else:
            # Fill with zeros for missing frames
            keypoints_2d.append(np.zeros((17, 2), dtype=np.float32))

    keypoints_2d_array = np.array(keypoints_2d)  # (N, 17, 2)

    return {
        "swings": swings,
        "keypoints_per_frame": frame_keypoints,
        "keypoints_2d": keypoints_2d_array,
    }
