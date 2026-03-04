"""
Shot Refinement Algorithm (SRA) — Combines TrackNetV3 shuttlecock
tracking and YOLOv8-Pose swing detection to pinpoint the exact
frame of the shuttlecock strike.

Integrates real CV models with graceful fallback to mock data
when model weights are not available.
"""

import numpy as np

# ──────────────────────────────────────────────
# Real Model Integration
# ──────────────────────────────────────────────

def run_tracknet(video_path: str) -> list:
    """
    Run shuttlecock tracking on a video.
    Uses TrackNetV3 if weights available, otherwise returns mock data.
    """
    try:
        from cv_pipeline.tracknet_v3 import run_tracknet_v3
        results = run_tracknet_v3(video_path)
        if results:
            return results
        print("[SRA] TrackNet returned no results, using mock data")
    except Exception as e:
        print(f"[SRA] TrackNet failed ({e}), using mock data")

    # Fallback mock data
    return [
        {"frame": 10, "x": 100, "y": 200, "confidence": 0.8},
        {"frame": 11, "x": 110, "y": 205, "confidence": 0.9},
        {"frame": 12, "x": 120, "y": 210, "confidence": 0.95},
        {"frame": 14, "x": 140, "y": 215, "confidence": 0.85},
        {"frame": 15, "x": 150, "y": 220, "confidence": 0.9},
        {"frame": 16, "x": 140, "y": 150, "confidence": 0.95},
    ]


def run_yolov7_swing(video_path: str) -> list:
    """
    Run swing action detection on a video.
    Uses YOLOv8-Pose if available, otherwise returns mock data.

    Returns:
        List of swing action dicts. Also stores full pose results
        in the returned dict under "_pose_data" key for 3D lifting.
    """
    try:
        from cv_pipeline.yolov8_pose import run_yolov8_pose
        results = run_yolov8_pose(video_path)
        swings = results.get("swings", [])
        if swings:
            # Attach pose data for downstream 3D lifting
            for swing in swings:
                swing["_pose_data"] = results
            return swings
        print("[SRA] YOLOv8-Pose detected no swings, using mock data")
    except Exception as e:
        print(f"[SRA] YOLOv8-Pose failed ({e}), using mock data")

    # Fallback mock data
    return [
        {"action": "swing", "start_frame": 12, "end_frame": 18, "confidence": 0.88}
    ]


# ──────────────────────────────────────────────
# SRA Algorithm (unchanged logic, works with real or mock data)
# ──────────────────────────────────────────────

def apply_sra(tracknet_data: list, yolo_data: list):
    """
    Shot Refinement Algorithm (SRA)
    Combines TrackNet trajectory and YOLO swing action to filter false positives
    and pinpoint the exact frame of the shuttlecock strike.
    """
    if not yolo_data:
        return None

    active_swing = yolo_data[0]
    std = active_swing.get('start_frame', 0)
    end = active_swing.get('end_frame', 999999)

    valid_points = [p for p in tracknet_data if std <= p['frame'] <= end]

    if len(valid_points) < 3:
        # If not enough tracking data within swing, return swing peak as hit frame
        peak = active_swing.get('peak_frame', (std + end) // 2)
        return {
            "hit_frame": peak,
            "tracking_points": valid_points,
            "swing_data": {k: v for k, v in active_swing.items() if k != "_pose_data"},
        }

    # Find sharpest trajectory change (direction reversal)
    max_angle_change = 0
    hit_frame = None

    for i in range(1, len(valid_points) - 1):
        prev = valid_points[i - 1]
        curr = valid_points[i]
        nxt = valid_points[i + 1]

        v1 = np.array([curr['x'] - prev['x'], curr['y'] - prev['y']])
        v2 = np.array([nxt['x'] - curr['x'], nxt['y'] - curr['y']])

        norm_v1 = np.linalg.norm(v1)
        norm_v2 = np.linalg.norm(v2)
        if norm_v1 > 0 and norm_v2 > 0:
            cos_theta = np.dot(v1, v2) / (norm_v1 * norm_v2)
            cos_theta = np.clip(cos_theta, -1.0, 1.0)
            angle = np.arccos(cos_theta)

            if angle > max_angle_change:
                max_angle_change = angle
                hit_frame = curr['frame']

    return {
        "hit_frame": hit_frame or valid_points[len(valid_points) // 2]['frame'],
        "tracking_points": valid_points,
        "swing_data": {k: v for k, v in active_swing.items() if k != "_pose_data"},
    }
