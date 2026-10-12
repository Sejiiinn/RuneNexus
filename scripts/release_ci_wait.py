"""One finite gh run watch owner per repository/run, with bounded final evidence.

Invoked by release_report.py wait. Locks are shared across local worktrees and
released by the OS on exit. A duplicate caller does not start another poller.
"""
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import signal
import subprocess
import time

from release_report import full_sha, now


def wait_run(repository, run_id, expected_sha, log_path, timeout=1800, interval=30):
    full_sha(expected_sha)
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Invalid GitHub repository")
    if not re.fullmatch(r"[1-9][0-9]*", str(run_id)) or not math.isfinite(timeout) or timeout <= 0 or interval < 1:
        raise ValueError("Run ID, timeout and interval must be positive")
    run_id = str(run_id)
    key = hashlib.sha256(f"{repository.lower()}:{run_id}".encode()).hexdigest()
    # TMPDIR may be isolated per task; ownership must still cover the same run.
    locks = Path("/tmp") / f"rune-release-wait-{os.getuid()}"
    locks.mkdir(mode=0o700, exist_ok=True)
    report = {"operation": "wait", "ok": False, "status": "unknown", "run_id": run_id,
              "expected_sha": expected_sha, "observed_at": now(), "errors": [],
              "run_url": f"https://github.com/{repository}/actions/runs/{run_id}",
              "log_path": str(log_path), "limitations": ["CI success does not imply publication, artifact byte identity, installation or game validation."]}
    with (locks / (key + ".lock")).open("a+") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            lock.seek(0)
            report.update(status="busy", owner=lock.read(), errors=["Another process owns this run watch; no query or watch started"])
            return report
        lock.seek(0)
        lock.truncate()
        json.dump({"pid": os.getpid(), "run_id": run_id, "expected_sha": expected_sha,
                   "log_path": str(log_path), "started_at": report["observed_at"]}, lock)
        lock.flush()
        deadline = time.monotonic() + timeout
        process = None

        def read(command):
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise subprocess.TimeoutExpired(command, timeout)
            result = subprocess.run(command, capture_output=True, text=True, check=True,
                                    timeout=min(45, remaining))
            return json.loads(result.stdout)

        def view():
            return read(["gh", "run", "view", run_id, "--repo", repository, "--json",
                         "databaseId,headSha,status,conclusion,url,jobs"])

        def identity(run):
            if str(run.get("databaseId")) != run_id or run.get("headSha") != expected_sha:
                raise ValueError("CI run ID or head SHA mismatch; watch rejected")

        def stop():
            if process is not None and process.poll() is None:
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    return
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=3)

        previous_term = signal.getsignal(signal.SIGTERM)
        def cancel_wait(signum, frame):
            raise KeyboardInterrupt
        signal.signal(signal.SIGTERM, cancel_wait)

        try:
            run = view()
            identity(run)
            report.update(run_status=run.get("status"), conclusion=run.get("conclusion"), head_sha=run["headSha"])
            if run.get("status") != "completed":
                log_path = Path(log_path)
                log_path.parent.mkdir(parents=True, exist_ok=True)
                with log_path.open("w", encoding="utf-8") as log:
                    process = subprocess.Popen(["gh", "run", "watch", run_id, "--repo", repository,
                                                "--interval", str(interval), "--exit-status"],
                                               stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                    # Reserve up to five seconds of the single deadline for the final query.
                    process.wait(timeout=max(0.01, deadline - time.monotonic() - min(5, timeout / 10)))
                    report["watch_exit_code"] = process.returncode
                run = view()
                identity(run)
            report.update(run_status=run.get("status"), conclusion=run.get("conclusion"),
                          head_sha=run["headSha"], jobs=run.get("jobs", []))
            report["failing_steps"] = [
                {"job": job.get("name"), "step": step.get("name"), "conclusion": step.get("conclusion")}
                for job in run.get("jobs", []) for step in job.get("steps", [])
                if step.get("conclusion") in ("failure", "cancelled", "timed_out", "action_required")]
            if run.get("status") != "completed":
                report["errors"].append("Watch ended before CI completed")
            elif run.get("conclusion") != "success":
                report["status"] = "fail"
                report["errors"].append(f"CI concluded {run.get('conclusion')}")
            else:
                report["status"] = "pass"
            try:
                artifacts = read(["gh", "api", f"repos/{repository}/actions/runs/{run_id}/artifacts?per_page=100"])
                report["artifacts"] = [{"id": item["id"], "name": item["name"], "expired": item.get("expired"),
                                        "digest": item.get("digest")} for item in artifacts["artifacts"]]
                if artifacts.get("total_count", len(report["artifacts"])) > len(report["artifacts"]):
                    report["errors"].append("Artifact list truncated; inspect the run explicitly")
                    if report["status"] == "pass":
                        report["status"] = "unknown"
            except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
                report["artifact_observation"] = {"status": "unknown", "reason": str(error)}
                if report["status"] == "pass":
                    report["status"] = "unknown"
        except subprocess.TimeoutExpired:
            report.update(status="timeout", errors=["CI wait or query exceeded the bounded deadline"])
        except KeyboardInterrupt:
            report.update(status="cancelled", errors=["Local wait cancelled; remote CI was not cancelled"])
        except ValueError as error:
            report.update(status="fail", errors=[str(error)])
        except (OSError, KeyError, TypeError, subprocess.SubprocessError) as error:
            report.update(status="unknown", errors=[f"CI observation unavailable: {error}"])
        finally:
            try:
                stop()
            finally:
                signal.signal(signal.SIGTERM, previous_term)
        report["ok"] = report["status"] == "pass"
        report["finished_at"] = now()
    return report
