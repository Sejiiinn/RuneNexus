"""Finite CI wait tests with fake gh; never query or trigger GitHub."""
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest
from unittest.mock import Mock, patch

from release_ci_wait import wait_run


class ReleaseCiWaitTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.log = self.root / "watch.log"
        self.sha = "a" * 40
        self.run = {"databaseId": 123, "headSha": self.sha, "status": "completed", "conclusion": "success", "jobs": []}
        self.artifacts = {"total_count": 1, "artifacts": [{"id": 456, "name": "apk", "expired": False}]}

    def fake_read(self, values):
        return [subprocess.CompletedProcess(["gh"], 0, json.dumps(value), "") for value in values]

    def test_completed_run_does_not_launch_watch(self):
        with patch("release_ci_wait.subprocess.run", side_effect=self.fake_read([self.run, self.artifacts])) as read, \
             patch("release_ci_wait.subprocess.Popen") as watch:
            report = wait_run("owner/repo", "123", self.sha, self.log)
        self.assertTrue(report["ok"])
        self.assertEqual(read.call_count, 2)
        watch.assert_not_called()
        self.assertEqual(report["artifacts"][0]["id"], 456)

    def test_wrong_head_sha_does_not_watch(self):
        self.run["headSha"] = "b" * 40
        with patch("release_ci_wait.subprocess.run", side_effect=self.fake_read([self.run])), \
             patch("release_ci_wait.subprocess.Popen") as watch:
            report = wait_run("owner/repo", "123", self.sha, self.log)
        self.assertEqual(report["status"], "fail")
        watch.assert_not_called()

    def test_one_watch_and_one_final_view_failure_step(self):
        pending = {**self.run, "status": "in_progress", "conclusion": None}
        self.run.update(conclusion="failure", jobs=[{"name": "Android build", "steps": [
            {"name": "Fixture check", "conclusion": "failure"}, {"name": "Publish", "conclusion": "skipped"}]}])
        process = Mock(returncode=1)
        process.poll.return_value = 1
        with patch("release_ci_wait.subprocess.run", side_effect=self.fake_read([pending, self.run, self.artifacts])) as read, \
             patch("release_ci_wait.subprocess.Popen", return_value=process) as watch:
            report = wait_run("owner/repo", "123", self.sha, self.log)
        self.assertEqual(report["status"], "fail")
        self.assertEqual(report["failing_steps"][0]["step"], "Fixture check")
        self.assertEqual(read.call_count, 3)
        watch.assert_called_once()
        self.assertTrue(watch.call_args.kwargs["start_new_session"])

    def test_timeout_kills_watch_group_releases_lock_then_allows_next_wait(self):
        pending = {**self.run, "status": "in_progress", "conclusion": None}
        process = Mock(pid=12345)
        process.poll.return_value = None
        process.wait.side_effect = [subprocess.TimeoutExpired("gh", 1), 0]
        with patch("release_ci_wait.subprocess.run", side_effect=self.fake_read([pending])), \
             patch("release_ci_wait.subprocess.Popen", return_value=process), \
             patch("release_ci_wait.os.killpg") as kill:
            report = wait_run("owner/repo", "123", self.sha, self.log, timeout=1)
        self.assertEqual(report["status"], "timeout")
        kill.assert_called_once_with(12345, signal.SIGTERM)
        with patch("release_ci_wait.subprocess.run", side_effect=self.fake_read([self.run, self.artifacts])):
            self.assertTrue(wait_run("owner/repo", "123", self.sha, self.log)["ok"])

    def test_duplicate_owner_starts_no_second_watch_or_query(self):
        pending = {**self.run, "status": "in_progress", "conclusion": None}
        process = Mock(returncode=0)
        process.poll.return_value = 0
        duplicate = []
        def while_watching(timeout):
            duplicate.append(wait_run("owner/repo", "123", self.sha, self.root / "duplicate.log"))
            return 0
        process.wait.side_effect = while_watching
        with patch("release_ci_wait.subprocess.run", side_effect=self.fake_read([pending, self.run, self.artifacts])) as read, \
             patch("release_ci_wait.subprocess.Popen", return_value=process) as watch:
            report = wait_run("owner/repo", "123", self.sha, self.log)
        self.assertTrue(report["ok"])
        self.assertEqual(duplicate[0]["status"], "busy")
        self.assertIn("expected_sha", duplicate[0]["owner"])
        self.assertEqual(read.call_count, 3)
        watch.assert_called_once()
        self.assertFalse((self.root / "duplicate.log").exists())

    def test_cancel_kills_watch_and_preserves_remote_run(self):
        pending = {**self.run, "status": "in_progress", "conclusion": None}
        process = Mock(pid=12345)
        process.poll.return_value = None
        process.wait.side_effect = [KeyboardInterrupt, 0]
        with patch("release_ci_wait.subprocess.run", side_effect=self.fake_read([pending])) as read, \
             patch("release_ci_wait.subprocess.Popen", return_value=process), \
             patch("release_ci_wait.os.killpg") as kill:
            report = wait_run("owner/repo", "123", self.sha, self.log)
        self.assertEqual(report["status"], "cancelled")
        kill.assert_called_once_with(12345, signal.SIGTERM)
        self.assertEqual(read.call_count, 1)

    def test_network_and_artifact_failure_unknown(self):
        with patch("release_ci_wait.subprocess.run", side_effect=OSError("offline")):
            report = wait_run("owner/repo", "123", self.sha, self.log)
        self.assertEqual(report["status"], "unknown")
        with patch("release_ci_wait.subprocess.run", side_effect=[*self.fake_read([self.run]), OSError("no artifact access")]):
            report = wait_run("owner/repo", "123", self.sha, self.log)
        self.assertEqual(report["status"], "unknown")
        self.assertEqual(report["conclusion"], "success")
        self.assertFalse(report["ok"])

    def fake_gh_cli(self):
        gh = self.root / "gh"
        gh.write_text("""#!/usr/bin/env python3
import json, os, pathlib, sys, time
root = pathlib.Path(os.environ['RELEASE_WAIT_FIXTURE'])
with (root / 'calls.log').open('a') as log:
    log.write(' '.join(sys.argv[1:3]) + '\\n')
if sys.argv[1:3] == ['run', 'view']:
    print(json.dumps({'databaseId': int(sys.argv[3]), 'headSha': 'a' * 40,
                      'status': 'in_progress', 'conclusion': None, 'jobs': []}))
elif sys.argv[1:3] == ['run', 'watch']:
    (root / 'watch.pid').write_text(str(os.getpid()))
    print('fake gh watch started', flush=True)
    time.sleep(60)
else:
    raise SystemExit(99)
""")
        gh.chmod(0o755)
        environment = {**os.environ, "PATH": str(self.root) + os.pathsep + os.environ["PATH"],
                       "RELEASE_WAIT_FIXTURE": str(self.root)}
        script = Path(__file__).with_name("release_report.py")
        command = [os.sys.executable, str(script), "wait", "--github-repo", "fixture/repo",
                   "--run-id", str(os.getpid()), "--expected-sha", self.sha, "--log", str(self.log),
                   "--output", str(self.root / "report.json")]
        return command, environment

    def assert_watch_stopped(self):
        pid = int((self.root / "watch.pid").read_text())
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)

    def test_actual_cli_timeout_cleans_child_process(self):
        command, environment = self.fake_gh_cli()
        result = subprocess.run(command + ["--timeout", "0.6"], env=environment,
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 1, result.stderr)
        report = json.loads((self.root / "report.json").read_text())
        self.assertEqual(report["status"], "timeout")
        self.assertLessEqual(len(result.stdout.splitlines()), 2)
        self.assert_watch_stopped()

    def test_actual_cli_duplicate_then_sigterm_cleans_child_and_lock(self):
        command, environment = self.fake_gh_cli()
        owner_tmp = self.root / "owner-temp"
        duplicate_tmp = self.root / "duplicate-temp"
        owner_tmp.mkdir()
        duplicate_tmp.mkdir()
        environment["TMPDIR"] = str(owner_tmp)
        owner = subprocess.Popen(command, env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(lambda: owner.kill() if owner.poll() is None else None)
        deadline = time.monotonic() + 5
        while not (self.root / "watch.pid").exists() and time.monotonic() < deadline:
            time.sleep(0.01)
        self.assertTrue((self.root / "watch.pid").exists())
        # Duplicate output is separate from the owner's result path.
        duplicate_command = command.copy()
        duplicate_command[-1] = str(self.root / "duplicate.json")
        calls_before = (self.root / "calls.log").read_text()
        duplicate = subprocess.run(duplicate_command, env={**environment, "TMPDIR": str(duplicate_tmp)},
                                   capture_output=True, text=True, timeout=5)
        self.assertEqual(duplicate.returncode, 1)
        self.assertEqual(json.loads((self.root / "duplicate.json").read_text())["status"], "busy")
        self.assertEqual((self.root / "calls.log").read_text(), calls_before)
        owner.terminate()
        _, stderr = owner.communicate(timeout=5)
        self.assertEqual(owner.returncode, 1, stderr)
        self.assertEqual(json.loads((self.root / "report.json").read_text())["status"], "cancelled")
        self.assert_watch_stopped()
        # The OS ownership lock is reusable after cancellation.
        again = subprocess.run(command + ["--timeout", "0.6"], env=environment,
                               capture_output=True, text=True, timeout=5)
        self.assertEqual(again.returncode, 1)
        self.assertEqual(json.loads((self.root / "report.json").read_text())["status"], "timeout")
        self.assert_watch_stopped()


if __name__ == "__main__":
    unittest.main()
