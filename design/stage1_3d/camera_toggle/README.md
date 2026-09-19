# 시점 버튼 축약

2026-09-19. 고정/드론 별도 버튼을 현재 시점 이름과 전환 아이콘의 버튼 하나로 통합. 누르면 반대 시점으로 전환한다. 높이 30→26, 가로 여백 8→6, 아이콘 16→14 logical px. 공용 GameButton 테마와 기존 카메라 전환 유지.

관련 widget test 2개, flutter analyze, Android release 빌드 PASS. Android API 37 ARM64 에뮬레이터 일반 본게임에서 고정→드론 전환·라벨·배치 확인. [고정](fixed.png), [드론](drone.png). 로컬 검수 APK versionCode 2008, 외부 배포 없음.
