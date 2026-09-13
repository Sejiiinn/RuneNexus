# 챕터 2 공유 타일 최적화

스테이지 6~10은 승인된 타일의 상면·균열·음각·색·재질을 유지하면서, 가려지는 하부 기하를 제거한 공유 타일을 사용한다. [챕터 2 디자인 방향](../README.md)과 [기존 타일 원본](../tiles/chapter2-tiles.blend)은 그대로이며, 기존 `chapter2_tiles.glb`도 비교 기준으로 보존한다.

## 현행 원본과 게임 출력

| 역할 | 파일 |
| --- | --- |
| 편집 원본 | [chapter2-tiles-optimized.blend](chapter2-tiles-optimized.blend) |
| 생성·내보내기 | [build_tile_variants.py](build_tile_variants.py) |
| 공유 면 제거 함수 | [hidden_geometry.py](hidden_geometry.py) |
| 게임 출력 | [chapter2_tiles_optimized.glb](../../../assets/images/stage1_3d/environment/chapter2_tiles_optimized.glb) |
| 에셋 수치 | [tile_variants_report.json](tile_variants_report.json) |
| 런타임 전후 비교 | [Godot 최적화 측정](../../../docs/analysis/godot_optimization_20260913.md) |

이웃 방향 조합 16개와 길·건설 종류 중 현재 6~10 맵에서 쓰는 28종을 내보낸다. 각 변형은 메시 하나와 재질 surface 두 개이며, 전체 라이브러리가 재질 3개와 이미지 9개를 공유한다. 출력은 24,289,176바이트(약 23.16MiB), 고유 삼각형은 250,797개다.

[Godot 전장](../../../godot/main.gd)은 같은 종류·이웃 마스크의 셀을 `MultiMesh`로 묶는다. 각 셀의 원래 위치와 `index % 4` 회전을 적용하며, 경로·건설 판정과 스테이지 6~10의 절벽·소품 배치는 바꾸지 않는다.

## 제거 범위와 보존 범위

이웃 타일이 있는 방향의 석조 기단 하단 두 단을 제거한다. 상단 한 단과 빈칸을 향한 외곽 측면은 유지한다. 추가 면 제거는 모든 꼭짓점이 불투명 내부 기단 안에 들어가거나 기존 지질 표면 아래에 묻힌 면에만 적용한다. 남는 면의 좌표·UV·재질은 변경하지 않으며 전체 메시 decimate는 사용하지 않는다. 이 출력은 기저 지질이 있는 현행 6~10 환경을 전제로 한다.

| 스테이지 | 기존 타일 삼각형 | 적용 후 타일 삼각형 | 감소율 | 변형 수 / 예상 기본 draw |
| --- | ---: | ---: | ---: | ---: |
| 6 | 892,716 | 371,183 | 58.42% | 15 / 30 |
| 7 | 830,610 | 332,084 | 60.02% | 17 / 34 |
| 8 | 757,042 | 309,942 | 59.06% | 15 / 30 |
| 9 | 778,404 | 335,922 | 56.84% | 18 / 36 |
| 10 | 981,706 | 431,324 | 56.06% | 22 / 44 |

삼각형 수는 타일 인스턴스를 모두 합한 기하 수치다. 예상 draw는 타일 재질 패스 기준이며 그림자와 다른 전장 요소는 포함하지 않는다. 약 56~60% 감소는 **타일 기하 작업량**에 해당하며 APK 용량이나 메모리 감소율을 뜻하지 않는다. 원본 두 종류보다 공유 변형의 고유 메시가 늘어나므로 용량·메모리·프레임 시간은 [실제 전후 측정](../../../docs/analysis/godot_optimization_20260913.md)으로 판단한다.

## 이웃 마스크와 회전 계약

루트는 `chapter2_tiles_optimized`, 변형 루트는 `path_tile_mask_N` 또는 `build_tile_mask_N`이다. `N`은 아래 비트의 합이며 **회전하기 전 타일 로컬 방향**을 나타낸다. 루트의 `maskBitOrder`·`directionCoordinates`에도 같은 계약을 저장한다.

| 방향 | 비트 | Blender 로컬 | Godot 로컬 |
| --- | ---: | --- | --- |
| W | 1 | -X | -X |
| E | 2 | +X | +X |
| N | 4 | +Y | -Z |
| S | 8 | -Y | +Z |

월드 이웃 방향에 셀 회전의 역회전을 적용해 로컬 마스크를 구한다. 생성기는 같은 결과를 얻도록 각 로컬 방향을 `index % 4`만큼 회전한 후 월드 이웃을 조회한다. 모델 배치에는 기존 Godot +Y축 90도 회전을 그대로 적용한다. 변형 아래 메시의 변환은 identity이며 타일 폭·깊이는 1, 표면은 Godot Y=0이다.

## 저장한 편집 내보내기

저장소 루트에서 실행한다. `--export-only`는 저장한 최적화 원본을 내보내며 기존 타일 원본을 재생성하지 않는다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/chapter2_3d/optimization/build_tile_variants.py -- --export-only
```

기존 타일 원본과 현재 맵 정의에서 최적화 원본을 다시 만들 때만 `--regenerate`를 사용한다. 이 옵션은 최적화 원본의 수동 편집을 덮어쓴다. 맵의 이웃 조합이 바뀌면 필요한 변형도 달라질 수 있으므로 생성기와 런타임 마스크 계약을 함께 확인한다.

## 미채택 맵 병합 실험

로컬 실험 폴더 `rejected-map-batches/`의 스테이지별 paving GLB 다섯 개는 미채택 산출물이며 게임 에셋 경로·패키징·커밋 대상에서 제외한다. 맵 전체를 재질별로 합치면 타일 기본 draw는 3개까지 줄지만, 각 맵에 정점이 중복되어 출력 합계가 약 169MB로 증가했다. 현행 공유 변형은 이 중복을 줄인 방식이다.

`stage6-paving.blend`~`stage10-paving.blend`, [build_paving.py](build_paving.py), [paving_report.json](paving_report.json)중 `.blend`는 로컬 실험 원본으로만 보관하고, 생성기와 수치 기록은 저장소에 보존한다. 해당 생성기의 출력 경로도 `rejected-map-batches`이며, 현행 라이브러리와 동일한 `hidden_geometry.py`를 사용한다.
