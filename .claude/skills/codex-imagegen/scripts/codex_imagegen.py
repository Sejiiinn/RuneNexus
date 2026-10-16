#!/usr/bin/env python3
"""Codex CLI(구독 계정)의 내장 image_gen 도구로 이미지를 생성해 지정 경로에 복사한다.

예:
  codex_imagegen.py --out design/foo/rune-icon.png --prompt "..."
  codex_imagegen.py --out design/foo/rune-icon.png --prompt-file prompt.txt \
      --ref assets/images/ui/hud/resource_runic_panel.png --transparent --count 2
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

# 사용자 지정: 이미지 생성 호출은 항상 이 모델로 실행한다.
MODEL = "gpt-6.1-sol"
CODEX_HOME = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp"}


def build_prompt(args: argparse.Namespace, prompt: str) -> str:
    lines = [
        "Use your built-in image_gen tool (imagegen skill, built-in mode only; never the CLI fallback).",
        f"Generate exactly {args.count} image(s) in total."
        + (" Each one is a separate variant of the same request." if args.count > 1 else ""),
        "Do not write code, run scripts, create, move, or edit any files. "
        "When finished, reply with only the saved image path(s), one per line.",
    ]
    if args.edit:
        lines.append(
            "The first attached image is the EDIT TARGET: modify it as requested and preserve everything not mentioned."
        )
    if args.ref:
        first = 2 if args.edit else 1
        idx = ", ".join(str(first + i) for i in range(len(args.ref)))
        lines.append(
            f"Attached image(s) #{idx} are REFERENCES for style/composition/mood only; do not copy them literally."
        )
    if args.transparent:
        lines.append("The output must have a genuinely transparent background (real alpha channel).")
    lines += ["", "Image request:", prompt.strip()]
    return "\n".join(lines)


def image_info(path: Path) -> dict:
    info: dict = {"bytes": path.stat().st_size}
    try:
        out = subprocess.run(
            ["sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", str(path)],
            capture_output=True, text=True, check=True,
        ).stdout
        for line in out.splitlines()[1:]:
            key, _, value = line.strip().partition(": ")
            info[key] = int(value) if value.isdigit() else value
    except (OSError, subprocess.CalledProcessError):
        pass
    return info


def output_paths(out: Path, count: int) -> list[Path]:
    if count == 1:
        return [out]
    return [out.with_name(f"{out.stem}-v{i}{out.suffix}") for i in range(1, count + 1)]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    src = parser.add_mutually_exclusive_group(required=True)
    src.add_argument("--prompt", help="이미지 요청 프롬프트")
    src.add_argument("--prompt-file", type=Path, help="프롬프트 텍스트 파일")
    parser.add_argument("--out", type=Path, required=True, help="저장 경로(.png). --count>1이면 -v1, -v2… 접미사")
    parser.add_argument("--ref", type=Path, action="append", default=[], help="스타일·구도 참고 이미지(반복 가능)")
    parser.add_argument("--edit", type=Path, help="수정 대상 이미지")
    parser.add_argument("--transparent", action="store_true", help="투명 배경 요청")
    parser.add_argument("--count", type=int, default=1, help="변형 개수(기본 1)")
    parser.add_argument("--force", action="store_true", help="기존 파일 덮어쓰기 허용")
    parser.add_argument("--timeout", type=int, default=900, help="Codex 실행 제한 시간(초)")
    args = parser.parse_args()

    if args.count < 1:
        parser.error("--count는 1 이상이어야 합니다")
    prompt = args.prompt if args.prompt is not None else args.prompt_file.read_text(encoding="utf-8")
    attachments = ([args.edit] if args.edit else []) + args.ref
    for p in attachments:
        if not p.is_file():
            parser.error(f"첨부 이미지가 없습니다: {p}")
    targets = [p.resolve() for p in output_paths(args.out, args.count)]
    existing = [str(p) for p in targets if p.exists()]
    if existing and not args.force:
        parser.error("이미 존재하는 파일(덮어쓰려면 --force): " + ", ".join(existing))

    # 프로젝트 AGENTS.md·저장소를 Codex가 읽지 않도록 빈 임시 디렉터리에서 실행한다.
    workdir = Path(tempfile.mkdtemp(prefix="codex-imagegen-"))
    cmd = ["codex", "exec", "-m", MODEL, "-s", "read-only", "--skip-git-repo-check",
           "--ephemeral", "--json", "-C", str(workdir)]
    for p in attachments:
        cmd += ["-i", str(p.resolve())]
    cmd += ["--", build_prompt(args, prompt)]

    started = time.time()
    try:
        proc = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=args.timeout)
    except subprocess.TimeoutExpired:
        print(json.dumps({"ok": False, "error": f"timeout after {args.timeout}s"}, ensure_ascii=False))
        return 1
    finally:
        shutil.rmtree(workdir, ignore_errors=True)
    elapsed = round(time.time() - started, 1)

    thread_id, messages, errors, usage = None, [], [], None
    for line in proc.stdout.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        kind = event.get("type")
        if kind == "thread.started":
            thread_id = event.get("thread_id")
        elif kind == "turn.completed":
            usage = event.get("usage")
        elif kind in ("turn.failed", "error"):
            errors.append(event.get("error") or event.get("message") or event)
        elif kind == "item.completed":
            item = event.get("item", {})
            if item.get("type") == "agent_message":
                messages.append(item.get("text", ""))
            elif item.get("type") == "error" and "unrecognized configuration" not in item.get("message", "") \
                    and "Under-development features" not in item.get("message", ""):
                errors.append(item.get("message"))

    generated: list[Path] = []
    if thread_id:
        folder = CODEX_HOME / "generated_images" / thread_id
        if folder.is_dir():
            generated = sorted((p for p in folder.iterdir() if p.suffix.lower() in IMAGE_SUFFIXES),
                               key=lambda p: p.stat().st_mtime)

    summary = {
        "ok": False, "model": MODEL, "thread_id": thread_id, "elapsed_sec": elapsed,
        "codex_exit": proc.returncode, "requested": args.count, "generated": len(generated),
        "usage": usage, "codex_reply": "\n".join(messages).strip(),
    }
    if proc.returncode != 0 or not generated:
        summary["errors"] = errors or [proc.stderr.strip()[-2000:]]
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return 1

    outputs = []
    for src_path, dst in zip(generated[-args.count:], targets):
        if dst.suffix.lower() != src_path.suffix.lower():
            dst = dst.with_suffix(src_path.suffix)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src_path, dst)
        outputs.append({"path": str(dst), "source": str(src_path), **image_info(dst)})
    summary.update(ok=len(outputs) == args.count, outputs=outputs)
    if errors:
        summary["warnings"] = errors
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0 if summary["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
