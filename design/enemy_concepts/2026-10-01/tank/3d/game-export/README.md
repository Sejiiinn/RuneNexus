# 승인 탱커 게임 적용

기존 탱커를 [승인 이동 원본](../walk/tank-walk.blend)의 모델과 보행으로 교체했다. 실제 desktop 게임 화면·동작과 관련 회귀, 별도 담당자의 독립 검증까지 완료했다. 적용 상태와 검증 근거는 이 문서에서 관리한다.

## 적용 산출물

- 게임 모델: [`assets/images/stage1_3d/enemies/tank.glb`](../../../../../../assets/images/stage1_3d/enemies/tank.glb). 이 폴더의 `tank-walk.glb`는 동일한 로컬 export 중간본이며 Git 추적에서 제외한다.
- GLB는 `12,405,040 bytes`다. 게임 준비 경로는 `assets/images/stage1_3d/`만 포함하고 `design/`의 제작 원본·중복 export는 게임 패키징 대상이 아니다. staged GLB는 기존 texture dedup으로 이미지 URI만 변경하며 BIN/나머지 JSON/4개 texture payload는 shipping과 byte 동일하다.
- 편집 가능한 게임 변환 원본: [tank-walk-runtime.blend](tank-walk-runtime.blend), `Tank_Walk_Runtime` 씬 / `Tank_Runtime_Rig` / `Walk` 액션. 승인 authoring 원본의 38개 메시와 재질은 보존하고 게임에서는 36개 돌 조각을 한 skinned surface로 묶어 실제 코어 구 2개와 총 3개 surface로 표시한다. 형상은 21,664삼각형 / 14개 rigid bone 그대로다.
- 2048² PBR atlas: [color](tank-color.png), [roughness](tank-roughness.png), [metallic](tank-metallic.png), [normal](tank-normal.png), [emission](tank-emission.png). 원본 Object 좌표를 `RestObject`로 보존해 프로시저럴 풍화돌을 UV bake했다. 균열과 음각 룬은 실제 메시다.
- 코어는 원본 크기의 실제 유리구/내부구다. glTF가 전달하지 못하는 내부구의 Layer Weight 색·발광 ramp는 [tank_amber_nucleus.gdshader](../../../../../../godot/effects/tank_amber_nucleus.gdshader)에서 실제 sphere normal/view로 재현한다. 탱커 구에만 specular/roughness 보정을 적용한다.
- 화상·냉각은 탱커 고유 bind의 `tank_status_burn.res`, `tank_status_frost_shards.res`, `tank_status_frost_grains.res`를 공유한다. [제작 데이터](tank-status-attachments.json). 작은 청록 눈과 비발광 룬, 코어 구는 성에로 덮지 않는다.
- 호환용 사망 atlas: [tank-death-slot.png](tank-death-slot.png), 편집 가능한 [death-atlas.xcf](death-atlas.xcf). 1536×192 atlas의 탱커 슬롯 4만 교체했고 다른 7개 슬롯 RGBA는 동일하다.

## 크기와 이동 계약

기준은 같은 REST geometry와 같은 표시 배율이다. 일반형 원본 높이 `4.533094734`, 탱커 `5.666368484`로 높이비 `1.25`를 보존한다. 일반형의 기준 폭 `4.129519224`로 두 모델을 변환하며 탱커 자신의 넓은 폭을 일반형 폭으로 축소하지 않는다.

기존 탱커 콘텐츠 `presentationScale=.65`는 유지한다. renderer 계수는 `(.55/.65)*1.15=.9730769231`로 두어 최종 world 계수가 일반형과 같은 `.55*1.15=.6325`가 된다. 공통 1.15를 중복 곱하지 않는다. 승인된 crouch/bob에 따른 순간 AABB 차이는 보행 그대로 유지한다.

`Walk` sampler 시각은 `0…26/60초`, preview 1주기 이동거리는 `.284375 tile`, 게임 표시 배율을 반영한 stride는 `.32703125 tile`이다. `phase=fposmod(실제 이동거리,stride)/stride`로 pose를 seek한다. 기존 게임 탱커 속도·HP·저항·경로·저장·전투 판정은 변경하지 않는다. 정지·감속·배속은 실제 이동거리를 따르고 텔레포트 거리 skip은 보행 phase를 증가시키지 않는다.

8개 지지 계층 bone은 원본의 0.1-frame sample 261개를 모두 유지한다. 몸통·머리·팔은 작은 오차 안에서 키를 줄인다. glTF 첫 키의 1/60초 offset은 제거했으며 끝 closure 키도 포함한다.

탱커 HP/armor/shield bar와 carrier만 현재 head bind bounds+bone pose+camera의 투영 상단에 붙인다. native label payload와 normal/fast 위치, 지면 상태 ring은 기존 계약을 유지한다.

네이티브 탱커 사망은 body/status/label과 전투 판정을 즉시 제거하고, [승인된 0.7초 붕괴·잔해 표현](../death/README.md)을 별도 presentation 노드로 재생한다. 제작 원본·수명·전환·최종 검증 상태는 해당 문서에서 관리한다. 별도 전달 `death` payload에 반응하는 기존 Canvas atlas/13조각·fade/drift/시간 경로는 새 탱커 슬롯으로 계속 호환된다.

## 실제 게임과 검증

- [게임 비교 화면](game-comparison.png): 실제 `main.tscn`/native combat의 지형·모델·조명·기본 카메라, drone 및 보조 근접 view. 원본 앱 HUD의 실제 탱커 웨이브도 별도로 확인했다.
- [실제 게임 이동 영상](game-walk.mp4): Metal Forward Mobile, 880×760, 60fps / 90frame / 1.5초. [12개 시간축 대표](game-walk-phases.png). native 이동을 매 1/60초 진행해 캡처했으며 source 모델 전용 preview가 아니다.
- [재질·사망 보조 근거](game-material-status-death.png): 탱커 교체 제작 당시의 원본 크기 코어 정면/사선, native 즉시 삭제와 호환 Canvas 입력을 기록한 과거 근거다. 이후 적용한 붕괴와 잔해의 현행 근거는 [사망 원본·실제 게임 검증](../death/README.md#실제-게임과-검증)을 따른다.
- 독립 shipping GLB 재수입: REST 높이비 `1.250000209`, 원본 vertex 최대오차 `1.0554e-6`, 21,664삼각형 / 3mesh / 14bone. 지지 구간 발 누적 drift `4.4381e-6 tile`, 접지오차 `4.4421e-6 tile`, 폐쇄오차 `1.49e-8 tile`.
- 독립 **Godot 엔진 실측**: REST normal `.694313884 tile`, tank `.867892027 tile`, 높이비 `1.249999528`; 발 지지 누적 drift `.003715108 tile`, 접지오차 `.001151862 tile`, 폐쇄오차 `1.786353e-7 tile`. Godot 기본 import가 30fps/13~14개 키로 재샘플링해 Blender 재수입보다 오차가 커진다. 정밀 helper의 `.001/.0001 tile` 기준은 초과했지만 최종 게임 크기에서 약 `.2/.06px`이며 실제 90개 시간축 frame과 인코딩 영상에서 가시 발 미끄럼·관통·연결/루프 결함이 없어 motion 독립 검수 PASS로 판정했다.
- 기본 검사 PASS: prepare 3 tests, skinned enemy presentation, burn 192 checks, frost 312 checks, battlefield labels/effects. 선택 native 회귀 `verify_native_enemy_state.gd`, `verify_teleport_gimmick.gd` PASS.
- 별도 담당자가 최종 GLB/texture 대응, Godot 실행의 크기·phase·status/해제·HPbar·삭제, 실제 영상/90frame 및 Canvas 호환 사망 입력을 직접 대조해 PASS했다. 원본 source hash와 normal/fast·전투/저장 계약 보존도 확인했다.

원시 frame/측정/로그·일회성 fixture는 ignored `local/`에 보관한다. 모든 실행은 사용자 플레이 저장과 분리했다. MCP 실제 앱은 `RuneNexus-tank-replacement-20261002-v3`, 최종 CLI fixture는 `RuneNexus-tank-replacement-fixture-20261002` custom user dir를 사용하고 fixture는 앱 저장 writer를 시작하지 않는다. 기존 helper editor 전체는 삭제하지 않고 `local/prior-godot-editor/`에 보존했으며 새 helper의 탱커 GLB/shader/atlas도 최종본으로 동기화했다. 열린 Blender frost mainfile의 미저장 상태와 다른 원본 씬도 보존했다. Android 실기기는 이번 desktop 검증 범위에 포함하지 않았으며 APK/배포를 수행하지 않았다.

## 제작 재실행

1. 열린 Blender를 보존하며 [stage_runtime.py](stage_runtime.py)를 Blender MCP로 실행한다. 현재 mainfile을 save/open하지 않고 `local/tank-runtime-staged.blend` library와 pose sample을 만든다.
2. 별도 background Blender에서 그 library를 열어 [export_runtime.py](export_runtime.py)를 실행한다. 기존 atlas를 재사용할 때 `-- --reuse-atlas`를 전달한다. 출력은 이 폴더의 GLB/runtime blend/atlas/[runtime-contract.json](runtime-contract.json)이다.
3. GLB를 게임 `tank.glb`에 복사한다. `scripts/prepare_godot_project.py` 이후 Godot import를 순차 실행한다. source에는 embedded GLB를 유지하고 staged asset의 texture dedup은 기존 준비 경로에 맡긴다.
4. bind/형상이 바뀐 경우에만 [bake_tank_status.gd](bake_tank_status.gd)를 prepared Godot에서 실행해 3개 resource를 갱신한다. 생성된 resources/attachment JSON을 게임 source와 이 폴더로 회수한다.
5. 사망 슬롯이 바뀌면 background Blender에서 승인 walk 원본과 [render_death_slot.py](render_death_slot.py)로 렌더한다. GIMP에서 XCF의 탱커 슬롯만 갱신해 atlas를 export한다.
