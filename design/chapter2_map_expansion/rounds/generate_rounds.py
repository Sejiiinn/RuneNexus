#!/usr/bin/env python3
"""Generate a chapter-two map/round proposal without changing playable content."""

import argparse
from collections import Counter
from copy import deepcopy
import hashlib
import json
import math
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from stage_progression import stage_ordinals
CONTENT = ROOT / "godot/content/game_content.json"
GROWTH = ROOT / "godot/content/growth_content.json"
MAPS = HERE.parent / "maps.json"
TYPES = ("normal", "fast", "tank", "shielded", "shieldBoss")
NAMES = {"normal": "일반", "fast": "빠름", "tank": "탱커", "shielded": "보호막병", "shieldBoss": "보호막 보스"}
PATTERNS = {1: "보호막 2열·일반", 2: "빠름 선두", 3: "보호막 대열", 4: "일반·보호막 겹침", 0: "혼합"}
INTRO = ("보호막·일반 복습", "보호막·빠름 복습", "보호막 2열 복습", "일반·빠름·보호막 복습", "보호막·탱커 복습")
INTENTS = {
    "2-6": ("긴 무포탈 경로", "보호막 2열 사이 휴지, 빠름 선두의 2파동", "중앙 굽이와 후반 경로를 맡는 포탑의 대상 전환 여지"),
    "2-7": ("청색 포탈로 분리된 전·후반", "빠름 선두의 2파동, 보스 후속 일반의 2파동", "출구 뒤 화력과 전반 화력의 배분 여지"),
    "2-8": ("주황 포탈 출구 뒤 S형 교전", "보호막 대열의 빠름 투입 지연, 혼합형 후속 보호막 조기 투입", "출구 뒤 연속 대열의 타겟 전환 여지"),
    "2-9": ("중앙 건설띠가 평행 경로를 함께 담당", "보호막 2열의 후속 일반 조기 투입, 혼합형 후속 보호막 조기 투입", "중앙 집중 화력에서 서로 다른 방어 계위가 겹치는 압박"),
    "2-10": ("두 포탈의 세 교전 구간", "후속 일반 2파동, 보스 후속 일반 2파동, 보호막 대열의 빠름 투입 조정", "각 출구 대응과 후방 화력 비축의 종합 확인"),
}


def num(value):
    return round(value, 9)


def span(group):
    return (group["count"] - 1) * group["interval"]


def end(group):
    return group["startDelay"] + span(group)


def absolute_groups(groups):
    """Existing relative delays use the previous listed group's last requested spawn."""
    result = []
    previous_end = 0.0
    for original in groups:
        group = {key: original[key] for key in ("enemyType", "count", "interval", "startDelay")}
        if original.get("startAfterPrevious", False):
            group["startDelay"] = previous_end + original["followDelay"]
        previous_end = end(group)
        result.append(group)
    return result


def queue_for(groups):
    # Python's stable sort preserves group order and member order for equal times.
    events = sorted(((g["startDelay"] + i * g["interval"], g["enemyType"])
                     for g in groups for i in range(g["count"])), key=lambda event: event[0])
    queue = []
    previous = -0.18
    for requested, enemy_type in events:
        actual = num(max(requested, previous + 0.18))
        queue.append({"enemyType": enemy_type, "delay": actual})
        previous = actual
    return queue


def same_queue(first, second):
    return len(first) == len(second) and all(
        a["enemyType"] == b["enemyType"]
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
        result[(group["enemyType"], num(group["interval"]))] += group["count"]
    return result


def split(group, first_count, rest, start=None):
    assert 0 < first_count < group["count"]
    first, second = deepcopy(group), deepcopy(group)
    first["count"] = first_count
    second["count"] -= first_count
    if start is not None:
        first["startDelay"] = num(start)
    second["startDelay"] = num(end(first) + rest)
    return first, second


def wave_for(source, chapter_stage):
    round_number = source["round"]
    # Keep source float values: rounding a 0.774999... interval can reverse a
    # same-time tie in the existing stable sort (ID 10, R24).
    groups = absolute_groups(source["groups"])
    original = deepcopy(groups)
    pattern = "intro" if round_number <= 5 else "boss" if round_number % 10 == 0 else str(round_number % 5)
    note = "기존 ID 10의 그룹 수량·간격·출현 시각을 유지."
    if round_number <= 5:
        note = "기존 ID 10의 복습 라운드를 그룹·실행 큐·보상까지 그대로 유지."
    elif chapter_stage == "2-6":
        if pattern == "1":
            groups[1]["startDelay"] = num(end(groups[0]) + 1.0)
            note = "첫 보호막병 열의 마지막 출현 뒤 1초에 둘째 열 시작. 긴 경로의 대상 전환을 의도."
        elif pattern == "2":
            groups[:1] = split(groups[0], math.ceil(groups[0]["count"] / 2), 1.3)
            note = "빠름 선두를 2파동으로 나누고 첫 파동 마지막 출현 뒤 1.3초에 재개."
    elif chapter_stage == "2-7":
        if pattern == "2":
            groups[:1] = split(groups[0], math.ceil(groups[0]["count"] / 2), 1.6)
            note = "빠름 선두 2파동, 첫 파동 마지막 출현 뒤 1.6초 휴지. 두 교전 구역 대응 의도."
        elif pattern == "boss":
            groups[4:5] = split(groups[4], math.ceil(groups[4]["count"] / 2), 1.6)
            note = "보스 1마리 유지. 보스 뒤 일반을 2파동으로 분리하고 첫 파동 뒤 1.6초 휴지."
    elif chapter_stage == "2-8":
        if pattern == "3":
            groups[3]["startDelay"] = num(groups[1]["startDelay"] - 1.2)
            note = "빠름을 둘째 보호막병 열 직전부터 투입하여 출구 뒤 혼합 대열을 의도."
        elif pattern == "4":
            groups[3]["startDelay"] = num(groups[1]["startDelay"] + span(groups[1]) * 0.6)
            note = "후속 보호막병을 첫 보호막병 열의 60% 시점부터 겹쳐 보냄."
    elif chapter_stage == "2-9":
        if pattern == "1":
            groups[3]["startDelay"] = num(groups[1]["startDelay"] + span(groups[1]) * 0.6)
            note = "후속 일반을 둘째 보호막병 열의 60% 시점부터 겹쳐 보냄."
        elif pattern == "4":
            groups[3]["startDelay"] = num(groups[2]["startDelay"] + span(groups[2]) * 0.55)
            note = "후속 보호막병을 빠름 출현 구간의 55% 시점부터 겹쳐 보냄."
    elif chapter_stage == "2-10":
        if pattern == "1":
            groups[3:4] = split(groups[3], math.ceil(groups[3]["count"] / 2), 1.8)
            note = "후속 일반을 2파동으로 분리해 후방 화력 비축을 의도. 파동 사이 요청 휴지 1.8초."
        elif pattern == "3":
            groups[3]["startDelay"] = num(groups[1]["startDelay"] - 0.8)
            note = "빠름을 둘째 보호막병 열 직전부터 투입해 두 포탈 출구 대비를 의도."
        elif pattern == "boss":
            groups[4:5] = split(groups[4], math.ceil(groups[4]["count"] / 2), 1.8)
            note = "보스 1마리 유지. 보스 후속 일반을 2파동으로 나누고 첫 파동 뒤 1.8초 휴지."
    else:
        raise AssertionError(chapter_stage)
    unchanged = groups == original
    label = INTRO[round_number - 1] if pattern == "intro" else "보호막 보스" if pattern == "boss" else PATTERNS[int(pattern)]
    return {"round": round_number, "pattern": pattern, "label": label,
            "clearRewardGold": source["clearRewardGold"], "groups": groups,
            "spawnQueue": deepcopy(source["spawnQueue"]) if unchanged else queue_for(groups),
            "queueSource": "existing-id10-spawnQueue" if unchanged else "existing-0.18s-normalization",
            "designNote": note}


def source_contract(content):
    stages = content["stages"]
    ordinals = stage_ordinals()
    assert [stage["id"] for stage in stages] == list(range(1, 26))
    for stage in stages:
        assert [wave["round"] for wave in stage["waves"]] == list(range(1, 41))
        for wave in stage["waves"]:
            assert same_queue(queue_for(absolute_groups(wave["groups"])), wave["spawnQueue"]), (stage["id"], wave["round"])
            factor = 2 ** ((wave["round"] - 1) / 10) * 1.15 ** (ordinals[stage["id"]] - 1)
            for enemy_type, definition in content["enemyDefinitions"].items():
                durability = wave["enemyDurability"][enemy_type]
                for field in ("maxHp", "maxShield", "maxArmor"):
                    assert math.isclose(durability[field], definition[field] * factor, rel_tol=1e-8, abs_tol=1e-7), (stage["id"], wave["round"], enemy_type, field)


def validate(proposal, source, rewards):
    assert len(proposal["stages"]) == 5
    source_total = Counter()
    for wave in source:
        source_total.update(counts(wave["groups"]))
    assert source_total == Counter(normal=187, fast=260, tank=17, shielded=444, shieldBoss=4)
    assert sum(source_total.values()) == 912
    assert sum(rewards[t] * n for t, n in source_total.items()) == 6132
    assert sum(wave["clearRewardGold"] for wave in source) == 2276
    for stage in proposal["stages"]:
        changed_patterns = set()
        total = Counter()
        assert [wave["round"] for wave in stage["rounds"]] == list(range(1, 41))
        for wave, base in zip(stage["rounds"], source):
            groups, original = wave["groups"], absolute_groups(base["groups"])
            assert counts(groups) == counts(original), (stage["chapterStage"], wave["round"], "counts")
            assert interval_inventory(groups) == interval_inventory(original), (stage["chapterStage"], wave["round"], "intervals")
            assert wave["clearRewardGold"] == base["clearRewardGold"]
            assert counts(groups)["shieldBoss"] == (1 if wave["round"] % 10 == 0 else 0)
            assert all(g["enemyType"] in TYPES and type(g["count"]) is int and g["count"] > 0
                       and math.isfinite(g["startDelay"]) and math.isfinite(g["interval"])
                       and g["startDelay"] >= 0 and g["interval"] > 0 for g in groups)
            queue = wave["spawnQueue"]
            assert same_queue(queue_for(groups), queue), (stage["chapterStage"], wave["round"], "queue")
            assert len(queue) == sum(counts(groups).values())
            assert Counter(entry["enemyType"] for entry in queue) == counts(groups)
            assert all(math.isfinite(entry["delay"]) and entry["delay"] >= 0 for entry in queue)
            assert all(b["delay"] - a["delay"] >= 0.18 - 1e-8 for a, b in zip(queue, queue[1:]))
            if wave["round"] <= 5 or wave["queueSource"] == "existing-id10-spawnQueue":
                assert queue == base["spawnQueue"]
            if wave["round"] <= 5:
                assert groups == original
            if groups != original:
                changed_patterns.add(wave["pattern"])
            total.update(counts(groups))
        assert len(changed_patterns) >= 2, (stage["chapterStage"], changed_patterns)
        assert total == source_total
        assert sum(rewards[t] * n for t, n in total.items()) == 6132
        assert sum(w["clearRewardGold"] for w in stage["rounds"]) == 2276


def build():
    content = json.loads(CONTENT.read_text())
    growth = json.loads(GROWTH.read_text())
    source_contract(content)
    assert growth["rewardRounds"][:8] == list(range(5, 41, 5))
    assert len(growth["roundShardRewards"]) > 40
    maps = json.loads(MAPS.read_text())["maps"]
    assert [m["chapterStage"] for m in maps] == [f"2-{n}" for n in range(6, 11)]
    ordinals = stage_ordinals()
    assert [m["progressionOrdinal"] for m in maps] == [ordinals[stage_id] for stage_id in range(21, 26)]
    source = next(stage for stage in content["stages"] if stage["id"] == 10)["waves"]
    rewards = {key: content["enemies"][key]["rewardGold"] for key in TYPES}
    stages = [{"chapterStage": m["chapterStage"], "name": m["name"],
               "progressionOrdinal": ordinals[21 + offset],
               "rounds": [wave_for(wave, m["chapterStage"]) for wave in source]}
              for offset, m in enumerate(maps)]
    proposal = {
        "status": "proposal-round-design-only",
        "source": {"contentPath": "godot/content/game_content.json", "referenceStageId": 10,
                   "referenceChapterStage": "2-5", "mapPath": "design/chapter2_map_expansion/maps.json",
                   "growthPath": "godot/content/growth_content.json",
                   "contentSha256": hashlib.sha256(CONTENT.read_bytes()).hexdigest(),
                   "growthSha256": hashlib.sha256(GROWTH.read_bytes()).hexdigest(),
                   "mapsSha256": hashlib.sha256(MAPS.read_bytes()).hexdigest()},
        "timeConvention": {"startDelay": "absolute seconds from wave start, excluding portal startup delay",
                           "spawnTime": "startDelay + index * interval; index = 0..count-1",
                           "spawnSpan": "(count - 1) * interval; one enemy has zero span",
                           "groupRest": "next group's first requested spawn minus prior group's last requested spawn",
                           "spawnNormalization": "stable sort requested spawn times, then actualDelay = max(requestedDelay, previousActualDelay + 0.18)",
                           "queueAuthority": "spawnQueue is execution authority; groups retain requested within-group intervals",
                           "normalizationReferenceCheck": "all 25 stages x 40 rounds reproduce existing spawnQueue"},
        "preservedRules": {"roundCount": 40, "gemRewardRounds": list(range(5, 41, 5)),
                           "bossRounds": [10, 20, 30, 40], "bossType": "shieldBoss", "bossCountPerBossRound": 1,
                           "allowedEnemyTypes": list(TYPES), "enemyKillGold": rewards,
                           "durabilityFormula": "enemyDefinitions.maxHp/maxShield/maxArmor * 2^((round - 1) / 10) * 1.15^(progressionOrdinal - 1)",
                           "progressionOrdinalRange": [16, 20],
                           "identityContract": "chapterStage is a display label; progressionOrdinal comes from stage_progression.gd ORDER; fixed IDs are 21..25",
                           "unchanged": ["enemy speed", "self shield regeneration and shield-break behavior", "damage/resistance/vulnerability rules", "core damage", "kill rewards", "five-round gem reward cadence", "clearRewardGold", "rune reward rules", "portal preserves enemy HP/shield/status"]},
        "stages": stages,
    }
    validate(proposal, source, rewards)
    return proposal, source, rewards


def fmt(value):
    return f"{num(value):.3f}".rstrip("0").rstrip(".")


def schedule(wave):
    # Display by requested first-spawn time; JSON group order remains untouched
    # because equal-time event ordering depends on it.
    ordered = sorted(wave["groups"], key=lambda group: group["startDelay"])
    return " → ".join(f"{NAMES[g['enemyType']]} {g['count']} @ {fmt(g['startDelay'])}초 / {fmt(g['interval'])}초" for g in ordered)


def render_readme(proposal, source, rewards):
    lines = ["# 챕터 2 신규 맵 2-6~2-10 라운드 설계", "",
             "역할: [신규 맵 배치](../maps.json)에 대응하는 5개 맵 × 40라운드 출현 설계안. 본게임 연결 상태는 [본게임 연결과 검증 범위](../../../godot/content/README.md#확장-진행과-고정-id)를 따른다.", "",
             "원본은 [rounds.json](rounds.json)이다. 200개 라운드의 모든 출현 그룹과 실행 `spawnQueue`를 명시한다. 이 README의 표는 JSON에서 생성하며 [생성·검사 도구](generate_rounds.py)는 현행 콘텐츠 ID 10과 신규 맵을 읽어 이 폴더만 갱신한다.", "",
             "```sh", "python3 design/chapter2_map_expansion/rounds/generate_rounds.py --check", "```", "",
             "## 유지하는 계약", "",
             "- 기준은 `godot/content/game_content.json`의 기존 ID 10(챕터 2의 2-5 맵) 40라운드다. 동일 라운드의 적 종류별 수량·적 종류별 그룹 내 간격 재고·처치 골드·`clearRewardGold`를 유지한다. 1~5라운드는 적·수량·간격·절대 요청 시각과 실행 큐도 원본 그대로다(원본 상대 지연은 절대 시각으로 펼쳐 표기).",
             "- 일반·빠름·탱커·보호막병·`shieldBoss`만 사용한다. 40라운드와 5라운드마다 기존 젬 보상, 10/20/30/40라운드의 보호막 보스 정확히 한 마리를 유지한다. 포탈 발동은 맵의 타일과 경로에 따른다. 적 스탯·경제·피해식·새 몹·무적 구간·주변 보호 기능은 추가하지 않는다.",
             "- 보호막병은 자기 보호막만 재생한다(현행 초당 최대 보호막 4%). 보호막 보스도 현행 자기 보호막 규칙을 따른다. 보호막이 깨진 뒤 복구되지 않는 현재 계약을 유지한다. 과거 후보 문서의 코어 노출 phase는 사용하지 않는다.",
             "- 현행 소스의 모든 1,000웨이브 수치와 대조한 성장식은 `적 정의의 maxHp/maxShield/maxArmor × 2^((round-1)/10) × 1.15^(progressionOrdinal-1)`이다. 신규 순번 16~20의 내구도는 이 공식을 잇는다. 본게임 고정 ID 21~25의 수치는 연결 도구가 생성하며 저장·해금 계약은 [본게임 연결과 검증 범위](../../../godot/content/README.md#확장-진행과-고정-id)를 따른다. 전체 25맵에 `godot/content/stage_progression.gd`의 `ORDER` 순번을 적용한다. 기존 챕터 2·3도 같은 순번으로 내구도를 계산하며 맵·출현·보상은 보존한다.",
             "- 맵당 912마리(일반 187 / 빠름 260 / 탱커 17 / 보호막병 444 / 보호막 보스 4), 기본 처치 6,132G + 기본 클리어 2,276G = 8,408G다. 코어 도달·미처치·성장 보정은 합계에 넣지 않았다.", "",
             "## 출현 시각과 포탈", "",
             "`startDelay`는 웨이브 시작 0초의 절대 요청 시각이며 포탈 준비 지연을 제외한다. 그룹의 i번째 적은 `startDelay + i × interval`에 출현을 요청한다. 마지막 요청은 `(count-1) × interval` 뒤다. 그룹 사이 휴지는 이전 그룹 마지막 요청부터 다음 그룹 첫 요청까지다.", "",
             "모든 요청을 시각으로 안정 정렬해 `실제시각 = max(요청시각, 직전 실제시각 + 0.18초)`로 정규화한다. 동일 시각은 그룹 배열 순서가 유지된다. 실행 기준은 `spawnQueue`다. 겹친 그룹은 실제 시각이 0.18초 규칙 때문에 밀릴 수 있으며, 순차 구현에서는 큐의 시각 차를 사용한다.", "",
             "포탈은 같은 적을 즉시 지정된 IN→OUT으로 옮기며 HP·보호막·상태를 보존한다. 포탈 간 이동 자체에 전투 시간이 추가되지 않으므로 이동 중 재생·무적·추가 출현을 가정하지 않는다. 저격은 OUT에서도 사거리 안이면 조준 시간을 유지하고, 사거리 밖으로 나가면 재조준한다. 출구 뒤 전투 중에는 정상 시간이 흐르므로 남아 있는 보호막의 재생 가능성은 있지만, 아래 운영 의도는 실제 체류·타겟·사거리 결과로 아직 검증하지 않았다.", "",
             "## 공통 40라운드 구성", "",
             "| R | 구성 | 일반 | 빠름 | 탱커 | 보호막병 | 보호막 보스 | 기본 처치 G | 클리어 G | 젬 단계 |",
             "| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |"]
    for wave in proposal["stages"][0]["rounds"]:
        c = counts(wave["groups"])
        kill = sum(rewards[t] * c[t] for t in TYPES)
        lines.append(f"| {wave['round']} | {wave['label']} | {c['normal']} | {c['fast']} | {c['tank']} | {c['shielded']} | {c['shieldBoss']} | {kill} | {wave['clearRewardGold']} | {'기존 보상' if wave['round'] % 5 == 0 else '—'} |")
    lines += ["", "## 맵별 출현 변형", "",
              "각 맵의 경로와 건설 구역에 맞춘 운영 의도이며, 실제 적 체류·추월·포탑 사거리·저격 조준 유지 여부를 플레이로 확인한 결과는 아니다. 변형 없는 라운드는 ID 10의 실행 큐를 그대로 쓴다.", "",
              "| 맵 | 경로 단서 | 바꾼 유형 | 운영 의도 |", "| --- | --- | --- | --- |"]
    for stage in proposal["stages"]:
        topology, change, purpose = INTENTS[stage["chapterStage"]]
        lines.append(f"| {stage['chapterStage']} {stage['name']} | {topology} | {change} | {purpose} |")
    lines += ["", "- `2-6`은 R6/11/16/21/26/31/36 보호막 2열의 요청 휴지를 1초로 맞추고 R7/12/17/22/27/32/37 빠름 선두를 1.3초 휴지의 2파동으로 나눈다.",
              "- `2-7`은 빠름 선두를 1.6초 휴지의 2파동으로 나누고, R10/20/30/40의 후속 일반을 1.6초 휴지의 2파동으로 나눈다.",
              "- `2-8`은 R8/13/18/23/28/33/38의 빠름 시작을 둘째 보호막병 시작 1.2초 전으로 옮기고, R9/14/19/24/29/34/39의 마지막 보호막병을 첫 보호막병 출현 구간 60%부터 보낸다.",
              "- `2-9`는 R6/11/16/21/26/31/36의 후속 일반을 둘째 보호막병 출현 구간 60%부터 보내고, R9/14/19/24/29/34/39의 마지막 보호막병을 빠름 출현 구간 55%부터 보낸다.",
              "- `2-10`은 R6/11/16/21/26/31/36의 후속 일반을 1.8초 휴지의 2파동으로 나누고, R8/13/18/23/28/33/38의 빠름을 둘째 보호막병 시작 0.8초 전으로 옮긴다. 보스 라운드의 후속 일반도 1.8초 휴지의 2파동으로 나눈다.", "",
              "출현 휴지는 경로에서 적이 사라진 시간과 다르다. 포탈 전송은 즉시 일어나며 적의 보호막·상태를 바꾸지 않는다. 뒤 구역에서 두 파동이 분리되어 보이는지와 불필요한 전투 공백 여부는 인게임 검증이 필요하다.", "",
              "## 보스 라운드 예시", "",
              "모든 맵에서 `shieldBoss`는 한 마리다. 아래 그룹은 첫 요청 시각순으로 표기하며 화살표는 앞 그룹이 끝날 때까지 기다린다는 뜻이 아니다. 같은 시각의 실제 이벤트 순서는 JSON 원본 그룹 배열을 유지한다. 아래 시각은 포탈 이동 시각이 아니라 적의 최초 출현 요청 시각이다.", "",
              "| 맵 | R | 출현 그룹(수량 @ 절대 시작 / 그룹 간격) |", "| --- | ---: | --- |"]
    for stage in (proposal["stages"][0], proposal["stages"][1], proposal["stages"][-1]):
        for wave in stage["rounds"]:
            if wave["round"] in (10, 40):
                lines.append(f"| {stage['chapterStage']} | {wave['round']} | {schedule(wave)} |")
    lines += ["", "## 자동 검사와 한계", "",
              "`--check`는 현행 25스테이지 × 40라운드 = 1,000웨이브의 상대 `followDelay`를 절대 시각으로 펼쳐 기존 실행 큐를 재현하고, HP·보호막·방어구 성장식을 전체 원본 수치와 대조한다. 신규 200라운드는 각 라운드의 유형·수량·그룹 내 간격 재고·보상, 보스 정확히 한 마리, 1~5라운드 원본 동일, 양수·유한 시각, 최종 큐 0.18초 간격, 맵별 둘 이상 유형 변형과 누적 경제를 검사한다. 기존 `growth_content.json`의 5라운드 보상 일정도 확인하며, 콘텐츠·성장·맵 SHA와 JSON/README 재생성 일치도 검사한다.", "",
              "이 검사는 설계 데이터의 정합성이다. 포탑 배치·체감 난이도·실제 전투 공백의 전체 플레이 검증과 구분한다. 본게임 연결·전송·저장 검증 범위는 [본게임 연결과 검증 범위](../../../godot/content/README.md#확장-진행과-고정-id)를 따른다.", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate source and compare committed outputs")
    args = parser.parse_args()
    proposal, source, rewards = build()
    json_text = json.dumps(proposal, ensure_ascii=False, indent=2) + "\n"
    readme_text = render_readme(proposal, source, rewards)
    for path, expected in ((HERE / "rounds.json", json_text), (HERE / "README.md", readme_text)):
        if args.check:
            assert path.read_text() == expected, f"stale generated file: {path}"
        else:
            path.write_text(expected)
    print("PASS: 1000 current waves; 200 proposed rounds; source, maps, queues, economy and README" if args.check else "Generated 200 proposed rounds and README")


if __name__ == "__main__":
    main()
