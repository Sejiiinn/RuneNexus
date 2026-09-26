# 냉각핀형 냉기 포탑 제작

승인 참조는 [냉각핀 시안](../iris-variants/03-ribbed-reactor.png)과 [보완 멀티뷰](../cooling-fin-multiview/cooling-fin-multiview.png)다. 멀티뷰의 RIGHT는 FRONT 반복이므로 실제 구조는 6장 셔터·6리브/냉각베이·4지지발로 정합화했다.

- 편집 원본: `frost.blend`. 기존에 열려 있던 다른 원본은 덮어쓰지 않고 독립 Scene으로 제작했다.
- 현재 게임 적용본은 [경량 모델](../optimized-game-distance/README.md)이다. 이 폴더의 `frost.blend`와 `frost.glb`는 표면 서리가 적용된 고해상도 원본으로 보관한다. 상하 청동 레일과 하부 소켓·발 연결부를 포함한 원본 부품은 개별 편집 가능하게 유지하고 GLB만 고정 몸체/고정 상단부/투명 표피 3메시로 병합했다.
- 현재 대표 Blender 렌더와 실제 게임 근거: [표면 서리 적용](../surface-frost-concept/integration/README.md). 형상 기준은 [기둥·상판 디테일 보완](detail-refinement/README.md)이다. `stage2f-hero.png`와 [review.md](review.md)는 보완 전 제작 단계의 기록이다.
- 수량·크기·해시·재질 목록: [model_audit.json](model_audit.json).
- HUD: `hud-frost.png`(256×256 RGBA), 편집 검수 Scene `hud-frost.blend`, 조건과 방향 기록 `hud-direction-verification.json`. 다른 다섯 아이콘은 변경하지 않았다.

실제 메시로 서로 겹치지 않는 두꺼운 곡선판 6장, 청동 pivot, 수직 냉각베이, 적층핀, 매립형 지지발 창, 표피와 내부 얼음층, 깊이가 다른 미세 균열과 서리를 구성했다. 금속/얼음 표면과 내부 냉광은 Blender에서 구워 기본 glTF PBR 텍스처로 전달한다. 평면 이미지로 입체 구조를 대체하지 않는다.

## 재현

Blender Python 경로를 사용한다. 새 작업 환경에서 아래 순서로 실행한다.

1. `bake_surfaces.py`: 금속·얼음의 basecolor/normal/roughness 생성.
2. `bake_ice_emission.py`: 얼음 내부 중심의 부드러운 냉광 생성.
3. `build_frost.py`: 메시/재질 생성, 원본과 병합 GLB 및 수량 감사 저장.
   병합용 복사본의 active-render UV를 공통 `UVMap`(UV0) 하나로 정규화한다. `World grain`과 `UVMap`을 그대로 병합하면 일부 primitive의 UV0가 상수로 채워져 Godot에서 텍스처가 사라진다.
4. `bake_surface_frost.py`의 `prepare(ns)` / `bake(ns)`를 실행하고 기존 namespace의 `export()`를 호출해 현재 표면 서리 재질을 베이크·내보낸다. [현재 재현 절차](../surface-frost-concept/integration/README.md#재현)를 따른다. 기본 `build_frost.py`만 실행하면 표면 서리 이전의 PBR 재질이 생성된다.
5. 생성 스크립트의 `render('hero')` / `render('top')`으로 대표 렌더. Blender MCP에서는 `exec(code, namespace)`로 실행한 동일 namespace의 함수를 호출한다.
6. `render_hud_icon.py`: 기존 `design/hud_turret_icons_fixed/render_icons.py`의 카메라·조명·256 RGBA 조건으로 frost 하나만 렌더한다.
7. `python3 check_glb_uv.py`: Blender와 독립된 GLB 바이너리 파서로 모든 텍스처 슬롯이 실제 선택한 UV의 분포·유한값을 검사하고 `glb_uv_validation.json`을 쓴다.

스크립트는 새 Scene을 생성한다. 같은 세션에서 반복 제작할 때는 이 제작 Scene만 제거한 뒤 재실행하며 다른 원본의 Scene·미저장 작업을 지우지 않는다.

## 게임 계약

`turret_root → turret_head → turret_barrel → muzzle` 이름과 계층을 유지한다. 몸체·베이·발은 root, 셔터·렌즈는 head에 속한다. barrel에는 발사 마커만 두어 게임의 barrel 반동으로 원형 헤드가 몸체에서 이탈하지 않는다. Blender +Z-up / -Y-forward를 glTF +Y-up / +Z-forward로 내보낸다.

투명 재질은 `Frost | transparent ice outer skin` 하나(alpha 0.13)다. 내부 얼음 재질 `Frost | deeply fractured blue ice lens`와 외피의 specular factor는 KHR_materials_specular로 전달한다. 엔진이 이 값을 지원하지 않으면 실제 Godot 캡처를 기준으로 대응하며 큰 흰 반사·기포로 렌즈 내부를 가리지 않는다. HUD 적용 경로는 `assets/images/ui/hud/turrets_3d/frost.png`다.

현재 모델 감사에는 253 편집 메시(검수용 바닥 제외), 4개 리그 노드, 7개 사용 이미지가 기록되어 있다. 제작 스크립트는 사용 이미지를 pack하고 hero 카메라와 함께 편집 원본을 저장한다. GLB는 같은 원본에서 임시 복사본만 병합해 3개 메시·19개 표면·7개 노드로 전달한다. Python 스크립트 구문 검사와 HUD 방향 검사도 통과했다. Blender 단계의 형태/재질은 독립 검수 PASS이며 실제 Godot·기기 최종 판정과 혼동하지 않는다.

## 게임 적용 검증

현재 경량 모델의 외형·충전·방출 검증은 [경량화 결과](../optimized-game-distance/README.md)를 따른다. 고해상도 원본의 표면 서리 적용은 [당시 결과](../surface-frost-concept/integration/README.md)에 보관하며, 아래 최초 적용 기록도 당시 상태의 근거다.

최종 GLB와 HUD를 정식 에셋 경로에 반영하고 Godot 프로젝트를 갱신했다. 최종 에셋은 72,752 삼각형, 12,576,616바이트이며 크기는 폭 0.8183 × 높이 0.5344다.

`verify_ingame.gd`는 별도 테스트 저장 디렉터리에서 실제 앱의 건설·선택·공격 경로를 실행한다. Godot 4.7.2 데스크톱 Mobile 렌더러에서 발사와 적 감속을 관찰했고 실패 항목은 없었다([실행 결과](godot/report.json)). 선택·전투·상단·사선 캡처는 `godot/`에 있다. 단계별 독립 시각 검수의 최종 판정은 [review.md](review.md)를 따른다. Android 실기기는 이번 검증 범위에 포함하지 않았다.
