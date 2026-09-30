#!/usr/bin/env python3
"""Generate the map-specific chapter-one round proposal; never writes game content."""

import argparse
from collections import Counter
from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
CONTENT = ROOT / "godot/content/game_content.json"
MAPS = HERE.parent / "maps.json"
TYPES = ("normal", "fast", "tank", "boss")
LABELS = {"baseline": "기준형", "rush": "러시형", "overlap": "겹침형", "tank": "탱커형", "compression": "압축형", "boss": "보스 호위형"}
INTRO = ("일반 복습", "일반 추가 복습", "일반 2파동 복습", "빠른 적 복습", "탱커 복습")


def number(value):
    return round(value, 9)


def duration(group):
    # First-to-last spawn span; one enemy occupies zero spawn span.
    return (group["count"] - 1) * group["interval"]


def end(group):
    return group["startDelay"] + duration(group)


def timeline(groups):
    return sorted(((g["startDelay"] + i * g["interval"], g["enemyType"])
                  for g in groups for i in range(g["count"])), key=lambda item: item[0])


def normalized_queue(groups):
    queue = []
    previous = -0.18
    for raw, enemy_type in timeline(groups):
        delay = number(max(raw, previous + 0.18))
        queue.append({"enemyType": enemy_type, "delay": delay})
        previous = delay
    return queue


def absolute_groups(groups):
    result = []
    previous_end = 0
    for original in groups:
        group = {k: original[k] for k in ("enemyType", "count", "interval", "startDelay")}
        if original.get("startAfterPrevious", False):
            group["startDelay"] = previous_end + original["followDelay"]
        previous_end = end(group)
        result.append(group)
    return result


def same_queue(first, second):
    return len(first) == len(second) and all(a["enemyType"] == b["enemyType"]
        and math.isclose(a["delay"], b["delay"], rel_tol=0, abs_tol=1e-8)
        for a, b in zip(first, second))


def counts(groups):
    result = Counter()
    for group in groups:
        result[group["enemyType"]] += group["count"]
    return result


def interval_inventory(groups):
    result = Counter()
    for group in groups:
        result[(group["enemyType"], number(group["interval"]))] += group["count"]
    return result


def pattern(round_number):
    if round_number <= 5:
        return "intro"
    if round_number % 10 == 0:
        return "boss"
    return ("compression", "baseline", "rush", "overlap", "tank")[round_number % 5]


def make_wave(source, map_number):
    r = source["round"]
    p = pattern(r)
    groups = [{k: number(g[k]) if k in ("interval", "startDelay") else g[k]
               for k in ("enemyType", "count", "interval", "startDelay")}
              for g in source["groups"]]
    rule_map = map_number
    if map_number == 10:
        rule_map = 6 if r <= 15 else 7 if r <= 25 else 8 if r <= 35 else 9
    note = "기존 1-5 동일 라운드의 그룹 구성과 출현 시각 유지."
    if r <= 5:
        note = "기존 1-5 입문 웨이브의 수량·간격·출현 시각·보상 그대로 유지."
    elif p == "boss":
        if map_number == 10 and r in (20, 30, 40):
            normal = groups[-1]
            first = deepcopy(normal)
            first["count"] = math.ceil(normal["count"] / 2)
            first["startDelay"] = number(groups[-2]["startDelay"] + 0.9)
            second = deepcopy(normal)
            second["count"] -= first["count"]
            second["startDelay"] = number(end(first) + 3.0)
            groups[-1:] = [first, second]
            note = "기존 보스·선행 호위 유지. 후속 일반을 보스+0.9초와 첫 일반 마지막 출현+3초의 2파동으로 분리."
        else:
            note = "기존 탱커→빠른 적→보스 1→후속 일반 호위 구조와 시각 유지."
    elif rule_map in (6, 9) and p == "rush":
        gap = 2.2 if rule_map == 6 else 2.5
        groups[2]["startDelay"] = number(end(groups[1]) + gap)
        note = f"빠른 적 1파 마지막 출현에서 2파 첫 출현까지 {gap}초 휴지. 일반과 1파는 기존 유지."
    elif rule_map == 7 and p == "tank":
        tank, normal, fast = deepcopy(groups)
        first = deepcopy(tank)
        first["count"] = math.ceil(tank["count"] / 2)
        rest = deepcopy(tank)
        rest["count"] -= first["count"]
        normal["startDelay"] = number(end(first) + 0.7)
        rest["startDelay"] = number(end(normal) + 0.7)
        fast["startDelay"] = number(end(rest) + 0.7)
        groups = [first, normal, rest, fast]
        note = "탱커 ceil(n/2) 선두→일반→남은 탱커→빠른 적. 각 그룹 마지막 출현 후 다음 그룹까지 0.7초."
    elif rule_map == 8 and p == "overlap":
        normal, fast = groups[:2]
        fast["startDelay"] = number(normal["startDelay"] + duration(normal) * 0.45)
        if len(groups) == 3:
            groups[2]["startDelay"] = number(fast["startDelay"] + duration(fast) * 0.5)
        note = "일반 출현 구간 45% 시점에 빠른 적 시작. 탱커가 있으면 빠른 적 출현 구간 50% 시점에 시작. 겹침형 안에서만 재배치."
    elif rule_map == 9 and p == "tank":
        groups[-1]["startDelay"] = number(end(groups[1]) + 2.0)
        note = "기존 탱커·일반 시각 유지. 마지막 빠른 적 그룹은 일반 마지막 출현+2초에 시작."
    unchanged = groups == [{k: number(g[k]) if k in ("interval", "startDelay") else g[k]
                           for k in ("enemyType", "count", "interval", "startDelay")} for g in source["groups"]]
    return {"round": r, "pattern": p, "label": INTRO[r - 1] if r <= 5 else LABELS[p],
            "clearRewardGold": source["clearRewardGold"], "groups": groups,
            "spawnQueue": deepcopy(source["spawnQueue"]) if unchanged else normalized_queue(groups),
            "queueSource": "existing-id5-spawnQueue" if unchanged else "existing-0.18s-normalization",
            "designNote": note}


def build():
    content = json.loads(CONTENT.read_text())
    maps = json.loads(MAPS.read_text())["maps"]
    source = next(stage for stage in content["stages"] if stage["id"] == 5)["waves"]
    rewards = {key: content["enemies"][key]["rewardGold"] for key in TYPES}
    assert [w["round"] for w in source] == list(range(1, 41))
    assert all(same_queue(normalized_queue(absolute_groups(w["groups"])), w["spawnQueue"])
               for stage in content["stages"] for w in stage["waves"]), "Existing spawn normalization changed"
    stages = [{"chapterStage": m["chapterStage"], "name": m["name"],
               "progressionOrdinal": int(m["chapterStage"].split("-")[1]),
               "rounds": [make_wave(w, int(m["chapterStage"].split("-")[1])) for w in source]}
              for m in maps]
    proposal = {
        "status": "proposal-round-design-only",
        "source": {"contentPath": "godot/content/game_content.json", "referenceStageId": 5,
                   "referenceChapterStage": "1-5", "mapPath": "design/chapter1_map_expansion/maps.json",
                   "contentSha256": hashlib.sha256(CONTENT.read_bytes()).hexdigest()},
        "timeConvention": {"startDelay": "absolute seconds from wave start, excluding portal startup delay",
                           "spawnTime": "startDelay + index * interval; index = 0..count-1",
                           "spawnSpan": "(count - 1) * interval; one enemy has zero span",
                           "groupRest": "next group's first requested spawn minus prior group's last requested spawn",
                           "spawnNormalization": "stable sort requested spawn times, then actualDelay = max(requestedDelay, previousActualDelay + 0.18)",
                           "queueAuthority": "spawnQueue is the execution authority; groups retain requested within-group intervals",
                           "normalizationReferenceCheck": "all 15 existing stages x 40 rounds reproduce existing spawnQueue"},
        "preservedRules": {"roundCount": 40, "gemRewardRounds": list(range(5, 41, 5)),
                           "bossRounds": [10, 20, 30, 40], "bossCountPerBossRound": 1,
                           "allowedEnemyTypes": list(TYPES), "enemyKillGold": rewards,
                           "hpFormula": "baseHp * 2^((round - 1) / 10) * 1.15^(progressionOrdinal - 1)",
                           "progressionOrdinalRange": [6, 10],
                           "identityContract": "chapterStage and progressionOrdinal are design fields, not existing stage IDs; do not overwrite chapter-two IDs 6..10",
                           "unchanged": ["enemy speed", "damage/resistance/vulnerability rules", "core damage", "kill reward rules", "gem reward rules", "clearRewardGold", "rune reward rules"]},
        "stages": stages,
    }
    validate(proposal, source, rewards)
    return proposal, source, rewards


def validate(proposal, source, rewards):
    assert len(proposal["stages"]) == 5
    source_total = Counter()
    for wave in source:
        source_total.update(counts(wave["groups"]))
    assert source_total == Counter(normal=436, fast=259, tank=52, boss=4)
    assert sum(source_total.values()) == 751
    for stage in proposal["stages"]:
        total = Counter()
        assert [w["round"] for w in stage["rounds"]] == list(range(1, 41))
        for wave, base in zip(stage["rounds"], source):
            groups = wave["groups"]
            assert counts(groups) == counts(base["groups"])
            assert interval_inventory(groups) == interval_inventory(base["groups"])
            assert wave["clearRewardGold"] == base["clearRewardGold"]
            assert counts(groups)["boss"] == (1 if wave["round"] % 10 == 0 else 0)
            assert all(g["enemyType"] in TYPES and isinstance(g["count"], int) and g["count"] > 0
                       and math.isfinite(g["interval"]) and math.isfinite(g["startDelay"])
                       and g["interval"] > 0 and g["startDelay"] >= 0 for g in groups)
            assert same_queue(normalized_queue(groups), wave["spawnQueue"])
            spawn = [(q["delay"], q["enemyType"]) for q in wave["spawnQueue"]]
            assert len(spawn) == sum(counts(groups).values())
            assert Counter(t for _, t in spawn) == counts(groups)
            assert all(b[0] - a[0] >= 0.18 - 1e-8 for a, b in zip(spawn, spawn[1:]))
            # Absolute overlapping groups are flattened and sorted, never encoded as negative sequential waits.
            if wave["round"] <= 5:
                assert wave["spawnQueue"] == base["spawnQueue"]
            if wave["queueSource"] == "existing-id5-spawnQueue":
                assert wave["spawnQueue"] == base["spawnQueue"]
            total.update(counts(groups))
        assert total == source_total
        assert sum(rewards[k] * v for k, v in total.items()) == 4083
        assert sum(w["clearRewardGold"] for w in stage["rounds"]) == 2276


def fmt(value):
    return f"{number(value):.3f}".rstrip("0").rstrip(".")


def schedule(wave):
    names = {"normal": "일반", "fast": "빠름", "tank": "탱커", "boss": "보스"}
    return " → ".join(f"{names[g['enemyType']]} {g['count']} @ {fmt(g['startDelay'])}초 / {fmt(g['interval'])}초" for g in wave["groups"])


def render_readme(proposal, source, rewards):
    lines = ["# 챕터 1 신규 맵 1-6~1-10 라운드 설계", "",
             "역할: [확정 맵 배치](../maps.json)에 대응하는 5개 맵 × 40라운드 출현 설계안. 기존 룰을 유지하고 그룹의 순서·시작 시각만 바꾼다. 본게임 연결 상태는 [본게임 연결과 검증 범위](../../../godot/content/README.md#확장-진행과-고정-id)를 따른다.", "",
             "원본은 [rounds.json](rounds.json)이다. 전체 200개 라운드의 모든 출현 그룹을 명시한다. 이 README의 구성표와 예시는 같은 JSON에서 생성한다. [생성·검사 도구](generate_rounds.py)는 기존 콘텐츠 ID 5의 `groups`와 확정 맵을 읽어 이 폴더의 두 설계 파일만 갱신한다.", "",
             "```sh", "python3 design/chapter1_map_expansion/rounds/generate_rounds.py --check", "```", "",
             "## 유지하는 계약", "",
             "- 기준은 [현행 밸런스](../../../docs/gameplay_balance_reference.md)와 `godot/content/game_content.json`의 ID 5 웨이브다. 각 동일 라운드의 적 종류별 수량, 그룹 안의 출현 간격, 처치 골드와 `clearRewardGold`를 보존한다.",
             "- 일반·빠름·탱커·보스만 사용한다. 보호막병·장갑병·새 몹·새 기믹은 추가하지 않는다. 1~5라운드는 기존 ID 5 입문 구성과 시각을 그대로 쓴다.",
             "- 40라운드, 5라운드마다 기존 젬 보상, 10/20/30/40라운드마다 보스 정확히 1마리를 유지한다. 기존 이동속도·피해·저항·취약·코어 피해·성장·보상 규칙은 바꾸지 않는다.",
             "- HP는 `기본HP × 2^((round - 1) / 10) × 1.15^(progressionOrdinal - 1)`를 유지한다. 논리 진행 순번은 1-6부터 1-10까지 6~10이다. 실제 수치 200벌은 중복 저장하지 않는다.",
             "- `chapterStage`는 표시명, `progressionOrdinal`은 계산용 논리 순번이다. 기존 챕터 2의 고정 콘텐츠 ID 6~10과 다르다. 본게임 고정 ID는 16~20이며 기존 데이터를 덮어쓰지 않는다. 진행·저장 계약은 [본게임 연결과 검증 범위](../../../godot/content/README.md#확장-진행과-고정-id)를 따른다.",
             "- 맵당 적 751마리(일반 436 / 빠름 259 / 탱커 52 / 보스 4), 기본 처치 골드 4,083G + 기본 클리어 골드 2,276G = 6,359G다. 미처치·코어 도달과 업그레이드 보정은 이 합계에 포함하지 않는다.", "",
             "## 시각 표기", "",
             "`startDelay`는 포탈 준비 지연을 제외한 웨이브 시작 0초 기준 절대 요청 시각이다. 그룹의 i번째 적은 `startDelay + i × interval`을 요청한다(i=0부터). 아래 표의 `일반 3 @ 7.95초 / 1초`는 7.95·8.95·9.95초 요청을 뜻한다.", "",
             "출현 구간 길이와 마지막 출현 요청은 `(count - 1) × interval`로 계산한다. 그룹 간 휴지는 이전 그룹 마지막 요청부터 다음 그룹 첫 요청까지다. 전체 요청 이벤트를 시각 기준으로 안정 정렬한 뒤 `실제시각 = max(요청시각, 직전 실제시각 + 0.18초)`의 기존 정규화를 적용한다. 실행 기준은 JSON의 `spawnQueue`이며 그룹 안 간격은 기존 요청 간격을 보존한다. 겹친 이벤트의 실제 간격은 기존처럼 조금 밀릴 수 있다. 순차 delay가 필요하면 큐 시각 차를 사용하므로 음수가 생기지 않는다. 출현 구간의 겹침은 실제 경로 위 적의 겹침·추월을 보장하지 않는다.", "",
             "## 공통 40라운드 구성", "",
             "종류별 수량과 경제는 다섯 맵 모두 같다. 1~5는 실제 구성에 맞춰 복습형으로 표기했다(원본의 순환용 `previewText`를 그대로 옮기지 않음). 6부터 기준→러시→겹침→탱커→압축의 5라운드 순환이며, 10의 배수는 압축 대신 보스다.", "",
             "| R | 구성 | 일반 | 빠름 | 탱커 | 보스 | 기본 처치 G | 클리어 G | 젬 단계 |",
             "| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |"]
    for wave in proposal["stages"][0]["rounds"]:
        c = counts(wave["groups"])
        kill = sum(rewards[t] * c[t] for t in TYPES)
        lines.append(f"| {wave['round']} | {wave['label']} | {c['normal']} | {c['fast']} | {c['tank']} | {c['boss']} | {kill} | {wave['clearRewardGold']} | {'기존 보상' if wave['round'] % 5 == 0 else '—'} |")
    lines += ["", "## 맵별 출현 규칙과 운영 의도", "",
              "타입·보상을 늘리지 않고 확정 경로와 건설 구역에 대응할 여지를 만든다. 아래 공략은 설계 의도이며 포탑 사거리·타겟 선택·둔화·실제 배치로 아직 검증하지 않았다.", "",
              "| 맵 | 적용 범위 | 기존 대비 변경 | 운영 의도 |",
              "| --- | --- | --- | --- |",
              "| 1-6 돌아오는 초원길 | 러시 R7/12/17/22/27/32/37 | 빠름 1파 끝→2파 시작 휴지를 0.75초에서 2.2초로 늘림 | U자 외곽과 복귀 구간을 맡는 배치에서 두 파동을 따로 처리할 여지 |",
              "| 1-7 바위 사이 고갯길 | 탱커 R9/14/19/24/29/34/39 | 탱커 ceil(n/2)→일반→남은 탱커→빠름, 그룹 간 0.7초 | 분리된 전방·후방 건설 구역에 내구 압박을 두 번 나눠 배분 |",
              "| 1-8 굽이진 들판 | 겹침 R8/13/18/23/28/33/38 | 빠름 시작=일반 출현 구간 45%; 탱커가 있으면 빠름 시작+빠름 출현 구간 50% | 가까운 S자 경로 구간의 타겟 전환과 혼합 대열 대응 |",
              "| 1-9 마지막 직선 | 탱커 R9/14/19/24/29/34/39, 러시 R7/12/17/22/27/32/37 | 탱커형 마지막 빠름=일반 끝+2초; 러시 2파=빠름 1파 끝+2.5초 | 초반 굽이와 마지막 직선의 역할을 나눌 여지 |",
              "| 1-10 초원의 수호문 | R6~15→1-6, R16~25→1-7, R26~35→1-8, R36~39→1-9 | 구간 안의 해당 유형만 같은 변형 적용; R20/30/40 후속 일반만 2파동 분리 | 외곽·복귀·중앙 코어를 맡는 배치의 종합 확인 |", "",
              "모든 맵의 나머지 유형은 기존 출현 시각을 쓴다. 1-8의 45%는 빠른 적을 반드시 앞당기는 규칙이 아니다. 기존 시작 2.2초보다 늦추어 일반 대열 중간에 넣는 조정이며 후반 스탯 강화 의미가 없다. 탱커가 없는 R8/13에 새 탱커를 넣지 않는다. 보스 라운드는 위 구간 규칙보다 우선한다.", "",
              "## 보스 10/20/30/40라운드 예시", "",
              "1-6~1-9의 모든 보스와 1-10의 R10은 기존 ID 5 호위를 유지한다. 1-10 R20/30/40은 후속 일반 n을 ceil(n/2)와 나머지로 나누며, 첫 파동은 보스+0.9초, 둘째는 첫 일반 파동 마지막 출현+3초다. 일반의 기존 간격 1초는 보존한다.", "",
              "| 맵 | R | 출현 그룹(수량 @ 절대 시작 / 그룹 간격) |", "| --- | ---: | --- |"]
    for stage in (proposal["stages"][0], proposal["stages"][-1]):
        for wave in stage["rounds"]:
            if wave["round"] % 10 == 0:
                name = "1-6~1-9" if stage["chapterStage"] == "1-6" else "1-10"
                lines.append(f"| {name} | {wave['round']} | {schedule(wave)} |")
    lines += ["", "## 스폰 시각 검사와 검증 한계", "",
              "생성·검사는 기존 15스테이지 × 40라운드 = 600웨이브 전체를 기존 상대 그룹 지연까지 확장하고 0.18초 정규화를 적용해 기존 `spawnQueue` 재현을 확인한다. 신규 200라운드의 적 종류별 수량·요청 간격·보스 수·기본 경제를 원본과 대조하고, 유한 절대 시각·양수 간격·양수 수량·최종 큐의 0.18초 이상 간격을 확인한다. 변경하지 않는 라운드와 모든 1~5라운드는 원본 `spawnQueue`를 그대로 보존한다. 이 검사는 Godot 실행·게임플레이·Android 검증을 대신하지 않는다.", "",
              "변형으로 바뀌는 마지막 실제 출현 시각의 범위(해당 맵의 변형 라운드만, 원본 실행 큐 기준):", "",
              "| 맵 | 변경 라운드 수 | 마지막 출현 시각 차(초) |", "| --- | ---: | ---: |"]
    for stage in proposal["stages"]:
        deltas = [number(w["spawnQueue"][-1]["delay"] - b["spawnQueue"][-1]["delay"])
                  for w, b in zip(stage["rounds"], source) if w["queueSource"] != "existing-id5-spawnQueue"]
        lines.append(f"| {stage['chapterStage']} | {len(deltas)} | {fmt(min(deltas))} ~ {fmt(max(deltas))} |")
    lines += ["",
              "- 그룹 배열은 출현 시작 순서다. 이벤트로 정렬하면 겹침형의 일반·빠름·탱커가 서로 끼어든다. 배열의 앞 그룹이 끝날 때까지 기다리는 순차 구현으로 읽으면 설계와 달라진다.",
              "- 1-7 탱커 분할은 수량·요청 간격을 유지하지만 변형된 7개 라운드 모두 마지막 출현이 원본보다 0.55초 빠르다. 이를 전체 난이도 상승이라고 단정하지 않는다.",
              "- 1-6 러시의 2.2초, 1-9 러시의 2.5초·탱커형 후속 빠름의 2초, 1-10 후속 일반의 3초는 의도한 출현 휴지다. 실제 배치 전의 초기 설계값이며 전장에 적이 남아 있는 시간과 다르므로 파동 분리 효과·불필요한 전투 공백 여부는 실제 플레이에서 확인해야 한다.",
              "- 기존 ID 5 겹침형의 일부 실행 시각은 그룹 요청보다 최대 0.17초 늦다. 기존 0.18초 정규화로 전부 재현되는 차이다. 새 설계도 같은 규칙을 쓰며 별도 출현 기믹을 추가하지 않는다.",
              "- 빠른 적의 추월, 경로 재공격 가능 범위, 탱커 뒤 빠른 적 압박, 마지막 직선의 방어 여유, 보스 호위와의 실제 동시 체류는 미확인이다. 논리 출현 검사만 통과했다.",
              "- 이 생성·검사는 출현 설계의 정합성만 판정한다. 본게임 이식 및 저장·해금 검증은 [본게임 연결과 검증 범위](../../../godot/content/README.md#확장-진행과-고정-id)를 따르며, 실제 40라운드 체감 공략 검증과 구분한다.", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="validate generated files without rewriting")
    args = parser.parse_args()
    proposal, source, rewards = build()
    outputs = {HERE / "rounds.json": json.dumps(proposal, ensure_ascii=False, indent=2) + "\n",
               HERE / "README.md": render_readme(proposal, source, rewards)}
    for path, text in outputs.items():
        if args.check:
            if not path.exists() or path.read_text() != text:
                raise SystemExit(f"FAIL: regeneration required: {path.relative_to(ROOT)}")
        else:
            path.write_text(text)
    print("PASS: 5 maps × 40 rounds; 751 enemies/map; counts, intervals, bosses, delays, economy and generated README agree")


if __name__ == "__main__":
    main()
