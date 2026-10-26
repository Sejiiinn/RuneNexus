"""운영 DB 백업 보관 규칙과 반영 검사의 docker 없는 단위 검사."""
from datetime import datetime, timedelta
from pathlib import Path
import unittest
from unittest.mock import patch

import server_backup
import server_release


def names(days):
    start = datetime(2026, 10, 26, 4, 17)
    return [f"rune-nexus-{(start - timedelta(days=day)):%Y%m%dT%H%M%SZ}-schema20.dump" for day in range(days)]


class RetentionTest(unittest.TestCase):
    def test_keeps_recent_days_and_one_per_recent_week(self):
        backups = names(90)
        keep = server_backup.retained(backups + ["backup-log.jsonl", "notes.txt"])
        self.assertTrue(set(backups[:14]) <= keep)
        older = sorted(keep - set(backups[:14]))
        weeks = {datetime.strptime(name[11:27], "%Y%m%dT%H%M%SZ").isocalendar()[:2] for name in keep}
        self.assertEqual(len(weeks), 8)
        self.assertTrue(older and all(name in backups for name in older))
        self.assertLess(len(keep), 14 + 8)

    def test_few_backups_are_all_kept(self):
        self.assertEqual(server_backup.retained(names(3)), set(names(3)))

    def test_unmounted_volume_never_creates_backup(self):
        with patch.object(Path, "is_mount", return_value=False), \
                patch.object(server_backup.server_ops, "credentials") as credentials:
            with self.assertRaises(SystemExit):
                server_backup.backup(Path("/Volumes/MISSING/RuneNexus/db-backups"))
        credentials.assert_not_called()


class ReleaseTest(unittest.TestCase):
    def test_changed_existing_rows_fail_unless_allowed(self):
        before = {"accounts": {"count": 1, "hash": "a"}, "mails": {"count": 2, "hash": "b"}}
        server_release.compare_tables(before, dict(before), set())
        changed = dict(before, mails={"count": 2, "hash": "c"})
        with self.assertRaises(RuntimeError):
            server_release.compare_tables(before, changed, set())
        server_release.compare_tables(before, changed, {"mails"})

    def test_deploy_requires_confirmation(self):
        with self.assertRaises(SystemExit):
            server_release.main(["deploy", "/nonexistent"])


if __name__ == "__main__":
    unittest.main()
