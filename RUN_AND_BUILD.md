# Minton Smash 실행 & 빌드 가이드

## Flutter 앱 (minton_smash/)

### 로컬 실행

```bash
cd minton_smash

# 의존성 설치
flutter pub get

# 연결된 디바이스에서 실행 (디버그 모드)
flutter run

# 특정 디바이스 지정 실행
flutter devices                  # 연결된 디바이스 목록 확인
flutter run -d <device_id>       # 특정 디바이스에서 실행

# 웹에서 실행
flutter run -d chrome

# 코드 분석 (린트)
flutter analyze

# 테스트 실행
flutter test
flutter test test/widget_test.dart   # 단일 테스트 파일 실행
```

### 디바이스 빌드

```bash
cd minton_smash

# Android APK 빌드
flutter build apk                    # 릴리스 APK
flutter build apk --debug            # 디버그 APK
flutter build apk --release          # 릴리스 APK (명시적)

# Android App Bundle (Play Store 배포용)
flutter build appbundle

# iOS 빌드 (macOS에서만 가능)
flutter build ios

# 빌드 결과물 위치
# APK:        build/app/outputs/flutter-apk/app-release.apk
# AAB:        build/app/outputs/bundle/release/app-release.aab
# iOS:        build/ios/iphoneos/Runner.app
```

### 디바이스에 직접 설치

```bash
cd minton_smash

# 빌드 + 설치를 한번에 (디바이스 연결 필요)
flutter install

# APK 직접 설치 (Android)
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Python 백엔드 (backend/)

### 로컬 실행

```bash
cd backend

# 가상환경 생성 및 활성화
python -m venv venv
source venv/bin/activate          # Linux/Mac
venv\Scripts\activate             # Windows

# 의존성 설치
pip install -r requirements.txt

# 서버 실행 (개발 모드, 핫리로드)
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

서버 실행 후 API 문서: `http://localhost:8000/docs`

### Docker 실행

```bash
cd backend

# CPU 빌드 (개발/테스트용, GPU 불필요)
docker build --build-arg BASE_IMAGE=python:3.11-slim --build-arg PYTORCH_EXTRA_INDEX="" -t minton-smash-cv:cpu .
docker run -p 8080:8080 minton-smash-cv:cpu

# GPU 빌드 (NVIDIA GPU 필요)
docker build -t minton-smash-cv:gpu .
docker run --gpus all -p 8080:8080 minton-smash-cv:gpu
```

---

## Firebase

```bash
cd minton_smash

# Firestore 규칙 배포
firebase deploy --only firestore:rules

# 로컬 에뮬레이터 실행
firebase emulators:start
```
