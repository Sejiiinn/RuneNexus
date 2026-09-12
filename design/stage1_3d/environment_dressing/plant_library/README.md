# 독립 식물 원본

역할: 2026-09-12 식물 자체의 형태 검수용 Blender 원본. 기존 군락 생성·밀도 조절에 앞서 독립 식물 조형을 확인한다. 독립 원본은 보존하고, [맵 조립 단계](../README.md)에서 저장된 메시의 맵용 복사본을 `environment-dressing.blend`·`dressing.glb`로 연결한다.

## 원본과 정지 이미지

- 편집 원본: [forest-plant-masters.blend](forest-plant-masters.blend)
- [식물 4종 정지 검수 이미지](plant-masters-review.png): 저장된 실제 메시를 Blender에서 촬영한 제작 렌더. 영상·생성형 이미지·실제 게임 캡처가 아니다.
- [촬영 및 원본 보존 확인](capture-verification.json): 원본 SHA256, 식물별 삼각형 수와 크기, 촬영 설정.

| Scene | 식물 | 조형 구분 |
| --- | --- | --- |
| `01 Grass Master` | 휘어진 풀 포기 | 가는 잎의 굽힘·높낮이·방향 변화 |
| `02 Fern Master` | 다층 고사리 | 휘어진 중심 줄기와 여러 높이의 잎층 |
| `03 Broadleaf Master` | 넓은 잎 식물 | 분리된 줄기·잎자루와 접히고 비틀린 잎 |
| `04 Groundcover Master` | 낮은 지피 | 옆으로 뻗는 줄기와 낮은 잎의 연결 |

네 원본은 각각 타일 단위·원점 0에서 편집한다. 마스터별 collection과 root empty 아래 줄기·잎 메시를 분리했다. Blender Python으로 식물별 형태와 잎 배치를 명시해 초기 원본을 제작했으며, 저장된 메시를 직접 수정할 수 있다. 기존 88개 군락을 분리해 이름만 바꾼 것이 아니다.

[원본 명세](master_manifest.json)의 총 삼각형은 8,748개(풀 1,112·고사리 4,326·넓은 잎 1,636·지피 1,674)다. 두 재질, 정점색, 불투명 메시를 사용하며 텍스처와 애니메이션은 없다. 독립 원본의 삼각형 수와 최종 맵의 배치·LOD·병합 수치는 구분하며, 최종 수치는 [환경 장식](../README.md)에 기록한다.

## 편집과 촬영

이후 조형 수정은 저장된 `.blend`의 해당 Scene에서 진행한다. 촬영 스크립트는 현재 메시와 evaluated modifier를 읽으며, 생성 스크립트를 호출하거나 원본을 저장하지 않는다. 원본 해시를 촬영 전후 대조한다.

[seed_plant_masters.py](seed_plant_masters.py)는 최초 원본 제작 기록이다. 저장된 마스터가 있으면 실행을 중단해 덮어쓰기를 막는다. 보정 후 원본을 삭제하고 seed를 다시 실행하면 보정이 사라지므로, 현행 `.blend`를 편집 기준으로 사용한다.

고사리는 성숙 잎축마다 잔잎 13쌍을 유지하고 끝으로 점차 좁아지는 윤곽을 사용한다. 시안보다 잎이 얇다는 피드백을 반영해 [broaden_fern_master.py](broaden_fern_master.py)로 저장된 잔잎의 폭을 직전 검수본 대비 1.5배로 넓혔다. 밑동·중륵·끝점·길이와 잎축을 보존하고, 메시 추가 없이 잎층의 면적과 겹침을 늘렸다. 다른 세 식물은 메시·변환·정점색 해시가 일치하며 총 삼각형 수는 동일하다. 직전 검수본은 `before-fern-width-review.png`, 폭 보정 전 원본은 `forest-plant-masters.before-fern-width.blend`에 보존했다. [초기 잎 수·윤곽 보정](refine_fern_master.py)과 `first-pass-review.png`는 제작 이력이다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background design/stage1_3d/environment_dressing/plant_library/forest-plant-masters.blend --python-exit-code 1 --python design/stage1_3d/environment_dressing/plant_library/capture_masters.py
```

큰 그림은 같은 배율의 조형 검수이며, 시선 방향 `(5, -13, 27)`은 게임의 고정 카메라 방향에 대응한다. 작은 그림은 1타일을 120px로 축소한 형태 확인용이다. Blender 조명·AgX를 사용하므로 게임의 재질·조명 결과를 보증하지 않는다.

형태 검수의 핵심은 네 식물의 구분되는 윤곽, 줄기와 잎의 자연스러운 연결, 잎층의 입체감, 작은 표시에서도 읽히는 실루엣이다. 맵별 밀도·위치·건설 점유·바람 UV와 실제 Android 화면·성능은 [맵 적용 검증](../verification/master-assets-20260912/README.md)에서 별도로 확인한다. 독립 마스터의 보정은 저장된 원본에 진행하고 맵 조립·출력 순서로 반영한다.
