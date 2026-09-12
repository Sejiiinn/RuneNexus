# 추가 환경 장식 독립 원본

역할: 2026-09-12 승인 시안에서 식별한 꽃·돌·이끼·덩굴·뿌리의 조형 검수. 기존 식물 4종에 이어 제작한 독립 원본이며, [맵 조립 단계](../README.md)에서 저장된 메시의 맵용 복사본을 게임 장식에 연결한다.

## 식별과 제작 범위

기준은 [승인 시안](../../environment_concepts/01-overgrown-stone-edges.png)이다. 외곽과 빈 건설칸에 가는 줄기 위의 작은 흰 꽃, 회색 면이 드러난 이끼 바위, 작은 돌, 낮은 이끼, 가장자리 아래로 늘어진 식생과 짧은 뿌리가 보인다. 정확한 꽃의 종이나 세부 표면 구조는 판별하지 않는다. 돌은 시안의 크기·높이 차이를 활용해 큰 바위·납작한 돌·잔돌의 세 제작 형태로 나눈다.

| 번호 | 독립 원본 | 시안에서 가져온 형태 |
| --- | --- | --- |
| 01 | 작은 흰 꽃 | 가는 줄기 끝의 작은 흰 꽃송이, 드문 간격과 높낮이 |
| 02 | 이끼 바위 | 회색 노출 면, 비대칭 능선과 부분적인 녹색 이끼 |
| 03 | 납작한 돌 | 낮은 높이, 넓고 깨진 돌면 |
| 04 | 작은 돌멩이 | 서로 다른 크기·방향의 잔돌 |
| 05 | 낮게 퍼진 이끼 | 불규칙한 가장자리와 낮게 엉긴 녹색 볼륨 |
| 06 | 늘어진 덩굴 | 벽 위에서 아래로 흐르는 작은 잎과 가지 |
| 07 | 드러난 뿌리 | 갈라지고 비틀리며 끝이 가늘어지는 짧은 뿌리 |

## 편집 원본과 정지 검수

- [꽃·이끼·덩굴·뿌리 원본](organic/organic-masters.blend): Scene `01 Wildflower Master`, `05 Moss Patch Master`, `06 Trailing Vine Master`, `07 Exposed Root Master`.
- [바위·돌 원본](rocks/rock-masters.blend): Scene `02 Mossy Boulder Master`, `03 Flat Stone Master`, `04 Pebbles Master`.
- [추가 에셋 7종 정지 이미지](companion-masters-review.png): 저장된 실제 Blender 메시 촬영. 마지막 칸은 [기존 식물 4종](../plant_library/README.md)의 축소 비교이며 신규 에셋 수에 포함하지 않는다.
- [촬영 및 원본 보존 확인](capture-verification.json): 원본 해시와 개별 삼각형 수.

각 Scene은 독립 root와 편집 가능한 메시를 보관한다. 1 Blender 단위는 게임 1타일이다. 덩굴은 벽 위 걸침점이 원점이며 아래로 내려가는 부분이 음수 Z를 사용한다. 나머지는 지면 기준 원점이다. 생성 스크립트는 최초 형태를 만드는 기록이며, 저장된 원본을 덮어쓰지 않는다. 이후 편집과 촬영은 저장된 `.blend`를 기준으로 한다.

최초 제작 기록은 [유기물 생성기](organic/seed_organic_masters.py)와 [돌 생성기](rocks/seed_rock_masters.py)에 있다. 식별 가능한 꽃송이·가지·잎·돌면과 비대칭 형태를 명시적으로 작성한 Blender 메시이며, 생성형 래스터 이미지를 3D 에셋으로 대신 사용하지 않는다. [유기물 명세](organic/organic_manifest.json)와 [돌 명세](rocks/rock-masters-manifest.json)는 최종 원본의 부품 수·크기·삼각형 수를 기록한다.

추가 원본 7종의 합계는 11,284삼각형이다. 꽃 2,072·이끼 바위 1,012·납작한 돌 1,158·돌멩이 156·이끼 3,746·덩굴 1,818·뿌리 1,322다. 모두 불투명 정점색 메시이며 텍스처와 애니메이션은 없다. 이 수치는 독립 원본 한 세트의 합계로, 최종 전장 배치량이나 게임 성능 수용 결과는 아니다.

최초 검수 이미지는 `first-pass-review.png`에 보존했다. 실제 렌더에서 확인한 두 형태를 보정했다. [이끼 보정](organic/refine_moss_master.py)은 최대 높이를 약 0.025타일로 낮추고 기존 작은 잎의 복사·재배치로 얇은 가장자리까지 덮는다. 납작한 돌은 저장된 메시의 두 파손면과 비대칭 상면으로 연속된 테두리를 끊었다. 각 보정에서 해당 원본 밖의 메시·정점색·변환 해시를 비교해 다른 에셋의 보존을 확인했다. 바위는 닫힌 메시와 이끼 표면 간격, 유기물은 원점·부모 연결·유효 정점과 퇴화 삼각형을 검사했다.

## 촬영과 후속 적용

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/stage1_3d/environment_dressing/companion_library/capture_companions.py
```

새 에셋 7종은 같은 배율과 조명으로 촬영한다. 작은 그림은 1타일 120px의 형태 확인용이다. 마지막 기존 식물 비교칸은 별도 축소 배율을 표시한다. 게임 카메라 방향 `(5, -13, 27)`을 사용하지만 Blender 조명·AgX로 렌더하므로 실제 Android 게임 캡처와 구분한다. 촬영은 원본을 저장하거나 재생성하지 않고 전후 해시를 대조한다.

크기·정점색·불투명 표면을 우선하고 확대해야 보이는 미세 묘사는 요구하지 않는다. 군락 구성, 최종 병합, 바람·점유 UV, 실제 배치량과 Android 화면·성능은 [맵 적용 검증](../verification/master-assets-20260912/README.md)에서 별도로 확인한다. 독립 원본과 제작 이미지는 `design/`에 보관하고, 맵용 복사본만 최종 `dressing.glb`로 내보낸다.
