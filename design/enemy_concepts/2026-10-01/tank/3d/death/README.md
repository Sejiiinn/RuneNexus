# 2026-10-02 이전 탱커 사망 붕괴 기록

역할: 2026-10-02 이전 모델의 제작·검증 이력. 아래 산출물·수치·실행 절차는 당시 기록이며, 현재 게임 출력과 재생 계약은 [최적화 탱커 게임 연결](../../../../2026-10-09/tank-game-integration/README.md)을 따른다.

## 모션과 적용 경계

- **0~0.15초**: 피격으로 살짝 뒤로 젖히고, 작은 호박 코어가 한 번 밝아진 뒤 꺼진다.
- **0.15~0.4초**: 무릎이 낮아지고 상체가 앞으로 기운다. 오른손은 약 0.27~0.4초에 실제 바닥에 닿아 지지한다.
- **0.4~0.7초**: 버티던 팔이 풀리고 가슴과 머리가 내려앉는다. 기존 어깨·팔의 큰 돌 덩어리 네 묶음이 떨어져 정착한다. 작은 파편 폭발은 없다.
- 손과 몸통 착지에 짧은 먼지 두 번을 붙였다. 본체 바깥 바닥의 8개 작은 puff이며 공용 카메라·조명·음향 설정은 바꾸지 않는다.
- **0.7~1.08초**: 무너진 원본 자세를 유지한다. **1.08~1.4초**에 소멸하고 root와 먼지를 함께 제거한다. 모두 전투 시계를 따라 정지·배속된다.

네이티브 사망 판정과 살아있는 body/status/HP 표시 제거는 즉시 진행한다. 잔해는 [guardian_preview.gd](../../../../../../godot/presentation/guardian_preview.gd)와 [tank_death.gd](../../../../../../godot/effects/tank_death.gd)의 표현 노드다. 타깃·피해·이동·저장·API 상태를 보유하지 않는다. 사망 시작은 마지막 보이는 위치·방향·배율·걷기 bone pose를 이어받고 0.1초 동안 원본 사망 자세에 수렴한다. 기존 normal 0.6초와 fast 0.55초 사망 경로는 유지한다. 별도 호환 Canvas `death` 입력도 유지하며 이 입력으로 네이티브 사망 root를 다시 생성하지 않는다.

## 유지하는 원본과 산출물

- 편집 가능한 38개 원본 메시: [tank-death.blend](tank-death.blend), `Tank_Heavy_Death` 접두사의 씬. 원래 돌·코어·눈·룬과 rigid bone 계층으로 사망 키를 편집한다.
- 게임 변환 원본: [tank-death-runtime.blend](tank-death-runtime.blend), `Tank_Death_Runtime` 접두사의 씬 / `Death` 액션 / 14개 bone / 3개 skinned surface. [build_death.py](build_death.py)와 [export_death.py](export_death.py)가 제작 입력이다.
- 게임 모델: [shipping tank_death.glb](../../../../../../assets/images/stage1_3d/enemies/tank_death.glb). 이 폴더의 `tank-death.glb`는 동일한 로컬 export 중간본이며 Git 추적에서 제외한다. [death-contract.json](death-contract.json)에 원본 해시·키 시점·형상 계약을 보관한다.
- 살아있는 원본 38개 메시·21,664삼각형·14개 bone의 형상, normal 기준 폭 정규화와 최종 `.6325` 배율을 그대로 쓴다. 걷기 GLB/Blender를 변경하지 않는다. 넓은 가슴·정상 머리 폭·짧고 굵은 다리·단일 등과 골반·풍화돌·청록 눈과 룬·작은 실제 구형 코어를 보존한다.
- 4개 embedded texture payload는 살아있는 탱커와 byte/hash 동일하다. 기존 준비기의 texture dedup은 image URI만 바꾸며 BIN과 나머지 JSON을 유지한다. `design/`의 편집 원본과 중복 GLB는 게임 패키징에 포함하지 않는다.
- 사망 돌 본체는 기존 불투명 깊이를 유지하고 마지막 소멸에만 dither discard를 사용한다. 한 surface의 눈과 안와를 투명 정렬로 분리하지 않는다. 코어와 소멸·먼지 파라미터는 corpse 전용 재질과 instance 값으로 적용하며 살아있는 재질을 변경하지 않는다.

## 실제 게임과 검증

- [기본 게임 영상](game-death.mp4): 실제 `main.tscn`/native combat/Metal Forward Mobile의 원래 카메라와 게임 배율, 880×760·60fps·1.7초. 걷기 12frame 후 native damage kill과 사망 90frame이다.
- [정면 사선·측면 보조 영상](game-death-detail.mp4): 같은 지형·조명·모델 배율에서 접점과 큰 조각을 확인하는 3.4초 영상. 보조 view만 카메라를 가까이 둔다.
- [3개 시점의 시간축](game-death-phases.png), [걷기→사망과 코어](game-death-transition.png): 초기 형태·얼굴 정합, 코어 1회 발광/소등, 손 지지·팔 풀림·착지 먼지, 잔해 유지·소멸을 확인했다. 부모와 구현 담당이 실제 최종 viewport를 직접 대조했다.
- 기본 검사 PASS: 준비기 3 tests, `verify_skinned_enemy_presentation.gd`, 선택 네이티브 회귀 `verify_native_enemy_state.gd`·`verify_teleport_gimmick.gd`. H264 출력은 880×760/60fps/1.7초이며 세 시점에서 다시 decode했다.
- 별도 검증자가 실제 Catalog+Native+Units+Labels의 29개 검사를 실행했다. 즉시 alive/target/body/status/HP 제거, 서로 다른 걷기 위상에서의 첫 pose/position/facing/scale 연속성, 동시 탱커 사망, 중복 kill/별도 death payload/소멸 뒤 replay, 정지·4배속, epoch·rewind·clear, normal/fast 보존이 PASS다.
- 최종 시간축·hold/fade·작은 착지 먼지·실제 worst halfkey viewport·source/prepared/editor 대응·출력 영상 decode까지 별도 검증자가 직접 확인해 독립 검증 전체 PASS로 판정했다. 미해결 시각 결함은 없다.
- 독립 GLB 대조에서 살아있는 모델과 모든 primitive의 geometry/normal/UV/joints/weights와 14개 joint 순서가 동일하고 inverse bind 최대차는 0이다. 실제 첫 사망 pose의 bone origin 최대차는 `6.66e-8 tile`, axis는 `9.35e-8`로 걷기 pose를 이어받는다.
- 사망에만 `animation/fps=60` import를 명시했다. 기본 30fps가 빠른 무릎 접힘의 발 접지 키를 건너뛰는 오차를 줄이고 다른 모델의 import는 유지한다. 실제 Godot skin의 60Hz 키 최저점은 `-0.000206 tile`이다. 독립 120Hz의 최악 중간 보간 시점 0.241667초는 `-0.007991 tile`이며 수치상 완전한 0 접지는 아니다. 그 한 시점의 실제 기본/front/side viewport에서 가시적인 관통이나 발 튐은 없음을 확인했다. 기본 게임 크기로 약 0.5px다.

원시 frame·측정·실행 로그·일회성 fixture·실패 초안은 ignored `local/`에 보관하며 위 최종 미디어만 유지한다. 먼지 위치와 60fps import의 영향인 0~0.95초를 다시 캡처했고, 이후 동일한 정착 pose의 hold/fade 근거는 재사용했다. fixture는 앱 저장 writer를 시작하지 않으며 사용자 플레이 저장을 변경하지 않는다. prepared 검수 설정은 `RuneNexus-tank-death-fixture-20261002` custom user dir다. Blender의 열린 frost mainfile·미저장 상태·기존 씬을 보존했고, Godot 편집 프로젝트의 기존 설정도 byte/hash 동일하게 보존하면서 source 링크와 새 에셋을 동기화했다. Android 실기기·APK·배포는 이번 범위에 포함하지 않았다.

## 제작 재실행

1. 기존 Blender MCP에서 [build_death.py](build_death.py)를 실행한다. 승인 walk/runtime 파일을 library로 읽고 별도 사망 library를 쓴다. 열린 mainfile의 save/open을 수행하지 않는다. 같은 이름이 열려 있으면 Blender의 숫자 suffix가 붙으므로 씬은 위 접두사로 찾는다.
2. 별도 background Blender에서 이 폴더의 `tank-death-runtime.blend`를 열고 [export_death.py](export_death.py)를 실행한다. 기존 packed atlas를 그대로 재사용한다.
3. GLB를 shipping `tank_death.glb`에 복사한 뒤 `python3 scripts/prepare_godot_project.py`와 prepared Godot import를 순차 실행한다. 준비기가 사망 GLB의 60fps import를 생성한다.
4. MCP 편집 프로젝트는 기존 helper로 준비한다. 공용 import/캐시는 복사하지 않고 해당 편집 에셋의 Animation FPS도 **60**으로 둔다. 이번 최종 편집 import에도 이를 적용했다.
