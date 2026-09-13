# 스테이지 6 일체형 균열 지형

[승인 시안](../../chapter2_asset_concepts/stage6/01-integrated-stage6.png)에 맞춰 기존 타일 아래와 외곽에 이어진 절벽을 만들고, 기둥·수정·균열을 그 지형에 배치한다. 포탈은 사용자의 지시대로 기존 바닥형을 유지한다. 원래 8×10 맵의 길·건설칸·포탈·코어 좌표와 게임 상태는 바꾸지 않는다.

| 구성 | 편집 원본 | 게임 자산 |
| --- | --- | --- |
| 연속 지층·절벽·외곽 선반 | [stage6-geology.blend](terrain/stage6-geology.blend) | `assets/images/stage1_3d/environment/chapter2_stage6_geology.glb` |
| 기둥·수정·균열 배치 | [stage6-props.blend](props/stage6-props.blend) | `assets/images/stage1_3d/environment/chapter2_stage6_props.glb` |

제작 좌표는 맵 중심 기준 Blender XY, 표면 Z=0이다. GLB는 Godot Y-up으로 출력한다. 원본의 돌 조각은 개별 편집 가능하고 게임 출력에서만 메시를 합친다. 기존 소품의 상부 형상·재질·수정 투명도는 보존하며, 별도 `floating_ground*` 받침은 제외한다.

암반의 중간 팽창과 균일한 모서리 절삭을 줄이고 큰 비대칭 파단면·작은 베벨로 형태를 정리했다. 비플레이 외곽에 부착형 파편과 낮은 잔돌을 보강했다. 챕터 2 전용 지형에서는 기본 조명·환경광을 조금 낮추고 기둥·수정 주변의 청록 점광원과 균열 주변의 보라 점광원을 적용한다. 다른 맵 진입 시 기본 조명으로 복원한다.

저장된 원본의 수동 편집은 아래 명령으로 내보낸다. 재생성은 명시적인 `--regenerate`에서만 수행한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python design/chapter2_3d/stage6/terrain/build_geology.py -- --export-only
/Applications/Blender.app/Contents/MacOS/Blender --background --python design/chapter2_3d/stage6/props/build_stage6_props.py -- --export-only
```

Godot 준비 단계에서 geology 루트의 `columns`·`rows`·`tileTypes`를 manifest로 추출한다. 실제 프레임 맵과 완전히 일치할 때만 두 원본을 지연 로딩하며, 해당 맵의 공용 장식 자동 배치는 건너뛴다. 카메라는 전용 지형 범위를 함께 담는다. 같은 표현을 적용한 [스테이지 7~10](../stages7_10/README.md)도 맵별 전용 원본을 사용한다.

사용자가 검증 범위를 줄이도록 요청하여 별도 테스트 반복·다중 스테이지 검사·최적화는 수행하지 않는다. 정상 Android 앱의 대표 스테이지 6 화면으로 적용 결과를 확인한다.

[실제 Android 적용 화면](verification/darker-facets/android-stage6.png). 균열의 주변 지면 높이를 조정하고 실제 외곽 지지점으로 카메라를 맞췄다. 검수용 메모리 게임을 종료하고 정상 앱으로 복원했다.
