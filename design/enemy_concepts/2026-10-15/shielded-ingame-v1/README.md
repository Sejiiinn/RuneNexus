# 방어막 적 게임용 에셋

채택한 단일뷰 9,757삼각형·청회색 석재/금동·하늘색 룬 원본을 게임용 GLB로 옮긴 결과다. 현재 GLB는 같은 형상·재질·Idle에 `Death` 클립을 더한 [사망 모션](../shielded-death-v1/README.md) 출력이며, 아래 SHA·검증 수치는 Idle만 있던 v1 기준이다. 원본 Blender·2K 텍스처는 외장 SSD에 보존하며 경로와 SHA는 `asset-contract.json`에서 관리한다.

- 게임 파일: `assets/images/stage1_3d/enemies/shielded.glb` → `res://assets/enemies/shielded.glb`.
- Y-up, 원점 `(0,0,0)`, 높이 약 `0.915336`. 정면 룬은 +Z 쪽이며 실제 면의 수평 법선에는 직립 후 약 -12.37°의 편향이 남는다. 게임 표시 크기는 기존 표시 책임에서 정규화한다.
- `HoverRoot` 아래 본체·고리·4개 물리 부유석과 각각의 `*Pivot`을 보존한다. `Idle`은 24초이며 본체 부유·고리 회전·부유석 자전이 모두 구워져 있다. 네 돌은 각 `1/-2/3/-4`회전한다. GLB 시간 키는 Blender의 프레임 1 오프셋을 제거한 정확한 `0..24초`다. 전투 시계로 같은 클립을 seek하여 정지·배속·복원을 처리한다.
- 기존 Albedo/Normal PNG 바이트를 그대로 GLB에 포함했다. 원래 UV의 procedural 발광만 Blender Cycles `EMIT`로 베이크하고 표준 glTF emissive texture와 강도 `3.8`로 연결했다. 재질은 metallic `0`, roughness `0.8`이다. 제작 2K는 유지하고 게임 import 크기 제한은 1K를 출발점으로 사용한다.
- 스튜디오 카메라·광원은 GLB에 넣지 않았다. `BodyPivot/RuneFront`, `RuneBack`은 실제 광원을 붙일 수 있는 빈 anchor다. 게임은 필요한 1~2개 은은한 광원만 사용한다. 보호막 외피는 원본 메시와 분리된 게임 상태 효과다.

`export_shielded.py`는 채택 원본을 읽어 새 게임용 `.blend`와 GLB를 만든다. Blender 배치 실행에서는 원본 `.blend`를 미리 열어 `--python`으로 실행한다. MCP에서는 파일 열기 호출이 끝난 뒤 스크립트를 실행한다. `use_selected_to_active=False`를 명시하여 과거 노멀 베이크 설정을 상속하지 않는다. 내보낸 애니메이션 input accessor의 시간 원점만 0초로 정규화하며 곡선 출력·형상·이미지 바이트는 바꾸지 않는다. Godot 준비·실행은 수행하지 않는다.

`verify_export.py`는 실제 GLB의 정방향 corner 좌표·UV·normal·원 PNG 바이트·24초 클립을 대조하고 최종 577프레임의 부품 간섭을 확인한다. 좌표 오차 0, UV 약 `3e-8`, GLB normal 인코딩 차이 최대 `6.43e-5`이며 별도 바이너리 normal 보정은 하지 않았다. 실제 GLB를 Blender로 다시 가져와 6개 메시·피벗·PBR 연결·원 bounds·루프를 확인했다.

## 게임 연결과 확인 범위

2026-10-15 Godot 4.7.2 / Apple M4 / Mobile(Metal), 440×900 데스크톱 앱에서 확인했다. `shielded_presentation.gd`는 후속 사용자 교정에 따라 전투 표시값을 바꾸지 않고 시각 root를 첫 적용 대비 1.5배로 표시하며 중심 원본을 경로 위로 올린다. 원본 `Idle`을 전투 시계로 직접 샘플링하여 정지·배속·시간 복원을 따르며 기존 임의 root 부유를 중복하지 않는다. 전후 룬 anchor에 짧은 범위의 그림자 없는 OmniLight 두 개를 붙였고 범위는 확대 비율에 맞춰 0.6으로 유지한다. 룬 발광 텍스처와 실제 주변 표면의 조명 반응은 별개로 유지한다. HP바는 움직이는 실제 여섯 부품의 시각 상단을 따라가며 전투 크기·충돌·저장 수치는 보존한다.

중앙 본체의 원본 메시에는 약 26.75°의 깊이 방향 기울기가 구워져 있었다. 후속 교정은 `BodyPivot`만 측정한 상하 tip 축에서 수직으로 정렬하고 공통 부유의 미세 기울기도 본체에서 상쇄하여, 룬 광원과 상태 부착이 직립 본체를 함께 따르게 한다. 고리의 기울어진 회전축·네 돌의 원래 곡선·GLB·UV·PBR은 보존한다. 직립 후 바닥 여유와 막 안의 포함을 유지하도록 모델 높이는 0.61, 막 중심 높이는 0.55로 맞췄다.

진행 방향 교정은 직립 후에도 남은 중앙 룬 면의 수평 편향 약 -12.37°를 전체 모델 부모에서 상쇄한다. 기준은 실제 중앙 발광 삼각형의 면적·발광 가중 법선이며 단순 +Z 위치의 `RuneFront` 광원 anchor나 전체 정점 PCA를 정면으로 간주하지 않는다. 조립체 전체를 같은 수직축으로 회전하여 본체·고리·네 돌의 상대배치와 원래 곡선·간격을 보존한다. root의 경로·위치·크기·전투·저장과 구형 보호막은 그대로 둔다. 사망 모델에도 같은 부모 보정을 적용하여 처치 순간 자세·휘청임·낙하 방향이 일관되게 이어지고, Blender 원본의 정점 높이·착지를 보존한다.

보호막은 별도 경량 구체의 개별 instance parameter에 실제 `shield/maxShield`를 전달한다. 알파는 `잔량 비율 × (0.045 + 0.54 × rim)`으로 첫 적용보다 약 1.75배 선명하게 표시한다. 100→50→5%에 따라 옅어지고 0에서는 메시를 숨긴다. 본체와 고리는 보호막 파괴 후에도 남는다. 구체는 224삼각형이며 원본 9,757삼각형을 포함한 최대 합계는 9,981삼각형이다. 화상·냉각은 같은 여섯 부품 자세를 받는 표시용 스킨으로 붙여 기존 공통 화상 한 배치·얼음 두 배치를 유지한다. 입자 운동은 공통 GPU 시계, 부착 자료는 로딩 시 한 번 준비하고 공유한다.

실제 Stage 10 앱 HUD의 시작 버튼으로 콘텐츠 웨이브를 생성해 잔량별 외피·파괴 전환·룬 광원 on/off·화상/냉각을 확인했다. 지원 드론 시점과 2.5배 확대에서 같은 시간·개체·카메라로 100/50/0%를 비교했다. 관련 자동 검사 `verify_shielded_presentation.gd`, `verify_enemy_burn.gd`, `verify_enemy_frost.gd`, `verify_target_geometry_preparation.gd`, `verify_stage_effect_cache.gd`를 통과했다. 별도 검증자가 최종 GLB와 준비 프로젝트의 geometry/animation accessor·원 PNG 대응·1K import, 전용 표시·로딩 캐시 검사 및 실제 화면을 독립 확인했다.

직립 교정은 실제 기본·드론 화면과 24초의 577개 키 자세에서 본체와 다른 다섯 부품 간섭 0·바닥 여유·여섯 부품의 보호막 내부 포함을 확인했다. 이전 12초·4초 촬영은 내부 `_step()`만 호출해 표현 시계를 멈췄으므로 방향 전환·Idle 동작의 근거에서 제외했다. 진행 방향 교정 전의 직립·고리·돌 동작 근거는 공식 `NativeCombatRuntime.advance_session()`으로 실제 Stage 10을 진행한 `build/ignored/enemy-facing-review-20261015/enemy-corners-official-session.mp4`(10초)다. 화면 내부의 일반형 두 코너 전환과 보호막형의 직립·고리·네 돌 움직임을 확인하며, 대응 프레임의 전투/표현 시계·일반형 전방과 경로 방향·Idle 위상은 같은 폴더 `screens/facing-trace.json`에 보관한다. 그 촬영 당시에는 제품의 방향 계산과 승인 GLB를 변경하지 않았다. 후속 진행 방향 보정의 근거로 이 영상을 재사용하지 않는다.

진행 방향 보정 최종본은 같은 Godot 4.7.2/Mobile(Metal)/440×900 실제 Stage 10에서 공식 세션 시계로 확인했다. `build/ignored/shielded-facing-fix/final-motion/`의 200프레임과 `facing-trace.json`은 보호막형의 세 진행 방향·두 코너에서 실제 룬 면과 경로 방향의 내적 1.0을 기록하며, 화면 촬영 포함 1,758개 항목을 통과했다. `verify_shielded_presentation`, 사망 전달, 화상·냉각 관련 회귀와 최종 사망 회귀를 통과했다(`final-project-checks.json`의 해당 네 사례와 후속 `final-death-checks.json`). 독립 검증은 최종 변환의 Idle 577키·Death 308자세에서 새 본체/다른 부품 교차 0, 조립체 상대관계·정점 높이 보존과 룬 정면 보정·직립을 확인했다. 기본·드론 시점의 세 진행 방향과 고리·네 돌의 움직임도 실제 화면에서 확인했다. 최종 근거는 같은 폴더의 `final-*`와 `independent/`에 보관한다.

검증 로그·임시 저장·대표 이미지·영상은 로컬 `build/ignored/shielded-integration/`(직립 교정은 `upright-v3/`), 독립 결과는 `build/ignored/shielded-independent/`에 보관했다. 새 체크아웃의 필수 입력으로 사용하지 않는다. 사용자 지정 범위는 데스크톱까지이며 Android/APK·모바일 GPU 성능·공개 배포는 이번에 실행하지 않았다. 제작/출력 SHA 대응은 기존 `asset_workflow_report.py shielded-single-view-idle --verify-records`로 조회한다.
