# 챕터 2 환경 소품 원본

편집 원본: `chapter2_props.blend`의 `Scene`. 원본은 개별 파단석·룬·금속·수정 외피·내부 광물 조각을 유지한다. 최종 GLB는 `assets/images/stage1_3d/environment/chapter2_props.glb`이며, 내보낼 때만 불투명 메시를 재질별로 합친다. 스튜디오 카메라·조명·바닥은 GLB에서 제외한다.

| 루트 | 원점과 크기(Blender XYZ) |
| --- | --- |
| `rune_pillar` | 기존 지면 중심 유지, 하부 포함 약 1.183 × 1.120 × 1.926; Z -.777~1.149 |
| `crystal_cluster` | 기존 지면 중심 유지, 하부 포함 약 1.180 × 1.121 × 1.419; Z -.774~.645 |
| `void_fissure` | 기존 피벗 유지, 하부 포함 약 1.322 × 1.256 × 1.061; Z -.871~.190 |

Godot은 Y-up으로 내보낸다. 부유암반의 수평 범위는 루트 중심 ±.70 안이다. 균열 윗바위면을 지면에 맞추려면 전체 bounds의 최대 Y를 뺀 위치에 배치한다. 상세 원본 bounds는 `bounds.json` 참고.

시안: `design/chapter2_asset_concepts/02-rune-pillar.png`, `03-crystal-cluster.png`, `04-void-fissure.png`.

## 소재와 검수

- 석재는 기존 승인 `C1_natural_rock_faces_basecolor.png`/`normal.png`의 한 돌 면을 Blender에서 재베이크한 512px albedo/normal과 면별 `Color` 속성을 사용한다. 원본 텍스처는 `design/stage1_3d/environment/approved_textures/`에 있다.
- 수정 외피와 내부 세로 광물 파편은 실제 분리된 메시이며 native alpha blend PBR이다. 화면 굴절·광학 커스텀 shader는 사용하지 않는다. 외피는 진보라 몸체와 청록 끝, 0 metallic, .13 roughness, 뿌리 .42→끝 .34 정점 alpha를 쓴다. 수정마다 여러 깊이의 비평면 광물 조각 14개를 두고 실제 외피 BVH 경계 안으로 제한한다. 내층의 포함물 이미지는 Blender에서 베이크한 표면 색 정보이며 반사 하이라이트를 그린 이미지가 아니다.
- Blender 5.2 exporter의 기본 MATERIAL 정점색 선택은 MixRGB 아래 색을 `COLOR_1`로 보내고 흰 `COLOR_0`를 생성할 수 있다. 이 원본은 `export_vertex_color='NAME'`, `export_vertex_color_name='Color'`, `export_all_vertex_colors=False`를 명시한다. Godot에서 `COLOR_0`를 albedo에 사용해야 한다.
- `*-studio.png`는 Blender 원본 검수 이미지다. 게임 내 재질·투명 정렬·공용 반사 및 실제 작은 크기의 수용성은 Android 검수로 별도 판단한다. 게임에서는 보라색 몸체·청록 끝·외피 안의 광물층이 구분되는지 확인한다.

## 편집 후 내보내기

수작업으로 `.blend`를 편집·저장한 뒤 원본을 다시 만들지 않고 내보낸다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python design/chapter2_3d/props/build_props.py -- --export-only
```

스튜디오 이미지도 갱신하려면 `--render`를 추가한다. 생성부터 다시 할 때만 `--regenerate`를 명시한다. 이 경로는 수작업 편집을 덮으므로 기존 원본을 백업한 뒤 사용한다. 제작 중 Blender MCP가 응답하지 않아 GUI를 건드리지 않는 별도 background Blender를 사용했다.

## 본판과 연결되는 부유 조각

`add_floating_ground.py`는 현재 편집 원본을 열어 `floating_ground*` 메시만 갱신한다. 상부 소품을 초기 생성기로 다시 만들지 않는다. 긴 절단면과 깨진 코너를 갖는 비대칭 판상 조각이며, 넓은 상판 4개의 절단선이 엇갈리도록 배치해 방사형 균열을 피한다. 하부는 중앙으로 모이지 않는 절단벽이며, 서로 다른 밑면 높이와 빠진 가장자리 돌로 작은 비대칭 단차를 유지한다.

상면 `chapter2_build`와 측면 `chapter2_side`는 `design/chapter2_3d/tiles/chapter2-tiles.blend`에서 직접 가져온 실제 재질이다. 동일한 albedo/normal/roughness 맵과 normal 강도, 타일의 월드 단위 planar UV 및 돌쌓임 제작 함수를 재사용한다. 타일 원본·맵·GLB는 수정하지 않는다. 기존 상부 소품의 재질도 그대로 유지한다. 기둥·수정은 상면 Z .018에 기존 기단 하부가 살짝 묻히고, 균열은 양쪽을 분리해 골짜기를 유지한다.

기존 소품 메시 228개의 정점·면·재질 이름 fingerprint가 동일함을 검사했다. 기존 자주색 깊이판만 Z를 -.64 내리고 가로/세로 범위를 골짜기 안쪽으로 줄였다. 사각 판이 절벽 밑으로 노출되지 않도록 하기 위한 지면 조정이며 상부 조형을 변경하지 않는다. 원본 이전 상태는 `before-floating-ground.blend`에 보존했다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python design/chapter2_3d/props/add_floating_ground.py
```

일반 편집은 `.blend` 저장 후 기존 `--export-only` 경로를 사용한다. 명시적 `--regenerate` 경로도 같은 하부 함수를 호출한다. 최신 범위와 기존 메시 보존 결과는 `floating-ground-check.json`, GLB 해시·용량·메시 비용은 `export-check.json`에 있다.

`tile-ground-comparison.png`는 같은 Blender 장면·조명에서 왼쪽에 실제 `chapter2_tiles.glb`의 건설 타일, 오른쪽에 소품을 둔 비교다. 상면 색과 텍셀 스케일, 측면 돌쌓임 재질을 직접 확인했다. `*-studio.png`에는 소품 세 종류의 전체 모습이 있다.
