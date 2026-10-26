"""배포 기록 정리와 APK 배포 실행기의 네트워크 없는 단위 검사."""
from datetime import datetime, timezone
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import apk_release
import deployment_record


class DeploymentRecordTest(unittest.TestCase):
    def test_archive_moves_only_that_component_and_relinks(self):
        with tempfile.TemporaryDirectory() as directory:
            status, history = Path(directory, "status.md"), Path(directory, "history.md")
            status.write_text("# 상태\n\n## 현재 미배포 변경\n\n없음.\n\n"
                              "## 2026-10-26 Android 0.2.27 / code 6056 — 공개 완료\n\n- [설계](support.md)\n\n"
                              "## 2026-10-26 서버·DB — `53fb799d` 반영 완료\n\n- 서버\n\n## 기록 유지 규칙\n\n- 규칙\n")
            history.write_text("# 이력\n\n역할: 보존본.\n\n## 2026-10-24 Android 0.2.26 / code 6055 — 공개 완료\n\n- 이전\n")
            deployment_record.archive("app", status, history)
            self.assertNotIn("code 6056", status.read_text())
            self.assertIn("서버·DB", status.read_text())
            moved = history.read_text()
            self.assertLess(moved.index("code 6056"), moved.index("code 6055"))
            self.assertIn("](../support.md)", moved)
            self.assertTrue(moved.startswith("# 이력\n\n역할: 보존본.\n\n## 2026-10-26 Android"))
            with self.assertRaises(SystemExit):
                deployment_record.archive("app", status, history)


class ApkReleaseTest(unittest.TestCase):
    def test_pick_run_ignores_older_or_other_commit_runs(self):
        started = datetime(2026, 10, 26, 5, 0, tzinfo=timezone.utc)
        runs = [{"databaseId": 3, "headSha": "other", "createdAt": "2026-10-26T05:01:00Z"},
                {"databaseId": 2, "headSha": "sha", "createdAt": "2026-10-26T04:59:00Z"},
                {"databaseId": 1, "headSha": "sha", "createdAt": "2026-10-26T05:00:30Z"}]
        self.assertEqual(apk_release.pick_run(runs, "sha", started), 1)
        self.assertIsNone(apk_release.pick_run(runs[:2], "sha", started))

    def test_dispatch_never_passes_commit_as_workflow_input(self):
        inputs = {"version_code": "6057", "version_name": "0.2.28", "notes": "n", "required_update": "false",
                  "sha": "abc"}
        calls = []
        with patch.object(apk_release, "sh", side_effect=lambda *a: calls.append(a) or
                          '[{"databaseId": 9, "headSha": "abc", "createdAt": "2999-01-01T00:00:00Z"}]'), \
                patch.object(apk_release.time, "sleep"):
            self.assertEqual(apk_release.dispatch(inputs, True), 9)
        fields = [calls[0][i + 1] for i, value in enumerate(calls[0]) if value == "-f"]
        self.assertIn("publish=true", fields)
        self.assertFalse(any(field.startswith("sha=") for field in fields))


if __name__ == "__main__":
    unittest.main()
