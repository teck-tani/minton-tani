from fastapi import FastAPI, BackgroundTasks, HTTPException
from pydantic import BaseModel
from cv_pipeline.sra_algorithm import run_tracknet, run_yolov7_swing, apply_sra
import time
import requests
import firebase_admin
from firebase_admin import auth as firebase_auth

app = FastAPI(title="Minton Smash CV Backend")

# Firebase Admin SDK (uses GOOGLE_APPLICATION_CREDENTIALS env var or default credentials)
if not firebase_admin._apps:
    firebase_admin.initialize_app()

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
    # 1. Download video from Firebase Storage URL (Mocked)
    print(f"Downloading {video_url}...")
    time.sleep(1) # Simulated delay
    
    # 2. Run TrackNet & YOLOv7 on the video
    tracknet_res = run_tracknet("local_video.mp4")
    yolo_res = run_yolov7_swing("local_video.mp4")
    
    # 3. Apply SRA Algorithm to pinpoint hitting frame
    sra_res = apply_sra(tracknet_res, yolo_res)
    print(f"SRA result for user {user_id}: {sra_res}")
    
    # 4. Generate AI Coaching Feedback using Gemini 1.5 Pro and RAG
    if rag_pipeline:
        print("Generating AI feedback...")
        # Note: We pass a mock SRA output dict since sra_res is just a string mock right now
        mock_cv_json = {
            "error_type": "late hitting point in smash",
            "frame_data": sra_res
        }
        feedback = rag_pipeline.generate_feedback(video_url, mock_cv_json)
        print(f"--- AI FEEDBACK GENERATED ---\n{feedback}\n---------------------------")
    else:
        print("Skipping AI feedback (Pipeline not initialized).")

    # 5. Save results back to Firestore
    print("Results saved to Firestore.")

@app.post("/analyze_video")
async def analyze_video(request: ProcessVideoRequest, background_tasks: BackgroundTasks):
    # Offload the heavy Computer Vision processing. Real app uses GCP Cloud Tasks/PubSub.
    background_tasks.add_task(background_video_processing, request.video_url, request.user_id)
    return {"message": "Video analysis started asynchronously", "status": "processing"}
