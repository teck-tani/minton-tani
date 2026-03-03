import numpy as np

def run_tracknet(video_path: str):
    """
    Mock function to simulate TrackNet shuttlecock tracking.
    In reality, this uses a PyTorch deep learning model to find the small ball.
    Returns: List of dicts with frame number and (x, y) coordinates of the shuttlecock.
    """
    # Dummy data: Shuttlecock appears and moves fast.
    return [
        {"frame": 10, "x": 100, "y": 200, "confidence": 0.8},
        {"frame": 11, "x": 110, "y": 205, "confidence": 0.9},
        {"frame": 12, "x": 120, "y": 210, "confidence": 0.95},
        # Sudden direction change implies hitting point (e.g., frame 15)
        {"frame": 14, "x": 140, "y": 215, "confidence": 0.85},
        {"frame": 15, "x": 150, "y": 220, "confidence": 0.9},
        {"frame": 16, "x": 140, "y": 150, "confidence": 0.95},
    ]

def run_yolov7_swing(video_path: str):
    """
    Mock function to simulate YOLOv7 player action recognition.
    Returns: List of dicts with timeframe for active 'swing' action.
    """
    return [
        {"action": "swing", "start_frame": 12, "end_frame": 18, "confidence": 0.88}
    ]

def apply_sra(tracknet_data: list, yolo_data: list):
    """
    Shot Refinement Algorithm (SRA)
    Combines TrackNet trajectory and YOLO swing action to filter false positives
    and pinpoint the exact frame of the shuttlecock strike.
    """
    # 1. Filter TrackNet points by YOLO swing bounds (temporal matching)
    if not yolo_data:
        return None

    # Assume we take the first localized swing action
    active_swing = yolo_data[0]
    std, end = active_swing['start_frame'], active_swing['end_frame']

    valid_points = [p for p in tracknet_data if std <= p['frame'] <= end]

    if len(valid_points) < 3:
        return None

    # 2. Find sharpest trajectory change (direction reversal or large vector change)
    max_angle_change = 0
    hit_frame = None

    for i in range(1, len(valid_points) - 1):
        prev = valid_points[i - 1]
        curr = valid_points[i]
        nxt = valid_points[i + 1]

        v1 = np.array([curr['x'] - prev['x'], curr['y'] - prev['y']])
        v2 = np.array([nxt['x'] - curr['x'], nxt['y'] - curr['y']])

        # Calculate angle
        norm_v1 = np.linalg.norm(v1)
        norm_v2 = np.linalg.norm(v2)
        if norm_v1 > 0 and norm_v2 > 0:
            cos_theta = np.dot(v1, v2) / (norm_v1 * norm_v2)
            # Clip cos_theta to valid range to avoid numerical issues
            cos_theta = np.clip(cos_theta, -1.0, 1.0)
            angle = np.arccos(cos_theta)

            if angle > max_angle_change:
                max_angle_change = angle
                hit_frame = curr['frame']

    return {
        "hit_frame": hit_frame or valid_points[len(valid_points)//2]['frame'],
        "tracking_points": valid_points
    }
