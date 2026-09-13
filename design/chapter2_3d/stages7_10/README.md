# 스테이지 7~10 일체형 균열 지형

스테이지 6에서 채택한 [각진 암반·은은한 색광](../stage6/verification/darker-facets/android-stage6.png)을 각 맵에 맞춰 확장한다. 실제 길·건설칸·포탈·코어 좌표는 유지하고, 기둥 1곳·수정 2곳·균열 1곳을 본판과 이어진 비플레이 외곽 지형에 배치한다. 비석은 포탈 옆 고정 배치를 피하고 맵마다 다른 외곽에 둔다. 외곽에 작은 부유 돌 조각을 8개씩 분산하고, 절벽의 큰 파단면과 겹친 암반 조각으로 밀도를 만들며, 기본 조명을 조금 낮추고 청록·보라 점광원으로 암반에 색감을 준다.

| 스테이지 | 편집 원본 | 실제 Android 화면 |
| --- | --- | --- |
| 7 | [stage7.blend](stage7.blend) | [스테이지 7](verification/fragments/android-stage7.png) |
| 8 | [stage8.blend](stage8.blend) | [스테이지 8](verification/fragments/android-stage8.png) |
| 9 | [stage9.blend](stage9.blend) | [스테이지 9](verification/fragments/android-stage9.png) |
| 10 | [stage10.blend](stage10.blend) | [스테이지 10](verification/fragments/android-stage10.png) |

[생성·내보내기](build_stages.py)는 스테이지 6의 암반 조형 함수를 재사용한다. 각 `.blend`에는 `stageN_geology`와 `stageN_props` 루트가 함께 있으며, 게임 출력은 `assets/images/stage1_3d/environment/chapter2_stageN_geology.glb`와 `chapter2_stageN_props.glb`로 나눈다. 공용 원본과 스테이지 6 원본은 그대로 보존한다.

수동 편집한 원본을 재생성 없이 내보내는 예:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python design/chapter2_3d/stages7_10/build_stages.py -- --stage 7 --export-only
```

지형 루트의 맵 크기·타일 배열이 실제 프레임과 일치할 때만 해당 원본을 사용한다. 실제 외곽 지지점과 광원 위치도 원본에서 manifest로 전달한다. 스테이지를 바꾸면 이전 지형 라이브러리를 해제하고 다음 원본을 사용하며, 다른 챕터에서는 기본 조명을 복원한다.

사용자 요청에 따라 정상 Android 앱에서 7~10의 고정 시점 화면을 한 장씩 촬영해 확인했다. 길·건설칸과 외곽 소품 4곳, 연결된 암반과 청록·보라 광원이 보인다. 후속 수정에서는 비석이 포탈과 분리된 위치에 놓이고 작은 돌 조각이 전장 주변에 떠 있는 화면으로 갱신했다. 별도 테스트 반복·성능 측정은 추가하지 않았다. 캡처에는 메모리 게임을 사용했으며 종료 후 정상 앱으로 복원했다.
