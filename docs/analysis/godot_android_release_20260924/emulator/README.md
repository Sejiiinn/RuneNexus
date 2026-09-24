# Android 격리 에뮬레이터 검증

2026-09-24 `RuneNexusGodotApi37`의 읽기 전용 인스턴스(`emulator-5554`)에 최종 `inspectionDebug` APK를 설치해 조작했다. 검수 패키지 ID는 `com.example.rune_nexus.godotonly`이며 운영 앱·운영 API·실제 로그인은 사용하지 않았다. [세부 결과](result.json).

로비에서 1단계를 열어 기관총을 배치했고 골드가 170→110, 전투력이 0→15.9로 바뀌었다. 웨이브 1/40을 시작해 적 이동·포탑 공격을 확인했다. Android 뒤로가기는 전투 하단 패널을 닫았다. 웨이브를 정지한 상태에서 HOME→앱 복귀 후에도 정지 상태가 유지됐다(정지 화면 (`paused-wave.png`, 로컬 검증 파일)).

전투 홈 메뉴로 저장한 뒤 검수 패키지만 force-stop→재실행했다. 로비에서 1/40라운드 이어하기가 표시됐고, 사용자가 이어하기를 누른 뒤 포탑 1개·골드 115·HP 20/20을 복원했다(복원 화면 (`restored-battle.png`, 로컬 검증 파일)). 이어하기를 누르면 정지 상태를 해제하는 것은 `godot/app/app_lifecycle.gd`의 계약이며 `godot/verify_app_lifecycle.gd`가 검사한다.

앱 로그의 네이티브 플러그인 `AndroidRuntime`·`RuneNexusPlatform` 등록을 확인했다. `SCRIPT ERROR`, 치명적 예외, 앱 종료, 검은 화면은 없었다. 시작 시 `res://main.tscn`의 UID `uid://bsx33k4sm13f8`을 찾지 못해 `res://main.gd` 텍스트 경로를 사용하는 경고와 `xr/shaders/enabled` 설정 경고가 각각 기록됐다. 실행을 막지 않은 리소스/엔진 경고로 분류한다. 에뮬레이터 MESA/ColorBuffer 메시지도 화면 오류로 이어지지 않았다. 원본 앱 프로세스 로그는 `build/godot/android-inspection/`에 있다.

실기기 GPU·서명된 production 패키지의 기존 앱 업그레이드·Google 로그인·운영 API·실제 업데이터 설치는 이 검수로 확인하지 않았다.

하단 탭은 전체 이미지의 축소 표시에서 잘려 보였으나 원본 확대와 픽셀/배치 대조로 정상임을 확인했다. 두 캡처의 최하단 52행은 동일하며 테두리와 하단 여백이 보존된다. 같은 비율 Godot 배치 검사도 화면 초과가 0이었다([대조 근거](hud-bottom-review.json)). 소스 변경이나 APK 재빌드는 하지 않았다.
