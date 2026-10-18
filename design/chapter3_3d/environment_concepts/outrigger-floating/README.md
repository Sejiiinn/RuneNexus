# 챕터 3 외곽 설비 받침·부유 잔해 시안

2026-10-18. 3장 전장이 1·2장보다 환경 연출이 약하다는 피드백에 대응한 **미승인 2D 시안**이다. 실제 게임 화면이 아니며 구현 요구로 쓰지 않는다. 현행 결정은 [전장·지형·효과](../../../../docs/design_decisions/battlefield.md)를 따른다.

## 방향

- 외곽 설비 받침: 판 바깥 측벽에 볼트로 고정한 낮은 비플레이 선반 3~4곳. 타일과 같은 청흑색 주조 철·청동 플랜지·깊은 측면 케이싱을 쓰고 받침마다 서로 다른 설비 하나를 둔다. 제련 도가니(주황 용융 테두리), 루버 냉각 굴뚝, 배관 매니폴드와 청록 공명 코일, 주괴·슬래그 상자. 2장의 외곽 암반 받침과 기둥·수정 배치 방식을 3장 재질로 옮긴 것이다.
- 부유 잔해: 판 가장자리 주변의 철판 조각·부러진 I형 거더·가는 주황 균열의 식은 슬래그·볼트 8~12개. 넓은 맵(3-6 등)은 내부 빈 공간에도 일부를 띄운다.
- 길·건설 타일 상면, 포탈·코어, 기존 벽 부착 소품과 환기 패널은 가리지 않는다.

## 산출물

| 파일 | 입력 |
| --- | --- |
| [stage11-outrigger-floating-v1.png](stage11-outrigger-floating-v1.png) | [3-1 실제 Godot 캡처](inputs/ingame-stage11.png) 편집 |
| [stage26-outrigger-floating-v1.png](stage26-outrigger-floating-v1.png) | [3-6 실제 Godot 캡처](inputs/ingame-stage26.png) 편집 |

공통 참조: [2장 스테이지 7 실제 캡처](inputs/ingame-chapter2-stage7.png)(외곽 받침·부유 조각 배치), [승인 벽 부착 소품 렌더](../../environment_props/export/integrated-v2-glb-mounted.png). 도구: Codex ImageGen(`gpt-6.1-sol`). 프롬프트: [prompt-base.txt](prompt-base.txt). 3-6은 큰 나선 맵의 바깥 둘레에만 받침을 두고 내부 빈 공간에는 잔해 일부만 띄우라는 문장을 추가했다.

## 승인 후 다음 단계

설비 4종은 형태가 복잡하므로 Blender 제작 전에 필요한 멀티뷰로 구조를 확정한다. 이후 Blender 원본 → 경량 GLB → 맵별 외곽 배치 순으로 진행하고, 실제 게임 카메라에서 판정한다.
