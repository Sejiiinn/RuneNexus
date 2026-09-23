# 냉각 포탑 충전·서리 안개 게임 적용

2026-09-23. 승인 원본은 [상위 시안](../README.md), 실제 적용은 `godot/main.gd`와 `godot/effects/frost_tower.gd`이다. 기존 냉각 포탑 GLB의 형태·재질 중 충전 대상이 아닌 표면과 적 성에 효과를 보존한다.

후속 미세 조정: 사용자 요청으로 안개 알파 계수만 0.32에서 0.36으로 높였다. 형태·색·운동·반경은 유지하며, 기존 게임 영상은 이 불투명도 조정 전 기록이다. 최신 근접 화면과 판정은 [독립 검증](review.md)을 따른다.

## 적용 계약

- 포탑과 건설 미리보기의 헤드는 회전하지 않는다. 냉각 포탑에 공용 총구 섬광·연기·포신 반동을 만들지 않는다.
- 기존 포탑 표시 배열의 뒤에 냉각 포탑만 `{cooldown, duration, radius}`를 덧붙인다. 8필드 입력도 안전하게 표시한다. 전투 피해·공격 간격·대상 판정·저장 스키마는 변경하지 않았다.
- 실제 남은 쿨타임과 해당 공격에서 정한 `lastBaseCooldown`으로 하단→상단 충전한다. 잔여 쿨타임만 저장된 복원 상태는 현재 공속과 잔여시간으로 분모를 보완한다. 적이 없으면 충전 완료를 유지한다.
- 처음 받은 발사 순번은 기준으로만 보관한다. 복원된 과거 발사를 재생하지 않는다. 이후 증가한 발사 순번에서만 안개가 시작되며, 실제 전투 시계로 나이를 계산한다. 정지·배속을 따르고 시간/순번 되감기에는 남은 안개를 제거한다. 매각·장면 초기화는 포탑의 자식 효과를 함께 해제한다.
- `centeredAreaRadius / tile_size`를 표시 반경으로 전달한다. 실제 광역 피해·감속은 기존 전투의 발사 순간 판정을 유지하며, 안개는 그 방출을 보여 주는 시각 효과이다.
- 승인 안개 GLB와 32개 정적 MultiMesh 인스턴스·noise를 공유한다. 매 프레임 입자별 CPU 이동이나 노드 생성/삭제는 없다. 정점 shader가 기존 시안의 이동을 수행하며 fragment의 noise 샘플은 2회이다. 나이·반경 재질은 포탑마다 분리하고 충전은 인스턴스 shader parameter로 전달한다.
- 충전 높이는 메시→포탑 로컬 변환으로 계산하므로 포탑 배치 높이와 미리보기의 상하 이동에 영향을 받지 않는다.
- 청록 광원은 그림자 없이 범위 1.15를 유지하고 최대 4개만 활성화한다. 이 예산은 기존 착탄 광원 4개와 별개이다. 에너지가 0이면 숨기며, 값이 바뀔 때만 에너지를 갱신한다.
- 기존 `battlefield_effects.gd`가 이미 frost impact 캔버스를 억제하므로 이를 다시 만들지 않았다. 일반 폭발·다른 포탑 총구 표현과 기존 적 성에를 변경하지 않았다.

## 확인한 결과

Godot 4.7.2, Apple M4, Metal Forward Mobile, 실제 앱(`--app`) 660×1100에서 확인했다. APK는 만들지 않았다.

- [계약 검사](contract.log): `godot/verify_frost_charge.gd`, 실패 0. 독립 충전·공유 32개 geometry·개별 effect clock, 실제 반경, 준비 대기, 발사 후 방전, 정지, 시간 되감기, 회전/반동 제거, 구 8필드, 복원 발사순번 40(피드백 0과 잔여 피드백 모두), 매각/ID 재사용, 광원 상한, 초기화, 저장 잔여시간 분모, 표시 코드의 전투상태 불변을 확인했다.
- [기존 전투 검사](combat-regression.log): `verify_legacy_combat_regressions.gd` 7,346 assertions PASS. 실제 냉각 범위·공통 치명타·감속·피해 관련 기존 계약 포함.
- [앱 실행 결과](report.json): 실패 0, 실제 건설 4기 중 냉각 2기, 기존 전투 경로 발사·적 감속 확인. 실제 pause 명령 후 30회 벽시계 입력에도 전투시계 고정. 실제 speed=4 명령 후 0.05초 입력으로 전투시계 0.2초 진행.
- [근접 보완 결과](detail-report.json): 실패 0. 앱 카메라 갱신 뒤 검수 카메라를 적용해 실제 충전·방출을 추가 촬영했다. 게임 소스는 바꾸지 않았다.
- 원본 냉각 GLB SHA-256: `43d87d3eae5fb3ac0867bcf4701e36df17b77570221d00f11dc08785aad26d26`.

## 실제 화면

| 상태 | 근거 |
|---|---|
| 적 없는 준비 대기·전체 충전 | [ready-waiting.png](ready-waiting.png), [model-hero.png](model-hero.png) |
| 실제 쿨타임 중 하단→상단 충전 | [detail-charging.png](detail-charging.png), [app-charging.png](app-charging.png) |
| 방전·3D 안개·기존 적 감속 | [detail-release.png](detail-release.png), [app-release-slowed.png](app-release-slowed.png) |
| 실제 정지 | [app-paused-release.png](app-paused-release.png) |
| 실제 4배속 명령·전투 시계 확인 | [하네스 결과](report.json), [검수 스크립트](verify_ingame.gd) — HUD 화면 증빙은 제외 |
| 다중 포탑·드론 | [app-drone.png](app-drone.png) |

[실제 게임 영상](gameplay.mp4)은 `frames/0000.png`부터 `0143.png`까지의 실제 전투 24fps·6초 캡처를 묶었다. 재생 시각 근거용이다. 캡처 중 디스크 쓰기가 있으므로 성능 측정 자료가 아니다.

## 재현과 격리

기존 `production/verify_ingame.gd`를 같은 실제 앱 검수 방식으로 확장한 [검수 스크립트](verify_ingame.gd)를 사용한다. 격리 프로젝트는 `build/godot/frost-charge-integration`, 저장은 `RuneNexus-Frost-Charge-Integration`이다. 기존 editor, embedded 실행, local-play 인스턴스·저장을 보존했다. 공용 prepare를 실행하지 않고 준비된 frost-review의 독립 복사에 현재 원본 소스와 새 GLB만 동기화했다.

```sh
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --path build/godot/frost-charge-integration --script res://verify_frost_charge.gd
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --path build/godot/frost-charge-integration --script res://verify_legacy_combat_regressions.gd
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --path build/godot/frost-charge-integration --resolution 660x1100 --script res://verify_ingame.gd -- --app
```

기존 전투 fixture는 `build/godot/test/fixtures/turret_stat_calculation.json`에 복사한다. 근접 캡처만 보완할 때 `--detail-only`를 추가하며 기존 144개 영상 프레임은 보존한다.

## 한계

이 통합 검수는 전체 게임 FPS·GPU 시간·Android 기기 성능 측정이 아니다. 시안의 8개 안개 성능 결과를 전체 게임 성능 보장으로 확장하지 않는다. 저장 스키마에 이전 발사의 실제 랜덤 쿨타임 분모가 없으므로, 복원 직후의 시각 충전비는 현재 공속 기반 추정이다. 남은 실제 쿨타임·발사 시점과 게임 계산은 변경하지 않는다.
