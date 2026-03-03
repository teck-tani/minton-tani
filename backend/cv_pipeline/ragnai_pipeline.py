import os
import json
from google import genai
from google.genai import types

# Mock BWF coaching reference data (embedded directly for MVP, replaces ChromaDB RAG)
BWF_COACHING_DATA = """
BWF Manual: The smash should be hit at the highest possible point.
Biomechanics: A late hitting point causes the shuttlecock to travel upwards or flat instead of steeply downward. This is often due to the player being behind the shuttle.
Biomechanics: To fix a late hitting point, the player should focus on earlier split-step timing and faster backward movement to get behind the shuttle.
BWF Manual: The racket arm should be fully extended at the point of impact for a smash.
Biomechanics: If the elbow is bent at impact, power is lost. This can be corrected by focusing on shoulder rotation and forearm pronation.
BWF Manual: Proper footwork involves a split-step, chassé steps, and lunges to maintain balance and reach.
Biomechanics: Hip rotation contributes up to 30% of smash power. Insufficient rotation leads to arm-dominant strokes and increased injury risk.
"""

class RAGAIPipeline:
    def __init__(self, data_dir="data"):
        self.data_dir = data_dir
        # On Cloud Run: use Vertex AI with ADC (no API key needed)
        # Locally with GOOGLE_API_KEY: use AI Studio
        project = os.environ.get('GOOGLE_CLOUD_PROJECT')
        if project:
            self.gemini_client = genai.Client(
                vertexai=True,
                project=project,
                location='asia-northeast3',
            )
        else:
            self.gemini_client = genai.Client()

    def generate_feedback(self, video_uri: str, cv_analysis_json: dict) -> str:
        query = "late hitting point smash"
        if "error_type" in cv_analysis_json:
             query = cv_analysis_json["error_type"]

        prompt = f"""
You are a world-class professional badminton coach and biomechanics expert.
Analyze the player's smash based on the provided computer vision data and reference the official BWF coaching guidelines.

### Official Coaching Reference:
{BWF_COACHING_DATA}

### Computer Vision Data (JSON):
{json.dumps(cv_analysis_json, indent=2)}

### Analysis Query:
{query}

Please provide a detailed biomechanical diagnostic report in JSON format matching the following schema:
{{
  "overall_score": 0-100,
  "strengths": ["...", "..."],
  "weaknesses": ["...", "..."],
  "improvement_plan": "...",
  "injury_risk_warning": "..."
}}
"""
        try:
            response = self.gemini_client.models.generate_content(
                model='gemini-2.5-pro',
                contents=[prompt],
            )
            return response.text
        except Exception as e:
            return json.dumps({"error": str(e), "message": "Failed to call Gemini API."})
