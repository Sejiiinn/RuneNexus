# 죽음 V4 — 착지한 잔해 전체를 빠르게 내리기

[두 시점 영상](whole-exit-preview.mp4) · [3/4](whole-exit-three-quarter.mp4) · [25° 드론](whole-exit-drone-25.mp4) · [GLB](medium-guardian-whole-exit.glb) · [편집 원본](medium-guardian-whole-exit.blend) · [런타임 원본](medium-guardian-whole-exit-runtime.blend) · [대표 위상](phase-sheet.png)

사용자의 정정에 맞춰 [V3](../v3-rubble/README.md)의 **붕괴와 착지 모습은 그대로**, 조각별로 줄어들며 사라지는 동작은 제거했다. 착지한 잔해 형태를 잠깐 유지한 뒤, **전체 루트만 아래로 이동**해 지형 아래로 정리한다. 기존 V3 원본·영상·GLB는 보존했다.

| 시간 | 동작 |
| --- | --- |
| 0~.28초 | 기존 14개 돌무더기 붕괴·착지 그대로. 눈·핵·룬의 기존 소등도 유지. |
| .28~.43초 | 모든 조각의 상대 위치·회전·크기를 고정한 채 잠깐 유지. |
| .43~.60초 | `whole_exit`의 Z만 움직여 **0.17초 동안 잔해 전체를 한 덩어리로** 지형 아래로 이동. |

실제 사망 클립은 **0.60초**, 60fps f1→37이다. 천천히 조각별로 흡수하거나 축소하는 효과가 아니다. 초기 모델·분할·착지 회전·먼지·재질은 변경하지 않았다.

## 확인 결과

[직접 동작 검사](motion-check.json) · [최종 GLB 검사](glb-stats.json) · [실제 GLB 재임포트](glb-reimport-check.blend) · [재임포트 위상](glb-reimport/)

- **V3와 착지 전 본 행렬 차이 0.** 기존 붕괴를 유지했다.
- **.28초 이후 개별 본의 상대행렬 변화 0.** 조각별 이동·회전·크기 변화가 없다.
- 전체 루트 X/Y는 0으로 유지하고 Z만 1.52885 model-unit 내린다. 종료 시 가장 높은 부품도 바닥보다 .04 model-unit 아래에 있다.
- GLB는 **1 mesh / 1 material / 18 joints / 1 animation**을 유지한다. 55채널 중 새 1채널이 전체 루트 translation이며, 표준 glTF 좌표 변환 후에도 실제 재임포트 하강을 확인한다.
- 불필요한 착지 이후 조각 소멸 키를 제거해 scalar key 값은 **V3 11,340→V4 6,279**다. GLB 4,065,964bytes.
- **재질 재베이크 없음.** GLB에 포함된 PBR 이미지 3개의 SHA-256이 V3와 완전히 같다. 이전 원본 형태/재질 검증 근거를 재사용하고, 이번에는 고정된 잔해의 전체 하강과 시간·종료 상태만 검증한다.

실시간 물리·IK·충돌 계산은 필요하지 않으며 기존 베이크 키를 재생한다. 키 보간·스키닝·렌더 비용은 남는다. 게임 통합·앱 FPS 측정·배포·커밋은 이번 작업에 포함하지 않는다.

[독립 검증](independent-review.md) **PASS**. 별도 원본 대조와 실제 GLB 재임포트에서 착지 전 동작 보존, 착지 후 개별 본 변화 0, 전체 루트 Z 하강, 종료 잔류 없음, 단일 클립과 V3 이미지 바이트 동일을 확인했다. 미해결 사항은 없다.

## 미리보기

실제 길 타일 위 초기 표시 폭 .55tile, 전방 -Y·위 +Z의 기존 계약을 유지한다. 왼쪽 3/4·오른쪽 수직에서 25° 드론 시점이다. 앞뒤 .3초씩 정지한 72프레임 구간을 3회 반복해 **60fps·216프레임·3.60초** 영상으로 만들었다. 본동작은 미리보기 f19→55다. [영상 검사](video-check.json)에서 세 MP4의 전체 디코드·시간·프레임을 확인한다.

대표 위상은 .28 착지 / .43 하강 시작 / .52 하강 중간 / .60 종료다. 작은 먼지는 기존 시안 보조 효과로 재사용하며 GLB 본체에는 포함하지 않는다.

## 재생성

1. 기존 Blender 인스턴스에서 `build_whole_exit.py` 실행. V3 제작 씬과 이전에 베이크한 런타임 씬을 별도 V4 씬으로 복사한다. `.28초` 이후 본 키를 고정하고 루트 Z 키 세 개만 추가한다. `build_preview.py`로 타일 씬을 만든다.
2. 별도 background에서 `medium-guardian-whole-exit.blend --python finalize.py`로 정상 열기 상태를 저장한다.
3. `medium-guardian-whole-exit-runtime.blend --python export_glb.py`로 기존 atlas/메시를 그대로 내보낸다. `ACTIVE_ACTIONS`로 단일 클립을 만들고 V3 이미지 바이트와 대조한다.
4. `whole-exit-tile-preview.blend --python render_whole_exit.py -- phases`는 대표 위상, 같은 명령에서 `-- phases`를 빼면 전체 영상 프레임이다. `pack_whole_exit.sh`, `check_video.py`로 패킹·검사한다.
5. `medium-guardian-whole-exit.blend --python measure_whole_exit.py`, `whole-exit-tile-preview.blend --python reimport_check.py`로 변경 구간만 확인한다.
