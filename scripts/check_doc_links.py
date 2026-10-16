#!/usr/bin/env python3
"""Check relative links and anchors in Markdown docs against the Git index.

A link passes only when its target will exist in a fresh checkout: the target
must be in the index (tracked or staged), not merely present on this machine.

  python3 scripts/check_doc_links.py              # current docs (records excluded)
  python3 scripts/check_doc_links.py --changed    # tracked/staged Markdown changed vs HEAD
  python3 scripts/check_doc_links.py --all        # every tracked Markdown file
  python3 scripts/check_doc_links.py docs/a.md    # given files

Exit code: 0 no issues, 1 issues found, 2 usage error.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import os
from pathlib import Path
import re
import subprocess
import sys
import unicodedata
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
# Dated records keep links to outputs that were never committed; see docs/documentation_guide.md.
RECORD_PREFIXES = ("docs/archive/", "docs/analysis/", "design/")

FENCE = re.compile(r"^(```|~~~).*?^\1", re.M | re.S)
INLINE_CODE = re.compile(r"`[^`\n]*`")
LINK = re.compile(r"!?\[(?:[^\[\]]|\[[^\]]*\])*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
HEADING = re.compile(r"^#{1,6}\s+(.*?)\s*#*\s*$", re.M)
HTML_ID = re.compile(r"<a\s+(?:name|id)=\"([^\"]+)\"")


@dataclass(frozen=True)
class Issue:
    file: str
    line: int
    kind: str
    target: str

    def __str__(self) -> str:
        return f"{self.file}:{self.line}\t{self.kind}\t{self.target}"


def git(root: Path, *args: str) -> str:
    return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, check=True).stdout


def slug(heading: str) -> str:
    """GitHub-style heading anchor: lowercase, keep letters/digits/marks, spaces and hyphens to '-'."""
    text = re.sub(r"<[^>]+>", "", heading)
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"[`*_~]", "", text).strip().lower()
    out = []
    for char in text:
        category = unicodedata.category(char)
        if char in " -":
            out.append("-")
        elif category[0] in "LN" or category == "Mn":
            out.append(char)
    return "".join(out)


def blank_code(text: str) -> str:
    """Remove code blocks and inline code while keeping line numbers."""
    text = FENCE.sub(lambda m: "\n" * m.group(0).count("\n"), text)
    return INLINE_CODE.sub("", text)


class Checker:
    def __init__(self, root: Path):
        self.root = root
        self.indexed = set(git(root, "ls-files", "-z").split("\0")) - {""}
        self.indexed_dirs = {str(Path(p).parent) for p in self.indexed}
        for directory in list(self.indexed_dirs):
            parent = Path(directory).parent
            while str(parent) != ".":
                self.indexed_dirs.add(str(parent))
                parent = parent.parent
        self._anchors: dict[str, set[str]] = {}

    def anchors(self, relative: str) -> set[str]:
        if relative not in self._anchors:
            path = self.root / relative
            text = path.read_text(encoding="utf-8") if path.is_file() else ""
            text = FENCE.sub("", text)
            found, seen = set(), {}
            for match in HEADING.finditer(text):
                base = slug(match.group(1))
                count = seen.get(base, 0)
                seen[base] = count + 1
                found.add(base if count == 0 else f"{base}-{count}")
            found.update(HTML_ID.findall(text))
            self._anchors[relative] = found
        return self._anchors[relative]

    def target_kind(self, relative: str) -> str | None:
        if relative in self.indexed or relative in self.indexed_dirs:
            return None
        path = self.root / relative
        if not path.exists():
            return "MISSING"
        result = subprocess.run(["git", "-C", str(self.root), "check-ignore", "-q", "--", relative],
                                capture_output=True, text=True)
        # Paths behind a symlinked directory (e.g. build/ on external storage) can never be tracked.
        local_only = result.returncode == 0 or "beyond a symbolic link" in result.stderr
        return "LOCAL_ONLY" if local_only else "NOT_STAGED"

    def check(self, relative: str) -> list[Issue]:
        issues = []
        text = blank_code((self.root / relative).read_text(encoding="utf-8"))
        for number, line in enumerate(text.splitlines(), 1):
            for match in LINK.finditer(line):
                url = match.group(1)
                if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", url) or url.startswith("//"):
                    continue
                path_part, _, fragment = url.partition("#")
                target = relative
                if path_part:
                    target = os.path.normpath(os.path.join(os.path.dirname(relative), unquote(path_part)))
                    if target.startswith(".."):
                        issues.append(Issue(relative, number, "OUTSIDE_REPO", url))
                        continue
                    kind = self.target_kind(target)
                    if kind:
                        issues.append(Issue(relative, number, kind, url))
                        continue
                if fragment and target.endswith(".md") and unquote(fragment).lower() not in self.anchors(target):
                    issues.append(Issue(relative, number, "ANCHOR", url))
        return issues


def default_files(checker: Checker, include_records: bool) -> list[str]:
    files = sorted(p for p in checker.indexed if p.endswith(".md") and (checker.root / p).is_file())
    return files if include_records else [p for p in files if not p.startswith(RECORD_PREFIXES)]


def changed_files(root: Path) -> list[str]:
    names = set()
    entries = iter(git(root, "status", "--porcelain=v1", "-uall", "-z").split("\0"))
    for entry in entries:
        if not entry:
            continue
        if entry[0] in "RC":
            next(entries, None)  # the rename source follows as its own -z entry
        if entry.startswith("??"):
            continue  # untracked files are checked once added, or when named explicitly
        names.add(entry[3:])
    return sorted(n for n in names if n.endswith(".md") and (root / n).is_file())


def main(argv: list[str] | None = None, root: Path = ROOT) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument("--all", action="store_true", help="include dated records (docs/archive, docs/analysis, design)")
    scope.add_argument("--changed", action="store_true", help="tracked or staged Markdown changed vs HEAD (git add new files first)")
    parser.add_argument("files", nargs="*", help="repository-relative Markdown files")
    args = parser.parse_args(argv)
    if args.files and (args.all or args.changed):
        parser.error("files cannot be combined with --all/--changed")

    checker = Checker(root)
    if args.files:
        files = [os.path.normpath(f) for f in args.files]
        missing = [f for f in files if not (root / f).is_file()]
        if missing:
            print("no such file: " + ", ".join(missing), file=sys.stderr)
            return 2
    elif args.changed:
        files = changed_files(root)
    else:
        files = default_files(checker, args.all)

    issues = [issue for f in files for issue in checker.check(f)]
    for issue in issues:
        print(issue)
    print(f"checked {len(files)} files, {len(issues)} issues", file=sys.stderr)
    return 1 if issues else 0


if __name__ == "__main__":
    sys.exit(main())
