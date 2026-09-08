# 코어 패시브 트리 현행 참조

문서 상태: 확인된 현재 구조와 근거를 연결하는 참조 문서
확인 기준: 2026-09-09 작업 트리의 코드와 테스트 소스 (이번 문서 정리에서 테스트 재실행 없음)

기존 경로를 유지하되 초기 구현 계획의 실행 지시를 대체한다.
당시 인터뷰와 전체 계획은 [역사 기록](archive/core_passive_tree_plan_2026-07-20.md)에 보존한다.

## 확인된 구조

- 노드 ID는 21개이며 공격·제어·효율 세 계통으로 구성된다.
- `corePassiveTreeRevision`은 4다.
- 과거 혼합 계통 6개 노드는 현행 노드 목록에 포함되지 않는다.
- 패시브 효과는 화면 표시만을 위한 상태가 아니다. 게임은 할당된 노드 랭크를 읽어
  포탑 레벨업·링크 비용 및 젬 효과 계산에 전달한다. 따라서 과거의 “효과를 계산에
  연결하지 않는다”는 조건을 현재 구현 기준으로 사용하지 않는다.

## 코드와 검증 근거

| 확인 대상 | 기준 파일 |
| --- | --- |
| 계통과 21개 노드 ID | [core_passive_tree.dart](../lib/domain/core/core_passive_tree.dart) |
| revision, 노드 정의·연결·비용·효과 계산 함수 | [game_core_passive_tree_data.dart](../lib/data/definitions/game_core_passive_tree_data.dart) |
| 게임에서 노드 랭크를 비용·젬 효과 계산에 전달 | [rune_nexus_game.dart](../lib/game/rune_nexus_game.dart) |
| revision 4, 21개 노드, 시작 노드·그래프 정합성 테스트 | [core_passive_tree_test.dart](../test/core_passive_tree_test.dart) |

이 확인 범위가 모든 노드 효과의 실행 검증이나 UI·저장·실기 QA 완료를 의미하지는 않는다.
변경할 때는 해당 효과의 호출 경로와 관련 테스트를 확인한다. 데미지 계산 변경은
[데미지 계산 규칙](damage_calculation_rules.md)을 먼저 따른다.

## 설계와 작업의 경계

장기 성장 방향은 [넥서스 코어 설계 방향](nexus_core_design.md)을 참고한다.
젬 공명, 확장 트리 등 미래 제안은 별도 합의 없이 구현할 작업 지시가 아니다.
현재 우선순위는 [다음 작업](next_work_priorities.md)을 따른다.
과거 계획의 27노드, 혼합 계통, 효과 미적용, 승인 요청 및 완료 조건은 현재 작업에 적용하지 않는다.
