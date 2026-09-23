"""Summarize Godot GUI benchmark samples without altering the raw record."""

from collections import defaultdict
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
data = json.loads((OUT / "raw.json").read_text())


def percentile(values, fraction):
    ordered = sorted(values)
    return ordered[max(0, min(len(ordered) - 1, int(len(ordered) * fraction + 0.999999) - 1))]


def metric(samples, key, positive=False):
    values = [float(row[key]) for row in samples if key in row and (not positive or float(row[key]) > 0)]
    if not values:
        return None
    return {"p50": round(percentile(values, 0.50), 3),
            "p95": round(percentile(values, 0.95), 3),
            "p99": round(percentile(values, 0.99), 3),
            "mean": round(sum(values) / len(values), 3),
            "valid_samples": len(values)}


trials = []
for trial in data["trials"]:
    samples = trial["samples"]
    item = {"pass": trial["pass"], "condition": trial["condition"], "frames": len(samples)}
    for key in ("interval_ms", "process_ms", "render_cpu_ms", "render_gpu_ms",
                "frame_setup_cpu_ms", "draw_calls", "reported_primitives"):
        item[key] = metric(samples, key, key in ("render_cpu_ms", "render_gpu_ms", "frame_setup_cpu_ms"))
    trials.append(item)

by_condition = defaultdict(list)
for trial in trials:
    by_condition[trial["condition"]].append(trial)
summary = {"metadata": data["metadata"], "trials": trials, "conditions": {}}
for condition, repeats in by_condition.items():
    summary["conditions"][condition] = {
        "repeats": len(repeats),
        "frames": sum(row["frames"] for row in repeats),
        "trial_median_range": {
            key: [min(row[key]["p50"] for row in repeats if row[key]),
                  max(row[key]["p50"] for row in repeats if row[key])]
            if all(row[key] for row in repeats) else None
            for key in ("interval_ms", "process_ms", "render_cpu_ms", "render_gpu_ms",
                        "frame_setup_cpu_ms", "draw_calls", "reported_primitives")
        },
        "trial_p95_interval_ms": [row["interval_ms"]["p95"] for row in repeats],
        "trial_p99_interval_ms": [row["interval_ms"]["p99"] for row in repeats],
    }
(OUT / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")

def cell(condition, key):
    rng = summary["conditions"][condition]["trial_median_range"][key]
    return "미측정" if rng is None else f"{rng[0]:.3f}–{rng[1]:.3f}"


lines = [
    "# Godot 데스크톱 냉각 안개 성능 측정",
    "",
    "Apple M4 / Godot 4.7.2 / Metal Forward Mobile / 1100×800 GUI 렌더. VSync 해제, 최대 FPS 제한 0, 직교 카메라 크기 9.5. 승인된 시안 씬·셰이더·GLB를 격리 프로젝트에 복사해 사용했다. 배경·포탑·적 위치는 고정하고 안개 복제 노드의 수와 위치만 바꿨다.",
    "",
    "조건마다 1초 워밍업 후 3초·300프레임 이상 수집했고 정방향과 역방향으로 1회씩 측정했다. 다음 값은 각 회차의 nearest-rank 중앙값 범위다. 시간 열은 ms, draw·primitive는 건수다. 프레임 간격 p95/p99도 nearest-rank 방식으로 아래에 별도 표시했다.",
    "",
    "| 조건 | 프레임 간격 | viewport 렌더 CPU | viewport GPU | setup CPU | draw | 엔진 보고 primitive |",
    "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
]
for condition in data["trials"][:7]:
    name = condition["condition"]
    lines.append("| " + name + " | " + " | ".join(cell(name, key) for key in (
        "interval_ms", "render_cpu_ms", "render_gpu_ms",
        "frame_setup_cpu_ms", "draw_calls", "reported_primitives")) + " |")
lines += ["", "프레임 간격 꼬리값 (정방향/역방향):", ""]
for condition in data["trials"][:7]:
    name = condition["condition"]
    s = summary["conditions"][name]
    lines.append(f"- `{name}`: p95 {s['trial_p95_interval_ms']}, p99 {s['trial_p99_interval_ms']} ms; {s['frames']} frames")
lines += [
    "",
    "안개 1개는 MultiMesh 32 인스턴스 × 메시당 576삼각형 = 실제 18,432삼각형이다. 4개와 8개는 각각 73,728·147,456삼각형이다. 엔진 primitive 통계는 MultiMesh 인스턴스 곱을 누락하므로 이 값과 직접 비교하지 않는다.",
    "",
    "이 측정은 동일 장면에서 다중 **안개**의 국소 비용을 비교한다. 다중 포탑/전투 전체나 Android 실기기 FPS를 뜻하지 않는다. age 0.5는 방출 중간의 고정 상태로 실제 최대 부하 시점을 탐색한 값은 아니다. 분산 배치의 8개는 대표 화면에서 모두 화면 안에 있음을 확인했다. 광원 OFF/ON은 충전 셰이더를 똑같이 1.0으로 두고 무그림자 OmniLight energy만 0/0.65로 바꾼 조건이다.",
    "",
    "VSync 모드 0(해제), Engine.max_fps 0으로 확인됐지만 표본은 약 144fps로 진행되어 화면 표시 주기나 다른 제한의 영향을 받았을 수 있다. 기존 Godot 플레이·편집 프로세스가 동시에 실행 중이었으며 사용자 세션은 보존했다. `Performance.TIME_PROCESS`는 원시 프레임마다 기록했지만 약 1초에 한 번만 갱신되어 프레임별 CPU 분포로 볼 수 없어 표에서 제외했다. viewport 렌더 CPU와 frame setup CPU도 별도 엔진 지표이며 합산하지 않았다. 프레임 간격은 GPU 완료 시간과 동일하지 않다. viewport GPU API는 존재하지만 모든 값이 0이어서 GPU 시간은 미측정으로 처리했다. 작은 차이는 이 2회 측정만으로 유의하다고 판단하지 않는다. 하네스에는 조건 전환·표본 버퍼 기록 부하가 있고 이미지 저장은 표본 수집 밖에서 수행했다. 본 시안의 경량 구조는 안개 1개당 1 draw/shared mesh/노이즈 2샘플/CPU age 업데이트뿐이다.",
    "",
    "## 재현",
    "",
    "저장소 루트에서 아래 순서로 실행한다. 마지막 명령만 실제 GUI 렌더이며 headless FPS는 사용하지 않는다.",
    "",
    "```sh",
    "python3 design/frost_tower_concepts/2026-09-23/charge-mist-concept/performance/prepare_benchmark.py",
    "build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --editor --path build/godot/frost-charge-benchmark --import --quit",
    "build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --path build/godot/frost-charge-benchmark --resolution 1100x800",
    "python3 design/frost_tower_concepts/2026-09-23/charge-mist-concept/performance/summarize.py",
    "```",
    "",
    "원시 표본은 [raw.json](raw.json), 집계는 [summary.json](summary.json), 화면 예시는 [중첩](mist_8_overlap.png)·[분산](mist_8_spread.png)이다.",
]
(OUT / "report.md").write_text("\n".join(lines) + "\n")
