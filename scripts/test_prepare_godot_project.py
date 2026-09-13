"""실제 준비 과정을 임시 프로젝트에서 실행해 재질·식생 import·폐기 자산을 검사한다."""

import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import prepare_godot_project as preparation


class MaterialPresetSyncTest(unittest.TestCase):
    def test_repeated_prepare_updates_and_removes_presets_without_deleting_imports(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "godot"
            project = root / "build/godot/project"
            assets = root / "assets/images/stage1_3d"

            def write(path, data):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)

            write(source / "project.godot", b"config_version=5\n")
            preset = source / "materials/core_glass.tres"
            write(preset, b'[gd_resource type="StandardMaterial3D" format=3]\n')
            for kind, names in (
                ("environment", ("dressing", "landmarks", "fern_shadow")),
                ("turrets", preparation.TURRET_TYPES),
                ("enemies", preparation.ENEMY_TYPES),
                ("effects", ("machinegun_muzzle",)),
            ):
                for name in names:
                    write(assets / kind / f"{name}.glb", b"asset fixture")
            for name in ("muzzle_flash.png", "gun_smoke.png", "cannon_field.json",
                         "cannon_field.bin", "machinegun_muzzle_noise.bin"):
                write(assets / "effects" / name, b"asset fixture")
            write(assets / "ui/turret_levels.png", b"badge atlas")
            write(root / "assets/images/diamond_currency.png", b"diamond icon")
            write(root / "assets/fonts/NotoSansKR-VF.ttf", b"font fixture")
            write(assets / "ui/labels/slow_shard.png", b"status sprite")
            write(assets / "ui/Roboto-OFL.txt", b"font license")
            document = json.dumps({"nodes": [{"name": "stage1_environment", "extras": {
                "columns": 2, "rows": 1, "tileTypes": ["path", "build"],
            }}]}).encode()
            document += b" " * (-len(document) % 4)
            write(assets / "environment/terrain.glb",
                  struct.pack("<IIIII", 0x46546C67, 2, 20 + len(document),
                              len(document), 0x4E4F534A) + document)
            protected = [project / ".godot/imported/cached.tres",
                         project / "assets/imported_surface.tres",
                         project / ".godot/imported/dressing.glb-keep.scn"]
            for path in protected:
                write(path, b"generated resource")
            retired = [project / "assets/environment/fern_shadow.glb",
                       project / "assets/environment/fern_shadow.glb.import",
                       project / ".godot/imported/fern_shadow.glb-old.scn",
                       project / ".godot/imported/fern_shadow.glb-old.md5",
                       project / "environment/fern_shadow.gdshader",
                       project / "environment/fern_shadow.gdshader.uid",
                       project / "environment/fern_shadow_outline.gdshaderinc",
                       project / "environment/fern_shadow_outline.gdshaderinc.uid"]
            for path in retired:
                write(path, b"retired resource")

            with patch.multiple(preparation, ROOT=root, SOURCE=source,
                                PROJECT=project, ASSETS=project / "assets",
                                SOURCE_ASSETS=assets):
                preparation.prepare()
                self.assertEqual((project / "assets/ui/labels/slow_shard.png").read_bytes(), b"status sprite")
                self.assertEqual((project / "assets/ui/diamond_currency.png").read_bytes(), b"diamond icon")
                self.assertEqual((project / "assets/ui/NotoSansKR-VF.ttf").read_bytes(), b"font fixture")
                self.assertTrue((project / "assets/ui/Roboto-OFL.txt").is_file())
                copied = project / "materials/core_glass.tres"
                self.assertEqual(copied.read_bytes(), preset.read_bytes())
                foliage_import = project / "assets/environment/dressing.glb.import"
                def subresources():
                    return json.JSONDecoder().raw_decode(foliage_import.read_text().split("_subresources=", 1)[1])[0]
                self.assertEqual(subresources(), {"meshes": {"Dressing Export (temporary)_stage1_dressing_foliage": {"generate/lods": 2}}})
                self.assertNotIn("meshes/generate_lods=false", foliage_import.read_text())
                for path in retired:
                    self.assertFalse(path.exists(), f"retired asset remains: {path}")
                # 기존 UID와 동일 GLB의 바위/재질 설정을 재준비에서 보존한다.
                existing = {"meshes": {
                    "Dressing Export (temporary)_stage1_dressing_foliage": {"generate/lods": 1, "generate/shadow_meshes": 0},
                    "stage1_dressing_foliage": {"generate/lods": 2},
                    "stage1_dressing_rocks": {"generate/lods": 1},
                }, "materials": {"rock": {"use_external/enabled": False}}}
                foliage_import.write_text('[remap]\nuid="uid://keep"\n\n[params]\nmeshes/generate_lods=true\nmeshes/create_shadow_meshes=true\n_subresources=' + json.dumps(existing) + '\n')
                other_import = project / "assets/environment/terrain.glb.import"
                other_import.write_text('[params]\nmeshes/generate_lods=true\n')

                preset.write_bytes(preset.read_bytes() + b"[resource]\nrefraction_enabled = true\n")
                preparation.prepare()
                self.assertEqual(copied.read_bytes(), preset.read_bytes())
                self.assertIn('uid="uid://keep"', foliage_import.read_text())
                self.assertIn("meshes/generate_lods=true", foliage_import.read_text())
                self.assertIn("meshes/create_shadow_meshes=true", foliage_import.read_text())
                del existing["meshes"]["stage1_dressing_foliage"]
                existing["meshes"]["Dressing Export (temporary)_stage1_dressing_foliage"]["generate/lods"] = 2
                self.assertEqual(subresources(), existing)
                self.assertEqual(other_import.read_text(), '[params]\nmeshes/generate_lods=true\n')

                renamed = preset.with_name("approved_glass.tres")
                preset.rename(renamed)
                preparation.prepare()
                self.assertFalse(copied.exists(), "renamed preset must not remain exportable")
                self.assertEqual((copied.parent / renamed.name).read_bytes(), renamed.read_bytes())

                renamed.unlink()
                preparation.prepare()
                self.assertFalse((copied.parent / renamed.name).exists())
                for path in protected:
                    self.assertEqual(path.read_bytes(), b"generated resource")
                for path in retired:
                    self.assertFalse(path.exists())
                self.assertTrue((source / "project.godot").is_file())


if __name__ == "__main__":
    unittest.main()
