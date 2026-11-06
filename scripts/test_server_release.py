import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import server_ops  # noqa: E402
import server_release  # noqa: E402


def owner_api():
    return {"environment": {"DATABASE_USER": "rune_nexus_app", "DATABASE_PASSWORD_FILE": "/run/secrets/postgres_password",
                            "TZ": "UTC"},
            "volumes": [{"type": "bind", "source": "/srv/.secrets/postgres_password",
                         "target": "/run/secrets/postgres_password", "read_only": True},
                        {"type": "bind", "source": "/srv/other", "target": "/other"}]}


class ApiRoleTest(unittest.TestCase):
    def test_switches_login_and_its_secret_only(self):
        api = owner_api()
        self.assertEqual(server_release.use_api_role(api), Path("/srv/.secrets/postgres_api_password"))
        self.assertEqual(api["environment"], {"DATABASE_USER": "rune_nexus_api", "TZ": "UTC",
                                              "DATABASE_PASSWORD_FILE": "/run/secrets/postgres_api_password"})
        self.assertEqual(api["volumes"][0]["target"], "/run/secrets/postgres_api_password")
        self.assertEqual(api["volumes"][1], owner_api()["volumes"][1])

    def test_switched_compose_stays_as_it_is(self):
        api = owner_api()
        secret = server_release.use_api_role(api)
        api["volumes"][0]["source"] = "/elsewhere/key"
        self.assertEqual(server_release.use_api_role(api), Path("/elsewhere/key"))
        self.assertNotEqual(secret, Path("/elsewhere/key"))

    def test_only_the_login_may_differ_after_the_switch(self):
        env = owner_api()["environment"]
        switched = dict(env, DATABASE_USER="rune_nexus_api")
        self.assertEqual(server_release.without_login(env), server_release.without_login(switched))
        self.assertNotEqual(server_release.without_login(env), server_release.without_login(dict(env, TZ="KST")))

    def test_password_mount_comparison_keeps_other_mounts(self):
        container = {"Config": {"Env": ["DATABASE_PASSWORD_FILE=/run/secrets/key"]},
                     "Mounts": [{"Destination": "/run/secrets/key"}, {"Destination": "/other"}]}
        self.assertEqual(server_release.without_password_mount(container), [{"Destination": "/other"}])

    def test_existing_secret_is_never_replaced(self):
        secret = mock.Mock(spec=Path)
        secret.exists.return_value = True
        with mock.patch.object(server_ops, "private_file") as opened:
            server_release.ensure_api_secret(secret)
        opened.assert_not_called()


class DockerStepsTest(unittest.TestCase):
    def test_migrate_hands_over_both_passwords(self):
        with mock.patch.object(server_ops, "run") as run:
            server_ops.migrate("image", Path("/m"), "net", "db", "owner", "name", Path("/owner"), Path("/api"))
        command = run.call_args.args[0]
        self.assertIn("API_PASSWORD_FILE=" + server_ops.API_SECRET_TARGET, command)
        self.assertIn(f"/api:{server_ops.API_SECRET_TARGET}:ro", command)
        self.assertIn("/owner:/run/secrets/postgres_password:ro", command)

    def test_role_step_runs_without_migrating(self):
        with mock.patch.object(server_ops, "run") as run:
            server_ops.migrate("image", Path("/m"), "net", "db", "owner", "name", Path("/owner"), Path("/api"),
                               command="api-role")
        self.assertEqual(run.call_args.args[0][-2:], ["image", "api-role"])

    def test_rehearsal_prepares_the_role_before_starting_the_current_api(self):
        source = Path(server_release.__file__).read_text()
        rehearse = source[source.index("def rehearse("):]
        self.assertLess(rehearse.index('command="api-role"'), rehearse.index('"up", "-d"'))

    def test_restore_drops_grants_a_fresh_database_cannot_apply(self):
        restored = mock.Mock(stdout=server_ops.SEARCH_PATH_RESET)
        with mock.patch.object(server_ops.subprocess, "run", return_value=restored) as subprocess_run, \
                mock.patch.object(server_ops, "run"):
            server_ops.restore(mock.MagicMock(spec=object), "db", "owner", "name")
        self.assertIn("--no-privileges", subprocess_run.call_args.args[0])


if __name__ == "__main__":
    unittest.main()
