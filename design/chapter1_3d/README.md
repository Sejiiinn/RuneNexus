# 스테이지 2~5 3D 전장 확장

2026-09-13. Android 본게임에서 기존 Godot 표시 범위를 스테이지 1~5로 확장했다. 공용 Blender 길·건설 타일과 포탈·코어·포탑·적 모델을 각 실제 맵에 배치한다. 스테이지 1의 전용 전체 환경·식생은 원래 맵에서 유지한다. 2~5에도 [승인 군락 기반 환경 장식](environment/README.md)을 맵에 맞춰 추가했다. 현재 6~10은 [챕터 2 전장](../chapter2_3d/README.md)을 사용하며, 11 이후와 Android 이외 플랫폼은 기존 2D 표시를 유지한다.

기존 웨이브·해금·저장·전투 수치는 변경하지 않는다. 로딩 화면과 고정/드론 시점을 공통 사용한다. 다른 스테이지로 전환하면 이전 투영·표시 그룹·효과를 즉시 무효화하고 새 Godot 장면 응답을 기다린다. 짧은 탄환과 전투 효과 전달도 현재 Android 1~10 지원 범위를 따른다.

## 검증

- 1~5 확장 당시 Flutter 관련 검사 45개와 정적 분석 통과. 실제 1~5 맵·투영 입력·적 모델 범위·6~15의 2D 유지·같은 게임 2→5→6 전환·지연 응답·로딩·탄환·효과를 확인했다.
- Godot 검사에서 실제 1→2→3→4→5→1 맵 교체, 경로 연속성, 빈 타일·포탈·코어 배치, 적·포탑 각 6종, 고정/드론 시점의 타일 포함과 깊이 범위를 확인했다. 검사 fixture는 실제 Dart 맵에서 생성하며 배포 프로젝트 밖에 둔다.
- 일반 `lib/main.dart` debug APK를 Android ARM64 에뮬레이터에서 실행했다. 디버거로 `RuneNexusApp`에 `MemorySaveRepository` 게임을 주입하고 2~5를 해금한 검사 상태를 사용했다. 검사용 해금·전투 진행을 기존 계정·로컬 저장에 기록하지 않았다.
- 스테이지 선택 UI로 2에 진입해 로딩→3D 전환을 확인했다. 가운데 독립 건설칸에 기관총을 터치로 설치해 170→110G 차감과 실제 3D 위치·선택 범위를 확인했다. 드론 시점에서 정상 웨이브의 적·체력 표시·코어 공격·포탑 피해를 확인했다.
- 같은 게임의 공개 `startStage`를 호출해 3→4→5 전환과 새 3D 맵·HUD를 직접 확인했다. 검사 상태 주입과 화면 전환은 실행 중 디버거에서만 수행했으며 제품 진입점이나 저장 로직은 변경하지 않았다.
- APK 빌드·설치까지 수행했다. 공개 배포·커밋은 하지 않았다. 실기기 지속 전투 성능을 측정한 검수는 아니다.

## 환경 장식 추가 검증 (2026-09-13)

후속 APK에서 2~5의 고정 시점, 5의 드론 시점을 확인했다. 2의 중앙 섬을 터치해 기관총 설치(170→110G) 시 고사리·꽃과 그림자가 숨고 가장자리 바위가 남으며, 환불(110→155G) 후 식생이 복원됐다. 위와 같은 메모리 저장 게임을 사용했으며 검사용 진행을 계정에 기록하지 않았다. 새 맵 장식·점유·재방문 및 기존 1 환경의 Godot 검사 모두 실패 0건이다. 저장된 Blender 파일에서 네 GLB를 다시 내보내 바이트 일치도 확인했다. 5 드론 시점에서 발견한 상단 시점 버튼·건설칸 겹침은 버튼을 HUD 쪽으로 올려 해소했고, 마지막 5의 두 시점 캡처에 반영했다. Flutter 관련 테스트 10개·정적 분석과 최종 APK 재빌드도 통과했다.

같은 Android ARM64 디버그 APK는 495,055,254→497,014,398바이트(+1,959,144, 약 0.40%). 새 환경 원본 GLB 총 3,212,524바이트이며, Godot PCK에만 포함된다. PCK는 74,365,128바이트, APK에 별도 원본 GLB나 `design/` 파일은 없다. 공개 릴리즈 APK 용량·성능 검증과는 구분한다. 추가 텍스처·광원·스킨을 사용하지 않는다.

- [환경 적용 스테이지 2](verification/stage2-environment.png), [설치 후](verification/stage2-environment-built.png), [환불 후 복원](verification/stage2-environment-restored.png)
- [환경 적용 스테이지 3](verification/stage3-environment.png)
- [환경 적용 스테이지 4](verification/stage4-environment.png)
- [환경 적용 스테이지 5](verification/stage5-environment.png), [드론 시점](verification/stage5-environment-drone.png)

## 환경 추가 전 Android 화면

- [스테이지 2](verification/stage2-angled.png), [로딩](verification/stage2-loading.png), [건설·비용 차감](verification/stage2-building.png), [드론 시점 전투](verification/stage2-drone-combat.png)
- [스테이지 3](verification/stage3-angled.png)
- [스테이지 4](verification/stage4-angled.png)
- [스테이지 5](verification/stage5-angled.png)

현행 표시 계약과 실행 경로는 [본게임 3D 전장](../../docs/stage1_3d_preview.md)을 따른다.
