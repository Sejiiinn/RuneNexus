# 코어 패시브 트리 구현 계획

> 2026-08-06 변경: 잘못된 투자를 막기 위해 혼합 계통 6개 노드를 우선 제거했다. 현행 트리는 공격·제어·효율 계통의 21개 노드와 `corePassiveTreeRevision = 4`를 사용한다. 아래의 27개 노드 및 혼합 계통 설계는 신규 계통 노드가 확정되기 전까지 과거 구현안으로만 참고한다.

## 1. 문서 상태와 우선순위

이 문서는 2026-07-20까지 진행한 사용자 인터뷰의 확정 사항을 실제 구현으로 옮기기 위한 인계 문서다.

- 이 문서 작성 단계에서는 코드와 게임 데이터에 어떠한 기능 변경도 하지 않는다.
- 후속 Agent는 이 문서를 구현 기준으로 사용한다.
- `docs/nexus_core_design.md`의 코어 지원 역할 원칙은 유지한다.
- 기존 `docs/core_passive_slot_ui_design.md`의 패시브 슬롯·카드 장착 설계는 이 문서로 대체한다.
- 전투 스킬 슬롯과 `수호 광선`·`균열 낙인`의 현재 장착 구조는 유지한다.
- 확정하지 않은 외곽 완성 링이나 심화 트리는 구현하지 않는다.

## 2. 목표

현재 코어 탭의 패시브 슬롯 2칸과 패시브 카드 장착 방식을 제거하고, 모바일에서 이동·확대할 수 있는 방사형 패시브 트리로 대체한다.

이번 단계에서 완성해야 하는 것은 다음과 같다.

1. 27개 노드로 구성된 `공격 / 제어 / 효율` 방사형 트리
2. 노드 랭크, 연결 개방, 포인트 소비와 무료 회수
3. 트리 상태 저장·불러오기
4. 스테이지 최초 클리어 코어 포인트 보상과 기존 클리어 기록 소급 지급
5. 결과 화면의 코어 포인트 보상 표시
6. `전투 스킬 / 패시브 트리` 코어 화면 전환
7. 드래그·핀치 확대/축소와 최소 배율 자동 중앙 정렬
8. 기존 슬롯 패시브 UI·저장·전투 효과 제거
9. 회귀 테스트와 320px 폭을 포함한 인앱 시각 검증

## 3. 명시적 제외 범위

다음은 이번 구현에 포함하지 않는다.

- 패시브 노드 효과를 전투·경제 계산에 실제 적용
- 외곽 완성 링과 최종 키스톤 장착 시스템
- 시즌 트리, 확장 포트, 별도 심화 트리
- 이벤트·업적·출석·토너먼트 포인트 지급
- 코어 포인트 유료 판매나 별도 재화 소비
- 패시브 초기화 비용
- 신규 패시브 아이콘 이미지 제작
- 기존 패시브 슬롯 해금에 사용한 다이아 환급
- 코어 트리 효과로 인한 데미지 계산식 변경
- 스테이지 선택 화면에 전체 포인트 보상표 추가

화면에는 노드가 실제로 작동하는 것처럼 이름과 효과 수치를 표시한다. `준비 중`, `미적용` 같은 사용자 안내 문구는 넣지 않는다. 단, 런타임 계산 코드는 저장된 노드 랭크를 읽지 않아야 한다.

## 4. 확정 UX

### 4.1 코어 탭 진입 구조

코어 탭 상단에 다음 두 전환 버튼을 둔다.

```text
전투 스킬 | 패시브 트리
```

- `전투 스킬`은 현재 수호 광선·균열 낙인 장착 기능을 유지한다.
- 기존 코어 소켓 보드에서는 패시브 슬롯 2개를 제거한다.
- `패시브 트리`는 포인트 요약, 트리 캔버스, 선택 노드 상세 패널 순서로 구성한다.
- 코어 탭 최초 진입 기본값은 `전투 스킬`로 유지한다.
- 같은 코어 탭 안에서 전환할 때 전투 스킬 선택 상태와 패시브 노드 선택 상태를 서로 덮어쓰지 않는다.

### 4.2 패시브 트리 화면 구조

```text
┌ 코어 포인트 20 · 사용 0 · 남음 20 · 전체 초기화 ┐
│                                                     │
│                 드래그/확대 가능한 트리             │
│                                                     │
├ 선택 노드 상세 ─────────────────────────────────────┤
│ 아이콘  이름  현재/최대 랭크                        │
│ 현재 효과 / 다음 효과 / 필요·반환 포인트            │
│          [−] [목표 랭크] [+]              [할당]     │
└─────────────────────────────────────────────────────┘
```

- 상세 패널은 트리 캔버스 위에 겹치지 않는다.
- 선택 노드가 없을 때는 `노드를 선택해 효과와 랭크를 확인하세요`와 조작 안내를 표시한다.
- `+ / −`는 저장값을 즉시 바꾸지 않고 선택 노드의 목표 랭크만 변경한다.
- `할당`을 누르면 목표 랭크를 한 번에 반영하고 저장한다.
- 선택 노드를 바꾸거나 코어 화면을 나가면 확정하지 않은 목표 랭크는 폐기한다.
- 회수로 인해 연결이 끊어지면 `−`를 비활성화한다.
- 전체 초기화는 무료이며 확인 다이얼로그를 거친다.
- 버튼 문구는 `투자`가 아니라 반드시 `할당`을 사용한다.

### 4.3 카메라와 제스처

- 한 손가락 드래그로 이동한다.
- 두 손가락 핀치로 확대·축소한다.
- 별도의 중앙 복귀 버튼은 두지 않는다.
- 최소 배율은 현재 캔버스 크기에서 전체 트리가 여백과 함께 화면에 가득 차는 값으로 동적 계산한다.
- 최소 배율에 도달하면 정중앙으로 자동 정렬한다.
- 최대 배율은 최소 배율의 약 2.2배로 둔다.
- 확대 상태에서도 트리가 화면 밖으로 완전히 사라지지 않게 이동 범위를 제한한다.
- 코어 탭을 벗어났다가 돌아오면 최소 배율의 전체 보기로 초기화한다.
- 320px 폭에서도 노드 터치 영역과 상세 패널 핵심 문구가 잘리지 않아야 한다.

## 5. 포인트 보상

### 5.1 스테이지 데이터

`StageDefinition`에 최초 클리어 코어 포인트 보상을 명시적으로 추가한다.

권장 필드:

```dart
final int firstClearCorePointReward;
```

생산 스테이지의 확정값은 다음과 같다.

| 스테이지 | 포인트 | 스테이지 | 포인트 | 스테이지 | 포인트 |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1 | 6 | 1 | 11 | 1 |
| 2 | 1 | 7 | 1 | 12 | 1 |
| 3 | 1 | 8 | 1 | 13 | 1 |
| 4 | 1 | 9 | 1 | 14 | 1 |
| 5 | 2 | 10 | 3 | 15 | 3 |

현재 15개 스테이지의 총 포인트는 20이다.

- 보상은 해당 스테이지 최초 성공 시에만 지급한다.
- 반복 클리어로 포인트를 재획득할 수 없다.
- 패배 결과에는 코어 포인트를 지급하지 않는다.
- 커스텀·테스트용 `StageDefinition`도 값을 명시하게 해 누락을 컴파일 단계에서 발견한다.
- `RuneNexusGame._buildInitialStages()`가 생성하는 커스텀 스테이지에는 테스트 의도가 없는 한 `0`을 전달한다.

### 5.2 결과 화면

`ResultOverlay`의 보상 요약에 최초 클리어로 획득한 포인트가 있을 때만 다음 행을 추가한다.

```text
+150 룬
+2 코어 포인트
```

- 전체 스테이지 보상표는 결과 화면이나 스테이지 선택 화면에 추가하지 않는다.
- 반복 클리어처럼 `lastRunCorePointReward == 0`이면 코어 포인트 행 자체를 숨긴다.
- 룬 보상·해금 항목·전투 기록의 현재 구조는 유지한다.

### 5.3 기존 클리어 기록 소급 지급

구버전 저장에는 코어 포인트 보상 수령 기록이 없으므로, 복원 직후 다음 절차를 한 번 수행한다.

1. `clearedStageNumbers`를 읽는다.
2. 별도 `claimedCorePointStageRewards`에 없는 스테이지만 찾는다.
3. 현재 로드된 `StageDefinition.firstClearCorePointReward`를 합산한다.
4. `totalCorePoints`에 더한다.
5. 처리한 스테이지 번호를 `claimedCorePointStageRewards`에 넣는다.
6. 즉시 저장을 예약해 다음 실행에서 중복 지급되지 않게 한다.

소급 지급은 저장 복원 경로에서만 수행하며 결과 화면의 `lastRunCorePointReward`에는 넣지 않는다. 따라서 앱 업데이트 후 로비에 들어왔을 때 과거 스테이지 보상이 가짜 전투 결과로 노출되지 않는다.

## 6. 트리 규칙

### 6.1 랭크와 비용

| 노드 등급 | 최대 랭크 | 랭크별 비용 | 주변 개방 랭크 |
| --- | ---: | --- | ---: |
| 일반 | 5 | `1 / 1 / 2 / 2 / 3` | 3 |
| 주요 | 3 | `2 / 3 / 5` | 3 |
| 중간 키스톤 | 1 | `5` | 해당 없음 |

- 비용 배열은 해당 랭크에 새로 도달할 때 필요한 포인트다.
- 예: 일반 노드 0→3은 총 4포인트, 3→5는 추가 5포인트다.
- 현재 캠페인 20포인트로 순수 계통의 중간 키스톤을 화면상 개방할 수 있지만, 키스톤 1랭크 할당에는 추가 포인트가 필요하게 구성한다. 이는 추후 이벤트·업적·출석 보상의 첫 장기 목표가 된다. 대신 플레이어는 키스톤 직전까지 집중하거나 두 계통의 중간 노드들을 조합할 수 있다.

### 6.2 주변 노드 개방

모든 일반·주요 노드에 같은 규칙을 사용한다.

- 중앙과 직접 연결된 시작 노드 6개는 처음부터 선택할 수 있다.
- 접근 가능한 노드가 3랭크에 도달하면 그 노드와 직접 연결된 주변 노드가 개방된다.
- 혼합 노드는 연결된 양쪽 계통 중 어느 한쪽 노드만 3랭크면 개방된다.
- 계통 누적 포인트 조건은 사용하지 않는다.
- 연결선마다 다른 개방 랭크를 사용하지 않는다.
- 잠긴 노드에는 정확한 수치 대신 `연결된 노드를 강화하면 개방됩니다`를 표시한다.
- 3랭크 이전에는 연결선을 단계적으로 밝히고, 3랭크에 도달하면 다음 노드까지 연결선을 완전히 점등한다.

### 6.3 연결 유효성 검사

단순히 `인접 노드 중 하나가 3랭크`인지 검사하면 순환 연결끼리 서로를 지지하는 고립 섬이 생길 수 있다. 할당과 회수 검증은 중앙에서 시작하는 도달 가능성 검사로 구현한다.

권장 알고리즘:

1. 시작 노드 6개를 `accessible` 집합에 넣는다.
2. `accessible` 노드 중 저장 랭크가 3 이상인 노드의 모든 인접 노드를 집합에 추가한다.
3. 새 노드가 없을 때까지 반복한다.
4. 랭크가 1 이상인 모든 노드가 `accessible`에 포함되어야 유효한 할당이다.
5. `−` 미리보기와 `할당` 확정 모두 같은 검증 함수를 사용한다.

이 검증으로 혼합 트리는 어느 한쪽 경로에서 들어갈 수 있지만, 진입 경로를 회수해 고립시킬 수는 없다.

### 6.4 포인트 계산

저장 상태의 기준값은 `총 획득 포인트`와 `노드 랭크`다.

```text
사용 포인트 = 각 노드의 0→현재 랭크 누적 비용 합계
남은 포인트 = 총 획득 포인트 - 사용 포인트
```

- 별도 소비 지갑을 저장하지 않는다.
- 무료 초기화는 노드 랭크만 비우므로 포인트 손실이 없다.
- 목표 랭크가 현재보다 높으면 비용 차이가 남은 포인트 이하여야 한다.
- 목표 랭크가 낮으면 반환량은 누적 비용 차이로 자동 계산한다.
- 비용표나 트리 구조가 이후 변경될 경우를 위해 `corePassiveTreeRevision`을 저장한다.
- 저장된 revision이 현재와 다르거나 할당이 유효하지 않으면 랭크만 초기화하고 총 획득 포인트는 보존한다.

## 7. 27개 노드 시안

노드 이름과 효과는 UI에서 실제 효과처럼 표시한다. 이번 구현에서는 이 값들을 전투 계산에 연결하지 않는다.

### 7.1 공격 계통

| ID | 이름 | 등급 | 효과 표시용 값 | 아이콘 |
| --- | --- | --- | --- | --- |
| `attackHaste` | 가속 회로 | 일반 | 코어 스킬 재사용 대기시간 `2/4/6/8/10%` 감소 | 기존 `skill_acceleration.png` |
| `attackOutput` | 출력 증폭 | 일반 | 코어 스킬 피해·증폭 효과 `3/6/9/12/15%` 증가 | `Icons.bolt` |
| `attackPrecompute` | 선행 계산 | 일반 | 라운드 첫 코어 스킬을 `10/20/30/40/50%` 충전 상태로 시작 | `Icons.timelapse` |
| `attackFocus` | 집중 해석 | 일반 | 같은 대상에 연속 적용되는 코어 스킬 효과 `3/6/9/12/15%` 증가 | `Icons.center_focus_strong` |
| `attackGuardianBeam` | 수호 광선 해석 | 주요 | 수호 광선 지속시간 `0.1/0.2/0.3초` 증가 | 기존 `guardian_beam.png` |
| `attackRiftMark` | 균열 낙인 해석 | 주요 | 균열 낙인 지속시간 `0.4/0.8/1.2초` 증가 | 기존 `rift_mark.png` |
| `attackOverclock` | 과부하 연산 | 중간 키스톤 | 재사용 대기시간 25% 감소, 대신 피해·증폭·지속시간 효과 15% 감소 | `Icons.electric_bolt` |

### 7.2 제어 계통

| ID | 이름 | 등급 | 효과 표시용 값 | 아이콘 |
| --- | --- | --- | --- | --- |
| `controlThreatSense` | 위협 감지 | 일반 | 경로 75%를 넘은 적이 있으면 코어 스킬 충전 속도 `4/8/12/16/20%` 증가 | `Icons.radar` |
| `controlSelfRepair` | 자가 수복 | 일반 | `9/8/7/6/5`라운드마다 넥서스 체력 1 회복 | 기존 `self_repair.png` |
| `controlRetarget` | 표적 재구성 | 일반 | 대상 사라짐 시 남은 코어 스킬 효과를 `40/55/70/85/100%` 효율로 이전 | `Icons.sync` |
| `controlRearLock` | 후방 봉쇄 | 일반 | 경로 80%를 넘은 적에 대한 코어 스킬 효과 `4/8/12/16/20%` 증가 | `Icons.shield_outlined` |
| `controlEmergencyCharge` | 비상 충전 | 주요 | 코어 피해 시 재사용 대기시간 `15/25/35%` 환급, 라운드당 1회 | `Icons.battery_charging_full` |
| `controlBufferShell` | 완충 외피 | 주요 | `10/8/6`라운드마다 코어가 받는 첫 피해 1 무효화 | `Icons.health_and_safety_outlined` |
| `controlFinalLine` | 최종 방위선 | 중간 키스톤 | 런당 1회 치명 피해를 받고 체력 1로 생존, 경로 후반부 대상 코어 스킬 효과 15% 증가 | `Icons.security` |

`제어`는 순수 체력·회복 계통이 아니다. 정상적인 플레이에서도 위협 감지, 표적 재구성, 후방 봉쇄가 작동한다는 컨셉을 유지하고 방어 효과는 일부 노드로 제한한다.

### 7.3 효율 계통

| ID | 이름 | 등급 | 효과 표시용 값 | 아이콘 |
| --- | --- | --- | --- | --- |
| `efficiencySaving` | 절약 설계 | 일반 | 포탑 건설 비용 `3/6/9/12/15%` 감소 | 기존 `cost_saving_design.png` |
| `efficiencyDiversity` | 다양성 감응 | 일반 | 첫 종류 이후 서로 다른 포탑 종류당 코어 충전 속도 `0.5/0.75/1/1.25/1.5%` 증가, 최대 4종 | `Icons.hub_outlined` |
| `efficiencyFirstDeploy` | 첫 배치 공학 | 일반 | 각 포탑 종류의 첫 건설 비용 `4/8/12/16/20%` 감소 | `Icons.precision_manufacturing_outlined` |
| `efficiencyFirstLink` | 첫 연결 공학 | 일반 | 런당 첫 링크 확장 비용 `4/8/12/16/20%` 감소 | `Icons.device_hub` |
| `efficiencyGemSpectrum` | 젬 스펙트럼 | 주요 | 서로 다른 젬 3종마다 코어 스킬 효과 `2/3/4%` 증가, 최대 3중첩 | `Icons.auto_awesome` |
| `efficiencySupplyRecovery` | 보급 회수 | 주요 | 보스 처치 후 다음 건설·강화·링크 비용 `8/12/16%` 감소 | `Icons.savings_outlined` |
| `efficiencyCombinedFront` | 통합 전선 | 중간 키스톤 | 포탑 4종 이상이면 코어 스킬 효과 20% 증가, 같은 종류 3기째부터 건설 비용 10% 증가 | `Icons.account_tree_outlined` |

### 7.4 혼합 계통

| 조합 | ID | 이름 | 등급 | 효과 표시용 값 | 아이콘 |
| --- | --- | --- | --- | --- | --- |
| 공격×제어 | `hybridEmergencyCompute` | 비상 연산 | 일반 | 적이 경로 80%를 처음 넘을 때 재사용 대기시간 `5/10/15/20/25%` 환급 | `Icons.warning_amber_rounded` |
| 공격×제어 | `hybridCounterFire` | 대응 사격 | 주요 | 다음 코어 스킬이 코어에 가까운 적을 우선 공격하고 효과 `10/20/30%` 증가 | `Icons.gps_fixed` |
| 공격×효율 | `hybridResonanceLoop` | 공명 루프 | 일반 | 서로 다른 젬 3종마다 코어 스킬 지속시간 `0.1/0.2/0.3/0.4/0.5초` 증가, 최대 3중첩 | `Icons.all_inclusive` |
| 공격×효율 | `hybridMixedFire` | 혼성 화력망 | 주요 | 물리·원소 포탑을 모두 운용하면 코어 스킬 효과 `6/9/12%` 증가 | `Icons.call_split` |
| 제어×효율 | `hybridSupplyBarrier` | 보급 방벽 | 일반 | 새로운 포탑 종류의 첫 건설 시 임시 보호막 1 획득, 최대 `1/2/3/4/5` | `Icons.shield_moon_outlined` |
| 제어×효율 | `hybridRecoveryBudget` | 복구 예산 | 주요 | 코어 피해 후 다음 건설·강화 비용 `8/12/16%` 감소 | `Icons.build_circle_outlined` |

## 8. 그래프와 배치

### 8.1 월드 좌표

- 트리 월드는 정사각형 `720 × 720` 논리 픽셀을 기준으로 한다.
- 중심점은 `(360, 360)`이다.
- 실제 화면에서는 `InteractiveViewer`가 월드 전체를 축소·확대한다.
- 공격은 우상단·우측의 금색, 제어는 좌상단·좌측의 청록색, 효율은 하단의 녹색을 사용한다.
- 혼합 노드는 인접 계통 경계에 자홍색으로 배치한다.

### 8.2 극좌표 배치

각도는 화면 오른쪽을 0도, 아래쪽을 90도로 본다.

| ID | 반지름 | 각도 |
| --- | ---: | ---: |
| `attackHaste` | 110 | 300° |
| `attackOutput` | 110 | 0° |
| `efficiencySaving` | 110 | 60° |
| `efficiencyDiversity` | 110 | 120° |
| `controlSelfRepair` | 110 | 180° |
| `controlThreatSense` | 110 | 240° |
| `attackPrecompute` | 180 | 310° |
| `attackFocus` | 180 | 350° |
| `attackGuardianBeam` | 245 | 300° |
| `attackRiftMark` | 245 | 0° |
| `attackOverclock` | 300 | 330° |
| `efficiencyFirstDeploy` | 180 | 70° |
| `efficiencyFirstLink` | 180 | 110° |
| `efficiencyGemSpectrum` | 245 | 60° |
| `efficiencySupplyRecovery` | 245 | 120° |
| `efficiencyCombinedFront` | 300 | 90° |
| `controlRetarget` | 180 | 190° |
| `controlRearLock` | 180 | 230° |
| `controlEmergencyCharge` | 245 | 180° |
| `controlBufferShell` | 245 | 240° |
| `controlFinalLine` | 300 | 210° |
| `hybridEmergencyCompute` | 170 | 270° |
| `hybridCounterFire` | 245 | 270° |
| `hybridResonanceLoop` | 170 | 30° |
| `hybridMixedFire` | 245 | 30° |
| `hybridSupplyBarrier` | 170 | 150° |
| `hybridRecoveryBudget` | 245 | 150° |

좌표는 최초 구현의 기준값이다. 320px 폭에서 노드가 겹치면 반지름과 각도를 소폭 조정할 수 있지만, 계통 순서와 연결 구조는 바꾸지 않는다.

### 8.3 연결 목록

중앙 코어는 다음 시작 노드 6개와 연결한다.

```text
attackHaste
attackOutput
efficiencySaving
efficiencyDiversity
controlSelfRepair
controlThreatSense
```

나머지 연결은 무방향 연결로 정의한다.

```text
attackHaste              - attackPrecompute
attackPrecompute         - attackGuardianBeam
attackGuardianBeam       - attackOverclock

attackOutput             - attackFocus
attackFocus              - attackRiftMark
attackRiftMark           - attackOverclock

efficiencySaving         - efficiencyFirstDeploy
efficiencyFirstDeploy    - efficiencyGemSpectrum
efficiencyGemSpectrum    - efficiencyCombinedFront

efficiencyDiversity      - efficiencyFirstLink
efficiencyFirstLink      - efficiencySupplyRecovery
efficiencySupplyRecovery - efficiencyCombinedFront

controlSelfRepair        - controlRetarget
controlRetarget          - controlEmergencyCharge
controlEmergencyCharge   - controlFinalLine

controlThreatSense       - controlRearLock
controlRearLock          - controlBufferShell
controlBufferShell       - controlFinalLine

attackHaste              - hybridEmergencyCompute
controlThreatSense       - hybridEmergencyCompute
hybridEmergencyCompute   - hybridCounterFire

attackOutput             - hybridResonanceLoop
efficiencySaving         - hybridResonanceLoop
hybridResonanceLoop      - hybridMixedFire

efficiencyDiversity      - hybridSupplyBarrier
controlSelfRepair        - hybridSupplyBarrier
hybridSupplyBarrier      - hybridRecoveryBudget
```

한쪽 시작 노드만 3랭크에 도달해도 해당 혼합 노드가 개방되어야 한다.

## 9. 도메인과 데이터 모델

### 9.1 신규 타입

권장 파일: `lib/domain/core/core_passive_tree.dart`

```dart
enum CorePassiveBranch { attack, control, efficiency, hybrid }

enum CorePassiveNodeGrade { normal, notable, keystone }

enum CorePassiveNodeId {
  // 27개 ID
}

class CorePassiveNodeDefinition {
  final CorePassiveNodeId id;
  final CorePassiveBranch branch;
  final CorePassiveNodeGrade grade;
  final int maxRank;
  final List<int> rankCosts;
  final List<CorePassiveNodeId> neighbors;
}
```

원칙:

- 도메인 정의에는 Flutter의 `Color`, `Offset`, `IconData`를 넣지 않는다.
- 효과 수치는 UI 표시용 정의로만 두고 게임 계산 API를 제공하지 않는다.
- 그래프 정의는 단일 원본만 유지하고 인접 목록을 초기화 시 대칭 검증한다.
- 모든 노드는 `rankCosts.length == maxRank`여야 한다.
- 시작 노드 ID 집합과 현재 트리 revision을 같은 데이터 모듈에서 제공한다.

### 9.2 게임 데이터

권장 파일: `lib/data/definitions/game_core_passive_tree_data.dart`

포함 항목:

- `corePassiveTreeRevision = 1`
- 27개 `CorePassiveNodeDefinition`
- 시작 노드 6개 집합
- 노드별 표시 값 목록
- 비용 누적 계산 함수
- 그래프 무결성 assert 또는 테스트용 검증 함수

노드 이름·효과 문구는 `RuneNexusLocalizations`의 ID 기반 switch에서 만든다. 위젯에 한글 문자열을 중복 작성하지 않는다.

## 10. 진행 상태와 저장

### 10.1 `RunProgression` 신규 상태

```dart
int totalCorePoints = 0;
int lastRunCorePointReward = 0;
int corePassiveTreeRevision = currentRevision;
final Map<CorePassiveNodeId, int> corePassiveNodeRanks = {};
final Set<int> claimedCorePointStageRewards = {};
```

계산 getter:

```dart
int get spentCorePoints;
int get availableCorePoints;
int corePassiveNodeRank(CorePassiveNodeId id);
```

변경 API:

```dart
bool setCorePassiveNodeRank(CorePassiveNodeId id, int targetRank);
bool resetCorePassiveTree();
void grantCorePoints(int amount);
int grantFirstClearCorePoints({required int stageNumber, required int reward});
```

- `setCorePassiveNodeRank`는 범위, 비용, 도달 가능성 검증을 한 번에 수행한다.
- UI가 맵을 직접 수정하지 않는다.
- 변경 성공 시에만 snapshot 게시와 저장 예약을 수행한다.
- 향후 이벤트·업적·출석·토너먼트는 `grantCorePoints`로 연결할 수 있게 한다.

### 10.2 `SavedProgression` 신규 필드

JSON 키:

```text
totalCorePoints
lastRunCorePointReward
corePassiveTreeRevision
corePassiveNodeRanks
claimedCorePointStageRewards
```

직렬화 형식:

```json
{
  "totalCorePoints": 20,
  "lastRunCorePointReward": 3,
  "corePassiveTreeRevision": 1,
  "corePassiveNodeRanks": {
    "attackHaste": 3,
    "attackPrecompute": 2
  },
  "claimedCorePointStageRewards": [1, 2, 3]
}
```

복원 규칙:

- 누락 필드는 0, 현재 revision, 빈 맵, 빈 집합으로 처리한다.
- 알 수 없는 노드 ID는 무시한다.
- 랭크는 해당 노드의 `0...maxRank`로 제한한다.
- 음수 포인트와 음수 스테이지 번호는 제거한다.
- revision 불일치, 과다 소비, 연결이 끊긴 할당이면 노드 랭크만 초기화한다.
- 총 획득 포인트와 스테이지 보상 수령 기록은 보존한다.
- 기존 `GameSaveData.currentVersion == 1`은 유지할 수 있다. 새 필드가 선택 기본값을 가지며 구 JSON의 추가 키를 무시하기 때문이다.

### 10.3 기존 슬롯 데이터 처리

사용자는 기존 패시브 데이터 초기화를 승인했다.

- `corePassiveSlotTwoUnlocked`, `corePassiveSlots`, `runCorePassiveSlots`를 신규 상태로 변환하지 않는다.
- 구 저장 JSON에 키가 남아 있어도 읽지 않고 무시한다.
- 다이아나 코어 포인트 보상을 지급하지 않는다.
- 구 슬롯 데이터 때문에 트리 노드가 자동 할당되지 않는다.
- `CorePassiveAbility` enum은 슬롯 제거 후 참조가 없어지면 삭제한다.
- 기존 세 이미지 자산은 새 트리 아이콘으로 계속 사용하므로 파일은 삭제하지 않는다.

## 11. 기존 패시브 효과 제거

다음 효과는 숨겨서 유지하지 말고 실제 런타임에서 제거한다.

- `자가 수복`: 5라운드마다 코어 체력 1 회복
- `절약 설계`: 포탑 건설 비용 15% 감소
- `연산 가속`: 전투 스킬 재사용 대기시간 10% 감소

점검 대상:

- `RuneNexusGame`의 `_runCorePassiveSlots`
- `costSavingDesignBuildDiscountPercent`
- 건설 비용 계산의 패시브 할인 분기
- 코어 전투 스킬 쿨다운 패시브 getter와 적용 경로
- 라운드 완료 시 자가 수복 처리
- 런 시작·재시작·복원 시 패시브 슬롯 복사
- 패시브 장착·해제·슬롯 해금 public 메서드
- 디버그 패시브 초기화 액션
- HUD의 장착 패시브 목록

이번 단계에서는 신규 `corePassiveNodeRanks`가 위 계산 경로를 대체하지 않는다. 노드를 할당해도 건설 비용, 코어 스킬 쿨다운, 넥서스 체력이 변하지 않는 회귀 테스트가 필요하다.

## 12. Snapshot과 UI API

`GameSnapshot`에 다음 값을 추가한다.

```dart
final int totalCorePoints;
final int spentCorePoints;
final int availableCorePoints;
final int lastRunCorePointReward;
final Map<CorePassiveNodeId, int> corePassiveNodeRanks;
```

기존 다음 값은 제거한다.

```dart
corePassiveSlots
corePassiveSlotCount
corePassiveSlotUnlockCost
canUnlockCorePassiveSlot
unlockedCorePassiveAbilities
```

`GameSnapshotBuilder`와 `_initialSnapshot()`을 함께 수정한다. 테스트의 snapshot fixture도 빠짐없이 갱신한다.

`RuneNexusGame`에는 UI가 사용할 다음 메서드만 노출한다.

```dart
bool setCorePassiveNodeRank(CorePassiveNodeId id, int rank);
bool resetCorePassiveTree();
```

화면에서 직접 `RunProgression` 상태를 변경하지 않는다.

## 13. 트리 렌더링 구현

### 13.1 파일 경계

권장 신규 파일:

- `lib/ui/menu/main_menu_core_tree.dart`

`main_menu_screen.dart`에 part 선언을 추가하고, `main_menu_core.dart`에는 상위 탭 전환과 기존 전투 스킬 UI만 남긴다.

`main_menu_core_tree.dart` 책임:

- 포인트 요약
- `InteractiveViewer`와 `TransformationController`
- 트리 월드 Stack
- 연결선 `CustomPainter`
- 노드 버튼과 상태 애니메이션
- 선택 노드 상세 패널
- 목표 랭크 draft
- 무료 전체 초기화 확인
- 최소 배율·중앙 transform 계산

### 13.2 노드 상태

시각 상태는 네 가지로 제한한다.

| 상태 | 표현 |
| --- | --- |
| 잠김 | 낮은 명도, 회색 테두리, 자물쇠 또는 흐린 아이콘 |
| 할당 가능 | 계통색 얇은 테두리, 약한 맥동 |
| 할당됨 | 계통색 채움과 강한 연결선, 랭크 배지 |
| 선택됨 | 외곽 이중 링과 글로우 |

계통색:

- 공격: 금색·주황
- 제어: 청록·하늘색
- 효율: 민트·녹색
- 혼합: 자홍색

노드 등급별 크기:

- 일반: 44~48
- 주요: 54~58
- 중간 키스톤: 64~70
- 중앙 코어: 86~96

정확한 값은 320px 폭에서 터치 영역을 보장하는 범위에서 조정한다. 화면이 좁다는 이유로 아이콘이나 랭크 표시를 제거하지 않는다.

### 13.3 연결선

- 연결선은 노드보다 먼저 그린다.
- 미개방 연결은 금속색 저명도 선으로 표시한다.
- 연결 시작 노드의 현재 랭크가 1·2일 때 선 길이 또는 광량을 단계적으로 증가시킨다.
- 3랭크에서 대상 노드까지 완전히 점등한다.
- 할당 경로는 계통색, 혼합 경로는 자홍색을 사용한다.
- 선의 장식이 노드 터치 판정을 가로채지 않게 `IgnorePointer` 또는 painter로 구현한다.

### 13.4 아이콘

재사용 자산:

- `assets/images/core_passives/self_repair.png`
- `assets/images/core_passives/cost_saving_design.png`
- `assets/images/core_passives/skill_acceleration.png`
- `assets/images/core_abilities/guardian_beam.png`
- `assets/images/core_abilities/rift_mark.png`

나머지는 표의 Material 선형 아이콘을 사용한다. 신규 래스터 이미지를 생성하지 않는다.

## 14. HUD 정리

`HudCoreInfoPanel`에서 기존 장착 패시브 목록을 제거한다.

권장 대체 표시:

```text
전투 스킬 1개 · 패시브 노드 6개 할당
패시브 트리 12 / 20pt
```

- 개별 노드 효과 목록은 전투 HUD에 반복하지 않는다.
- 기존 코어 전투 스킬 기여도와 넥서스 내구도는 유지한다.
- 패시브 트리 요약은 실제 효과가 아닌 할당 상태만 보여준다.

## 15. 로컬라이제이션

`RuneNexusLocalizations`에 최소한 다음 문구를 한·영으로 추가한다.

- 전투 스킬
- 패시브 트리
- 코어 포인트
- 사용 / 남음
- 전체 초기화
- 초기화 확인 제목·본문
- 할당
- 반환 포인트
- 연결된 노드를 강화하면 개방됩니다
- 노드 선택 안내
- 공격 / 제어 / 효율
- 코어 포인트 획득
- 27개 노드 이름
- 랭크별 효과 문구

노드 이름과 효과는 `CorePassiveNodeId`와 랭크를 받는 switch 메서드로 중앙화한다. 위젯과 결과 화면에 한글을 중복 작성하지 않는다.

## 16. 파일별 변경 계획

### 신규

| 파일 | 역할 |
| --- | --- |
| `lib/domain/core/core_passive_tree.dart` | 노드 ID·계통·등급·정의 타입 |
| `lib/data/definitions/game_core_passive_tree_data.dart` | 27개 노드, 비용, 연결, 시작 노드, revision |
| `lib/ui/menu/main_menu_core_tree.dart` | 방사형 트리 UI와 제스처·상세 패널 |
| `test/core_passive_tree_test.dart` | 비용·연결·할당·회수·무결성 단위 테스트 |

### 수정

| 파일 | 작업 |
| --- | --- |
| `lib/domain/stage/stage_definition.dart` | 최초 클리어 코어 포인트 필드 추가 |
| `lib/data/definitions/game_stage_data.dart` | 15개 스테이지 보상값 입력 |
| `lib/domain/core/core_ability.dart` | 전투 스킬은 유지하고 구 패시브 enum 제거 |
| `lib/data/save/game_save_data.dart` | 트리·포인트 저장 필드 추가, 구 슬롯 필드 제거 |
| `lib/game/systems/run_progression.dart` | 포인트·랭크·보상 수령·할당 검증 추가, 구 슬롯 진행 제거 |
| `lib/game/systems/game_save_adapter.dart` | 런 저장의 구 패시브 슬롯 제거 |
| `lib/game/game_restore_controller.dart` | 구 런 패시브 복원 제거, 스테이지 보상 소급 정산 호출 |
| `lib/game/game_snapshot.dart` | 트리·포인트 snapshot 필드 추가, 슬롯 필드 제거 |
| `lib/game/game_snapshot_builder.dart` | 신규 snapshot 값 게시 |
| `lib/game/rune_nexus_game.dart` | 할당 API, 최초 클리어 보상 전달, 구 패시브 효과·슬롯 제거 |
| `lib/ui/menu/main_menu_screen.dart` | 트리 데이터 import와 신규 part 선언 |
| `lib/ui/menu/main_menu_core.dart` | 상단 전환 탭, 전투 스킬 전용 화면으로 정리 |
| `lib/ui/menu/main_menu_debug_panel.dart` | 구 패시브 슬롯 초기화 액션 제거 또는 트리 무료 초기화로 명칭·동작 변경 |
| `lib/ui/menu/main_menu_research.dart` | 패시브 슬롯 다이아 해금 다이얼로그 제거 |
| `lib/ui/menu/result_overlay.dart` | 최초 클리어 코어 포인트 보상 행 추가 |
| `lib/ui/hud/core_info_panel.dart` | 구 패시브 목록을 트리 할당 요약으로 교체 |
| `lib/ui/game/core_ability_icon.dart` | 패시브 enum 의존 제거, 재사용 자산을 노드 ID에 매핑 |
| `lib/l10n/rune_nexus_localizations.dart` | 트리와 결과 보상 문구 추가 |
| `test/run_progression_core_test.dart` | 저장·보상·소급·효과 미적용·구 슬롯 제거 회귀 테스트 |
| `test/main_menu_core_test.dart` | 코어 탭·트리·할당 패널·320px 레이아웃 테스트 |
| `test/result_overlay_test.dart` | 결과 보상 표시 테스트 |

구 패시브 참조는 구현 종료 전 다음 검색 결과가 0이어야 한다. 이미지 파일명은 예외다.

```powershell
rg -n "CorePassiveAbility|corePassiveSlots|corePassiveSlotCount|corePassiveSlotUnlockCost|runCorePassiveSlots" lib test
```

## 17. 구현 순서

### 1단계: 도메인과 정적 데이터

1. 노드 ID·등급·계통 타입 추가
2. 27개 노드와 연결 정의
3. 비용·접근 가능성 검증 함수 추가
4. 그래프 대칭·중복 ID·랭크 비용 무결성 테스트

성공 기준: Flutter UI 없이 모든 그래프·비용 테스트 통과.

### 2단계: 진행 상태와 저장

1. `RunProgression`에 포인트·랭크·수령 기록 추가
2. atomic 할당·회수·전체 초기화 추가
3. `SavedProgression` 직렬화·복원 추가
4. revision 불일치와 잘못된 JSON 복원 테스트
5. 기존 클리어 기록 소급 지급 추가

성공 기준: 재실행 후 포인트·랭크가 동일하고 소급 보상이 한 번만 지급됨.

### 3단계: 스테이지 보상

1. `StageDefinition` 보상 필드 추가
2. 15개 값 입력
3. `_settleRunResult()`에서 현재 스테이지 보상 전달
4. 최초 성공에서만 지급
5. `lastRunCorePointReward` snapshot 게시

성공 기준: 최초 클리어는 표의 값을 지급하고 반복 클리어·패배는 0.

### 4단계: 구 패시브 제거

1. 슬롯 UI·해금 다이얼로그 제거
2. 진행·런 저장 필드 제거
3. 장착·해제 API 제거
4. 자가 수복·건설 할인·쿨다운 감소 적용 제거
5. HUD와 디버그 메뉴 정리

성공 기준: 구 패시브 심볼이 사라지고 노드 할당 전후 전투 수치가 동일함.

### 5단계: 코어 트리 UI

1. 상단 화면 전환
2. 포인트 요약
3. 방사형 월드와 연결선 painter
4. 노드 상태·선택·랭크 배지
5. 상세 패널 draft와 `할당`
6. 무료 초기화
7. 동적 fit scale과 자동 중앙 정렬

성공 기준: 320px와 일반 모바일 폭에서 잘림 없이 할당·회수·제스처 사용 가능.

### 6단계: 결과 화면·로컬라이제이션·문서

1. 결과 화면 포인트 행
2. 한·영 문구
3. `docs/nexus_core_design.md` 현재 상태 갱신
4. `docs/core_passive_slot_ui_design.md`를 삭제하거나 역사 문서로 명시
5. `docs/implementation_status.md` 갱신

성공 기준: 코드·문서가 슬롯 패시브를 현재 기능으로 설명하지 않음.

## 18. 필수 테스트

### 18.1 그래프 단위 테스트

- 노드가 정확히 27개다.
- 시작 노드가 정확히 6개다.
- 모든 연결이 대칭이다.
- 자기 자신·중복 연결이 없다.
- 모든 노드가 중앙 시작 노드 집합에서 도달 가능하다.
- 비용 배열 길이와 최대 랭크가 일치한다.
- 일반 노드 3랭크 비용은 4포인트다.
- 한쪽 시작 노드 3랭크만으로 혼합 노드가 열린다.
- 양쪽 모두 2랭크면 혼합 노드가 열리지 않는다.
- 연결 경로를 끊는 회수는 거부된다.
- 순환 노드끼리 만든 고립 섬은 유효하지 않다.

### 18.2 포인트·저장 테스트

- 새 저장은 총 포인트 0, 빈 랭크, 빈 수령 기록이다.
- 할당 후 사용·남은 포인트가 정확하다.
- 무료 회수와 전체 초기화에서 총 포인트가 줄지 않는다.
- 알 수 없는 ID, 음수 랭크, 초과 랭크를 안전하게 처리한다.
- revision 불일치 시 랭크만 초기화한다.
- 구 저장 JSON의 패시브 슬롯 키를 무시한다.
- 저장 후 복원하면 유효한 랭크가 유지된다.

### 18.3 스테이지 보상 테스트

- 표의 15개 보상 합이 20이다.
- 스테이지 5 최초 클리어는 2포인트다.
- 스테이지 10과 15 최초 클리어는 각각 3포인트다.
- 반복 클리어는 0포인트다.
- 패배는 0포인트다.
- 구 저장의 클리어 기록을 한 번만 소급 정산한다.
- 소급 정산은 `lastRunCorePointReward`에 나타나지 않는다.

### 18.4 효과 미적용 회귀 테스트

노드를 최대 랭크로 할당해도 다음 값은 변하지 않아야 한다.

- 포탑 건설 비용
- 수호 광선 발동 간격
- 균열 낙인 발동 간격
- 넥서스 체력과 라운드 종료 회복
- 포탑 피해·공속·치명타·저항 계산

### 18.5 위젯 테스트

- 코어 탭에 `전투 스킬 / 패시브 트리`가 보인다.
- 구 패시브 슬롯·해금 비용·장착 버튼은 보이지 않는다.
- 패시브 트리에서 27개 노드가 생성된다.
- 잠긴 노드의 `할당`은 비활성화된다.
- 시작 노드 목표 랭크를 3으로 정하고 할당하면 주변 노드가 열린다.
- `−`로 연결을 끊으려 하면 비활성화된다.
- 전체 초기화 확인 후 사용 포인트가 0이 된다.
- 결과 화면은 최초 클리어 포인트가 있을 때만 `+N 코어 포인트`를 표시한다.
- 320px 폭에서 상세 패널의 이름·랭크·`할당` 문구가 잘리지 않는다.

## 19. 검증 절차

Windows Flutter 검증은 `.agents/windows_flutter_guide.md`와 `.agents/in_app_test_guide.md` 순서를 따른다.

1. 수정 Dart 파일 포맷

```powershell
C:\Users\rlatp\develop\flutter\bin\cache\dart-sdk\bin\dart.exe format <수정 파일 목록>
```

2. 신규 단위 테스트

```powershell
flutter test test/core_passive_tree_test.dart
```

3. 핵심 회귀 테스트

```powershell
flutter test test/run_progression_core_test.dart
flutter test test/main_menu_core_test.dart test/result_overlay_test.dart
```

4. 정적 분석과 전체 테스트

```powershell
flutter analyze
flutter test
```

5. 인앱 서버 상태 확인

```powershell
scripts/in_app_server.ps1 -Action status
```

6. 서버가 살아 있으면 hot reload와 브라우저 새로고침을 우선한다. 오래된 번들이 의심될 때만 `restart`와 새 cache-bust URL을 사용한다.

7. 수동 확인 항목

- 최소 배율에서 트리 전체가 정중앙에 맞고 화면을 채운다.
- 확대 후 드래그할 수 있다.
- 다시 최소 배율로 축소하면 중앙에 맞춰진다.
- 별도 중앙 복귀 버튼이 없다.
- 노드 터치와 캔버스 드래그가 충돌하지 않는다.
- 320px 폭에서 상단 포인트, 노드, 상세 패널, `할당` 버튼이 잘리지 않는다.
- 전투 스킬 장착·해제는 기존대로 동작한다.
- 구 패시브 효과가 전투 중 발동하지 않는다.
- 최초 클리어 결과에만 코어 포인트가 보인다.

Flutter 실행·테스트·서버 시작은 Windows 샌드박스 밖 승인이 필요한 명령이므로 후속 Agent가 실행 전에 해당 가이드를 확인해야 한다.

## 20. 완료 조건

다음이 모두 충족되어야 구현 완료로 판단한다.

- [ ] 패시브 슬롯·카드 장착·다이아 슬롯 해금이 UI와 런타임에서 제거됨
- [ ] `전투 스킬 / 패시브 트리` 전환이 동작함
- [ ] 27개 노드가 확정 그래프대로 배치됨
- [ ] 모든 일반·주요 노드는 3랭크에서 주변 노드를 개방함
- [ ] 혼합 노드는 어느 한쪽 연결 경로만으로 개방 가능함
- [ ] 목표 랭크 `+ / −`와 `할당`이 atomic하게 동작함
- [ ] 연결을 끊는 회수가 차단됨
- [ ] 무료 전체 초기화가 포인트를 보존함
- [ ] 15개 스테이지 최초 클리어 보상 총합이 20포인트임
- [ ] 기존 클리어 기록에 포인트가 정확히 한 번 소급 지급됨
- [ ] 결과 화면은 이번 최초 클리어 획득량만 표시함
- [ ] 저장·복원 후 포인트와 랭크가 유지됨
- [ ] 구 패시브 저장 데이터는 보상 없이 무시됨
- [ ] 노드 효과가 전투·경제 계산에 적용되지 않음
- [ ] 최소 축소 상태가 전체 트리 정중앙 맞춤임
- [ ] 별도 중앙 복귀 버튼이 없음
- [ ] 320px 폭에서 핵심 UI 문구와 조작이 잘리지 않음
- [ ] 한·영 UI 문구가 모두 준비됨
- [ ] 관련 단위·위젯·전체 테스트와 analyze가 통과함

## 21. 후속 구현에서 임의로 바꾸면 안 되는 결정

- 세 계통은 `공격 / 제어 / 효율`이다.
- 순수 방어 계통으로 되돌리지 않는다.
- 노드는 27개다.
- 외곽 완성 링은 구현하지 않는다.
- 주변 개방은 노드 3랭크 하나의 규칙으로 통일한다.
- 혼합 트리는 양쪽 동시 투자를 요구하지 않는다.
- 버튼 문구는 `할당`이다.
- 효과 문구는 실제 효과처럼 보이게 하되 계산에는 연결하지 않는다.
- 기존 슬롯 패시브 효과는 유지하지 않는다.
- 기존 슬롯 데이터와 해금 비용은 보상 없이 초기화한다.
- 초기화는 무료다.
- 스테이지 15 보상은 3포인트다.
- 별도의 전체 포인트 보상표 화면을 만들지 않는다.
- 최소 축소는 트리 전체 맞춤과 중앙 정렬이다.
- 중앙 복귀 버튼을 추가하지 않는다.

이 항목 중 하나를 변경해야 구현이 가능하다고 판단되면 임의 변경하지 말고 사용자에게 확인한다.
