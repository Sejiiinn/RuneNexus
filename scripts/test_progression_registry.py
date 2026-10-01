#!/usr/bin/env python3
"""Progression source validation, runtime freshness and immutable SQL agreement."""
import copy
import json
from pathlib import Path
import re
import tempfile
import unittest

from compile_progression import compile_progression, generated_outputs
from stage_progression import ROOT, SOURCE, load_progression, stage_ordinals


class ProgressionRegistryTests(unittest.TestCase):
    def test_checked_in_runtime_tables_are_fresh(self):
        compile_progression(check=True)

    def test_registry_rejects_missing_duplicate_unknown_and_malformed_ids(self):
        data = load_progression()
        variants = []
        for order in (data['order'][:-1], data['order'][:-1] + [data['order'][0]],
                      data['order'][:-1] + [100], data['order'][:-1] + [True]):
            changed = copy.deepcopy(data)
            changed['order'] = order
            variants.append(changed)
        changed = copy.deepcopy(data)
        changed['stages'][-1]['id'] = 100
        changed['order'] = [100 if stage == data['stages'][-1]['id'] else stage for stage in data['order']]
        variants.append(changed)
        changed = copy.deepcopy(data)
        changed['requirements']['turret']['sniper'] = 100
        variants.append(changed)
        changed = copy.deepcopy(data)
        changed['unlockDisplay'][0]['key'] = 'missing'
        variants.append(changed)
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path = root / SOURCE
            path.parent.mkdir(parents=True)
            for changed in variants:
                path.write_text(json.dumps(changed))
                with self.assertRaises(ValueError):
                    load_progression(root)

    def test_source_rejects_duplicate_keys_and_nonfinite_constants(self):
        source = (ROOT / SOURCE).read_text(encoding="utf-8")
        malformed = [
            (source.replace('"sniper": 3', '"sniper": 4, "sniper": 3', 1),
             'Duplicate JSON key: sniper'),
            (source.replace('"schemaVersion": 1', '"schemaVersion": 2, "schemaVersion": 1', 1),
             'Duplicate JSON key: schemaVersion'),
        ]
        # Even unknown metadata must obey JSON rather than silently carry NaN/Infinity.
        for constant in ('NaN', 'Infinity', '-Infinity'):
            malformed.append((source.replace('{', '{"unused": ' + constant + ',', 1),
                              'Non-finite JSON value'))
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path = root / SOURCE
            path.parent.mkdir(parents=True)
            for payload, message in malformed:
                with self.subTest(message=message, payload=payload[:60]):
                    path.write_text(payload, encoding="utf-8")
                    with self.assertRaisesRegex(ValueError, message):
                        load_progression(root)

    def test_schema_version_requires_integer_not_bool_or_float(self):
        data = load_progression()
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path = root / SOURCE
            path.parent.mkdir(parents=True)
            for version in (True, False, 1.0, '1'):
                with self.subTest(version=version):
                    changed = copy.deepcopy(data)
                    changed['schemaVersion'] = version
                    path.write_text(json.dumps(changed), encoding="utf-8")
                    with self.assertRaisesRegex(ValueError, 'schemaVersion 1'):
                        load_progression(root)

    def test_new_registry_stage_does_not_require_python_hardcode(self):
        data = copy.deepcopy(load_progression())
        data['stages'].append(dict(id=26, chapter=3, chapterStage=6))
        data['order'].append(26)
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path = root / SOURCE
            path.parent.mkdir(parents=True)
            path.write_text(json.dumps(data))
            self.assertEqual(stage_ordinals(root)[26], 26)
            compile_progression(root)
            compile_progression(root, check=True)
            generated = root / next(iter(generated_outputs(root)))
            generated.write_text(generated.read_text() + '\n')
            with self.assertRaises(ValueError):
                compile_progression(root, check=True)

    def test_applied_sql_migration_order_agrees_with_registry(self):
        # Migration 012 is immutable. This guard catches source edits that require
        # a NEW database migration; it must never encourage rewriting old SQL.
        sql = (ROOT / 'server/db/migrations/012_expanded_stage_progression.sql').read_text()
        body = re.search(r'SELECT CASE(.*?)ELSE 0 END;', sql, re.S).group(1)
        cases = re.findall(r'WHEN stage_id BETWEEN (\d+) AND (\d+) THEN stage_id(?: ([+-]) (\d+))?', body)
        self.assertEqual(len(cases), body.count('WHEN'))
        sql_ordinals = {}
        for low, high, sign, amount in cases:
            offset = int(amount or '0') * (-1 if sign == '-' else 1)
            for stage in range(int(low), int(high) + 1):
                self.assertNotIn(stage, sql_ordinals)
                sql_ordinals[stage] = stage + offset
        self.assertEqual(sql_ordinals, stage_ordinals(),
                         'Progression SQL differs: add a new migration, preserve applied 012')
        upper = int(re.search(r'CHECK \(stage_number BETWEEN 1 AND (\d+)\)', sql).group(1))
        self.assertEqual(set(sql_ordinals), set(range(1, upper + 1)))


if __name__ == '__main__':
    unittest.main()
