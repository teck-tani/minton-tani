# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Minton Smash is an AI-powered badminton biomechanics analysis app. Flutter mobile frontend with a Python FastAPI backend that uses computer vision (TrackNet, YOLOv7) and Gemini 1.5 Pro for coaching feedback via RAG pipeline.

## Architecture

- **`minton_smash/`** — Flutter mobile app (Dart). Entry point: `lib/main.dart`
- **`backend/`** — Python FastAPI server deployed to GCP Cloud Run via Docker
  - `main.py` — API server with `/analyze_video` endpoint (async background processing)
  - `cv_pipeline/sra_algorithm.py` — Shot Refinement Algorithm: pinpoints shuttlecock hit frame from TrackNet + YOLOv7 data
  - `cv_pipeline/ragnai_pipeline.py` — RAG pipeline using ChromaDB + sentence-transformers + Gemini 1.5 Pro for structured coaching JSON
- **`stitch_screens/`** — Design reference mockups (HTML/PNG), not source code

### Frontend-Backend Communication

1. Flutter uploads video to Firebase Storage (`videos/{userId}/{timestamp}.mp4`)
2. POST to backend `/analyze_video` with `video_url` and `user_id`
3. Backend processes asynchronously: TrackNet → YOLOv7 → SRA → RAG/Gemini
4. Results saved to Firestore; Flutter reads via Firestore SDK

### Flutter App Screens (Bottom Nav)

- 홈 (Home) → `BiomechanicsReportScreen` — analysis results, stats, drills
- 분석 (Analytics) → `InjuryPreventionScreen` — injury risk, corrective exercises
- 미러 (Mirror) → `CameraMirrorScreen` — real-time ML Kit 33-point pose detection overlay
- 훈련 (Training) → placeholder
- 마이페이지 (My Page) → placeholder

## Build & Run Commands

### Flutter App

```bash
cd minton_smash
flutter pub get              # install dependencies
flutter run                  # run on connected device
flutter analyze              # lint/analyze
flutter test                 # run tests
flutter test test/widget_test.dart  # run single test
flutter build apk            # build Android APK
flutter build appbundle      # build Android AAB
flutter build ios            # build iOS
```

### Python Backend

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Docker (Backend)

```bash
cd backend
docker build -t minton-smash-cv:latest .
docker run -p 8080:8080 minton-smash-cv:latest
```

### Firebase

```bash
cd minton_smash
firebase deploy --only firestore:rules
firebase emulators:start
```

## Firebase

- **Project ID:** `minton-smash-cv-app`
- **Android package:** `com.dckwon.minton_smash`
- **iOS bundle:** `com.dckwon.mintonSmash`
- Firestore rules are currently open (dev mode, expires April 2026)

## Key Dependencies

- **Flutter:** Riverpod (state), camera, google_mlkit_pose_detection, firebase_core/cloud_firestore/firebase_storage
- **Backend (Python 3.9):** FastAPI, google-genai (Gemini), langchain, sentence-transformers, chromadb, firebase-admin, opencv-python-headless

## Current MVP Status

- Camera mirror + pose detection: implemented
- SRA algorithm + RAG/Gemini pipeline: implemented
- TrackNet/YOLOv7 models: **mocked** (placeholder functions in `main.py`)
- Firebase Auth: not yet integrated
- Training and MyPage screens: placeholders

## Conventions

- UI language is Korean
- Theme: Material Design 3, primary color `#137FEC`, font: Space Grotesk
- Pose painter uses color-coded limbs: green=center, yellow=left, blue=right
- Backend uses Pydantic models for request validation
- Long-running video analysis runs as FastAPI background tasks
