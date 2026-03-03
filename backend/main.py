from fastapi import FastAPI, BackgroundTasks, HTTPException
from pydantic import BaseModel
from cv_pipeline.sra_algorithm import run_tracknet, run_yolov7_swing, apply_sra
import os
import time
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
def health_check():
    return {"status": "ok", "message": "CV Pipeline is running."}

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
        # 1. Download video from Firebase Storage URL (Mocked for now)
        print(f"Downloading {video_url}...")
        time.sleep(1)

        # 2. Run TrackNet & YOLOv7 on the video
        tracknet_res = run_tracknet("local_video.mp4")
        yolo_res = run_yolov7_swing("local_video.mp4")

        # 3. Apply SRA Algorithm to pinpoint hitting frame
        sra_res = apply_sra(tracknet_res, yolo_res)
        print(f"SRA result for user {user_id}: {sra_res}")

        # 4. Generate AI Coaching Feedback using Gemini and RAG
        coaching_data = {"summary": "", "drills": [], "keyPoints": []}
        if rag_pipeline:
            print("Generating AI feedback...")
            cv_json = {
                "error_type": "late hitting point in smash",
                "frame_data": sra_res
            }
            feedback = rag_pipeline.generate_feedback(video_url, cv_json)
            coaching_data = {
                "summary": feedback if isinstance(feedback, str) else str(feedback),
                "drills": ["오버헤드 지연 스냅 훈련", "팔꿈치 타이밍 교정"],
                "keyPoints": ["타점을 높이세요", "팔꿈치를 늦게 펴세요"],
            }
        else:
            print("Skipping AI feedback (Pipeline not initialized).")

        # 5. Build analysis result (mocked biomechanics values for now)
        import random
        result_data = {
            "smashSpeed": round(random.uniform(180, 280), 1),
            "impactAngle": round(random.uniform(25, 45), 1),
            "elbowAngle": round(random.uniform(140, 175), 1),
            "shoulderAngle": round(random.uniform(150, 180), 1),
            "wristSnapSpeed": round(random.uniform(800, 1500), 1),
            "footwork": round(random.uniform(60, 95), 1),
            "hipRotation": round(random.uniform(30, 60), 1),
            "overallScore": round(random.uniform(55, 95), 1),
        }

        # 6. Save completed analysis to Firestore
        analysis_ref.update({
            "status": "completed",
            "result": result_data,
            "coaching": coaching_data,
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

        # 8. Check for injury risk and create alert
        if result_data["elbowAngle"] < 150:
            db.collection("injuryAlerts").add({
                "userId": user_id,
                "createdAt": datetime.utcnow().isoformat(),
                "bodyPart": "팔꿈치",
                "riskLevel": "high" if result_data["elbowAngle"] < 140 else "medium",
                "description": f"팔꿈치 각도가 {result_data['elbowAngle']}°로 안전 범위(150°) 이하입니다. 팔꿈치 부상 위험이 있습니다.",
                "exercises": ["팔꿈치 스트레칭", "전완근 강화 운동", "오버헤드 폼 교정"],
            })

        if result_data["footwork"] < 70:
            db.collection("injuryAlerts").add({
                "userId": user_id,
                "createdAt": datetime.utcnow().isoformat(),
                "bodyPart": "무릎",
                "riskLevel": "medium",
                "description": f"풋워크 점수가 {result_data['footwork']}점으로 낮아 착지 시 무릎 부상 위험이 있습니다.",
                "exercises": ["싱글 레그 스쿼트", "둔근 활성화 운동", "무릎 안정화 훈련"],
            })

        print(f"Analysis complete for user {user_id}")

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
