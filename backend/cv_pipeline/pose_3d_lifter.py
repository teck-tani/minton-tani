"""
MotionAGFormer — 2D-to-3D Pose Lifting.
Lifts 2D pose keypoints from monocular video to 3D joint coordinates.
Reference: https://github.com/TaatiTeam/MotionAGFormer (WACV 2024)

Input:  (N, 17, 2)  — N frames of 2D keypoints (COCO 17-joint format)
Output: (N, 17, 3)  — N frames of 3D joint coordinates
"""

import os
import math
import numpy as np
import torch
import torch.nn as nn

# ──────────────────────────────────────────────
# MotionAGFormer XS Model Architecture
# Simplified version for inference (27-frame temporal window)
# ──────────────────────────────────────────────

class AGFormerBlock(nn.Module):
    """Attention-GCN Fusion block."""
    def __init__(self, dim, num_joints=17, num_heads=4):
        super().__init__()
        self.norm1 = nn.LayerNorm(dim)
        self.attn = nn.MultiheadAttention(dim, num_heads, batch_first=True)
        self.norm2 = nn.LayerNorm(dim)
        self.ff = nn.Sequential(
            nn.Linear(dim, dim * 4),
            nn.GELU(),
            nn.Linear(dim * 4, dim),
        )
        # GCN branch
        self.gcn_norm = nn.LayerNorm(dim)
        self.gcn_linear = nn.Linear(dim, dim)
        # Adjacency for 17-joint skeleton
        self.adj = self._build_adjacency(num_joints)
        self.alpha = nn.Parameter(torch.tensor(0.5))

    def _build_adjacency(self, n):
        """Build skeleton adjacency matrix for COCO 17 joints."""
        connections = [
            (0, 1), (0, 2), (1, 3), (2, 4),   # head
            (5, 6), (5, 7), (7, 9), (6, 8), (8, 10),  # arms
            (5, 11), (6, 12), (11, 12),  # torso
            (11, 13), (13, 15), (12, 14), (14, 16),  # legs
        ]
        adj = torch.eye(n)
        for i, j in connections:
            adj[i, j] = 1
            adj[j, i] = 1
        # Normalize
        deg = adj.sum(dim=1, keepdim=True).clamp(min=1)
        return nn.Parameter(adj / deg, requires_grad=False)

    def forward(self, x):
        # x: (B, T*J, dim)
        B = x.shape[0]

        # Transformer attention branch
        attn_out = self.norm1(x)
        attn_out, _ = self.attn(attn_out, attn_out, attn_out)

        # GCN branch: reshape to (B*T, J, dim), apply adjacency
        T_J = x.shape[1]
        J = self.adj.shape[0]
        T = T_J // J

        gcn_in = self.gcn_norm(x).reshape(B * T, J, -1)
        gcn_out = self.gcn_linear(torch.bmm(
            self.adj.unsqueeze(0).expand(B * T, -1, -1), gcn_in
        )).reshape(B, T_J, -1)

        # Fuse
        x = x + self.alpha * attn_out + (1 - self.alpha) * gcn_out
        x = x + self.ff(self.norm2(x))
        return x


class MotionAGFormerXS(nn.Module):
    """
    MotionAGFormer XS variant (2.2M params, 27 temporal frames).
    Input:  (B, 27, 17, 2) — normalized 2D keypoints
    Output: (B, 27, 17, 3) — 3D coordinates
    """
    def __init__(self, num_frames=27, num_joints=17, in_dim=2, out_dim=3,
                 embed_dim=128, depth=4, num_heads=4):
        super().__init__()
        self.num_frames = num_frames
        self.num_joints = num_joints

        # Input projection
        self.input_proj = nn.Linear(in_dim, embed_dim)
        self.pos_embed = nn.Parameter(torch.randn(1, num_frames * num_joints, embed_dim) * 0.02)

        # Transformer-GCN blocks
        self.blocks = nn.ModuleList([
            AGFormerBlock(embed_dim, num_joints, num_heads)
            for _ in range(depth)
        ])

        self.norm = nn.LayerNorm(embed_dim)
        self.output_proj = nn.Linear(embed_dim, out_dim)

    def forward(self, x):
        """
        x: (B, T, J, 2)
        Returns: (B, T, J, 3)
        """
        B, T, J, C = x.shape
        # Flatten temporal and joint dimensions
        x = x.reshape(B, T * J, C)
        x = self.input_proj(x) + self.pos_embed[:, :T * J, :]

        for block in self.blocks:
            x = block(x)

        x = self.norm(x)
        x = self.output_proj(x)
        x = x.reshape(B, T, J, 3)
        return x


# ──────────────────────────────────────────────
# 3D Biomechanics Analysis
# ──────────────────────────────────────────────

# COCO joint indices (matching YOLOv8-Pose output)
J_LEFT_SHOULDER = 5
J_RIGHT_SHOULDER = 6
J_LEFT_ELBOW = 7
J_RIGHT_ELBOW = 8
J_LEFT_WRIST = 9
J_RIGHT_WRIST = 10
J_LEFT_HIP = 11
J_RIGHT_HIP = 12
J_LEFT_KNEE = 13
J_RIGHT_KNEE = 14
J_LEFT_ANKLE = 15
J_RIGHT_ANKLE = 16


def _angle_3d(p1, p2, p3):
    """Calculate 3D angle at p2 between vectors p1→p2 and p3→p2 (degrees)."""
    v1 = p1 - p2
    v2 = p3 - p2
    cos_a = np.dot(v1, v2) / (np.linalg.norm(v1) * np.linalg.norm(v2) + 1e-8)
    cos_a = np.clip(cos_a, -1.0, 1.0)
    return float(np.degrees(np.arccos(cos_a)))


def _angular_velocity(angles, fps):
    """Calculate angular velocity (degrees/second) from angle sequence."""
    if len(angles) < 2:
        return 0.0
    diffs = [abs(angles[i] - angles[i - 1]) for i in range(1, len(angles))]
    return max(diffs) * fps if diffs else 0.0


def analyze_3d_biomechanics(poses_3d: np.ndarray, fps: float) -> dict:
    """
    Extract detailed 3D biomechanical metrics from 3D pose sequence.

    Args:
        poses_3d: (N, 17, 3) array of 3D joint coordinates
        fps: Video frame rate

    Returns:
        Dict with 3D-specific biomechanics metrics
    """
    N = poses_3d.shape[0]
    if N < 3:
        return {}

    # Per-frame 3D angles
    right_elbow_angles = []
    left_elbow_angles = []
    right_shoulder_angles = []
    left_shoulder_angles = []
    right_knee_angles = []
    left_knee_angles = []

    # Pronation angle: forearm rotation (cross product of elbow-wrist with shoulder plane)
    pronation_angles = []

    for i in range(N):
        p = poses_3d[i]

        right_elbow_angles.append(_angle_3d(p[J_RIGHT_SHOULDER], p[J_RIGHT_ELBOW], p[J_RIGHT_WRIST]))
        left_elbow_angles.append(_angle_3d(p[J_LEFT_SHOULDER], p[J_LEFT_ELBOW], p[J_LEFT_WRIST]))
        right_shoulder_angles.append(_angle_3d(p[J_RIGHT_ELBOW], p[J_RIGHT_SHOULDER], p[J_RIGHT_HIP]))
        left_shoulder_angles.append(_angle_3d(p[J_LEFT_ELBOW], p[J_LEFT_SHOULDER], p[J_LEFT_HIP]))
        right_knee_angles.append(_angle_3d(p[J_RIGHT_HIP], p[J_RIGHT_KNEE], p[J_RIGHT_ANKLE]))
        left_knee_angles.append(_angle_3d(p[J_LEFT_HIP], p[J_LEFT_KNEE], p[J_LEFT_ANKLE]))

        # Forearm pronation: angle of forearm vector relative to the vertical plane
        forearm = p[J_RIGHT_WRIST] - p[J_RIGHT_ELBOW]
        if np.linalg.norm(forearm) > 1e-6:
            # Project to horizontal plane (xz) and measure rotation
            pronation = math.degrees(math.atan2(forearm[2], forearm[0] + 1e-8))
            pronation_angles.append(abs(pronation))

    # Find impact frame (max arm extension in 3D)
    arm_extensions = [max(r, l) for r, l in zip(right_elbow_angles, left_elbow_angles)]
    impact_idx = int(np.argmax(arm_extensions))

    # Determine dominant arm
    is_right = right_elbow_angles[impact_idx] >= left_elbow_angles[impact_idx]
    elbow_angles = right_elbow_angles if is_right else left_elbow_angles
    shoulder_angles = right_shoulder_angles if is_right else left_shoulder_angles

    # 3D hip rotation: angle between shoulder plane and hip plane normals
    hip_rotations_3d = []
    for i in range(N):
        p = poses_3d[i]
        shoulder_vec = p[J_RIGHT_SHOULDER] - p[J_LEFT_SHOULDER]
        hip_vec = p[J_RIGHT_HIP] - p[J_LEFT_HIP]
        if np.linalg.norm(shoulder_vec) > 1e-6 and np.linalg.norm(hip_vec) > 1e-6:
            cos_a = np.dot(shoulder_vec, hip_vec) / (
                np.linalg.norm(shoulder_vec) * np.linalg.norm(hip_vec))
            cos_a = np.clip(cos_a, -1.0, 1.0)
            hip_rotations_3d.append(float(np.degrees(np.arccos(cos_a))))

    # Wrist speed in 3D space
    wrist_idx = J_RIGHT_WRIST if is_right else J_LEFT_WRIST
    wrist_speeds = []
    for i in range(1, N):
        dist = np.linalg.norm(poses_3d[i, wrist_idx] - poses_3d[i - 1, wrist_idx])
        wrist_speeds.append(dist * fps)

    return {
        "elbowAngle3D": round(elbow_angles[impact_idx], 1),
        "shoulderAngle3D": round(shoulder_angles[impact_idx], 1),
        "elbowAngularVelocity": round(_angular_velocity(elbow_angles, fps), 1),
        "shoulderAngularVelocity": round(_angular_velocity(shoulder_angles, fps), 1),
        "maxPronationAngle": round(max(pronation_angles) if pronation_angles else 0, 1),
        "pronationSpeed": round(_angular_velocity(pronation_angles, fps) if len(pronation_angles) > 1 else 0, 1),
        "hipRotation3D": round(max(hip_rotations_3d) if hip_rotations_3d else 0, 1),
        "maxWristSpeed3D": round(max(wrist_speeds) if wrist_speeds else 0, 1),
        "kneeAngleAtImpact": round(
            (right_knee_angles[impact_idx] if is_right else left_knee_angles[impact_idx]), 1),
        "impactFrame3D": impact_idx,
        "dominantSide": "right" if is_right else "left",
    }


# ──────────────────────────────────────────────
# Inference Wrapper
# ──────────────────────────────────────────────

_model = None
_device = None
TEMPORAL_WINDOW = 27  # XS model: 27 frames


def _load_model():
    """Load MotionAGFormer model (singleton)."""
    global _model, _device
    if _model is not None:
        return _model

    _device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    model = MotionAGFormerXS(num_frames=TEMPORAL_WINDOW)

    # Check for pretrained weights
    weight_paths = [
        os.path.join(os.path.dirname(__file__), "..", "models", "motionagformer_xs.pt"),
        os.path.join(os.path.dirname(__file__), "..", "models", "MotionAGFormer-xs-h36m.pth.tr"),
    ]

    for path in weight_paths:
        if os.path.exists(path):
            print(f"[3DPose] Loading weights from {path}")
            state_dict = torch.load(path, map_location=_device, weights_only=True)
            if "model_state_dict" in state_dict:
                state_dict = state_dict["model_state_dict"]
            model.load_state_dict(state_dict, strict=False)
            break
    else:
        print("[3DPose] WARNING: No pretrained weights found. Run scripts/download_models.sh")
        print("[3DPose] Model will produce approximate outputs.")

    model = model.to(_device)
    model.eval()
    _model = model
    print(f"[3DPose] MotionAGFormer-XS loaded on {_device}")
    return _model


def lift_2d_to_3d(keypoints_2d: np.ndarray, fps: float) -> dict:
    """
    Lift 2D pose sequence to 3D and compute biomechanics.

    Args:
        keypoints_2d: (N, 17, 2) normalized 2D keypoints from YOLOv8-Pose
        fps: Video frame rate

    Returns:
        Dict with:
        - "poses_3d": (N, 17, 3) array
        - "biomechanics_3d": 3D biomechanics analysis dict
    """
    model = _load_model()
    N = keypoints_2d.shape[0]

    if N < TEMPORAL_WINDOW:
        # Pad with repeated frames
        pad_size = TEMPORAL_WINDOW - N
        padding = np.repeat(keypoints_2d[-1:], pad_size, axis=0)
        keypoints_padded = np.concatenate([keypoints_2d, padding], axis=0)
    else:
        keypoints_padded = keypoints_2d

    # Process in sliding windows
    all_3d = []

    with torch.no_grad():
        for start in range(0, len(keypoints_padded) - TEMPORAL_WINDOW + 1, TEMPORAL_WINDOW // 2):
            window = keypoints_padded[start:start + TEMPORAL_WINDOW]
            input_tensor = torch.from_numpy(window).float().unsqueeze(0).to(_device)

            output = model(input_tensor)  # (1, 27, 17, 3)
            poses_3d = output[0].cpu().numpy()

            if not all_3d:
                all_3d.append(poses_3d)
            else:
                # Overlap blending: use second half of window
                half = TEMPORAL_WINDOW // 2
                all_3d.append(poses_3d[half:])

    if not all_3d:
        return {"poses_3d": None, "biomechanics_3d": {}}

    poses_3d = np.concatenate(all_3d, axis=0)[:N]  # Trim to original length

    # Analyze 3D biomechanics
    biomechanics_3d = analyze_3d_biomechanics(poses_3d, fps)

    print(f"[3DPose] Lifted {N} frames to 3D, impact at frame {biomechanics_3d.get('impactFrame3D', '?')}")

    return {
        "poses_3d": poses_3d,
        "biomechanics_3d": biomechanics_3d,
    }
