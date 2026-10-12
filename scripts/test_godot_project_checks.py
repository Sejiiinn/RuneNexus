"""Runner/CI failure semantics, without launching Godot or touching player saves."""
import contextlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import run_godot_project_checks as runner


class ProjectChecksTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name)

    def run_output(self, stdout="PASS", stderr="", returncode=0):
        with patch.object(runner.subprocess, "run", return_value=subprocess.CompletedProcess(
                [], returncode, stdout, stderr)):
            return runner.run_case("godot", "case.gd", "PASS", {}, self.work)

    def test_success_marker_cannot_hide_engine_resource_error(self):
        failure = self.run_output("PASS", "ERROR: Failed loading resource: res://missing.glb\n")
        self.assertIn("Failed loading resource", failure)

    def test_skip_and_missing_marker_cannot_pass(self):
        for index, output in enumerate(("case: SKIP missing renderer\nPASS", "Godot started")):
            with self.subTest(output=output), patch.object(runner.subprocess, "run", return_value=
                    subprocess.CompletedProcess([], 0, output, "")):
                self.assertIsNotNone(runner.run_case("godot", f"case{index}.gd", "PASS", {}, self.work))

    def test_timeout_is_failure(self):
        with patch.object(runner.subprocess, "run", side_effect=subprocess.TimeoutExpired("godot", 1)):
            self.assertIn("timed out", runner.run_case("godot", "case.gd", "PASS", {"timeout": 1}, self.work))

    def test_declared_rejection_must_occur_once_and_cannot_hide_other_errors(self):
        expected = "ERROR: Combat runtime rejected: fixture (testRejected)"
        outputs = (expected + "\nPASS", "PASS", expected + "\n" + expected + "\nPASS",
                   expected + "\nERROR: Failed loading resource\nPASS")
        for index, output in enumerate(outputs):
            with self.subTest(index=index), patch.object(runner.subprocess, "run", return_value=
                    subprocess.CompletedProcess([], 0, output, "")):
                failure = runner.run_case("godot", f"rejection{index}.gd", "PASS",
                                          {"expected_errors": [expected]}, self.work)
                self.assertEqual(failure is None, index == 0)

    def test_restart_steps_share_only_their_case_save_directory(self):
        with patch.object(runner.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "PASS", "")) as run:
            options = {"steps": [["write", "{tmp}/save"], ["read", "{tmp}/save"]]}
            self.assertIsNone(runner.run_case("godot", "restart.gd", "PASS", options, self.work))
            self.assertIsNone(runner.run_case("godot", "other.gd", "PASS", {}, self.work))
        first, second, other = run.call_args_list
        self.assertEqual(first.args[0][-1], second.args[0][-1])
        self.assertEqual(first.kwargs["env"]["HOME"], second.kwargs["env"]["HOME"])
        self.assertNotEqual(first.kwargs["env"]["HOME"], other.kwargs["env"]["HOME"])
        self.assertIn("--headless", first.args[0])

    def execute(self, selected, strict=True):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()), \
                patch.object(runner, "source_revision", return_value={"head": "fixture", "tracked_dirty": True}), \
                patch.object(runner, "validate_project"), patch.object(runner, "godot_executable", return_value="godot"), \
                patch.object(runner.subprocess, "check_output", return_value="4.7.2.fixture\n"), \
                patch.object(runner, "run_case", return_value=None) as run:
            report, code = runner.execute(selected, headless_only=True, require_complete=strict)
            return report, code, run.call_count

    def test_headless_render_case_is_incomplete_and_ci_fails(self):
        report, code, calls = self.execute(["verify_environment.gd", "verify_app_resume.gd"])
        self.assertEqual((report["status"], code, calls), ("INCOMPLETE", 2, 1))
        self.assertEqual(report["counts"], {"PASS": 1, "FAIL": 0, "NOT_RUN": 1})
        self.assertEqual(report["cases"][0]["reason"], "renderer required")
        self.assertTrue(report["source"]["tracked_dirty"])
        report, code, _ = self.execute(["verify_environment.gd"], strict=False)
        self.assertEqual((report["status"], code), ("INCOMPLETE", 0))

    def test_preflight_failure_has_report_and_never_executes_case(self):
        output = self.work / "results.json"
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()), \
                patch.object(runner, "source_revision", return_value={}), \
                patch.object(runner, "validate_project", side_effect=RuntimeError("stale source")), \
                patch.object(runner, "run_case") as run:
            code = runner.main(["--preset", "session", "--require-complete", "--output", str(output)])
        report = json.loads(output.read_text())
        self.assertEqual((code, report["status"]), (1, "FAIL"))
        self.assertEqual(report["errors"], ["stale source"])
        self.assertEqual(report["counts"]["NOT_RUN"], len(runner.PRESETS["session"]))
        run.assert_not_called()

    def test_presets_and_explicit_cases_deduplicate_without_adding_unrelated_checks(self):
        with patch.object(runner, "execute", return_value=({}, 0)) as execute:
            self.assertEqual(runner.main(["--preset", "session", "verify_session_controller.gd"]), 0)
        selected = execute.call_args.args[0]
        self.assertEqual(selected, list(runner.PRESETS["session"]))
        self.assertNotIn("verify_environment.gd", selected)

    def test_stale_or_missing_prepared_source_is_detected(self):
        source, project = self.work / "source", self.work / "project"
        source.mkdir(); project.mkdir()
        (source / "main.gd").write_text("new source")
        (project / "main.gd").write_text("old source")
        with patch.object(runner, "SOURCE", source), patch.object(runner, "PROJECT", project):
            self.assertEqual(runner.stale_project_files(), ["main.gd"])
            (project / "main.gd").write_text("new source")
            self.assertEqual(runner.stale_project_files(), [])
            (project / "main.gd").unlink()
            self.assertEqual(runner.stale_project_files(), ["main.gd"])

    def test_changed_shared_shader_include_invalidates_prepared_project(self):
        source, project = self.work / "source", self.work / "project"
        source.mkdir(); project.mkdir()
        (source / "shared.gdshaderinc").write_text("const float GAIN = 2.0;")
        (project / "shared.gdshaderinc").write_text("const float GAIN = 1.0;")
        with patch.object(runner, "SOURCE", source), patch.object(runner, "PROJECT", project):
            self.assertEqual(runner.stale_project_files(), ["shared.gdshaderinc"])

    def test_copied_settings_binary_resources_and_new_types_cannot_be_stale(self):
        source, project = self.work / "source", self.work / "project"
        paths = ("project.godot", "export_presets.cfg", "lightning_attack_meshes/attack.res",
                 "material.newtype", "script.gd.uid")
        for relative in paths:
            for root, data in ((source, b"current"), (project, b"old")):
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
        with patch.object(runner, "SOURCE", source), patch.object(runner, "PROJECT", project):
            self.assertEqual(set(runner.stale_project_files()), set(paths))

    def test_regenerated_authoring_editor_and_documentation_files_are_not_compared(self):
        source, project = self.work / "source", self.work / "project"
        project.mkdir()
        for relative in (".godot/cache.bin", "nested/.godot/cache.bin", "content/source/authored.json",
                         "assets/generated.res", "app_config.json", "app/README.md"):
            path = source / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("not a copied runtime input")
        with patch.object(runner, "SOURCE", source), patch.object(runner, "PROJECT", project):
            self.assertEqual(runner.stale_project_files(), [])

    def test_release_workflow_checks_prepared_project_before_apk(self):
        workflow = (runner.ROOT / ".github/workflows/deploy-apk.yml").read_text()
        prepare = workflow.index("python3 scripts/build_godot_pack.py")
        checks = workflow.index("python3 scripts/run_godot_project_checks.py")
        apk = workflow.index(":app:assembleProductionRelease")
        self.assertLess(prepare, checks)
        self.assertLess(checks, apk)
        self.assertIn("--preset session --preset lifecycle --headless-only --require-complete", workflow[checks:apk])
        self.assertIn("always() && hashFiles('build/godot-project-checks.json')", workflow[checks:apk])
        for preset in ("session", "lifecycle"):
            for name in runner.PRESETS[preset]:
                self.assertIn(name, runner.CASES)
                self.assertFalse(runner.CASES[name][1].get("renderer", False))


if __name__ == "__main__":
    unittest.main()
