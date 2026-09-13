#!/usr/bin/env python3
"""Reassemble RN_AB chunks and compare two complete release measurement runs.

Usage: python3 compare_logs.py baseline.log optimized.log [--output-dir DIR]
Only complete START/CONT/END records are accepted. Legacy RN_AB lines are ignored.
No dependencies beyond Python's standard library.
"""

import argparse
import json
import math
from pathlib import Path
import re
import statistics
import sys


PHASES = ("stage10_idle", "stage10_cannon4x")
CHUNK = re.compile(r"\bRN_AB_CHUNK (START|CONT) (.*)$")
END = re.compile(r"\bRN_AB_END\s*$")
WEIGHTED = {
    "apply_frame_ms": "profile_apply_samples",
    "json_parse_ms": "profile_parse_samples",
    "render_cpu_ms": "profile_render_samples",
    "render_gpu_ms": "profile_render_samples",
}
RESOURCES = ("draw_calls", "primitives", "objects", "texture_memory", "video_memory")


def read_records(path):
    records, chunks = [], None
    start_line = 0
    for line_number, line in enumerate(path.read_text().splitlines(), 1):
        match = CHUNK.search(line)
        if match:
            kind, payload = match.groups()
            if kind == "START":
                if chunks is not None:
                    raise ValueError(f"{path}:{line_number}: previous START has no END")
                chunks, start_line = [payload], line_number
            else:
                if chunks is None:
                    raise ValueError(f"{path}:{line_number}: CONT without START")
                chunks.append(payload)
        elif END.search(line):
            if chunks is None:
                raise ValueError(f"{path}:{line_number}: END without START")
            try:
                record = json.loads("".join(chunks))
            except json.JSONDecodeError as error:
                raise ValueError(f"{path}:{start_line}: incomplete/invalid JSON: {error}") from error
            if not isinstance(record, dict):
                raise ValueError(f"{path}:{start_line}: JSON record must be an object")
            records.append(record)
            chunks = None
    if chunks is not None:
        raise ValueError(f"{path}:{start_line}: incomplete record at EOF")
    if not records:
        raise ValueError(f"{path}: no complete chunk records; legacy/truncated RN_AB is not accepted")
    return records


def number(value, label):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError(f"{label}: expected a finite number, got {value!r}")
    return value


def percentile(values, fraction):
    ordered = sorted(values)
    return ordered[max(0, math.ceil(len(ordered) * fraction) - 1)]


def summarize(records, variant, expected_samples):
    if any(record.get("variant") != variant for record in records):
        raise ValueError(f"{variant}: record variant mismatch")
    result = {}
    for phase in PHASES:
        phase_records = [record for record in records if record.get("phase") == phase]
        samples = [record["metrics"] for record in phase_records if record.get("event") == "sample"]
        ends = [record for record in phase_records if record.get("event") == "end"]
        begins = [record for record in phase_records if record.get("event") == "begin"]
        if len(samples) != expected_samples or len(ends) != 1 or len(begins) != 1:
            raise ValueError(
                f"{variant}/{phase}: expected 1 begin, {expected_samples} samples, 1 end; "
                f"got {len(begins)}, {len(samples)}, {len(ends)}"
            )
        if phase_records[0].get("event") != "begin" or phase_records[-1].get("event") != "end":
            raise ValueError(f"{variant}/{phase}: begin/end order invalid")
        window_ids = [sample.get("profile_window_id") for sample in samples]
        if None in window_ids or len(set(window_ids)) != len(window_ids):
            raise ValueError(f"{variant}/{phase}: missing/duplicate profiling window")
        intervals = []
        for sample in samples:
            raw = sample.get("frame_intervals_ms")
            if not isinstance(raw, list) or not raw:
                raise ValueError(f"{variant}/{phase}: missing raw frame intervals")
            if sample.get("profile_frame_samples") != len(raw):
                raise ValueError(f"{variant}/{phase}: raw interval count mismatch")
            for value in raw:
                if number(value, "frame interval") <= 0:
                    raise ValueError("frame interval must be positive")
            intervals.extend(raw)
        total_ms = sum(intervals)
        row = {
            "metric_samples": len(samples),
            "profile_window_ids": window_ids,
            "interval_count": len(intervals),
            "interval_total_ms": total_ms,
            "measured_fps": len(intervals) * 1000 / total_ms,
            "frame_interval_mean_ms": statistics.mean(intervals),
            "frame_interval_p50_ms": percentile(intervals, .50),
            "frame_interval_p95_ms": percentile(intervals, .95),
            "frame_interval_p99_ms": percentile(intervals, .99),
            "frame_interval_max_ms": max(intervals),
            "weighted_sample_counts": {},
        }
        for metric, weight_key in WEIGHTED.items():
            numerator = denominator = 0
            for sample in samples:
                weight = number(sample.get(weight_key), weight_key)
                if weight < 0 or int(weight) != weight:
                    raise ValueError(f"{weight_key}: expected nonnegative integer")
                if weight:
                    numerator += number(sample.get(metric), metric) * weight
                    denominator += weight
            row[metric] = numerator / denominator if denominator else None
            row["weighted_sample_counts"][metric] = denominator
        row["gpu_timing_supported"] = any(sample.get("render_gpu_ms", 0) > 0 for sample in samples)
        if not row["gpu_timing_supported"]:
            row["render_gpu_ms"] = None
        for metric in RESOURCES:
            row[metric] = statistics.mean(number(sample.get(metric), metric) for sample in samples)
        row["end_summaries"] = {
            key: value for key, value in ends[0].items()
            if key not in ("variant", "event", "phase")
        }
        for key in ("game_update_us", "flutter_build_us", "flutter_raster_us"):
            summary = row["end_summaries"].get(key)
            if not isinstance(summary, dict) or number(summary.get("samples"), key) <= 0:
                raise ValueError(f"{variant}/{phase}: missing/empty {key} end summary")
            for stat in ("mean", "p50", "p95", "p99", "max"):
                number(summary.get(stat), f"{key}.{stat}")
        result[phase] = row
    return result


def delta(before, after):
    return {
        "baseline": before,
        "optimized": after,
        "delta": after - before if before is not None and after is not None else None,
        "delta_percent": (after / before - 1) * 100 if before and after is not None else None,
    }


def comparisons(baseline, optimized):
    result = {}
    for phase in PHASES:
        before, after = baseline[phase], optimized[phase]
        metrics = [
            "measured_fps", "frame_interval_mean_ms", "frame_interval_p50_ms",
            "frame_interval_p95_ms", "frame_interval_p99_ms", "frame_interval_max_ms",
            *WEIGHTED, *RESOURCES,
        ]
        row = {metric: delta(before[metric], after[metric]) for metric in metrics}
        for key in ("game_update_us", "flutter_build_us", "flutter_raster_us"):
            for stat in ("mean", "p50", "p95", "p99", "max"):
                row[f"{key}.{stat}"] = delta(
                    before["end_summaries"][key][stat], after["end_summaries"][key][stat]
                )
        result[phase] = row
    return result


def markdown(report):
    lines = [
        "# Godot 최적화 A/B 로그 집계", "",
        "분할 로그의 완성된 JSON만 사용한다. 프레임 간격은 모든 원시 표본을 합친 뒤 "
        "nearest-rank p50/p95/p99를 계산한다. FPS는 표본 수 × 1000 / 간격 합(ms)이다.", "",
        "apply/json/render는 해당 프로파일 표본 수로 가중 평균한다. draw/primitives/메모리는 "
        "측정 창별 값의 산술 평균이다. 변화율은 (개선본/기준본 − 1) × 100이며 FPS 외에는 "
        "대체로 음수가 감소를 뜻한다. GPU timing이 모두 0이면 미지원으로 표시한다.", "",
    ]
    for phase in PHASES:
        before, after = report["baseline"][phase], report["optimized"][phase]
        lines.extend([
            f"## {phase}", "",
            f"기준/개선 측정 창: {before['metric_samples']}/{after['metric_samples']}; "
            f"원시 간격 수: {before['interval_count']}/{after['interval_count']}; "
            f"표본 시간: {before['interval_total_ms'] / 1000:.3f}/{after['interval_total_ms'] / 1000:.3f}초.", "",
            "| 지표 | 기준 | 개선 | 차이 | 변화율 |",
            "| --- | ---: | ---: | ---: | ---: |",
        ])
        for metric, values in report["comparison"][phase].items():
            def display(value):
                return "미지원/없음" if value is None else f"{value:,.3f}"
            pct = values["delta_percent"]
            lines.append(
                f"| {metric} | {display(values['baseline'])} | {display(values['optimized'])} "
                f"| {display(values['delta'])} | {'—' if pct is None else f'{pct:+.2f}%'} |"
            )
        lines.extend(["", "메모리 단위는 bytes, `_ms`는 ms, `_us`는 µs이다. "
                      "Flutter/game 끝 요약의 분위수는 원래 요약 값을 비교하며 Godot 간격과 합치지 않는다.", ""])
    lines.extend([
        "이 결과는 에뮬레이터의 release 격리 패키지에서 actual GameHud/MemorySave로 측정한 "
        "두 실행의 비교다. 실기기 성능, 전체 앱 서비스 부하, GPU 비용을 대표하지 않는다.", "",
    ])
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("optimized", type=Path)
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--expected-samples", type=int, default=15)
    args = parser.parse_args()
    if args.expected_samples <= 0:
        parser.error("--expected-samples must be positive")
    try:
        baseline = summarize(read_records(args.baseline), "baseline", args.expected_samples)
        optimized = summarize(read_records(args.optimized), "optimized", args.expected_samples)
    except (ValueError, KeyError, TypeError, OSError) as error:
        parser.exit(1, f"측정 로그 오류: {error}\n")
    report = {
        "sources": {"baseline": str(args.baseline.resolve()), "optimized": str(args.optimized.resolve())},
        "method": {
            "percentile": "nearest-rank of pooled raw frame_intervals_ms",
            "fps": "len(raw intervals) * 1000 / sum(raw intervals in ms)",
            "timing_weights": WEIGHTED,
            "resources": "arithmetic mean across metric windows",
            "gpu_zero": "unsupported; never interpreted as zero GPU work",
        },
        "baseline": baseline,
        "optimized": optimized,
        "comparison": comparisons(baseline, optimized),
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for name, content in (
        ("comparison.json", json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + "\n"),
        ("comparison.md", markdown(report)),
    ):
        target = args.output_dir / name
        target.write_text(content)
        print(target)


if __name__ == "__main__":
    main()
