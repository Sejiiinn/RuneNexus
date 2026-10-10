# 냉각 포탑 1만 내외 재베이크·게임 반영

원본 **47,912 → 11,760삼각형(75.5% 감소)**. Meshoptimizer `simplifyWithAttributes`, options `0`으로 원본 정점 위치만 선택해 부품별로 감량했다. 499개 연결 부품, 72개 냉각핀, 6장 셔터와 틈, 6개 베이, 4발, 오목한 창과 렌즈 깊이를 유지했다. 3메시·19표면·13재질과 7개 노드의 이름·계층·변환, 축과 치수를 보존한다.

최종 GLB를 게임 `assets/images/stage1_3d/turrets/frost.glb`에 반영했다. 47,912삼각형 입력은 Git `d83e73f32ee59112505b7e00c9222c4b774b0ef8`에 고정하며 제작 원본 두 Blend, 이전 33,566삼각형 통과 후보와 실패한 11,104삼각형 진단 후보를 보존했다. 실제 앱 검증은 [게임 반영 검사](integration/README.md)와 [독립 검증](integration-review.md)을 따른다. FPS·Android 성능은 측정하지 않았고 APK를 만들지 않았다.

## 결과물과 비교

- [게임 적용 GLB](frost-rebaked-10k.glb), SHA256 `efb65415c4b69e9e25ecd3625b49daed7805bd78eac25a8eda01c24cefc1221f`
- [편집 원본 Blend](frost-rebaked-10k.blend), SHA256 `0a43ba24f0f21f43b462118b36846e54a7289ce843e10ab4a7ced9d59741d082`
- 정면 근접: [원본](before-hero.png) / [감량 후](after-hero.png)
- 반대편 근접: [원본](before-opposite.png) / [감량 후](after-opposite.png)

Blender 비교는 1100×1100, Cycles CPU 48 samples, 동일 카메라·조명·색 관리로 렌더했다. 원본 이미지는 동일 원본 SHA와 조건의 기존 렌더를 재사용했다. 최종 렌더 대상 GLB SHA와 카메라는 [render-manifest.json](render-manifest.json)에 기록했다. UV 찢김·렌즈 잡음·금속 포화·하부링의 불규칙한 검은 패치는 해소했다. 저폴리 핀/볼트 곡면과 최하단 외곽의 작은 그림자 차이는 남는다. 독립 검수 결과는 [review.md](review.md)에 기록했으며 최종 PASS다.

Godot 검수는 macOS Mobile renderer의 격리된 표현 fixture에서 동일 카메라 4쌍과 충전 0/.5/1·발사 후 안개 4쌍을 대조했다. [runtime-summary.json](review/runtime-summary.json)과 [capture-conditions.json](review/capture-conditions.json)에 조건을 기록했고 `review/`에 원본 크기의 crop 16장을 보관했다. 이 비교 fixture의 결과는 해당 표현 상태를 확인한다. 최종 게임 반영 뒤 별도로 [실제 앱 HUD·건설·전투 확인](integration/README.md)을 수행했다. Android·FPS 결과로 확장하지 않는다.

## UV·PBR 전사 범위

xatlas 0.0.11로 새 `RebakeUV`를 만들고 원본 고밀도 메시에서 Cycles selected-to-active로 전사했다. Base Color, tangent normal(OpenGL +X/+Y/+Z), roughness, metallic, emission은 **기존 원본 재질과 맵의 전사**이며 새로 생성한 Albedo가 아니다. Roughness/metallic은 ORM의 G/B로 합쳤다. 최종 GLB에는 BC·normal·ORM 2048² 세 장과 렌즈 emission 1024² 한 장이 내장된다. RGBA8 단순 환산은 약 52MiB(원본 7장 약 61MiB); GPU 실제 메모리·성능 측정값은 아니다.

텍스처가 있는 6개 재질만 새 맵을 사용한다. 원래 비발광인 금속에는 emission texture를 연결하지 않는다. 나머지 7개 상수 재질 값과 이름은 유지했다. 충전용 `cold aluminum fins` / `cold circulating core` 표면은 존재하며 텍스처 노멀에 의존하지 않도록 핀 캡의 평면 노멀과 측면의 방사 노멀을 별도로 유지했다. 이 상수 재질들의 UV `.5/.5` 중첩은 텍스처를 샘플하지 않는 영역의 의도된 설정이다.

125개 텍스처 부품을 원본의 대응 연결 부품만 대상으로 격리해 bake했다. 임시 고밀도 원본의 UV 이름은 `UVMap`이며, GLB UV의 V를 Blender의 `1-v`로 변환한다. 이를 생략하면 원본 atlas의 빈 영역을 샘플하는 결함이 생긴다. 저폴리 정점 노멀은 원본 corner 중 face 방향과 가장 잘 맞는 값을 선택하며, 케이지 `.02`/광선 거리 `.06`으로 해당 원본 부품만 전사한다.

## 검사 근거

[geometry-manifest.json](geometry-manifest.json), [uv-manifest.json](uv-manifest.json), [bake-manifest.json](bake-manifest.json), [map-validation.json](map-validation.json)에 입력·삼각형·부품·atlas·packed 재열기·픽셀 검사를 기록했다. 자체 검사에서 실제 텍스처 재질의 1픽셀 내부 1,024,986 pixels는 중첩·검은 BC 누락·노멀 누락·퇴화/역방향 노멀 모두 0이었다. 노멀 벡터 길이는 0.940~1.007이다. 이 자체 픽셀 마스크는 제작 NPZ UV 기준이며, 독립 검수는 최종 GLB의 float32 UV와 내장 PNG로 별도 대조한다.

편집본에는 보이는 11,760삼각형 후보와 숨긴 원본 고밀도 3메시, 기존 7개 이미지와 새 4개 이미지가 packed 상태로 들어 있다. 저장 후 재열기에서 후보 삼각형 수, 11개 packed 이미지와 `dirty=false`를 확인했다. 제작/렌더 background Blender는 정상 종료했고 기존 GUI 인스턴스는 보존했다.

## 재생성

저장소 루트에서 아래 도구를 순서대로 실행한다. 중간 배열/로그/roughness·metallic 개별 맵은 `checks/`에 보관한다. 이 폴더는 Git 제외 대상이며 최종 4맵·편집본·대표 이미지·제작 도구를 유지한다. 추가 설치는 필요하지 않다.

```sh
/Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 design/frost_tower_concepts/2026-09-23/meshoptimizer-rebake-10k/scripts/prepare_geometry.py
/Volumes/KIOXIA_MAC/AI-3D/envs/pixal3d-mlx/bin/python design/frost_tower_concepts/2026-09-23/meshoptimizer-rebake-10k/scripts/unwrap_xatlas.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python design/frost_tower_concepts/2026-09-23/meshoptimizer-rebake-10k/scripts/bake_frost.py
/Volumes/KIOXIA_MAC/AI-3D/envs/pixal3d-mlx/bin/python design/frost_tower_concepts/2026-09-23/meshoptimizer-rebake-10k/scripts/validate_maps.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python design/frost_tower_concepts/2026-09-23/meshoptimizer-rebake-10k/scripts/render_rebake.py
```

입력은 Git `d83e73f32ee59112505b7e00c9222c4b774b0ef8:assets/images/stage1_3d/turrets/frost.glb`(SHA256 `7d71195e972710488c6912d68b1f3d5eb54ee38adf31f9a524788a8d1d3aee39`)이다. `scripts/source_input.py`가 이를 `checks/source/`에 검증·추출하므로 게임 파일 교체 후에도 재생성할 수 있다. 해당 Git 이력이 없는 얕은 clone은 이력을 먼저 가져와야 한다. 비교 카메라·조명은 이 폴더의 `comparison-conditions.json`과 `scripts/comparison_studio.py`, 원본 렌더는 `before-*.png`에 유지한다. 이전 비교 폴더를 실행 입력으로 읽지 않는다. Meshoptimizer dylib는 `/Volumes/KIOXIA_MAC/AI-3D/apps/Blender.app/Contents/Resources/lib/libmeshoptimizer.dylib`를 사용한다. `FROST_BAKE_PILOT=1`은 하부링·청동·셔터·렌즈 4부품 진단만 `checks/`에 저장하며 최종 GLB를 교체하지 않는다.
