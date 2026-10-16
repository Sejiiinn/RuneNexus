import contextlib
import io
from pathlib import Path
import subprocess
import tempfile
import unittest

from check_doc_links import Checker, main, slug


class CheckDocLinksTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        (self.root / ".gitignore").write_text("local/\n")
        (self.root / "docs").mkdir()
        (self.root / "docs/target.md").write_text("# 작업·검증 기준\n\n## 완료 확인\n\n## 완료 확인\n")
        (self.root / "docs/README.md").write_text("[지도](target.md)\n")
        self.add(".gitignore", "docs/target.md", "docs/README.md")

    def add(self, *paths):
        subprocess.run(["git", "-C", str(self.root), "add", "--", *paths], check=True)

    def write(self, relative, text):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def issues(self, relative):
        return [(i.kind, i.target) for i in Checker(self.root).check(relative)]

    def test_slug_matches_github_for_korean_and_punctuation(self):
        self.assertEqual(slug("작업·검증 기준"), "작업검증-기준")
        self.assertEqual(slug("검증과 완료 기준 — 완벽한 복제보다 요청 충족"), "검증과-완료-기준--완벽한-복제보다-요청-충족")
        self.assertEqual(slug("3. 단계와 `의존` 관계"), "3-단계와-의존-관계")

    def test_tracked_targets_and_anchors_pass(self):
        self.write("docs/a.md", "[a](target.md#작업검증-기준) [b](target.md#완료-확인-1) [c](#로컬) [d](../docs/)\n\n## 로컬\n")
        self.add("docs/a.md")
        self.assertEqual(self.issues("docs/a.md"), [])

    def test_reports_missing_local_only_unstaged_outside_and_anchor(self):
        self.write("local/run.log", "x")
        self.write("docs/new.md", "x")
        self.write("docs/a.md", "[m](gone.md) [l](../local/run.log) [n](new.md) [o](../../x.md) [h](target.md#없음)\n")
        self.assertEqual(self.issues("docs/a.md"), [
            ("MISSING", "gone.md"), ("LOCAL_ONLY", "../local/run.log"), ("NOT_STAGED", "new.md"),
            ("OUTSIDE_REPO", "../../x.md"), ("ANCHOR", "target.md#없음")])

    def test_ignores_code_external_links_and_keeps_line_numbers(self):
        self.write("docs/a.md", "```\n[x](gone.md)\n```\n`[y](gone.md)` [w](https://example.com/a.md)\n[z](gone.md)\n")
        issues = Checker(self.root).check("docs/a.md")
        self.assertEqual([(i.line, i.target) for i in issues], [(5, "gone.md")])

    def test_cli_default_scope_skips_records_and_returns_status(self):
        self.write("design/old/README.md", "[x](missing.png)\n")
        self.add("design/old/README.md")
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(main([], root=self.root), 0)
            self.assertEqual(main(["--all"], root=self.root), 1)
            self.assertEqual(main(["docs/none.md"], root=self.root), 2)

    def test_changed_scope_includes_staged_new_files_only(self):
        self.write("docs/fresh.md", "[x](missing.md)\n")
        self.write("design/scratch/README.md", "[y](missing.md)\n")
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(main(["--changed"], root=self.root), 0)
        self.add("docs/fresh.md")
        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(main(["--changed"], root=self.root), 1)
        self.assertIn("docs/fresh.md:1\tMISSING\tmissing.md", output.getvalue())


if __name__ == "__main__":
    unittest.main()
