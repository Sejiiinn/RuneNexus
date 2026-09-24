"""실제 준비 과정을 임시 프로젝트에서 실행해 재질·식생 import·폐기 자산을 검사한다."""

import base64
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import prepare_godot_project as preparation


class MaterialPresetSyncTest(unittest.TestCase):
    def test_production_config_requires_all_values_and_https(self):
        variables = {
            "RUNE_NEXUS_REQUIRE_PRODUCTION_CONFIG": "true",
            "RUNE_NEXUS_API_BASE_URL": "https://api.example.test",
            "GOOGLE_WEB_CLIENT_ID": "client-id",
            "RUNE_NEXUS_UPDATE_MANIFEST_URL": "https://example.test/update.json",
            "RUNE_NEXUS_CLIENT_BUILD": "android:commit",
        }
        with patch.dict("os.environ", variables):
            self.assertEqual(preparation.app_config()["googleClientId"], "client-id")
        with patch.dict("os.environ", {**variables, "GOOGLE_WEB_CLIENT_ID": ""}):
            with self.assertRaises(RuntimeError): preparation.app_config()
        with patch.dict("os.environ", {**variables, "RUNE_NEXUS_API_BASE_URL": "http://api.example.test"}):
            with self.assertRaises(RuntimeError): preparation.app_config()

    def test_app_ui_manifest_copies_only_requested_assets_and_rejects_escape(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "godot"
            (source / "ui").mkdir(parents=True)
            images = root / "assets/images/ui"
            images.mkdir(parents=True)
            (images / "frame.png").write_bytes(b"approved frame")
            (images / "unused.png").write_bytes(b"unused")
            manifest = source / "ui/assets.json"
            manifest.write_text('["ui/frame.png"]')
            output = root / "build/assets"
            with patch.multiple(preparation, ROOT=root, SOURCE=source, ASSETS=output):
                preparation._prepare_app_ui()
                self.assertEqual((output / "app/ui/frame.png").read_bytes(), b"approved frame")
                self.assertFalse((output / "app/ui/unused.png").exists())
                manifest.write_text('["../outside.png"]')
                with self.assertRaises(RuntimeError):
                    preparation._prepare_app_ui()
                manifest.write_text('["ui/missing.png"]')
                with self.assertRaises(FileNotFoundError):
                    preparation._prepare_app_ui()

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
                ("environment", ("dressing", "landmarks", "fern_shadow",
                                 "chapter2_tiles", "chapter2_tiles_optimized", "chapter2_props", "chapter3_tiles", "chapter3_props")
                 + tuple(f"chapter2_stage{stage}_props" for stage in range(6, 11))),
                ("projectiles", ("cannonball",)),
                ("turrets", preparation.TURRET_TYPES),
                ("enemies", preparation.ENEMY_TYPES),
                ("effects", ("machinegun_muzzle",)),
            ):
                for name in names:
                    write(assets / kind / f"{name}.glb", b"asset fixture")
            for name in ("muzzle_flash.png", "gun_smoke.png", "cannon_field.json",
                         "cannon_field.bin", "machinegun_muzzle_noise.bin"):
                write(assets / "effects" / name, b"asset fixture")
            for name in ("crystals.glb", "attachments.json", "rime_mask.bin", "grain.png"):
                write(assets / "effects/enemy_frost" / name, b"frost fixture")
            burn_source = assets / "effects/enemy_burn"
            write(burn_source / "attachments.json", b'{"normal": []}')
            write(burn_source / "flame_atlas.png", b"approved flame atlas")
            write(assets / "ui/turret_levels.png", b"badge atlas")
            write(root / "assets/images/diamond_currency.png", b"diamond icon")
            write(root / "assets/fonts/NotoSansKR-VF.ttf", b"font fixture")
            write(root / "assets/fonts/MaterialIcons-Regular.otf", b"icon font fixture")
            write(root / "assets/fonts/MaterialIcons_LICENSE.txt", b"icon font license")
            write(assets / "ui/labels/slow_shard.png", b"status sprite")
            write(assets / "ui/Roboto-OFL.txt", b"font license")
            def write_map_glb(path, node_name):
                document = json.dumps({"nodes": [{"name": node_name, "extras": {
                    "columns": 2, "rows": 1, "tileTypes": ["path", "build"],
                }}]}).encode()
                document += b" " * (-len(document) % 4)
                write(path, struct.pack("<IIIII", 0x46546C67, 2, 20 + len(document),
                                        len(document), 0x4E4F534A) + document)

            write_map_glb(assets / "environment/terrain.glb", "stage1_environment")
            for stage in range(2, 6):
                write_map_glb(assets / f"environment/dressing_stage{stage}.glb", "stage1_dressing")
            for stage in range(6, 11):
                write_map_glb(assets / f"environment/chapter2_stage{stage}_geology.glb", f"stage{stage}_geology")
            # Preparation consumes the committed catalog with no Dart sources/SDK.
            catalog = {"stages": [{"id": stage, "map": {
                "columns": 2, "rows": 1, "tiles": ["path", "build"], "path": [[0, 0]],
                "tileTheme": "chapterOne" if stage <= 5 else
                    "chapterTwoRift" if stage <= 10 else "chapterThreeForge",
            }} for stage in range(1, 16)]}
            write(source / "content/game_content.json", json.dumps(catalog).encode())
            # Texture staging now parses every GLB, even texture-free fixtures.
            for path in assets.rglob("*.glb"):
                if path.read_bytes() in (b"asset fixture", b"frost fixture"):
                    write_map_glb(path, path.stem)
            png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=")
            image_document = json.dumps({"buffers": [{"byteLength": len(png)}],
                "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": len(png)}],
                "images": [{"bufferView": 0, "mimeType": "image/png"}]}).encode()
            image_document += b" " * (-len(image_document) % 4)
            binary = png + b"\0" * (-len(png) % 4)
            write(assets / "effects/machinegun_muzzle.glb",
                  struct.pack("<IIIII", 0x46546C67, 2, 28 + len(image_document) + len(binary),
                              len(image_document), 0x4E4F534A) + image_document
                  + struct.pack("<II", len(binary), 0x004E4942) + binary)
            protected = [project / ".godot/imported/cached.tres",
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
                self.assertEqual(len(json.loads((project.parent / "chapter_one_frames.json").read_text())), 5)
                self.assertEqual(len(json.loads((project.parent / "chapter_two_frames.json").read_text())), 5)
                self.assertEqual(len(json.loads((project.parent / "chapter_three_frames.json").read_text())), 5)
                for chapter, theme, boss in (("one", "chapterOne", None),
                                            ("two", "chapterTwoRift", "shieldBoss"),
                                            ("three", "chapterThreeForge", "forgeBoss")):
                    frames = json.loads((project.parent / f"chapter_{chapter}_frames.json").read_text())
                    for frame in frames:
                        self.assertEqual(frame["map"]["theme"], theme)
                        expected = set(preparation.ENEMY_TYPES) | ({boss} if boss else set())
                        self.assertEqual({enemy[7] for enemy in frame["enemies"]}, expected)
                self.assertEqual((project / "assets/ui/labels/slow_shard.png").read_bytes(), b"status sprite")
                self.assertEqual((project / "assets/ui/diamond_currency.png").read_bytes(), b"diamond icon")
                self.assertEqual((project / "assets/ui/NotoSansKR-VF.ttf").read_bytes(), b"font fixture")
                self.assertEqual((project / "assets/ui/MaterialIcons-Regular.otf").read_bytes(), b"icon font fixture")
                self.assertTrue((project / "assets/ui/MaterialIcons_LICENSE.txt").is_file())
                self.assertTrue((project / "assets/ui/Roboto-OFL.txt").is_file())
                burn_target = project / "assets/effects/enemy_burn"
                for name in ("attachments.json", "flame_atlas.png"):
                    self.assertEqual((burn_target / name).read_bytes(), (burn_source / name).read_bytes())
                burn_import = burn_target / "flame_atlas.png.import"
                self.assertIn("compress/mode=0", burn_import.read_text())
                self.assertIn("mipmaps/generate=false", burn_import.read_text())
                self.assertIn("detect_3d/compress_to=0", burn_import.read_text())
                copied = project / "materials/core_glass.tres"
                self.assertEqual(copied.read_bytes(), preset.read_bytes())
                foliage_import = project / "assets/environment/dressing.glb.import"
                def subresources():
                    return json.JSONDecoder().raw_decode(foliage_import.read_text().split("_subresources=", 1)[1])[0]
                self.assertEqual(subresources(), {"meshes": {"Dressing Export (temporary)_stage1_dressing_foliage": {"generate/lods": 2}}})
                self.assertNotIn("meshes/generate_lods=false", foliage_import.read_text())
                for path in retired:
                    self.assertFalse(path.exists(), f"retired asset remains: {path}")
                # 식생 import 보정 자체는 UID와 바위/재질 설정을 보존한다.
                existing = {"meshes": {
                    "Dressing Export (temporary)_stage1_dressing_foliage": {"generate/lods": 1, "generate/shadow_meshes": 0},
                    "stage1_dressing_foliage": {"generate/lods": 2},
                    "stage1_dressing_rocks": {"generate/lods": 1},
                }, "materials": {"rock": {"use_external/enabled": False}}}
                foliage_import.write_text('[remap]\nuid="uid://keep"\n\n[params]\nmeshes/generate_lods=true\nmeshes/create_shadow_meshes=true\n_subresources=' + json.dumps(existing) + '\n')
                other_import = project / "assets/environment/terrain.glb.import"
                other_import.write_text('[params]\nmeshes/generate_lods=true\n')

                preparation._preserve_foliage_geometry()
                self.assertIn('uid="uid://keep"', foliage_import.read_text())
                self.assertIn("meshes/generate_lods=true", foliage_import.read_text())
                self.assertIn("meshes/create_shadow_meshes=true", foliage_import.read_text())
                del existing["meshes"]["stage1_dressing_foliage"]
                existing["meshes"]["Dressing Export (temporary)_stage1_dressing_foliage"]["generate/lods"] = 2
                self.assertEqual(subresources(), existing)

                # Repeated prepares replace atlas bytes and undo editor mipmap changes.
                write(burn_source / "flame_atlas.png", b"revised approved flame atlas")
                burn_import.write_text('[params]\nmipmaps/generate=true\n')
                preset.write_bytes(preset.read_bytes() + b"[resource]\nrefraction_enabled = true\n")
                preparation.prepare()
                self.assertEqual(copied.read_bytes(), preset.read_bytes())
                self.assertEqual((burn_target / "flame_atlas.png").read_bytes(), b"revised approved flame atlas")
                self.assertIn("mipmaps/generate=false", burn_import.read_text())
                # 전체 재준비는 빌드 전용 assets를 새로 만들어 낡은 import를 없앤다.
                self.assertNotIn('uid="uid://keep"', foliage_import.read_text())
                self.assertFalse(other_import.exists())

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
