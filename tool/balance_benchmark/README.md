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
| `calibrate` | `--types`의 종류마다 그 종류만 짓는 판을 돌려, 실제 피해 ÷ 예측 피해 비율을 기관총(항상 측정) 대비로 맞춘 `typeFactors`를 낸다. 모든 종류가 코어가 피해를 입은 포탑×웨이브 30 이상이면 그 표본만, 아니면 전체 표본을 쓴다(보고서 `source`). 빠진 종류(기본 냉각)와 해금되지 않아 표본이 없는 종류(`unmeasured`)는 기존 값을 유지한다. `--write`면 `calibration.json`에 기록. 보정값이 봇의 종류 선택에도 쓰이므로, 값이 바뀌면 같은 명령을 다시 돌려 그대로인지 확인한다 |
| `ab` | 같은 계정·시드로 `--variants`의 매개변수 묶음을 비교. 계정은 `--progression-file`(campaign 보고서 폴더의 `snapshot-<id>.json`) |

```sh
python3 scripts/run_balance_benchmark.py --job=campaign --stages=1-10 --trajectories=3 --seeds=3 --max-attempts=60
python3 scripts/run_balance_benchmark.py --job=checkpoint --stages=6-10 --trajectories=5 --seeds=3 --farm-clears=3 --max-attempts=15
python3 scripts/run_balance_benchmark.py --job=calibrate --stages=3,5,20,10,25,11,13 --seeds=2 --runes=3000 --cleared=1-25 --write
python3 scripts/run_balance_benchmark.py --job=ab --stage=9 --seeds=6 --progression-file=<snapshot> --variants='[{}, {"slowUptime":1.0}]'
```

`--cleared=<첫 ID>-<끝 ID>`와 `--stages=<첫 ID>-<끝 ID>`는 두 고정 스테이지 ID 사이를 진행 순서로 고른다. `1-25`가 1-1~2-10이고, `1-20`은 1-1~1-10이다(라이트닝·독 해금 전).

[calibration.json](calibration.json)은 봇 판단의 보정값이며 `_notes`에 근거 측정을 적는다. 결과는 `build/balance-benchmark/run-*/summary.json`에 남는다. `checkpoint`·`campaign` 행과 `ab` 변형마다 `board`(판당 종류별 포탑 수, 종류별 피해 비중, 종류별 직격·범위·연쇄·화상 비율)를 요약하고, `checkpoint`·`campaign` 행은 그 판의 장착 모듈(`modules`)도 남긴다. 포탑별 원자료(`turrets`의 `damageParts`, 경로 위치 `pathProgress` 0=입구·1=코어)는 각 작업 보고서에 있다.

### 이어 하기 (`--resume`·`--fork`)

`campaign`·`checkpoint`는 경로마다 스테이지를 클리어할 때 `run-*/checkpoints/t<경로>/after-<ID>/`에 상태를 남긴다. 클리어 정산 뒤·다음 스테이지 소비 전의 계정 전체(봇 전용 키 포함), 봇 기억(직전 판·피해·수입·클리어 기록), 모듈 난수 상태를 Godot 바이너리(`state.bin`)로 저장하고, 마지막에 `manifest.json`(해시)을 쓴다. 매니페스트가 없는 폴더는 미완성이다. 실행 폴더의 `manifest.json`에는 입력 지문(게임 코드·콘텐츠, 봇, `_notes`를 뺀 보정값, `--params`, 작업 종류, `--farm-clears`, 엔진 버전)과 봇 인자가 남는다.

```sh
python3 scripts/run_balance_benchmark.py --job=checkpoint --resume=build/balance-benchmark/run-<id> --stages=26-30
python3 scripts/run_balance_benchmark.py --job=checkpoint --fork=build/balance-benchmark/run-<id> --stages=26-30 --params='{...}'
```

| 옵션 | 동작 |
| --- | --- |
| `--resume` | 원래 실행의 경로 수·봇 인자·`--params`를 이어받아 `--stages` 직전 클리어 상태에서 경로마다 출발한다. 지문이 하나라도 다르면 거부한다. 같은 입력이면 연속 실행과 결과가 같다 |
| `--fork` | 같은 출발 상태에 바뀐 입력(콘텐츠·`--params` 등)을 적용하는 실험이다. 주지 않은 봇 인자·`--params`는 원래 실행 값을 이어받고(`--params`는 통째로 바뀌며, 비우려면 `--params='{}'`), 다른 항목을 `parent.differs`에 남긴다 |
| `--margins=0` | `campaign`·`checkpoint` 뒤의 여유도 측정을 건너뛴다 |

`--stages`는 저장된 클리어 바로 다음 스테이지에서 시작해야 하고, 경로 하나라도 상태가 없으면 실행하지 않는다. 앞 구간을 고정하고 한 스테이지의 수치만 비교할 때는 `--fork`, 변경의 누적 영향을 볼 때는 처음부터 다시 돌린다. 오래 도는 실행이 있는 동안 다른 측정을 하려면 `BALANCE_BENCHMARK_CACHE=<다른 폴더>`로 격리 프로젝트를 나눈다(실행기는 시작할 때 격리 프로젝트를 다시 쓴다). `--progression-file`·`snapshot-*.json`은 계정만 넣는 실험 입력으로 따로 남아 있다.

### 실험용 매개변수

`--params`(또는 `ab`의 `--variants`)로 넘긴다. 기본값은 모두 꺼져 있어 일반 측정에는 영향이 없다.

| 매개변수 | 용도 |
| --- | --- |
| `bannedTypes` | 짓지 않을 종류 목록 |
| `typeShares` | `{종류: 비중}`. 적힌 종류만 짓고, 각 종류는 `현재 개수 < 비중 × (판 포탑 수 + 1)`일 때만 새로 짓는다. 근사 상한이라 판이 작을 때는 비중을 넘을 수 있다(50:50에서 2:1). 강제 건설은 아니다 |
| `typeAfter` | `{종류: 개수}`. 판에 포탑이 그 개수 이상일 때부터 그 종류를 짓는다 |
| `typeProgress` | `{종류: [시작, 끝]}`. 사거리 안 경로의 평균 진행도(0 입구, 1 코어)가 구간 안인 칸에만 짓는다 |
| `frontTypes`·`frontProgress` | 적힌 종류는 `frontProgress` 앞쪽, 나머지는 뒤쪽 칸에만 짓는다 |
| `turretOverrides` | `{종류: {정의 필드: 값}}`. 이 프로세스 안에서만 기본 스탯(피해·공격 속도·폭발 반경 등)을 바꾼다. 건설·강화 비용은 바꾸지 못한다 |
| `moduleType` | 모든 모듈을 이 종류로 뽑는다(기본은 마지막 판 피해 1위 종류) |
| `moduleFloor` | 런마다 모든 종류의 코어·포신·프레임을 이 등급 이상으로 채운다. 빈 칸이나 낮은 칸에는 뽑기 규칙으로 굴린 그 등급 모듈을 끼우고, 그보다 낮게 뽑힌 모듈은 분해한다. 바닥 모듈은 분해 보상이 없다. 기본 설정(`calibration.json`)은 `rare`로, 주력 종류에 모듈이 몰려 종류 판단이 기우는 것을 막는다 |
| `runeWeights` | `{강화 ID: 가중치}`. `RUNE_WEIGHTS`를 바꾼다. 판 기록이 없는 출발 계정의 계열 강화를 원소 쪽으로 돌릴 때 쓴다 |

조합을 고정해 비교할 때는 주력 종류로 `moduleType`을 맞추고, 원소 조합이면 `runeWeights`로 원소 강화를 앞세운다. 그렇지 않으면 출발 계정의 모듈·강화가 물리 종류에 쏠려 결과가 왜곡된다.

포탑 조합·배치·수치안 비교 기록은 [포탑 밸런스 측정](../../docs/analysis/turret_balance_20261104/README.md)에 있다.

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
- 모듈(`modules`): 다이아를 모듈권(40다이아)으로 바꾸고, 모든 권으로 마지막 판에서 피해가 가장 큰 포탑 종류의 모듈을 서버 규칙(부위 균등, 뽑기 수에 따른 등급, 등급별 옵션 수, 옵션 범위)대로 뽑는다. 부위마다 마지막 판 기준 DPS가 가장 높은 모듈만 남기고, 나머지는 분해 환급(다이아)한다. 기본 설정은 `moduleFloor: rare`라 뽑기와 별개로 모든 종류가 희귀 이상 3부위를 갖는다. 판 안 다이아 드롭, 첫 클리어 모듈권, 새로 달성한 도전 보상을 서버처럼 더한다. 전투 없이 정산하는 클리어는 그 스테이지의 마지막 실제 클리어 기록(없으면 `baselineRunGameSeconds`·`baselineRunDiamonds`)을 쓴다.
- 다루지 않는 것: 누적 업적·컬렉션 메달 다이아, 우편, 연구 2번 슬롯·다이아 가속, 여러 종류에 나눠 뽑는 모듈 전략(희귀 바닥이 대신한다).

## 해석할 때 주의할 한계

- 종류 선택은 계정 상태에 따라 기운다. 계열 강화(물리·원소·독)와 모듈이 이미 쌓인 종류가 계속 유리해지므로(모듈은 희귀 바닥으로 줄였지만 주력 종류만 고유 등급까지 오른다), 물리로 키운 계정에서 원소 종류를 거의 고르지 않는다. 자유 선택 결과만으로 종류의 강약을 판단하지 않고, 조합을 제한한 비교(`typeShares`·`moduleType`·`runeWeights`)로 확인한다.
- 갈래 경로 맵(3-8·3-10 등 `routes`)은 경로마다 경로 정보를 따로 만들고, 사거리 안 경로 길이를 경로별 적 체력 비중으로 가중한다. 보스 몫은 다음 보스가 오는 경로만 센다. 웨이브마다 경로가 바뀌어도 배치는 스테이지 전체 비중으로 판단한다.
- 칸이 가득 차도 싼 포탑을 팔고 비싼 포탑으로 바꾸지 않는다. 타일당 화력이 높은 종류는 칸이 부족한 맵에서 실제보다 불리하게 나온다.
- 범위·연쇄·지속피해·감속 가치는 고정 배율과 `typeFactors`로 근사한다. 실제 피해는 보고서의 `damageParts`(직격·범위·연쇄·화상)로 확인한다.
- `checkpoint`의 반복 클리어는 전투 없이 보상만 더한다. 그 조합으로 직전 스테이지를 실제로 반복 클리어할 수 있는지는 확인하지 않는다.
- 경로 3개 정도의 측정은 경로 간 범위가 넓다. 20% 안쪽 차이는 같은 수준으로 본다.

가중치와 배율은 보고서의 `heuristics`에 함께 기록한다. 결과는 "무난한 플레이어" 기준이며 최적 플레이의 하한이 아니다.
