import os
import json
import chromadb
from sentence_transformers import SentenceTransformer
from google import genai
from google.genai import types

class RAGAIPipeline:
    def __init__(self, data_dir="data"):
        self.data_dir = data_dir
        self.chroma_client = chromadb.Client()
        self.collection = self.chroma_client.get_or_create_collection(name="bwf_biomechanics")
        self.embedding_model = SentenceTransformer('all-MiniLM-L6-v2')
        self.gemini_client = genai.Client()
        self._initialize_mock_rag_data()

    def _initialize_mock_rag_data(self):
        # In a real scenario, this would load from PDFs or a real DB.
        # Adding mock BWF and Biomechanics data for demonstration.
        mock_data = [
            "BWF Manual: The smash should be hit at the highest possible point.",
            "Biomechanics: A late hitting point causes the shuttlecock to travel upwards or flat instead of steeply downward. This is often due to the player being behind the shuttle.",
            "Biomechanics: To fix a late hitting point, the player should focus on earlier split-step timing and faster backward movement to get behind the shuttle.",
            "BWF Manual: The racket arm should be fully extended at the point of impact for a smash.",
            "Biomechanics: If the elbow is bent at impact, power is lost. This can be corrected by focusing on shoulder rotation and forearm pronation."
        ]
        
        # Check if empty, if so, populate.
        if self.collection.count() == 0:
            embeddings = self.embedding_model.encode(mock_data).tolist()
            self.collection.add(
                documents=mock_data,
                embeddings=embeddings,
                metadatas=[{"source": "mock_bwf"} for _ in mock_data],
                ids=[f"doc_{i}" for i in range(len(mock_data))]
            )

    def retrieve_context(self, query: str, n_results: int = 2) -> list[str]:
        query_embedding = self.embedding_model.encode([query]).tolist()
        results = self.collection.query(
            query_embeddings=query_embedding,
            n_results=n_results
        )
        if results['documents'] and len(results['documents']) > 0:
            return results['documents'][0]
        return []

    def generate_feedback(self, video_uri: str, cv_analysis_json: dict) -> str:
        # Based on CV analysis (e.g. SRA detects a 'late hitting point')
        # We query the RAG system to find relevant coaching instructions.
        
        # Determine query based on mock CV analysis
        query = "late hitting point smash" # Mocked extraction from SRA
        if "error_type" in cv_analysis_json:
             query = cv_analysis_json["error_type"]
             
        rag_context = self.retrieve_context(query)
        context_str = "\n".join(rag_context)

        # Build prompt
        prompt = f"""
You are a world-class professional badminton coach and biomechanics expert.
Analyze the player's smash based on the provided computer vision data and reference the official BWF coaching guidelines.

### Official Coaching Reference (RAG Context):
{context_str}

### Computer Vision Data (JSON):
{json.dumps(cv_analysis_json, indent=2)}

### Video Feed:
Analyze the attached video frame for additional visual context.

Please provide a detailed biomechanical diagnostic report in JSON format matching the following schema:
{{
  "overall_score": 0-100,
  "strengths": ["...", "..."],
  "weaknesses": ["...", "..."],
  "improvement_plan": "...",
  "injury_risk_warning": "..."
}}
"""
        # Note: Depending on the specific Gemini 1.5 Pro implementation,
        # video_uri might need to be uploaded using the File API first if it's a local file.
        # For this prototype, we will assume standard text generation or mocked video handling.
        
        try:
            response = self.gemini_client.models.generate_content(
                model='gemini-2.5-pro',
                contents=[
                    # If video_uri was a google-genai File object it would be passed here
                    prompt
                ],
            )
            return response.text
        except Exception as e:
            return json.dumps({"error": str(e), "message": "Failed to call Gemini API."})

# Example usage:
# pipeline = RAGAIPipeline()
# result = pipeline.generate_feedback("gs://...", {"error_type": "late hitting point in smash"})
# print(result)
