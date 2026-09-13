# 스테이지 6 배치 소품

편집 원본은 `stage6-props.blend`, 장면은 `Stage 6 Placed Upper Props`다. 게임용 출력은 `assets/images/stage1_3d/environment/chapter2_stage6_props.glb`, 최상위 루트는 `stage6_props`다.

공용 `design/chapter2_3d/props/chapter2_props.blend`에서 상부 소품만 복사했다. 모든 `floating_ground*`는 제외했으며 공용 원본·GLB를 수정하지 않는다. 기존 수정의 정점색·native alpha·내부 광물층, 룬·금속·기단과 깊어진 균열 깊이판을 보존한다. 각 기단을 감싸는 지면은 스테이지 6 일체 지형이 담당한다. 독립 받침대·별도 포탈은 추가하지 않는다.

Blender XY는 8×10 맵 중심 기준이고 Z=0은 지면이다. GLB는 Y-up으로 내보낸다.

| 소품 루트 | 위치 XYZ | 배율 | Z 회전 |
| --- | --- | --- | --- |
| `pillar` | -4.48, 4.35, 0 | 1.10 | -14° |
| `crystal_lower_left` | -1.65, -3.50, 0 | 1.20 | 17° |
| `crystal_right` | 3.45, -2.35, 0 | 1.20 | -21° |
| `void_fissure` | 3.40, 2.48, -.19 | 1.00 | 12° |

편집·저장한 원본만 내보내기:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python design/chapter2_3d/stage6/props/build_stage6_props.py -- --export-only
```

처음 복사 생성은 옵션 없이 실행한다. 기존 배치를 공용 원본에서 다시 복사하려는 경우에만 명시적 `--refresh`를 쓴다. 내보낼 때만 불투명 메시를 재질별로 합치고 투명 수정은 개체별 정렬 단위를 유지한다. 실제 `Color` 속성을 `COLOR_0`로 강제해 흰 정점색 대체를 방지한다.

요청에 따라 별도 렌더·테스트·Android 빌드는 수행하지 않았다. 전체 일체 지형에 합친 대표 화면은 상위 작업에서 확인한다.
