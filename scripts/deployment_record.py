#!/usr/bin/env python3
"""배포 기록 정리: 배포 상태 문서의 직전 앱·서버 기록을 이력 문서 맨 위로 옮긴다.

archive app|server  같은 구성 요소의 기존 절을 이력으로 옮긴다(새 기록을 쓰기 전에 실행).
                    상대 링크는 docs/archive/ 기준으로 고친다.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
STATUS = ROOT / "docs/deployment_status.md"
HISTORY = ROOT / "docs/archive/deployment_history_godot.md"
KINDS = {"app": re.compile(r"^## \d{4}-\d{2}-\d{2} Android "), "server": re.compile(r"^## \d{4}-\d{2}-\d{2} 서버")}
LINK = re.compile(r"\]\((?!https?:|#|mailto:)([^)\s]+)\)")


def sections(text):
    """머리말과 '## ' 절 목록으로 나눈다."""
    parts = re.split(r"(?m)^(?=## )", text)
    return parts[0], parts[1:]


def archive(kind, status=STATUS, history=HISTORY):
    head, parts = sections(status.read_text())
    moved = [part for part in parts if KINDS[kind].match(part)]
    if not moved:
        raise SystemExit(f"No {kind} record in {status.name}")
    kept = [part for part in parts if part not in moved]
    status.write_text(head + "".join(kept))
    history_head, history_parts = sections(history.read_text())
    relinked = [LINK.sub(lambda m: f"](../{m.group(1)})", part).rstrip() + "\n\n" for part in moved]
    history.write_text(history_head + "".join(relinked) + "".join(history_parts))
    for part in moved:
        print("archived:", part.splitlines()[0])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("archive").add_argument("kind", choices=sorted(KINDS))
    args = parser.parse_args(argv)
    archive(args.kind)


if __name__ == "__main__":
    main()
