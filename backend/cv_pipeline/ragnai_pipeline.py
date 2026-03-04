import os
import json
import time
from google import genai
from google.genai import types

# BWF coaching reference data (embedded for MVP)
BWF_COACHING_DATA = """
BWF Manual: The smash should be hit at the highest possible point.
Biomechanics: A late hitting point causes the shuttlecock to travel upwards or flat instead of steeply downward. This is often due to the player being behind the shuttle.
Biomechanics: To fix a late hitting point, the player should focus on earlier split-step timing and faster backward movement to get behind the shuttle.
BWF Manual: The racket arm should be fully extended at the point of impact for a smash.
Biomechanics: If the elbow is bent at impact, power is lost. This can be corrected by focusing on shoulder rotation and forearm pronation.
BWF Manual: Proper footwork involves a split-step, chassé steps, and lunges to maintain balance and reach.
Biomechanics: Hip rotation contributes up to 30% of smash power. Insufficient rotation leads to arm-dominant strokes and increased injury risk.
BWF Manual: The non-racket arm should be raised and pointed towards the shuttle during preparation, then pulled down during the swing for balance and rotational power.
BWF Manual: Weight transfer from the back foot to the front foot is essential for generating power in the smash.
Biomechanics: Forearm pronation speed directly correlates with shuttlecock speed. Elite players achieve >1500°/s pronation.
Biomechanics: The kinetic chain for a badminton smash: legs → hips → trunk → shoulder → elbow → wrist → racket. Energy loss at any link reduces power.
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

    def _upload_video(self, video_path: str):
        """Upload video to Gemini Files API and wait for processing."""
        print(f"[Gemini] Uploading video: {video_path}")
        video_file = self.gemini_client.files.upload(file=video_path)

        # Wait for the video to be processed
        while video_file.state == "PROCESSING":
            print("[Gemini] Video processing...")
            time.sleep(3)
            video_file = self.gemini_client.files.get(name=video_file.name)

        if video_file.state == "FAILED":
            raise RuntimeError(f"Video processing failed: {video_file.state}")

        print(f"[Gemini] Video ready: {video_file.name}")
        return video_file

    def generate_feedback(self, video_path: str, cv_analysis_json: dict) -> str:
        """
        Generate coaching feedback using Gemini 2.5 Pro with multimodal video analysis.

        Args:
            video_path: Local path to the video file (will be uploaded to Gemini)
            cv_analysis_json: Dict with 'biomechanics' (MediaPipe data) and 'sra_data'
        """
        biomechanics = cv_analysis_json.get("biomechanics", {})
        sra_data = cv_analysis_json.get("sra_data", {})

        prompt = f"""당신은 세계적인 프로 배드민턴 코치이자 생체역학 전문가입니다.
선수의 스매시 영상을 직접 분석하고, 컴퓨터 비전으로 추출한 생체역학 데이터와 BWF 공식 코칭 가이드라인을 참고하여 코칭 피드백을 제공하세요.

### BWF 공식 코칭 레퍼런스:
{BWF_COACHING_DATA}

### MediaPipe 생체역학 데이터 (실제 관절 각도):
{json.dumps(biomechanics, indent=2, ensure_ascii=False, default=str)}

### SRA 셔틀콕 타점 분석:
{json.dumps(sra_data, indent=2, default=str) if sra_data else "셔틀콕 추적 데이터 없음 (TrackNet 미구현)"}

### 분석 지시사항:
1. 영상을 주의 깊게 시청하고, 스매시 동작의 각 단계(준비, 백스윙, 임팩트, 팔로스루)를 분석하세요.
2. MediaPipe 데이터와 영상에서 보이는 실제 자세를 비교하세요.
3. 다음 항목들을 평가하세요:
   - 타점 높이 (임팩트 시 팔꿈치/어깨 각도)
   - 팔꿈치 신전 (임팩트 시 완전 신전 여부)
   - 손목 스냅 (전완 회내전 속도)
   - 골반 회전 (상체-하체 분리)
   - 풋워크 (스플릿 스텝, 착지 안정성)
   - 키네틱 체인 (에너지 전달 순서)

다음 JSON 형식으로 응답하세요 (다른 텍스트 없이 JSON만):
{{
  "overall_score": 0에서 100 사이의 점수,
  "strengths": ["잘하고 있는 점 2-3개 (한국어)"],
  "weaknesses": ["개선이 필요한 점 2-3개 (한국어)"],
  "detailed_feedback": {{
    "hitting_point": "타점에 대한 구체적 피드백 (한국어)",
    "elbow_extension": "팔꿈치 신전에 대한 피드백 (한국어)",
    "wrist_snap": "손목 스냅에 대한 피드백 (한국어)",
    "hip_rotation": "골반 회전에 대한 피드백 (한국어)",
    "footwork": "풋워크에 대한 피드백 (한국어)",
    "kinetic_chain": "키네틱 체인에 대한 피드백 (한국어)"
  }},
  "drills": ["추천 훈련 드릴 3-4개 (한국어)"],
  "key_points": ["핵심 개선 포인트 2-3개 (한국어)"],
  "injury_risk_warning": "부상 위험 경고 (해당 시, 한국어, 없으면 빈 문자열)"
}}"""

        try:
            # Try multimodal: upload video + send with prompt
            if video_path and os.path.exists(video_path):
                video_file = self._upload_video(video_path)
                response = self.gemini_client.models.generate_content(
                    model='gemini-2.5-pro',
                    contents=[video_file, prompt],
                )
            else:
                # Fallback: text-only analysis (no video file available)
                print("[Gemini] No video file available, using text-only analysis")
                response = self.gemini_client.models.generate_content(
                    model='gemini-2.5-pro',
                    contents=[prompt],
                )

            return response.text

        except Exception as e:
            print(f"[Gemini] Error: {e}")
            # Fallback: try text-only if video upload failed
            try:
                print("[Gemini] Retrying with text-only...")
                response = self.gemini_client.models.generate_content(
                    model='gemini-2.5-pro',
                    contents=[prompt],
                )
                return response.text
            except Exception as e2:
                return json.dumps({
                    "error": str(e2),
                    "message": "Gemini API 호출에 실패했습니다.",
                })
