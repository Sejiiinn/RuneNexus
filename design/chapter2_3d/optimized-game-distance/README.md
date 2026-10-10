# 챕터 2 타일 감량본

역할: 기존 석재 타일의 외형과 이웃별 가려진 면 제거를 보존한 현행 게임용 메시·편집 원본·재현 경로. 확인: 2026-10-10 KST. [승인 외형](../../../DESIGNS.md), [기본 제작 원본](../tiles/chapter2-tiles.blend), [가려진 면 제거 원본](../optimization/README.md), [확장 변형 원본](../../stage_expansion_runtime/chapter2-expansion-tile-variants.blend)은 유지한다.

게임의 기존 GLB 세 개를 감량본으로 교체했다. 해시·기법·보존 계약·검증 요약은 [manifest.json](manifest.json)을 기준으로 한다. 각 `.blend`에는 원본 PBR 이미지 9개를 패킹했으며 저장 후 실제 재열기를 확인했다.

| 종류 | 게임 파일 | 편집 원본 | 감량 전 삼각형 | 감량 후 삼각형 |
| --- | --- | --- | ---: | ---: |
| 기본 2종 | [chapter2_tiles.glb](../../../assets/images/stage1_3d/environment/chapter2_tiles.glb) | [기본 감량본](chapter2-base-tiles-optimized.blend) | 36,784 | 24,822 |
| 공유 28종 | [chapter2_tiles_optimized.glb](../../../assets/images/stage1_3d/environment/chapter2_tiles_optimized.glb) | [공유 감량본](chapter2-shared-tiles-optimized.blend) | 250,797 | 180,611 |
| 확장 3종 | [chapter2_tiles_expansion.glb](../../../assets/images/stage1_3d/environment/chapter2_tiles_expansion.glb) | [확장 감량본](chapter2-expansion-tiles-optimized.blend) | 29,289 | 21,463 |
| **고유 33종 합계** | | | **316,870** | **226,896** |

삼각형은 28.39%, GLB 합계는 44,550,860→38,557,432바이트로 13.45% 줄었다. 고유 라이브러리 수치이며 맵 인스턴스 합계·FPS·APK 감소율과 구분한다. 실제 앱 전장의 소품·포탈·코어까지 포함한 기하량은 스테이지 6에서 439,337→332,787, 스테이지 23에서 466,884→369,178삼각형이었다.

## 감량과 보존

챕터 3과 같은 `meshoptimizer`의 `meshopt_simplifyWithAttributes`, `options=0`을 사용했다. 챕터 2의 균열·단차를 비교해 상대 오차 상한 `.0015`를 선택했으며, 실제 목표 감량률보다 외형 보존을 우선했다. 정확히 같은 위치·UV의 분할 정점만 임시 연결하고 법선 가중치 `.03`, UV 가중치 `1`을 적용했다. 출력 정점은 원본 위치·UV·법선 속성 묶음의 부분집합이다. 원본에 없는 탄젠트·정점색 속성을 추가하지 않았다.

두 재질 surface를 별도로 처리하고 노출 경계·재질 경계·비다양체 경계·치수 극값을 잠갔다. 기본·공유·확장 루트와 변형 이름·변환·마스크 extras, 원본 3개 재질과 9개 이미지 payload, 모든 메시의 외곽 치수·기하 경계·연결 요소 수를 보존했다. 이웃 방향 마스크, 셀의 `index % 4` 회전, MultiMesh 공유, 가려진 하부 제거, 텔레포트 받침 구멍은 현행 게임 경로를 유지한다. 위치 이동·새 UV·재베이크·재색칠은 하지 않았다. 삼각형 연결 변화에 따른 일부 베벨 음영 차이는 있으며 픽셀 동일성을 주장하지 않는다.

## 검증과 한계

- Blender 5.2.2 LTS/Cycles의 같은 카메라·조명에서 [기본 전](review/before-base.png)·[후](review/after-base.png), [공유 전](review/before-masks.png)·[후](review/after-masks.png), [확장 전](review/before-expansion.png)·[후](review/after-expansion.png)를 비교했다. 최종 GLB 재임포트와 packed `.blend` 저장·재열기는 통과했다.
- 별도 검증자가 33개 메시의 구조·원본 속성·이미지 payload·원본 `.blend` 해시를 직접 대조했다. 새 구멍이나 연결 변화는 없었다. 양방향 표면 중심 표본의 최대 기하 편차는 약 `.002157`타일이었다. 이는 전수 오차 상한 측정은 아니다.
- Godot 4.7.2 Mobile/Metal, Apple M4, 440×900의 실제 앱 준비 화면에서 스테이지 6·23의 고정/드론 시점과 각각 2.5배 확대를 전후 비교했다. 부모·독립 검증 모두 외형 유지 PASS. [최종 실제 게임 화면](game-preview.png)은 최종 게임 GLB와 해시가 같은 검수 후보에 대응한다. 검수는 사용자 저장·네트워크를 분리했다.
- 실제 앱에서 챕터 2 전체 10개 스테이지(6~10·21~25)와 스테이지 6 재진입을 검사했다. 기존 paving 검사 항목을 현행 앱 입력 및 텔레포트 슬롯 추출에 맞춰 적용했으며 타일 누락·중복, 원래 좌표·회전, 이웃 마스크, 메시 공유, 두 surface/PBR, 반사·그림자, 카메라 깊이, 이전 배치 해제가 통과했다. 텔레포트로 잘린 받침은 공유 배치와 함께 대조했다.
- 원본 `.blend`에서 export-only로 비교 입력을 재생성하고 다시 감량한 출력 해시가 일치했다. 이미 감량한 입력을 재감량하는 요청은 도구가 거부한다.
- FPS·실제 GPU 시간·Android 실기기·APK·배포는 미측정/미실행이다. 일회성 검사·원시 수치·캡처·비교 GLB·자동 백업·로그는 로컬 `checks/`에 보관하고 Git 추적에서 제외한다.

## 재현

저장소 루트에서 실행한다. 기존 열린 Blender 문서를 보존하고 독립 background 실행을 사용한다. 첫 명령은 보존한 원본에서 export-only로 비교 GLB를 생성하며 기존 baseline이 있으면 덮어쓰지 않는다. 다른 suffix는 `prepare_baseline.py -- --suffix regenerated`로 지정한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --python design/chapter2_3d/optimized-game-distance/scripts/prepare_baseline.py
for asset in chapter2_tiles chapter2_tiles_optimized chapter2_tiles_expansion; do
  /Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 design/chapter2_3d/optimized-game-distance/scripts/optimize_tiles.py --asset "$asset.glb" --source "design/chapter2_3d/optimized-game-distance/checks/$asset-before.glb" --output "design/chapter2_3d/optimized-game-distance/checks/$asset-candidate.glb" --error .0015
done
/Applications/Blender.app/Contents/MacOS/Blender -b --python design/chapter2_3d/optimized-game-distance/scripts/verify_render.py
```

감량 도구는 `--library`로 meshoptimizer 라이브러리 경로를 지정할 수 있다. 원본 surface별 삼각형 수와 기하 해시를 검사한다. 게임 파일 복사는 시각 검수 후 별도로 수행하며 기존 기본·면 제거·확장 제작 원본을 덮어쓰지 않는다.
