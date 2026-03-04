"""
MediaPipe Pose Annotator — processes a video with MediaPipe Pose,
draws skeleton overlay on each frame, encodes as H.264, uploads
the annotated video to Firebase Storage, and extracts biomechanical
angle data per frame for analysis.
"""

import math
import os
import subprocess
import tempfile
from statistics import mean

import cv2
import mediapipe as mp
import requests as http_requests
import firebase_admin
from firebase_admin import storage

# MediaPipe Pose landmark indices (matching Flutter PosePainter joints)
LEFT_SHOULDER = 11
RIGHT_SHOULDER = 12
LEFT_ELBOW = 13
RIGHT_ELBOW = 14
LEFT_WRIST = 15
RIGHT_WRIST = 16
LEFT_HIP = 23
RIGHT_HIP = 24
LEFT_KNEE = 25
RIGHT_KNEE = 26
LEFT_ANKLE = 27
RIGHT_ANKLE = 28

# Skeleton connections grouped by color (same as pose_painter.dart)
CENTER_CONNECTIONS = [
    (LEFT_SHOULDER, RIGHT_SHOULDER),
    (LEFT_HIP, RIGHT_HIP),
]
LEFT_CONNECTIONS = [
    (LEFT_SHOULDER, LEFT_ELBOW),
    (LEFT_ELBOW, LEFT_WRIST),
    (LEFT_SHOULDER, LEFT_HIP),
    (LEFT_HIP, LEFT_KNEE),
    (LEFT_KNEE, LEFT_ANKLE),
]
RIGHT_CONNECTIONS = [
    (RIGHT_SHOULDER, RIGHT_ELBOW),
    (RIGHT_ELBOW, RIGHT_WRIST),
    (RIGHT_SHOULDER, RIGHT_HIP),
    (RIGHT_HIP, RIGHT_KNEE),
    (RIGHT_KNEE, RIGHT_ANKLE),
]

# Colors (BGR for OpenCV) — matching pose_painter.dart
COLOR_CENTER = (127, 255, 0)   # greenAccent
COLOR_LEFT = (0, 255, 255)     # yellow
COLOR_RIGHT = (230, 105, 65)   # blueAccent
COLOR_DOT = (255, 255, 255)    # white
COLOR_DOT_OUTLINE = (127, 255, 0)

FIREBASE_STORAGE_BUCKET = "minton-smash-cv-app.firebasestorage.app"


def _calculate_angle(p1, center, p3):
    """Calculate angle at center point (degrees). Mirrors PosePainter._calculateAngle."""
    v1 = (p1[0] - center[0], p1[1] - center[1])
    v2 = (p3[0] - center[0], p3[1] - center[1])
    dot = v1[0] * v2[0] + v1[1] * v2[1]
    mag1 = math.sqrt(v1[0] ** 2 + v1[1] ** 2)
    mag2 = math.sqrt(v2[0] ** 2 + v2[1] ** 2)
    if mag1 == 0 or mag2 == 0:
        return 0
    cos_angle = max(-1.0, min(1.0, dot / (mag1 * mag2)))
    return math.acos(cos_angle) * 180 / math.pi


def _get_landmark_px(landmarks, idx, w, h):
    """Get landmark pixel coordinates."""
    lm = landmarks.landmark[idx]
    return int(lm.x * w), int(lm.y * h)


def _extract_frame_angles(landmarks, w, h):
    """Extract all joint angles and wrist positions from a single frame."""
    get = lambda idx: _get_landmark_px(landmarks, idx, w, h)

    left_elbow_angle = _calculate_angle(get(LEFT_SHOULDER), get(LEFT_ELBOW), get(LEFT_WRIST))
    right_elbow_angle = _calculate_angle(get(RIGHT_SHOULDER), get(RIGHT_ELBOW), get(RIGHT_WRIST))
    left_shoulder_angle = _calculate_angle(get(LEFT_ELBOW), get(LEFT_SHOULDER), get(LEFT_HIP))
    right_shoulder_angle = _calculate_angle(get(RIGHT_ELBOW), get(RIGHT_SHOULDER), get(RIGHT_HIP))
    left_knee_angle = _calculate_angle(get(LEFT_HIP), get(LEFT_KNEE), get(LEFT_ANKLE))
    right_knee_angle = _calculate_angle(get(RIGHT_HIP), get(RIGHT_KNEE), get(RIGHT_ANKLE))

    # Hip rotation: angle between shoulder midpoint-hip midpoint line and vertical
    ls, rs = get(LEFT_SHOULDER), get(RIGHT_SHOULDER)
    lh, rh = get(LEFT_HIP), get(RIGHT_HIP)
    shoulder_mid = ((ls[0] + rs[0]) / 2, (ls[1] + rs[1]) / 2)
    hip_mid = ((lh[0] + rh[0]) / 2, (lh[1] + rh[1]) / 2)
    # Angle between shoulder line and hip line (torso rotation)
    shoulder_vec = (rs[0] - ls[0], rs[1] - ls[1])
    hip_vec = (rh[0] - lh[0], rh[1] - lh[1])
    dot = shoulder_vec[0] * hip_vec[0] + shoulder_vec[1] * hip_vec[1]
    mag_s = math.sqrt(shoulder_vec[0]**2 + shoulder_vec[1]**2)
    mag_h = math.sqrt(hip_vec[0]**2 + hip_vec[1]**2)
    if mag_s > 0 and mag_h > 0:
        cos_rot = max(-1.0, min(1.0, dot / (mag_s * mag_h)))
        hip_rotation = math.acos(cos_rot) * 180 / math.pi
    else:
        hip_rotation = 0

    # Wrist positions for velocity calculation
    lw = get(LEFT_WRIST)
    rw = get(RIGHT_WRIST)

    return {
        "left_elbow": left_elbow_angle,
        "right_elbow": right_elbow_angle,
        "left_shoulder": left_shoulder_angle,
        "right_shoulder": right_shoulder_angle,
        "left_knee": left_knee_angle,
        "right_knee": right_knee_angle,
        "hip_rotation": hip_rotation,
        "left_wrist_pos": lw,
        "right_wrist_pos": rw,
        # Arm extension: max of elbow angles (higher = more extended)
        "arm_extension": max(left_elbow_angle, right_elbow_angle),
    }


def _compute_biomechanics_summary(frame_data_list: list, fps: float) -> dict:
    """
    Aggregate per-frame angle data into a biomechanics summary.
    Finds the impact frame (max arm extension) and extracts metrics at that point.
    """
    if not frame_data_list:
        return {}

    # Find the frame with maximum arm extension (likely the impact frame)
    impact_idx = max(range(len(frame_data_list)),
                     key=lambda i: frame_data_list[i]["arm_extension"])

    impact = frame_data_list[impact_idx]

    # Use the dominant arm (whichever elbow is more extended at impact)
    if impact["right_elbow"] >= impact["left_elbow"]:
        elbow_angle = impact["right_elbow"]
        shoulder_angle = impact["right_shoulder"]
        wrist_key = "right_wrist_pos"
    else:
        elbow_angle = impact["left_elbow"]
        shoulder_angle = impact["left_shoulder"]
        wrist_key = "left_wrist_pos"

    # Calculate wrist snap speed (pixels/second → normalized by frame height)
    wrist_snap_speed = 0.0
    if impact_idx > 0:
        prev = frame_data_list[impact_idx - 1]
        curr_w = impact[wrist_key]
        prev_w = prev[wrist_key]
        pixel_dist = math.sqrt((curr_w[0] - prev_w[0])**2 + (curr_w[1] - prev_w[1])**2)
        wrist_snap_speed = pixel_dist * fps  # pixels per second

    # Footwork score: based on knee angle stability and range
    knee_angles = [f["left_knee"] for f in frame_data_list] + [f["right_knee"] for f in frame_data_list]
    knee_angles = [a for a in knee_angles if a > 0]
    if knee_angles:
        knee_mean = mean(knee_angles)
        knee_std = (sum((a - knee_mean)**2 for a in knee_angles) / len(knee_angles)) ** 0.5
        # Good footwork: knees bent (90-140°) with low variance
        knee_range_score = max(0, min(100, 100 - abs(knee_mean - 120) * 1.5))
        knee_stability = max(0, min(100, 100 - knee_std * 2))
        footwork_score = (knee_range_score + knee_stability) / 2
    else:
        footwork_score = 50.0

    # Hip rotation: max rotation observed during the swing
    hip_rotations = [f["hip_rotation"] for f in frame_data_list if f["hip_rotation"] > 0]
    max_hip_rotation = max(hip_rotations) if hip_rotations else 0

    # Impact angle: shoulder angle at the impact frame (angle of arm relative to body)
    impact_angle = shoulder_angle

    # Overall score: weighted combination
    # Elbow fully extended (170-180°) → high score
    elbow_score = max(0, min(100, (elbow_angle - 100) * 100 / 80))
    # Shoulder angle (150-180°) → high hitting point
    shoulder_score = max(0, min(100, (shoulder_angle - 100) * 100 / 80))
    # Hip rotation (>15° = good rotation)
    hip_score = max(0, min(100, max_hip_rotation * 100 / 40))
    overall_score = (
        elbow_score * 0.3 +
        shoulder_score * 0.25 +
        footwork_score * 0.2 +
        hip_score * 0.15 +
        min(100, wrist_snap_speed / 30) * 0.1  # normalize wrist speed
    )

    return {
        "elbowAngle": round(elbow_angle, 1),
        "shoulderAngle": round(shoulder_angle, 1),
        "impactAngle": round(impact_angle, 1),
        "wristSnapSpeed": round(wrist_snap_speed, 1),
        "footwork": round(footwork_score, 1),
        "hipRotation": round(max_hip_rotation, 1),
        "overallScore": round(overall_score, 1),
        "impactFrame": impact_idx,
        "totalFrames": len(frame_data_list),
        "dominantSide": "right" if impact["right_elbow"] >= impact["left_elbow"] else "left",
        # Per-frame data summary for Gemini context
        "frameAngles": {
            "elbowAtImpact": round(elbow_angle, 1),
            "shoulderAtImpact": round(shoulder_angle, 1),
            "kneeAtImpact": round(impact.get("left_knee", 0), 1),
            "hipRotationMax": round(max_hip_rotation, 1),
        },
    }


def _draw_skeleton(frame, landmarks, w, h):
    """Draw skeleton overlay on a single frame."""

    def draw_connections(connections, color):
        for idx1, idx2 in connections:
            pt1 = _get_landmark_px(landmarks, idx1, w, h)
            pt2 = _get_landmark_px(landmarks, idx2, w, h)
            cv2.line(frame, pt1, pt2, color, 3, cv2.LINE_AA)

    # Draw connections
    draw_connections(CENTER_CONNECTIONS, COLOR_CENTER)
    draw_connections(LEFT_CONNECTIONS, COLOR_LEFT)
    draw_connections(RIGHT_CONNECTIONS, COLOR_RIGHT)

    # Draw landmark dots (all 33 points)
    for i in range(33):
        pt = _get_landmark_px(landmarks, i, w, h)
        cv2.circle(frame, pt, 4, COLOR_DOT, -1, cv2.LINE_AA)
        cv2.circle(frame, pt, 4, COLOR_DOT_OUTLINE, 1, cv2.LINE_AA)

    # Draw angle labels (matching PosePainter thresholds)
    _draw_angle_label(frame, landmarks, w, h,
                      LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST, "elbow")
    _draw_angle_label(frame, landmarks, w, h,
                      RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST, "elbow")
    _draw_angle_label(frame, landmarks, w, h,
                      LEFT_HIP, LEFT_KNEE, LEFT_ANKLE, "knee")
    _draw_angle_label(frame, landmarks, w, h,
                      RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE, "knee")
    _draw_angle_label(frame, landmarks, w, h,
                      LEFT_ELBOW, LEFT_SHOULDER, LEFT_HIP, "shoulder")
    _draw_angle_label(frame, landmarks, w, h,
                      RIGHT_ELBOW, RIGHT_SHOULDER, RIGHT_HIP, "shoulder")


def _draw_angle_label(frame, landmarks, w, h, idx1, idx_center, idx3, joint_type):
    """Draw angle label with color-coded background at the center joint."""
    p1 = _get_landmark_px(landmarks, idx1, w, h)
    pc = _get_landmark_px(landmarks, idx_center, w, h)
    p3 = _get_landmark_px(landmarks, idx3, w, h)

    angle = _calculate_angle(p1, pc, p3)
    if angle == 0:
        return

    # Color thresholds matching pose_painter.dart
    if joint_type == "elbow":
        if angle < 140:
            bg_color = (0, 0, 255)      # red
        elif angle < 155:
            bg_color = (0, 165, 255)    # orange
        else:
            bg_color = (0, 200, 0)      # green
    elif joint_type == "knee":
        if angle < 90:
            bg_color = (0, 0, 255)
        elif angle < 120:
            bg_color = (0, 165, 255)
        else:
            bg_color = (0, 200, 0)
    else:  # shoulder
        bg_color = (230, 105, 65)       # blueAccent

    text = f"{int(angle)}"
    font = cv2.FONT_HERSHEY_SIMPLEX
    font_scale = 0.45
    thickness = 1
    (tw, th), baseline = cv2.getTextSize(text, font, font_scale, thickness)

    # Position label slightly offset from joint
    lx = pc[0] + 15
    ly = pc[1] - 10
    pad = 4

    # Background rectangle
    cv2.rectangle(frame,
                  (lx - pad, ly - th - pad),
                  (lx + tw + pad, ly + pad),
                  bg_color, -1, cv2.LINE_AA)
    # Degree text
    cv2.putText(frame, text, (lx, ly),
                font, font_scale, (255, 255, 255), thickness, cv2.LINE_AA)


def annotate_video_with_pose(video_url: str, user_id: str, analysis_id: str) -> tuple[str | None, dict]:
    """
    Download video, run MediaPipe Pose on each frame, draw skeleton,
    encode as H.264 MP4, upload to Firebase Storage.

    Returns (annotated_video_url, biomechanics_data).
    biomechanics_data contains real joint angles extracted from MediaPipe.
    """
    tmp_input = None
    tmp_raw_output = None
    tmp_h264_output = None

    try:
        # 1. Download video
        print(f"[MediaPipe] Downloading video: {video_url[:80]}...")
        resp = http_requests.get(video_url, stream=True, timeout=120)
        resp.raise_for_status()

        tmp_input = tempfile.NamedTemporaryFile(suffix=".mp4", delete=False)
        for chunk in resp.iter_content(chunk_size=8192):
            tmp_input.write(chunk)
        tmp_input.close()
        input_path = tmp_input.name

        # 2. Open video
        cap = cv2.VideoCapture(input_path)
        if not cap.isOpened():
            print("[MediaPipe] Failed to open video")
            return None, {}

        fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        print(f"[MediaPipe] Video: {width}x{height} @ {fps}fps, {total_frames} frames")

        # 3. Prepare output writer (mp4v, then re-encode to H.264)
        tmp_raw_output = tempfile.NamedTemporaryFile(suffix=".mp4", delete=False)
        tmp_raw_output.close()
        raw_output_path = tmp_raw_output.name

        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        writer = cv2.VideoWriter(raw_output_path, fourcc, fps, (width, height))

        # 4. Process frames with MediaPipe Pose and collect angle data
        mp_pose = mp.solutions.pose
        frame_count = 0
        frame_data_list = []

        with mp_pose.Pose(
            static_image_mode=False,
            model_complexity=1,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5,
        ) as pose:
            while cap.isOpened():
                ret, frame = cap.read()
                if not ret:
                    break

                rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                results = pose.process(rgb)

                if results.pose_landmarks:
                    _draw_skeleton(frame, results.pose_landmarks, width, height)
                    angles = _extract_frame_angles(results.pose_landmarks, width, height)
                    frame_data_list.append(angles)

                writer.write(frame)
                frame_count += 1

                if frame_count % 100 == 0:
                    print(f"[MediaPipe] Processed {frame_count}/{total_frames} frames")

        cap.release()
        writer.release()
        print(f"[MediaPipe] Processed {frame_count} frames total, {len(frame_data_list)} with pose")

        # Compute biomechanics summary from collected frame data
        biomechanics = _compute_biomechanics_summary(frame_data_list, fps)

        # 5. Re-encode to H.264 with ffmpeg for mobile compatibility
        tmp_h264_output = tempfile.NamedTemporaryFile(suffix=".mp4", delete=False)
        tmp_h264_output.close()
        h264_path = tmp_h264_output.name

        ffmpeg_cmd = [
            "ffmpeg", "-y",
            "-i", raw_output_path,
            "-c:v", "libx264",
            "-preset", "fast",
            "-crf", "23",
            "-c:a", "copy",
            "-movflags", "+faststart",
            h264_path,
        ]
        result = subprocess.run(ffmpeg_cmd, capture_output=True, text=True, timeout=300)
        if result.returncode != 0:
            print(f"[MediaPipe] ffmpeg error: {result.stderr[:500]}")
            # Fallback: use the mp4v version
            h264_path = raw_output_path

        # 6. Upload to Firebase Storage
        storage_path = f"annotated_videos/{user_id}/{analysis_id}.mp4"
        print(f"[MediaPipe] Uploading to {storage_path}...")

        bucket = storage.bucket(FIREBASE_STORAGE_BUCKET)
        blob = bucket.blob(storage_path)
        blob.upload_from_filename(h264_path, content_type="video/mp4")
        blob.make_public()
        public_url = blob.public_url

        print(f"[MediaPipe] Upload complete: {public_url[:80]}...")
        return public_url, biomechanics

    except Exception as e:
        print(f"[MediaPipe] Annotation failed: {e}")
        return None, {}

    finally:
        # Cleanup temp files
        for tmp in [tmp_input, tmp_raw_output, tmp_h264_output]:
            if tmp and os.path.exists(tmp.name):
                try:
                    os.unlink(tmp.name)
                except OSError:
                    pass
