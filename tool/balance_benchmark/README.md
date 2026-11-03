# 밸런스 벤치마크 봇

역할: 규칙 기반 봇이 실제 런 도메인(`run_session`·`run_commands`·`growth_rules`)과 `NativeCombatRuntime`으로 스테이지를 헤드리스로 플레이해, 클리어에 필요한 최소 계정 성장과 스테이지의 여유를 잰다. 개발 도구이며 앱·APK에 포함하지 않는다. LLM을 쓰지 않고, 같은 시드는 같은 결과를 낸다.

## 실행

```sh
python3 scripts/run_balance_benchmark.py --stage=1 --mode=grind --trajectories=5
python3 scripts/run_balance_benchmark.py --stage=1 --mode=single --runes=300 --seeds=10
python3 scripts/run_balance_benchmark.py --stage=1 --mode=margin --runes=0 --seeds=5
```

실행기는 네이티브 회귀와 같은 구성의 격리 프로젝트(`build/godot-balance-benchmark/`)를 만들고, 상세 보고서를 `build/balance-benchmark/`에 JSON으로 저장한다. 사용자 저장·회귀 캐시는 건드리지 않는다.

| 모드 | 측정 |
| --- | --- |
| `grind` | 신규 계정이 실패 → 런 종료 룬 → 영구 강화 → 재도전을 반복해 클리어까지 걸린 횟수 |
| `single` | 지정한 룬을 영구 강화에 쓴 계정의 시드별 클리어율 |
| `margin` | 봇이 쓸 수 있는 골드 비율을 낮춰 가며 클리어가 끊기는 지점. 낮을수록 스테이지 여유가 크다 |
| `campaign` | 신규 계정으로 `--stages=1-5`를 진행 순서대로 클리어될 때까지 반복. 룬·코어 포인트·해금이 이어진다. `--margin=1`이면 첫 경로에서 각 스테이지를 클리어한 계정으로 `margin`을 잰다 |

```sh
python3 scripts/run_balance_benchmark.py --mode=campaign --stages=1-5 --trajectories=3 --margin=1 --seeds=3
```

### 병렬 작업 (`--job`, 기본 6프로세스 `--jobs=6`)

| 작업 | 내용 |
| --- | --- |
| `campaign` | 경로를 병렬로 진행한 뒤, 첫 경로의 클리어 시점 계정으로 스테이지별 여유도를 병렬 측정. `--stages=1-10`은 진행 순서 1-1~2-5 |
| `checkpoint` | 권장 흐름 계정(앞 스테이지를 한 번씩 클리어했다고 보고 전투 없이 보상·연구 시간만 적용)에서 `--stages` 구간만 진행한다. 실패할 때마다 직전 클리어 스테이지를 `--farm-clears`번 반복 클리어했다고 보고 룬을 더한 뒤 재도전한다 |
| `calibrate` | 모든 해금 종류를 짓는 탐색 판에서 종류별 예측/실제 피해를 모아 `typeFactors`를 맞춘다. `--write`면 `calibration.json`에 기록 |
| `ab` | 같은 계정·시드로 `--variants`의 매개변수 묶음을 비교. 계정은 `--progression-file`(campaign 보고서 폴더의 `snapshot-<id>.json`) |

```sh
python3 scripts/run_balance_benchmark.py --job=campaign --stages=1-10 --trajectories=3 --seeds=3 --max-attempts=60
python3 scripts/run_balance_benchmark.py --job=checkpoint --stages=6-10 --trajectories=5 --seeds=3 --farm-clears=3 --max-attempts=15
python3 scripts/run_balance_benchmark.py --job=calibrate --stages=1,3,5,17,20,7,10 --seeds=4 --runes=1500 --cleared=1-10 --write
python3 scripts/run_balance_benchmark.py --job=ab --stage=9 --seeds=6 --progression-file=<snapshot> --variants='[{}, {"slowUptime":1.0}]'
```

[calibration.json](calibration.json)은 봇 판단의 보정값이며 `_notes`에 근거 측정을 적는다. 결과는 `build/balance-benchmark/run-*/summary.json`에 남는다.

## 봇의 판단 규칙

- 골드: 건설·강화·런 업그레이드 중 골드 1당 증가 가치가 가장 큰 행동을 고른다. 최선의 70%에 못 미치는 선택지만 살 수 있으면 저축한다. 경제 업그레이드(`waveGold`)는 코어가 온전하고 포탑이 있을 때만, 8웨이브 안에 돌려받는 골드로 평가한다.
- 포탑 가치(웨이브 몫): 실제 스탯 계산(`turret_stat_calculation`)의 단일 대상 DPS × 사거리 안 경로 길이 × 종류별 보정(`typeFactors`). 경로는 최근 적이 실제로 도달한 비율로 가중하고(텔레포트 구간 제외), 범위·연쇄·지속피해·방어 관통은 고정 배율로 근사한다. 감속은 범위 안에서 다른 포탑이 더 주는 피해 × `slowUptime`으로 평가한다.
- 보스 몫(`bossWeight`): 다음 보스 웨이브(`bossLookahead` 안)의 보스가 경로 전체를 걷는 동안 현재 판이 주는 단일 대상 피해 ÷ 보스 내구도를 처치 여유로 본다. 여유가 `bossMargin`보다 모자란 만큼만 각 포탑의 보스 피해(연쇄·범위 제외, 추가 투사체 일부)를 가치에 더한다. 저격 2차 특성(노출 표식·마무리 사격)은 보스 몫에 반영한다. 표적 우선순위 연구가 있으면 한 방 피해가 다가올 일반 적 평균 내구도의 `strongestHitShare` 이상인 포탑만 '가장 강한 적'을 노린다.
- 젬: 서버와 같은 규칙(해금 젬 중 서로 다른 3개)으로 만든 로컬 덱에서 가치 증가가 가장 큰 젬을 고르고, 빈 슬롯이 없으면 링크를 사서 장착한다. 증가가 2% 미만이면 파편을 고른다. 다음 특성 비용을 넘는 파편으로 젬 구매를 한다. 리롤은 하지 않는다.
- 특성: 가치가 가장 큰 포탑부터 조건과 파편이 되면 `traitChoices`의 선택지(기본 첫 번째)를 고른다. 스탯 계산에 없는 전투 특성(과열 탄창·연쇄 정리·제압 사격 등)은 `COMBAT_TRAITS` 배율로 평가한다. `shardPolicy="value"`면 모든 포탑의 특성과 젬 구매(3개 중 최선의 기대 가치)를 파편 1당 가치로 비교한다(측정상 이득이 없어 기본은 `fixed`).
- 영구 강화: `RUNE_WEIGHTS`(1레벨당 피해 환산 가치 가정) ÷ 비용 순으로 산다. `boardRuneWeights`면 한 판을 마친 뒤부터 피해 강화(화력·계열·치명 피해, 치명타 연구)는 마지막 판 포탑 구성의 실제 DPS 증가율로, 골드 강화(정비 보급·처치 골드·시작 골드)는 마지막 판 총수입 대비 늘어나는 골드 × `goldElasticity`로 평가한다.
- 코어 트리: 런 사이에 남은 포인트를 `CORE_WEIGHTS`(효과 1단위의 피해 환산 가치 가정) ÷ 포인트 순으로 1랭크씩 배분한다. 키스톤은 고르지 않는다.
- 연구: 슬롯이 비면 `RESEARCH_WEIGHTS` ÷ 룬 비용으로 영구 강화와 함께 비교해 시작한다. 계정 시계는 판마다 게임 시간 ÷ `playSpeed`(기본 2배속) + `secondsBetweenRuns`(기본 60초)만큼 흐르고, 다음 시도 전에 끝난 연구를 받는다.
- 달력(`playHoursPerDay`): 0보다 크면 실제 시간이 플레이 시간의 24/playHoursPerDay배로 흐른다. 연구는 오프라인에도 진행되고, 하루마다 일일·주간 퀘스트와 출석 보상(다이아·모듈권, 모두 완료 가정)이 들어온다. 보고서의 `clockHours`는 달력 시간, `playHours`는 플레이 시간이다.
- 모듈(`modules`): 다이아를 모듈권(40다이아)으로 바꾸고, 모든 권으로 마지막 판에서 피해가 가장 큰 포탑 종류의 모듈을 서버 규칙(부위 균등, 뽑기 수에 따른 등급, 등급별 옵션 수, 옵션 범위)대로 뽑는다. 부위마다 마지막 판 기준 DPS가 가장 높은 모듈만 남기고, 나머지는 분해 환급(다이아)한다. 판 안 다이아 드롭, 첫 클리어 모듈권, 새로 달성한 도전 보상을 서버처럼 더한다. 전투 없이 정산하는 클리어는 그 스테이지의 마지막 실제 클리어 기록(없으면 `baselineRunGameSeconds`·`baselineRunDiamonds`)을 쓴다.
- 다루지 않는 것: 누적 업적·컬렉션 메달 다이아, 우편, 연구 2번 슬롯·다이아 가속, 여러 종류에 나눠 뽑는 모듈 전략.

가중치와 배율은 보고서의 `heuristics`에 함께 기록한다. 결과는 "무난한 플레이어" 기준이며 최적 플레이의 하한이 아니다.
