"""배포 기록 정리와 APK 배포 실행기의 네트워크 없는 단위 검사."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import apk_release
import deployment_record
import promote_apk_candidate


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
        self.assertFalse(any(field.startswith("promote_run_id=") for field in fields))

    def test_publish_dispatch_promotes_the_build_only_run(self):
        inputs = {"version_code": "6058", "version_name": "0.2.29", "notes": "n", "required_update": "false",
                  "sha": "abc"}
        calls = []
        with patch.object(apk_release, "sh", side_effect=lambda *a: calls.append(a) or
                          '[{"databaseId": 9, "headSha": "abc", "createdAt": "2999-01-01T00:00:00Z"}]'), \
                patch.object(apk_release.time, "sleep"):
            apk_release.dispatch(inputs, True, 41)
        fields = [calls[0][i + 1] for i, value in enumerate(calls[0]) if value == "-f"]
        self.assertIn("promote_run_id=41", fields)


def release(code, draft=False):
    return {"tag_name": f"apk-{code}", "draft": draft, "published_at": None if draft else "2026-10-27T00:00:00Z"}


class PromoteCandidateTest(unittest.TestCase):
    INPUTS = {"version_code": "6058", "version_name": "0.2.29", "notes": "- 개선", "required_update": "false"}
    RELEASES = [release(6057), release(6056), release(6055), release(6054)]

    def candidate(self, directory):
        folder = Path(directory)
        apk, patch_file = folder / "rune-nexus.apk", folder / "patch-from-6057.rndelta"
        apk.write_bytes(b"apk")
        patch_file.write_bytes(b"patch")
        (folder / "update.json").write_text(json.dumps({
            "versionCode": 6058, "versionName": "0.2.29", "notes": "- 개선", "minimumSupportedVersionCode": 6055,
            "sha256": hashlib.sha256(b"apk").hexdigest(), "sizeBytes": 3,
            "patches": [{"fromVersionCode": 6057, "sha256": hashlib.sha256(b"patch").hexdigest(), "sizeBytes": 5}],
        }, ensure_ascii=False))
        recorded = {**self.INPUTS, "sha": "abc", "patch_base_tags": ["apk-6057", "apk-6056", "apk-6055"]}
        return folder, recorded

    def check(self, folder, recorded, inputs=None, releases=None):
        return promote_apk_candidate.check_candidate(folder, recorded, inputs or self.INPUTS, "abc",
                                                     self.RELEASES if releases is None else releases)

    def test_matching_candidate_can_be_promoted(self):
        with tempfile.TemporaryDirectory() as directory:
            folder, recorded = self.candidate(directory)
            self.assertEqual(self.check(folder, recorded), [])
            # 초안은 패치 기준이 아니므로 바뀌어도 공개 가능
            self.assertEqual(self.check(folder, recorded, releases=self.RELEASES + [release(6050, draft=True)]), [])

    def test_refuses_when_a_release_was_published_after_the_build(self):
        with tempfile.TemporaryDirectory() as directory:
            folder, recorded = self.candidate(directory)
            problems = self.check(folder, recorded, releases=[release(6058)] + self.RELEASES)
            self.assertTrue(any("rebuild" in problem for problem in problems))
            self.assertTrue(any("versionCode" in problem for problem in problems))

    def test_refuses_changed_inputs_commit_or_files(self):
        with tempfile.TemporaryDirectory() as directory:
            folder, recorded = self.candidate(directory)
            self.assertTrue(self.check(folder, recorded, inputs={**self.INPUTS, "notes": "다른 안내"}))
            self.assertTrue(self.check(folder, {**recorded, "sha": "other"}))
            self.assertTrue(self.check(folder, recorded, inputs={**self.INPUTS, "required_update": "true"}))
            (folder / "extra.txt").write_text("x")
            self.assertTrue(any("candidate files" in p for p in self.check(folder, recorded)))
            (folder / "extra.txt").unlink()
            (folder / "patch-from-6057.rndelta").write_bytes(b"other")
            self.assertTrue(any("patch-from-6057" in p for p in self.check(folder, recorded)))


if __name__ == "__main__":
    unittest.main()
