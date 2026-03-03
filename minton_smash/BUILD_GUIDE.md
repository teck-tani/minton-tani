# Flutter 빌드 가이드 (Windows → Android 핸드폰)

## 사전 준비

- Flutter SDK: `C:\DevProgram\flutter\bin`
- USB 디버깅 활성화된 Android 핸드폰을 USB로 연결
- 현재 연결된 디바이스: **SM S908N** (Galaxy S22 Ultra, Android 16)

## 명령어 모음

PowerShell에서 `minton_smash` 폴더 기준으로 실행:

```powershell
cd C:\tani\minton-tani\minton_smash
```

### 1. 연결된 디바이스 확인

```powershell
C:\DevProgram\flutter\bin\flutter devices
```

### 2. 핸드폰에 빌드 + 설치 + 실행 (디버그 모드)

```powershell
C:\DevProgram\flutter\bin\flutter run -d R5CT22WW2DB
```

> `-d R5CT22WW2DB`는 디바이스 ID. `flutter devices`에서 확인 가능.
> 디바이스가 하나만 연결되어 있으면 `-d` 생략 가능.

### 3. 릴리스 모드로 실행 (성능 테스트용)

```powershell
C:\DevProgram\flutter\bin\flutter run -d R5CT22WW2DB --release
```

### 4. APK 빌드만 (설치는 수동)

```powershell
# 디버그 APK
C:\DevProgram\flutter\bin\flutter build apk --debug

# 릴리스 APK
C:\DevProgram\flutter\bin\flutter build apk --release
```

생성 경로: `build\app\outputs\flutter-apk\app-release.apk`

### 5. APK를 핸드폰에 수동 설치

```powershell
adb install build\app\outputs\flutter-apk\app-release.apk
```

### 6. App Bundle 빌드 (Play Store 업로드용)

```powershell
C:\DevProgram\flutter\bin\flutter build appbundle --release
```

생성 경로: `build\app\outputs\bundle\release\app-release.aab`

## 자주 쓰는 명령어

| 명령어 | 설명 |
|--------|------|
| `flutter pub get` | 패키지 설치 |
| `flutter clean` | 빌드 캐시 초기화 |
| `flutter analyze` | 린트/분석 |
| `flutter run` | 빌드 + 실행 |
| `flutter run --release` | 릴리스 모드 실행 |
| `flutter build apk` | APK 빌드 |
| `flutter build appbundle` | AAB 빌드 |
| `flutter logs` | 디바이스 로그 보기 |

## 핫 리로드 / 핫 리스타트

`flutter run` 실행 중 터미널에서:
- **`r`** → Hot Reload (UI 변경 즉시 반영)
- **`R`** → Hot Restart (앱 상태 초기화 후 재시작)
- **`q`** → 종료

## 빌드 에러 시

```powershell
C:\DevProgram\flutter\bin\flutter clean
C:\DevProgram\flutter\bin\flutter pub get
C:\DevProgram\flutter\bin\flutter run -d R5CT22WW2DB
```

## PATH 영구 등록 (선택)

매번 전체 경로를 입력하기 싫으면 PowerShell에서 한 번 실행:

```powershell
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\DevProgram\flutter\bin", "User")
```

이후 새 터미널에서 `flutter run`만으로 실행 가능.
