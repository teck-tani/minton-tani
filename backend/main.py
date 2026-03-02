from fastapi import FastAPI, BackgroundTasks
from pydantic import BaseModel
from cv_pipeline.sra_algorithm import run_tracknet, run_yolov7_swing, apply_sra
import time

app = FastAPI(title="Minton Smash CV Backend")

class ProcessVideoRequest(BaseModel):
    video_url: str
    user_id: str

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
