"""앱 공개·서버 반영 대상 커밋의 검사 CI 통과를 강제한다.

대상에서 가장 가까운, 검사 CI가 실행된 커밋으로 판정한다. 그 뒤의 변경이 모두
paths-ignore 대상일 때만 그 결과를 쓴다. 실행 중·실패·취소·기록 없음은 전부 거부한다.
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ".github/workflows/checks.yml"


def sh(*args):
    return subprocess.run(args, cwd=ROOT, check=True, text=True, capture_output=True).stdout.strip()


def ignored_paths(workflow: str) -> list[re.Pattern]:
    """워크플로의 paths-ignore 글롭을 전체 경로 일치 정규식으로 바꾼다."""
    block = workflow[workflow.index("paths-ignore:"):workflow.index("workflow_dispatch:")]
    patterns = []
    for glob in re.findall(r"- '([^']+)'", block):
        escaped = re.escape(glob).replace(r"/\*\*/", "/(?:.*/)?").replace(r"/\*\*", "/.*").replace(r"\*", "[^/]*")
        patterns.append(re.compile(escaped))
    return patterns


def nearest_checked(commits: list[str], runs: list[dict]) -> tuple[str | None, list[dict]]:
    """commits는 대상부터 과거 순이다."""
    for commit in commits:
        matched = [run for run in runs if run["headSha"] == commit]
        if matched:
            return commit, matched
    return None, []


def refusal(base: str | None, runs: list[dict], changed: list[str], ignored: list[re.Pattern]) -> str | None:
    """대상을 내보낼 수 없는 이유, 없으면 None."""
    if base is None:
        return "no Checks run found for this commit or its history"
    unchecked = [path for path in changed if not any(pattern.fullmatch(path) for pattern in ignored)]
    if unchecked:
        return f"{len(unchecked)} changed files after the last checked commit {base[:8]}, e.g. {unchecked[0]}"
    if any(run["conclusion"] == "success" for run in runs):
        return None
    if any(run["status"] != "completed" for run in runs):
        return f"Checks still running at {base[:8]}; wait for it"
    return f"Checks did not pass at {base[:8]} ({runs[0]['conclusion']})"


def require_checks(sha: str) -> str:
    """통과한 검사 CI의 커밋을 돌려주고, 아니면 종료한다."""
    runs = json.loads(sh("gh", "run", "list", "--workflow", Path(WORKFLOW).name, "--branch", "main",
                         "--limit", "100", "--json", "headSha,status,conclusion"))
    base, matched = nearest_checked(sh("git", "rev-list", "--max-count=500", sha).splitlines(), runs)
    changed = sh("git", "diff", "--name-only", base, sha).splitlines() if base else []
    reason = refusal(base, matched, changed, ignored_paths(sh("git", "show", f"{sha}:{WORKFLOW}")))
    if reason:
        raise SystemExit(f"Refusing {sha[:8]}: {reason}")
    print(f"Checks passed at {base[:8]}", flush=True)
    return base
