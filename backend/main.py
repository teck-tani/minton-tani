from fastapi import FastAPI, BackgroundTasks, HTTPException
from pydantic import BaseModel
from cv_pipeline.sra_algorithm import run_tracknet, run_yolov7_swing, apply_sra
from cv_pipeline.mediapipe_annotator import annotate_video_with_pose
import os
import time
import json
import uuid
import tempfile
import requests
import firebase_admin
from firebase_admin import auth as firebase_auth, credentials, firestore
from datetime import datetime

app = FastAPI(title="Minton Smash CV Backend")

# Firebase Admin SDK
# Priority: GOOGLE_APPLICATION_CREDENTIALS env var > local service-account-key.json > ADC (Cloud Run)
cred = None
key_path = os.path.join(os.path.dirname(__file__), 'service-account-key.json')
if not os.environ.get('GOOGLE_APPLICATION_CREDENTIALS') and os.path.exists(key_path):
    cred = credentials.Certificate(key_path)

if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)

db = firestore.client()

class ProcessVideoRequest(BaseModel):
    video_url: str
    user_id: str

class SocialTokenRequest(BaseModel):
    access_token: str

class CoachChatRequest(BaseModel):
    user_id: str
    message: str
    conversation_id: str | None = None

class CoachChatResponse(BaseModel):
    response: str
    conversation_id: str


# --- Social Auth: Kakao → Firebase Custom Token ---
@app.post("/auth/kakao")
async def auth_kakao(request: SocialTokenRequest):
    # Verify Kakao token by calling Kakao user info API
    headers = {"Authorization": f"Bearer {request.access_token}"}
    resp = requests.get("https://kapi.kakao.com/v2/user/me", headers=headers)
    if resp.status_code != 200:
        raise HTTPException(status_code=401, detail="카카오 토큰 검증 실패")

    kakao_user = resp.json()
    kakao_uid = str(kakao_user["id"])
    nickname = kakao_user.get("properties", {}).get("nickname", "카카오 사용자")

    # Create or update Firebase user
    firebase_uid = f"kakao:{kakao_uid}"
    try:
        firebase_auth.get_user(firebase_uid)
    except firebase_auth.UserNotFoundError:
        firebase_auth.create_user(uid=firebase_uid, display_name=nickname)

    custom_token = firebase_auth.create_custom_token(firebase_uid)
    return {"firebase_token": custom_token.decode("utf-8") if isinstance(custom_token, bytes) else custom_token}


# --- Social Auth: Naver → Firebase Custom Token ---
@app.post("/auth/naver")
async def auth_naver(request: SocialTokenRequest):
    # Verify Naver token by calling Naver user profile API
    headers = {"Authorization": f"Bearer {request.access_token}"}
    resp = requests.get("https://openapi.naver.com/v1/nid/me", headers=headers)
    if resp.status_code != 200:
        raise HTTPException(status_code=401, detail="네이버 토큰 검증 실패")

    naver_data = resp.json()
    if naver_data.get("resultcode") != "00":
        raise HTTPException(status_code=401, detail="네이버 사용자 정보 조회 실패")

    naver_user = naver_data["response"]
    naver_uid = naver_user["id"]
    nickname = naver_user.get("nickname", "네이버 사용자")

    # Create or update Firebase user
    firebase_uid = f"naver:{naver_uid}"
    try:
        firebase_auth.get_user(firebase_uid)
    except firebase_auth.UserNotFoundError:
        firebase_auth.create_user(uid=firebase_uid, display_name=nickname)

    custom_token = firebase_auth.create_custom_token(firebase_uid)
    return {"firebase_token": custom_token.decode("utf-8") if isinstance(custom_token, bytes) else custom_token}

@app.get("/")
def root():
    return {"status": "ok", "message": "CV Pipeline is running."}

@app.get("/health")
def health_check():
    return {"status": "ok"}

from cv_pipeline.ragnai_pipeline import RAGAIPipeline
import threading

# Initialize the RAG pipeline once at startup
try:
    rag_pipeline = RAGAIPipeline()
    print("RAG and Gemini Pipeline Initialized.")
except Exception as e:
    print(f"Warning: Failed to init RAG Pipeline: {e}")
    rag_pipeline = None

def background_video_processing(video_url: str, user_id: str):
    analysis_ref = db.collection("analyses").document()
    analysis_id = analysis_ref.id

    # Mark analysis as processing
    analysis_ref.set({
        "userId": user_id,
        "videoUrl": video_url,
        "createdAt": datetime.utcnow().isoformat(),
        "status": "processing",
    })

    try:
        # 1. Download video from Firebase Storage URL
        print(f"Downloading {video_url}...")
        resp = requests.get(video_url, stream=True, timeout=120)
        resp.raise_for_status()
        tmp_video = tempfile.NamedTemporaryFile(suffix=".mp4", delete=False)
        for chunk in resp.iter_content(chunk_size=8192):
            tmp_video.write(chunk)
        tmp_video.close()
        local_video_path = tmp_video.name
        print(f"Downloaded video to {local_video_path}")

        # 1.5. Run MediaPipe Pose annotation + extract real biomechanics
        annotated_url = None
        mediapipe_biomechanics = {}
        try:
            annotated_url, mediapipe_biomechanics = annotate_video_with_pose(video_url, user_id, analysis_id)
            print(f"MediaPipe annotation complete: {annotated_url}")
            if mediapipe_biomechanics:
                print(f"Biomechanics extracted: {list(mediapipe_biomechanics.keys())}")
        except Exception as mp_err:
            print(f"MediaPipe annotation failed (non-fatal): {mp_err}")

        # 2. Run TrackNet & YOLOv8-Pose on the video
        tracknet_res = run_tracknet(local_video_path)
        yolo_res = run_yolov7_swing(local_video_path)

        # 3. Apply SRA Algorithm to pinpoint hitting frame
        sra_res = apply_sra(tracknet_res, yolo_res)
        print(f"SRA result for user {user_id}: {sra_res}")

        # 3.5. Run 3D pose lifting (MotionAGFormer)
        biomechanics_3d = {}
        try:
            # Get 2D keypoints from YOLOv8-Pose results
            pose_data = None
            if yolo_res and "_pose_data" in yolo_res[0]:
                pose_data = yolo_res[0]["_pose_data"]

            if pose_data and pose_data.get("keypoints_2d") is not None:
                import cv2 as _cv2
                _cap = _cv2.VideoCapture(local_video_path)
                video_fps = _cap.get(_cv2.CAP_PROP_FPS) or 30.0
                _cap.release()

                from cv_pipeline.pose_3d_lifter import lift_2d_to_3d
                lift_result = lift_2d_to_3d(pose_data["keypoints_2d"], video_fps)
                biomechanics_3d = lift_result.get("biomechanics_3d", {})
                if biomechanics_3d:
                    print(f"3D biomechanics: {list(biomechanics_3d.keys())}")
        except Exception as e3d:
            print(f"3D pose lifting failed (non-fatal): {e3d}")

        # 4. Build analysis result from real data
        bio = mediapipe_biomechanics
        if bio:
            result_data = {
                "impactAngle": bio.get("impactAngle", 0),
                "elbowAngle": bio.get("elbowAngle", 0),
                "shoulderAngle": bio.get("shoulderAngle", 0),
                "wristSnapSpeed": bio.get("wristSnapSpeed", 0),
                "footwork": bio.get("footwork", 0),
                "hipRotation": bio.get("hipRotation", 0),
                "overallScore": bio.get("overallScore", 0),
                "impactFrame": bio.get("impactFrame", 0),
                "dominantSide": bio.get("dominantSide", "right"),
                "smashSpeed": 0,
            }
        else:
            result_data = {
                "smashSpeed": 0,
                "impactAngle": 0,
                "elbowAngle": 0,
                "shoulderAngle": 0,
                "wristSnapSpeed": 0,
                "footwork": 50.0,
                "hipRotation": 0,
                "overallScore": 0,
            }

        # Enrich with 3D data if available
        if biomechanics_3d:
            result_data["elbowAngle3D"] = biomechanics_3d.get("elbowAngle3D", 0)
            result_data["shoulderAngle3D"] = biomechanics_3d.get("shoulderAngle3D", 0)
            result_data["elbowAngularVelocity"] = biomechanics_3d.get("elbowAngularVelocity", 0)
            result_data["pronationAngle"] = biomechanics_3d.get("maxPronationAngle", 0)
            result_data["pronationSpeed"] = biomechanics_3d.get("pronationSpeed", 0)
            result_data["hipRotation3D"] = biomechanics_3d.get("hipRotation3D", 0)
            result_data["maxWristSpeed3D"] = biomechanics_3d.get("maxWristSpeed3D", 0)

        # Enrich with swing detection data
        if yolo_res and "peak_wrist_velocity" in yolo_res[0]:
            result_data["peakWristVelocity"] = yolo_res[0].get("peak_wrist_velocity", 0)

        # 5. Generate AI Coaching Feedback using Gemini (multimodal video + data)
        coaching_data = {"summary": "", "drills": [], "keyPoints": []}
        if rag_pipeline:
            print("Generating AI feedback with video...")
            cv_json = {
                "biomechanics": mediapipe_biomechanics,
                "biomechanics_3d": biomechanics_3d,
                "sra_data": sra_res,
            }
            feedback_raw = rag_pipeline.generate_feedback(local_video_path, cv_json)

            # Parse Gemini JSON response
            try:
                cleaned = feedback_raw.strip()
                if cleaned.startswith("```"):
                    cleaned = cleaned.split("\n", 1)[1]
                    if cleaned.endswith("```"):
                        cleaned = cleaned[:-3]
                    cleaned = cleaned.strip()
                feedback_json = json.loads(cleaned)
                coaching_data = {
                    "summary": json.dumps(feedback_json.get("detailed_feedback", {}), ensure_ascii=False),
                    "drills": feedback_json.get("drills", []),
                    "keyPoints": feedback_json.get("key_points", []),
                    "strengths": feedback_json.get("strengths", []),
                    "weaknesses": feedback_json.get("weaknesses", []),
                    "injuryRiskWarning": feedback_json.get("injury_risk_warning", ""),
                    "detailedFeedback": feedback_json.get("detailed_feedback", {}),
                }
                # Blend Gemini visual score with MediaPipe data score
                gemini_score = feedback_json.get("overall_score")
                if gemini_score is not None and isinstance(gemini_score, (int, float)):
                    if bio:
                        blended = bio.get("overallScore", 0) * 0.6 + gemini_score * 0.4
                        result_data["overallScore"] = round(blended, 1)
                    else:
                        result_data["overallScore"] = round(float(gemini_score), 1)
            except (json.JSONDecodeError, KeyError):
                coaching_data = {
                    "summary": feedback_raw,
                    "drills": [],
                    "keyPoints": [],
                }
        else:
            print("Skipping AI feedback (Pipeline not initialized).")

        # 6. Save completed analysis to Firestore
        analysis_ref.update({
            "status": "completed",
            "result": result_data,
            "coaching": coaching_data,
            "annotatedVideoUrl": annotated_url,
            "completedAt": datetime.utcnow().isoformat(),
        })
        print(f"Analysis {analysis_id} saved to Firestore.")

        # 7. Update user stats
        user_ref = db.collection("users").document(user_id)
        user_doc = user_ref.get()
        if user_doc.exists:
            stats = user_doc.to_dict().get("stats", {})
            total = stats.get("totalAnalyses", 0) + 1
            prev_avg = stats.get("avgSmashSpeed", 0)
            new_avg = round(((prev_avg * (total - 1)) + result_data["smashSpeed"]) / total, 1)
            best = max(stats.get("bestSmashSpeed", 0), result_data["smashSpeed"])
            user_ref.update({
                "stats.totalAnalyses": total,
                "stats.avgSmashSpeed": new_avg,
                "stats.bestSmashSpeed": best,
            })
        else:
            user_ref.set({
                "stats": {
                    "totalAnalyses": 1,
                    "avgSmashSpeed": result_data["smashSpeed"],
                    "bestSmashSpeed": result_data["smashSpeed"],
                    "totalTrainingMinutes": 0,
                }
            }, merge=True)

        # 8. Check for injury risk and create alert (skip if no data)
        if 0 < result_data["elbowAngle"] < 150:
            db.collection("injuryAlerts").add({
                "userId": user_id,
                "createdAt": datetime.utcnow().isoformat(),
                "bodyPart": "팔꿈치",
                "riskLevel": "high" if result_data["elbowAngle"] < 140 else "medium",
                "description": f"팔꿈치 각도가 {result_data['elbowAngle']}°로 안전 범위(150°) 이하입니다. 팔꿈치 부상 위험이 있습니다.",
                "exercises": ["팔꿈치 스트레칭", "전완근 강화 운동", "오버헤드 폼 교정"],
            })

        if 0 < result_data["footwork"] < 70:
            db.collection("injuryAlerts").add({
                "userId": user_id,
                "createdAt": datetime.utcnow().isoformat(),
                "bodyPart": "무릎",
                "riskLevel": "medium",
                "description": f"풋워크 점수가 {result_data['footwork']}점으로 낮아 착지 시 무릎 부상 위험이 있습니다.",
                "exercises": ["싱글 레그 스쿼트", "둔근 활성화 운동", "무릎 안정화 훈련"],
            })

        print(f"Analysis complete for user {user_id}")

        # Cleanup temp video file
        try:
            os.unlink(local_video_path)
        except OSError:
            pass

    except Exception as e:
        print(f"Error processing video: {e}")
        analysis_ref.update({
            "status": "failed",
            "error": str(e),
        })

@app.post("/analyze_video")
async def analyze_video(request: ProcessVideoRequest, background_tasks: BackgroundTasks):
    # Offload the heavy Computer Vision processing. Real app uses GCP Cloud Tasks/PubSub.
    background_tasks.add_task(background_video_processing, request.video_url, request.user_id)
    return {"message": "Video analysis started asynchronously", "status": "processing"}


from cv_pipeline.ragnai_pipeline import BWF_COACHING_DATA

@app.post("/ai_coach/chat", response_model=CoachChatResponse)
async def ai_coach_chat(request: CoachChatRequest):
    if not rag_pipeline:
        raise HTTPException(status_code=503, detail="AI 코치 서비스가 준비되지 않았습니다.")

    # 1. Fetch user's recent completed analyses (last 5)
    user_analyses = []
    try:
        analyses_docs = (
            db.collection("analyses")
            .where("userId", "==", request.user_id)
            .where("status", "==", "completed")
            .order_by("createdAt", direction=firestore.Query.DESCENDING)
            .limit(5)
            .stream()
        )
        for doc in analyses_docs:
            data = doc.to_dict()
            user_analyses.append({
                "result": data.get("result", {}),
                "coaching": data.get("coaching", {}),
                "createdAt": data.get("createdAt", ""),
            })
    except Exception as e:
        print(f"Firestore analyses query error: {e}")

    # 2. Fetch user stats
    user_stats = {}
    try:
        user_doc = db.collection("users").document(request.user_id).get()
        user_stats = user_doc.to_dict().get("stats", {}) if user_doc.exists else {}
    except Exception as e:
        print(f"Firestore user stats query error: {e}")

    # 3. Fetch recent injury alerts
    injury_alerts = []
    try:
        for doc in (
            db.collection("injuryAlerts")
            .where("userId", "==", request.user_id)
            .order_by("createdAt", direction=firestore.Query.DESCENDING)
            .limit(3)
            .stream()
        ):
            alert = doc.to_dict()
            injury_alerts.append({
                "bodyPart": alert.get("bodyPart", ""),
                "riskLevel": alert.get("riskLevel", ""),
                "description": alert.get("description", ""),
            })
    except Exception as e:
        print(f"Firestore injury alerts query error: {e}")

    # 4. Build prompt with user context
    prompt = f"""당신은 "민턴 스매시"라는 배드민턴 코칭 앱의 AI 코치입니다.
사용자의 실제 분석 데이터를 기반으로 친절하고 구체적인 코칭을 제공합니다.
한국어로 자연스럽게 대화하세요. 300자 이내로 간결하게 답변하세요.

### BWF 공식 코칭 레퍼런스:
{BWF_COACHING_DATA}

### 사용자 최근 분석 데이터 (최대 5개, 최신순):
{json.dumps(user_analyses, ensure_ascii=False, indent=2, default=str)}

### 사용자 통계:
{json.dumps(user_stats, ensure_ascii=False, indent=2, default=str)}

### 부상 경고:
{json.dumps(injury_alerts, ensure_ascii=False, indent=2, default=str)}

### 사용자 질문:
{request.message}

위 데이터를 참고하여 사용자의 질문에 맞춤형 코칭을 제공하세요.
구체적인 수치를 인용하면서 개선 방법을 제시해주세요.
데이터가 없는 경우 일반적인 배드민턴 코칭 조언을 제공하세요."""

    # 5. Call Gemini
    try:
        gemini_response = rag_pipeline.gemini_client.models.generate_content(
            model='gemini-2.5-pro',
            contents=[prompt],
        )
        response_text = gemini_response.text
    except Exception as e:
        print(f"Gemini API error: {e}")
        response_text = "죄송합니다. AI 코치 응답 생성 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."

    conversation_id = request.conversation_id or uuid.uuid4().hex

    return CoachChatResponse(
        response=response_text,
        conversation_id=conversation_id,
    )
