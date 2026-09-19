# 선택 상태·고리 계산의 Godot 이관

2026-09-19. 최종 Flame 제거 방향의 중간 단계. 전투 판정·타깃·사거리 스탯·저장 계약은 변경하지 않았다.

## 구현

- 정적 선택·범위·레벨·장착 젬·건설/보상 대상 상태를 revision 실제 적용 ACK 전까지 재전송하고 ACK 뒤 생략한다. 이후 선택 입력은 시계와 실제 조준만 반복 전송한다.
- Godot이 공용 전투 시계로 고리 phase와 레벨 오라를 계산한다. 지원 중 Flame 고리 phase 누적을 생략하고 미지원·2D 복귀 시 위상을 이어간다. 첫 ACK, 배속, 정지, 같은 칸 새 포탑을 포함한다.
- 정적 DTO 수집·비교, 실제 전투 계산과 전체 전장 프레임 전달은 남는다. 단일 포탑+조준 fixture의 selection JSON은 331→61 bytes(81.6% 감소)이며 전체 프레임/FPS 수치가 아니다.
- 함께 적용한 [화염 MultiMesh](../../../fire_tower_concepts/runic_3d/migration/README.md#2026-09-19-불꽃-메시-일괄-제출)는 기존 메시·재질·5개 불꽃의 운동과 GPU 입자를 보존한다. 표시 노드는 포탑 상부+포구 10→4, 발사체 5→2. 변환 업로드·정점·픽셀 수는 유지한다.
- [전투 이관 단위 문서](../../../../docs/godot_combat_migration_boundaries.md)를 추가했다. 이 항목은 후속 구현 경계·검증 기준의 문서화이며 전투 이관 완료가 아니다.

## 검증

- Dart 신규/관련 8 tests + 기존 view/frame 회귀 4 tests PASS. [로그](flutter-tests.log), [view/frame](view-frame-tests.log). view의 renderer unavailable/MissingPluginException 출력은 의도한 fallback 검사다.
- Godot 선택 lifecycle·기존 선택 0 failures, 기존 사거리 투영 캐시 728 checks PASS. [명령·결과](verification-results.txt).
- 화염 실제 Metal Mobile 변환 동등성·정지·wrap·seek·풀 재사용과 GPU 입자 정지/진행 검사는 [화염 검증 자료](../../../fire_tower_concepts/runic_3d/migration/multimesh-check/)에 기록했다.
- `flutter analyze` No issues, Android release APK 빌드·업데이트 설치 PASS. [분석](analyze.log), [빌드](android-build.log), [설치](install.log).
- 일반 `lib/main.dart`, 로컬 검수용 debug panel 포함, versionCode 2008. Android 17 ARM64 emulator-5554, 1080×2424, Godot 4.7.2. 기존 스테이지 1 저장에서 이어 진행했다. MSAA/그림자 등 저장된 그래픽 옵션은 변경하지 않았으며 정확한 설정값은 이번 실행에서 별도 수집하지 않았다. 이전 캡처와 픽셀 A/B로 간주하지 않는다.
- [보상 대상 강조·교체 표식](reward-target.png), 젬 장착 후 고리, [선택·레벨 변경·업그레이드 예상 범위](selection-level.png), [1배속 화염 사격](combat-fixed.png), [4배속 드론 사격](combat-4x-6s.png), [앱 복귀](resumed.png) 확인. 원본 영상: [1배속](combat.mp4), [4배속](combat-4x.mp4). 시각 검사용 녹화이며 성능 측정이 아니다. 검수 종료 상태는 23웨이브 시작 전 준비 상태다.
- 이번 실행 [Android 로그](android.log)에서 SCRIPT ERROR·Parse Error·FATAL EXCEPTION이 없었다. 모든 스테이지·실기기 지속 성능 검사 완료를 의미하지 않는다.

APK는 431,481,576 bytes로 직전 로컬 본게임 APK 대비 +18,304 bytes다. 압축 ZIP 주요 차이는 armeabi-v7a libapp.so +16,384, Godot PCK +1,920 bytes이며 새 에셋·엔진 의존성을 추가하지 않았다. design/ 원본 포함 없음. [용량·해시](apk-size.json), [코드·에셋 입력 해시](inputs.json). 외부 배포는 하지 않았다.

후속 요청으로 [60초 FPS를 재측정](../../../../docs/analysis/selection_multimesh_fps_20260919/README.md)했다. 대포 45.24 / 화염 29.93 Flutter 갱신/초로, 직전 대비 +2.7% / -4.9%다. 화염 전체 성능 개선은 확인하지 못했고 GPU 시간은 미측정이다.
