# Minton Smash - 기술 스택 분석

## 프로젝트 개요

배드민턴 AI 바이오메카닉스 분석 앱. Flutter 모바일 프론트엔드 + Python FastAPI 백엔드(Cloud Run GPU)로 구성. 5단계 CV 파이프라인(MediaPipe → TrackNetV3 → YOLOv8-Pose → MotionAGFormer → Gemini 2.5 Pro)을 활용한 코칭 피드백 제공.

---

## 1. 프론트엔드 (Flutter)

### 코어 프레임워크

| 기술 | 버전 | 역할 |
|------|------|------|
| Flutter SDK | ^3.7.0 | 크로스플랫폼 모바일 프레임워크 |
| Dart | >=3.10.0 <4.0.0 | 프로그래밍 언어 |
| Material Design 3 | - | UI 디자인 시스템 |

### Flutter 패키지 (의존성)

#### Firebase 연동

| 패키지 | 버전 | 용도 | 사용 파일 |
|--------|------|------|-----------|
| `firebase_core` | 4.4.0 | Firebase 초기화 | `main.dart` |
| `firebase_auth` | 6.1.4 | 사용자 인증 | `services/auth_service.dart` |
| `cloud_firestore` | 6.1.2 | NoSQL 데이터베이스 | `providers/analysis_provider.dart` |
| `firebase_storage` | 13.0.6 | 영상 업로드/다운로드 | `services/api_service.dart` |

#### 카메라 & AI

| 패키지 | 버전 | 용도 | 사용 파일 |
|--------|------|------|-----------|
| `camera` | 0.11.2+1 | 실시간 카메라 캡처 | `screens/camera_mirror_screen.dart`, `screens/smash_recording_screen.dart` |
| `google_mlkit_pose_detection` | 0.14.0 | 33포인트 포즈 감지 (온디바이스) | `widgets/pose_painter.dart` |
| `image_picker` | 1.2.1 | 갤러리에서 영상 선택 | `screens/smash_recording_screen.dart` |

#### 소셜 로그인

| 패키지 | 버전 | 용도 | 사용 파일 |
|--------|------|------|-----------|
| `google_sign_in` | 6.3.0 | Google OAuth | `services/auth_service.dart` |
| `kakao_flutter_sdk_user` | 1.10.0 | 카카오 OAuth | `services/auth_service.dart` |
| `flutter_naver_login` | 2.1.1 | 네이버 OAuth | `services/auth_service.dart` |

#### 상태관리 & UI

| 패키지 | 버전 | 용도 | 사용 파일 |
|--------|------|------|-----------|
| `flutter_riverpod` | 2.6.1 | 상태 관리 | `providers/*.dart`, `main.dart` |
| `google_fonts` | 6.3.2 | Space Grotesk 폰트 | `theme.dart` |
| `material_symbols_icons` | 4.2906.0 | Material 아이콘 | 전체 UI |
| `fl_chart` | 1.1.1 | 차트/그래프 | 통계 시각화 |
| `video_player` | 2.11.0 | 영상 재생 | `screens/analysis_detail_screen.dart` |
| `chewie` | 1.13.0 | 영상 플레이어 UI | `screens/analysis_detail_screen.dart` |
| `http` | 1.6.0 | HTTP 요청 | `services/api_service.dart` |
| `permission_handler` | 12.0.1 | 권한 관리 | 카메라/마이크 접근 |

### 앱 테마

- **Primary Color**: `#137FEC`
- **폰트**: Space Grotesk (Google Fonts)
- **다크/라이트 모드**: `ThemeMode.system` (시스템 설정 따름)
- **배경색**: Light `#F6F7F8` / Dark `#101922`

---

## 2. 백엔드 (Python FastAPI)

### 코어 프레임워크

| 기술 | 버전 | 역할 |
|------|------|------|
| Python | 3.11 | 서버 언어 |
| FastAPI | 0.104.1 | REST API 프레임워크 |
| uvicorn | 0.24.0 | ASGI 서버 |
| Pydantic | 2.4.2 | 데이터 유효성 검증 |

### Python 패키지 (의존성)

| 패키지 | 버전 | 용도 | 사용 파일 |
|--------|------|------|-----------|
| `firebase-admin` | 6.2.0 | Firebase 서버 SDK (Auth, Firestore, Storage) | `main.py` |
| `google-genai` | 0.3.0 | Gemini 2.5 Pro API (멀티모달 영상 분석) | `cv_pipeline/ragnai_pipeline.py` |
| `mediapipe` | 0.10.14 | 포즈 감지 + 실제 관절 각도 추출 | `cv_pipeline/mediapipe_annotator.py` |
| `opencv-python-headless` | latest | 영상 프레임 처리 | `cv_pipeline/mediapipe_annotator.py` |
| `numpy` | latest | 수치 연산 (궤적/각도 분석) | `cv_pipeline/sra_algorithm.py` |
| `torch` | 2.2.2 | PyTorch GPU 추론 (CUDA 12.1) | `cv_pipeline/tracknet_v3.py`, `cv_pipeline/pose_3d_lifter.py` |
| `torchvision` | 0.17.2 | PyTorch 비전 유틸리티 | `cv_pipeline/tracknet_v3.py` |
| `ultralytics` | ≥8.1.0 | YOLOv8-Pose 17 키포인트 추출 | `cv_pipeline/yolov8_pose.py` |
| `requests` | 2.31.0 | OAuth 토큰 검증 (카카오/네이버 API) | `main.py` |
| `python-multipart` | 0.0.6 | 파일 업로드 파싱 | `main.py` |
| `google-cloud-storage` | 2.13.0 | GCS 클라이언트 | Firebase Storage 연동 |

### API 엔드포인트

| 메서드 | 경로 | 용도 | 처리 방식 |
|--------|------|------|-----------|
| GET | `/` | 루트 | 동기 |
| GET | `/health` | 헬스 체크 (Docker HEALTHCHECK) | 동기 |
| POST | `/analyze_video` | 영상 분석 파이프라인 트리거 | **비동기 (BackgroundTask)** |
| POST | `/auth/kakao` | 카카오 로그인 | 동기 |
| POST | `/auth/naver` | 네이버 로그인 | 동기 |
| POST | `/ai_coach/chat` | AI 코치 대화 | 동기 |

### Docker 구성

```dockerfile
# GPU 빌드 (기본)
FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04
# Python 3.11 + PyTorch (CUDA 12.1) + 모델 가중치
# CPU 빌드: --build-arg BASE_IMAGE=python:3.11-slim
ENV PORT=8080
CMD: uvicorn main:app --host 0.0.0.0 --port $PORT
```

- **CUDA 12.1**: NVIDIA L4 GPU 추론 (TrackNetV3, MotionAGFormer)
- **FFmpeg**: H.264 영상 재인코딩 (모바일 호환)
- **libgl1**: OpenCV C++ 바인딩
- **PORT**: Cloud Run이 자동 주입
- **HEALTHCHECK**: `/health` 엔드포인트 30초 간격 체크

---

## 3. 외부 서비스 & API 연결

### Google Cloud Platform (GCP)

| 서비스 | 리전 | 용도 |
|--------|------|------|
| **Cloud Run (GPU)** | asia-northeast3 | 백엔드 컨테이너 + NVIDIA L4 GPU |
| **Vertex AI** | asia-northeast3 | Gemini 2.5 Pro LLM |
| **Firebase Firestore** | nam5 | NoSQL 실시간 데이터베이스 |
| **Firebase Storage** | - | 영상 파일 저장소 |
| **Firebase Auth** | - | 사용자 인증 |

**Cloud Run URL**: `https://minton-smash-cv-120519944306.asia-northeast3.run.app`

### Firebase 프로젝트

| 항목 | 값 |
|------|-----|
| Project ID | `minton-smash-cv-app` |
| Android 패키지 | `com.dckwon.minton_smash` |
| iOS 번들 | `com.dckwon.mintonSmash` |
| Firestore 위치 | `nam5` |
| 보안 규칙 만료 | 2026-04-02 (개발 모드) |

### OAuth 프로바이더

| 프로바이더 | 인증 방식 | 토큰 검증 엔드포인트 |
|-----------|-----------|---------------------|
| **Google** | Firebase 네이티브 | Firebase SDK 직접 처리 |
| **카카오** | Custom Token (백엔드 경유) | `https://kapi.kakao.com/v2/user/me` |
| **네이버** | Custom Token (백엔드 경유) | `https://openapi.naver.com/v1/nid/me` |
| **게스트** | Firebase Anonymous | 토큰 검증 불필요 |

### AI/ML 모델 (5단계 파이프라인)

| 단계 | 모델 | 용도 | 상태 | 파일 |
|------|------|------|------|------|
| 1 | **MediaPipe Pose** | 서버 영상 주석 + 실제 관절 각도 추출 | 구현 완료 | `cv_pipeline/mediapipe_annotator.py` |
| 2 | **Gemini 2.5 Pro** | 멀티모달 영상 분석 + RAG 코칭 피드백 | 구현 완료 | `cv_pipeline/ragnai_pipeline.py` |
| 3 | **TrackNetV3** | 셔틀콕 궤적 추적 (U-Net 히트맵) | 구현 완료 | `cv_pipeline/tracknet_v3.py` |
| 4 | **YOLOv8-Pose** | 17 키포인트 + 스윙 페이즈 감지 | 구현 완료 | `cv_pipeline/yolov8_pose.py` |
| 5 | **MotionAGFormer XS** | 2D→3D 포즈 리프팅 + 3D 생체역학 | 구현 완료 | `cv_pipeline/pose_3d_lifter.py` |
| - | **Google ML Kit** | 온디바이스 33포인트 포즈 감지 (Flutter) | 구현 완료 | Flutter 앱 |
| - | **SRA Algorithm** | TrackNet + YOLO 융합 → 타격 프레임 특정 | 구현 완료 | `cv_pipeline/sra_algorithm.py` |

#### 모델 가중치

| 모델 | 파일명 | 크기 | 다운로드 |
|------|--------|------|----------|
| TrackNetV3 | `TrackNet_best.pt` | ~15MB | [GitHub](https://github.com/qaz812345/TrackNetV3) |
| YOLOv8m-Pose | `yolov8m-pose.pt` | ~52MB | [Ultralytics](https://github.com/ultralytics/assets) |
| MotionAGFormer XS | `motionagformer_xs.pt` | ~9MB | [GitHub](https://github.com/TaatiTeam/MotionAGFormer) |

> 가중치 미설치 시 mock 데이터로 자동 폴백 (graceful degradation)

---

## 4. Firestore 데이터 구조

### analyses (영상 분석 결과)

```
analyses/{analysisId}
├── userId: string
├── videoUrl: string              // Firebase Storage URL
├── status: "processing" | "completed" | "failed"
├── createdAt: ISO 8601
├── completedAt: ISO 8601
├── result
│   ├── smashSpeed: number        // km/h
│   ├── impactAngle: number       // 타점 각도 (도)
│   ├── elbowAngle: number        // 팔꿈치 각도 (도, MediaPipe)
│   ├── shoulderAngle: number     // 어깨 각도 (도, MediaPipe)
│   ├── wristSnapSpeed: number    // 손목 스냅 속도
│   ├── footwork: number          // 풋워크 점수 (0-100)
│   ├── hipRotation: number       // 힙 회전 (도)
│   ├── overallScore: number      // 종합 점수 (MediaPipe 60% + Gemini 40%)
│   ├── dominantSide: string      // "right" | "left"
│   ├── impactFrame: number       // 타격 프레임 번호
│   ├── peakWristVelocity: number // YOLOv8 최대 손목 속도 (px/frame)
│   ├── elbowAngle3D: number      // 3D 팔꿈치 각도 (MotionAGFormer)
│   ├── shoulderAngle3D: number   // 3D 어깨 각도
│   ├── elbowAngularVelocity: number // 팔꿈치 각속도 (°/s)
│   ├── pronationAngle: number    // 전완 회내전 각도 (°)
│   ├── pronationSpeed: number    // 회내전 속도 (°/s)
│   ├── hipRotation3D: number     // 3D 힙 회전 (°)
│   └── maxWristSpeed3D: number   // 3D 최대 손목 속도
├── coaching
│   ├── summary: string           // AI 코칭 요약
│   ├── drills: object[]          // 추천 훈련
│   ├── keyPoints: string[]       // 핵심 포인트
│   ├── strengths: string[]       // 강점
│   ├── weaknesses: string[]      // 약점
│   ├── injuryRiskWarning: string // 부상 위험 경고
│   └── detailedFeedback: object  // Gemini 상세 피드백 (카테고리별)
└── annotatedVideoUrl: string     // 포즈 주석 영상 URL
```

### users (사용자 프로필)

```
users/{userId}
└── stats
    ├── totalAnalyses: number
    ├── avgSmashSpeed: number
    ├── bestSmashSpeed: number
    └── totalTrainingMinutes: number
```

### injuryAlerts (부상 위험 경고)

```
injuryAlerts/{alertId}
├── userId: string
├── createdAt: ISO 8601
├── bodyPart: string           // "팔꿈치", "무릎"
├── riskLevel: "high" | "medium"
├── description: string
└── exercises: string[]
```

### sampleAnalyses (프로 선수 레퍼런스)

```
sampleAnalyses/{sampleId}
├── isSample: true
├── playerName: string
├── playerInfo: string
└── (analyses와 동일한 구조)
```

---

## 5. 데이터 플로우

### 영상 분석 파이프라인

```
[Flutter 앱] 촬영/갤러리 선택
    │
    ▼
[Firebase Storage] videos/{userId}/{timestamp}.mp4
    │
    ▼ POST /analyze_video {video_url, user_id}
    │
[Cloud Run 백엔드 + NVIDIA L4 GPU] (비동기 BackgroundTask)
    ├─ [1] Firebase Storage에서 영상 다운로드
    ├─ [1.5] MediaPipe Pose 주석 + 실제 관절 각도 추출
    │       └─ FFmpeg H.264 재인코딩 → Firebase Storage 업로드
    ├─ [2] TrackNetV3 셔틀콕 추적 (GPU, U-Net 히트맵)
    ├─ [3] YOLOv8-Pose 스윙 감지 (GPU, 17 키포인트)
    ├─ [3.5] MotionAGFormer 3D 포즈 리프팅 (GPU, 2D→3D)
    │       └─ 3D 생체역학: 팔꿈치/어깨 각속도, 전완 회내전, 3D 힙 회전
    ├─ [4] SRA 알고리즘 → 타격 프레임 특정
    ├─ [5] Gemini 2.5 Pro → 멀티모달 영상 + 데이터 → 코칭 JSON
    │       └─ 종합 점수 = MediaPipe 60% + Gemini 40%
    ├─ [6] 부상 위험 임계값 체크
    │       ├─ 팔꿈치 < 150° → injuryAlert 생성
    │       └─ 풋워크 < 70점 → injuryAlert 생성
    └─ [7] Firestore에 결과 저장
           ├─ analyses/{id} → status: "completed"
           └─ users/{userId} → stats 업데이트
    │
    ▼ (Firestore 실시간 리스너)
    │
[Flutter 앱] Riverpod StreamProvider → UI 자동 업데이트
    ├─ 분석 메인 화면 (히스토리 리스트)
    ├─ 홈 대시보드 (최신 분석 결과)
    └─ 분석 상세 화면 (영상 + 메트릭 + 코칭)
```

### 인증 플로우 (카카오 예시)

```
[Flutter 앱] 카카오 로그인 버튼
    │
    ▼
[카카오 SDK] 카카오톡 앱/웹 로그인 → OAuth Access Token
    │
    ▼ POST /auth/kakao {access_token}
    │
[Cloud Run 백엔드]
    ├─ GET https://kapi.kakao.com/v2/user/me (토큰 검증)
    ├─ Firebase Auth: 사용자 생성/조회 (uid: "kakao:{id}")
    └─ Firebase Custom Token 생성 → 응답
    │
    ▼
[Flutter 앱]
    ├─ FirebaseAuth.signInWithCustomToken(token)
    ├─ authProvider → AuthStatus.authenticated
    └─ MainLayoutScreen으로 이동
```

### AI 코치 대화 플로우

```
[Flutter 앱] 사용자 질문 입력
    │
    ▼ POST /ai_coach/chat {user_id, message, conversation_id?}
    │
[Cloud Run 백엔드]
    ├─ Firestore에서 최근 5개 분석 결과 조회
    ├─ 사용자 통계 조회
    ├─ 최근 부상 경고 3개 조회
    ├─ 컨텍스트 프롬프트 구성:
    │   ├─ BWF 공식 코칭 레퍼런스
    │   ├─ 사용자 분석 데이터
    │   ├─ 사용자 통계
    │   └─ 부상 경고
    └─ Gemini 2.5 Pro 호출 → 한국어 답변 (300자 이내)
    │
    ▼
[Flutter 앱] 채팅 UI에 응답 표시
```

---

## 6. GPU 인프라 & 비용

### Cloud Run GPU 설정

| 항목 | 값 |
|------|-----|
| GPU | NVIDIA L4 (24GB VRAM) |
| CPU | 4 vCPU |
| 메모리 | 16 GiB |
| GPU 비용 | ~$0.67/hr |
| Scale-to-Zero | 미사용 시 $0 |
| 분석 1건 (~60초) | ~$0.011 (~₩15) |

### 배포 명령어

```bash
# 모델 가중치 다운로드
bash scripts/download_models.sh

# GPU Docker 빌드
cd backend && docker build -t minton-smash-cv:gpu .

# CPU 빌드 (개발/테스트용)
docker build --build-arg BASE_IMAGE=python:3.11-slim --build-arg PYTORCH_EXTRA_INDEX="" -t minton-smash-cv:cpu .

# Cloud Run GPU 배포
gcloud run deploy minton-smash-cv \
  --image minton-smash-cv:gpu \
  --gpu 1 --gpu-type nvidia-l4 \
  --memory 16Gi --cpu 4
```

---

## 7. 빌드 환경

### Android

| 항목 | 값 |
|------|-----|
| Android Gradle Plugin | 8.9.1 |
| Gradle Wrapper | 8.11.1 |
| Kotlin | 2.1.0 |
| NDK | 27.0.12077973 |
| Java | 11 |
| Min SDK | Flutter 기본값 |

### iOS

| 항목 | 값 |
|------|-----|
| Bundle ID | com.dckwon.mintonSmash |
| URL Schemes | `kakao18648a6e358f2d09fcf450bb515fbafc`, `mintonsmash` |
| 카메라 사용 설명 | "This app needs camera access for real-time motion capture analysis." |

### 개발 서버

```bash
# Flutter 앱
cd minton_smash && flutter run

# 백엔드 (로컬)
cd backend && uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Docker CPU (로컬 테스트)
cd backend && docker build --build-arg BASE_IMAGE=python:3.11-slim --build-arg PYTORCH_EXTRA_INDEX="" -t minton-smash-cv:cpu .
docker run -p 8080:8080 minton-smash-cv:cpu

# Docker GPU (Cloud Run과 동일)
cd backend && docker build -t minton-smash-cv:gpu .
docker run --gpus all -p 8080:8080 minton-smash-cv:gpu

# Firebase 에뮬레이터
cd minton_smash && firebase emulators:start
```

---

## 8. 현재 MVP 상태

| 기능 | 상태 | 비고 |
|------|------|------|
| 실시간 포즈 감지 (ML Kit) | 구현 완료 | 33포인트, 온디바이스 |
| 카메라 녹화 + 갤러리 업로드 | 구현 완료 | |
| Firebase Storage 영상 업로드 | 구현 완료 | |
| 소셜 로그인 (카카오/네이버/구글/게스트) | 구현 완료 | |
| Firestore 실시간 데이터 동기화 | 구현 완료 | |
| AI 코치 채팅 (Gemini 2.5 Pro) | 구현 완료 | 컨텍스트 기반 |
| MediaPipe 영상 주석 + 실제 각도 추출 | 구현 완료 | random.uniform() 제거 |
| Gemini 멀티모달 영상 분석 | 구현 완료 | 실제 영상 업로드 |
| 부상 위험 감지 & 경고 | 구현 완료 | 자동 임계값 체크 |
| 분석 탭 (히스토리 + 촬영 가이드) | 구현 완료 | |
| TrackNetV3 셔틀콕 추적 | 구현 완료 | GPU 추론, mock 폴백 |
| YOLOv8-Pose 스윙 감지 | 구현 완료 | 17 키포인트, 페이즈 감지 |
| MotionAGFormer 3D 포즈 리프팅 | 구현 완료 | 2D→3D, 3D 생체역학 |
| SRA 셔틀콕 타격 프레임 특정 | 구현 완료 | TrackNet + YOLO 융합 |
| Docker GPU 빌드 (CUDA 12.1) | 구현 완료 | L4 GPU 지원 |
| 모델 가중치 다운로드 스크립트 | 구현 완료 | `scripts/download_models.sh` |
| Firestore 보안 규칙 | **개발 모드** | 2026-04-02 만료 |


무료 회원: 월 3회 무료 분석
유료 회원 (₩6,900/월): 월 30회 + AI코치 채팅 무제한
추가 분석: ₩300/건 (유료 회원 할인)