# 챕터 3 스테이지 11 이식

2026-09-18 두꺼운 Blender 타일을 실제 스테이지 11에 연결했다. 첫 이식은 사용자가 참조와 다르다고 지적했으므로 채택 결과로 취급하지 않는다. 현재 외형 기준은 [사용자 참조](reference-fix/target.jpg)와 [교체형 패널·타일 혼합 배치](modular-panels/README.md), [환기구 열기 가독성 복원](vent-readability/README.md), [설치 타일 포함 무작위 패널 배치](random-vents/README.md)를 따른다. 이전 [참조 외형 수정 기록](reference-fix/README.md)은 해당 단계의 검수 기록이다. [벽체 연결형 파이프·배기구 3종](integrated-mounts/README.md)을 추가했다. 기존 맵 좌표·경로·건설칸·HUD를 유지하며 총 53개 타일 중 길 5칸에 열 배출 격자를 적용한다. 스테이지 12~15는 기존 2D를 유지한다.

- [벽체 연결형 장식 적용 후 실제 Android 화면](integrated-mounts/android-stage11.png)
- [수정 후 포탑 설치 화면](reference-fix/android-stage11-final-built.png)
- [터치 설치·선택 확인](verification/android-stage11-building.png)
- [Blender → GLB 원본·재질 이관 기록](../export/README.md)

캡처는 Android 17 arm64 에뮬레이터의 별도 `com.example.rune_nexus.godotpreview` 앱에서 실제 RuneNexusApp·Godot 전장·전투 HUD를 실행했다. `android_preview.dart`는 저장을 메모리로 격리하고 스테이지 11만 진입 가능하도록 앞선 10개 스테이지를 해금한다. 본게임 설치본과 저장 진행은 보존한다. 실제 인게임 캡처이며 합성 또는 Blender 렌더가 아니다.

첫 캡처에서 메시와 입력 연결은 확인했으나, 밝은 회색 표면·금색 링·약한 하부 깊이 때문에 참조 외형 재현은 실패했다. 실제 터치로 기관총을 설치했고 금액 170→110, 전투력 15.9, 선택 범위와 레벨 표시를 확인했다. 장시간 전투 성능 측정은 이번 시각 이식 확인에 포함하지 않았다.

검증: 관련 Flutter 18개 테스트, flutter analyze, Godot 스테이지 11 구조 검사 및 챕터 1·2 현행 검사 통과. 로그는 `../tiles/verification/`에 있다. 패키징 준비 unittest도 통과했다.

arm64 검증 APK 234,997,305 bytes, PCK 101,555,192 bytes. 이전 로컬 APK 221,347,325 bytes 및 PCK 90,985,404 bytes 대비 각각 +13,649,980 / +10,569,788 bytes다. 공개 배포본 비교는 아니며 배포하지 않았다. 승인 형상 및 PBR atlas 추가가 팩 증가 요인이다. 단일 arm64 ABI, PCK 한 개, 원본 GLB·Blender·design 파일 중복 포함 없음. PCK 논리/실제 중복 payload 0 bytes. 상세는 `verification/apk-before.json`, `apk-after.json`, `apk-audit.json` 참조.
