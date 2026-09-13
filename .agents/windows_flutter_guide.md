# Windows Flutter Guide

Windows에서 Flutter/Dart 명령을 실행할 때만 적용한다. 공통 명령은 [AGENTS.md](../AGENTS.md#flutter-공통-검증), 서버와 실제 화면 확인은 [인앱 검증](in_app_test_guide.md)을 따른다.

## SDK 실행

Windows의 배치 래퍼는 오래 멈추거나 `dartaotruntime.exe`의 `Access denied` 오류를 낼 수 있다. 포맷은 가능한 경우 직접 Dart SDK를 호출한다.

```powershell
C:\Users\rlatp\develop\flutter\bin\cache\dart-sdk\bin\dart.exe format <수정 파일>
```

위 경로가 없는 환경에서는 설치된 SDK 위치를 확인한다. 실제 실행 권한 문제는 [권한 기준](sandbox_command_guide.md)을 따른다.
