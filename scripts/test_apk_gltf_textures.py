"""Geometry preservation and shared-image packaging contracts, without Godot."""
import base64
import copy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest

from prepare_shared_gltf_textures import externalize_textures


PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII="
)
VERTICES = struct.pack("<9f", 0, 0, 0, 1, 0, 0, 0, 1, 0)


def write_glb(path, document, binary):
    text = json.dumps(document).encode()
    text += b" " * (-len(text) % 4)
    padded = binary + b"\0" * (-len(binary) % 4)
    raw = (struct.pack("<IIIII", 0x46546C67, 2, 28 + len(text) + len(padded),
                       len(text), 0x4E4F534A) + text
           + struct.pack("<II", len(padded), 0x004E4942) + padded)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)


def read_glb(path):
    raw = path.read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    return json.loads(raw[20:20 + length]), raw[20 + length:]


def fixture():
    binary = VERTICES + PNG
    return {
        "asset": {"version": "2.0"},
        "buffers": [{"byteLength": len(binary)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(VERTICES), "target": 34962},
            {"buffer": 0, "byteOffset": len(VERTICES), "byteLength": len(PNG)},
        ],
        "accessors": [{"bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3"}],
        "images": [{"name": "authored_normal", "bufferView": 1, "mimeType": "image/png",
                    "extras": {"artist": "preserve me"}}],
        "textures": [{"source": 0, "sampler": 0}],
        "samplers": [{"magFilter": 9729, "wrapS": 10497}],
        "materials": [{"name": "authored_material", "normalTexture": {"index": 0, "scale": 1.2},
                       "pbrMetallicRoughness": {"metallicFactor": .7, "roughnessFactor": .4}}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "material": 0}]}],
        "nodes": [{"mesh": 0, "translation": [1, 2, 3], "extras": {"grid_cell": [2, 4]}}],
        "scenes": [{"nodes": [0]}], "scene": 0,
    }, binary


class SharedGltfTexturesTest(unittest.TestCase):
    def test_aliases_share_exact_payload_and_preserve_all_nonimage_data(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            assets = root / "staged"
            document, binary = fixture()
            source = root / "original.glb"
            write_glb(source, document, binary)
            original = source.read_bytes()
            paths = [assets / "environment/a.glb", assets / "turrets/b.glb"]
            for i, path in enumerate(paths):
                variant = copy.deepcopy(document)
                variant["images"][0]["name"] = f"different_alias_{i}"
                write_glb(path, variant, binary)
            before = {path: read_glb(path) for path in paths}
            manifest = externalize_textures(assets)
            self.assertEqual(manifest["embedded_image_count"], 2)
            self.assertEqual(manifest["unique_image_count"], 1)
            self.assertEqual(manifest["deduplicated_embedded_bytes"], len(PNG))
            self.assertEqual(manifest["normal_role_collisions"], [])
            self.assertEqual([row["roles"] for row in manifest["images"]], [["normalTexture"]] * 2)
            shared = assets / "shared_textures" / (hashlib.sha256(PNG).hexdigest() + ".png")
            self.assertEqual(shared.read_bytes(), PNG)
            self.assertEqual(list(shared.parent.iterdir()), [shared])
            for path in paths:
                result, tail = read_glb(path)
                previous, previous_tail = before[path]
                self.assertEqual(tail, previous_tail)  # BIN header, geometry and image bytes.
                self.assertEqual({k: v for k, v in result.items() if k != "images"},
                                 {k: v for k, v in previous.items() if k != "images"})
                image = result["images"][0]
                self.assertEqual(image["name"], previous["images"][0]["name"])
                self.assertEqual(image["extras"], previous["images"][0]["extras"])
                self.assertNotIn("bufferView", image)
                self.assertNotIn("mimeType", image)
                self.assertEqual((path.parent / image["uri"]).resolve(), shared.resolve())
            self.assertEqual(source.read_bytes(), original)

    def test_repeat_is_byte_identical_and_existing_safe_external_uri_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            assets = Path(directory)
            document, binary = fixture()
            write_glb(assets / "embedded.glb", document, binary)
            external = copy.deepcopy(document)
            external["images"] = [{"name": "external", "uri": "../textures/original%20image.png"}]
            image = assets / "textures/original image.png"
            image.parent.mkdir()
            image.write_bytes(PNG)
            glb = assets / "models/external.glb"
            write_glb(glb, external, binary)
            original_external = glb.read_bytes()
            externalize_textures(assets)
            before = {p: p.read_bytes() for p in assets.rglob("*") if p.is_file()}
            second = externalize_textures(assets)
            self.assertEqual(second["rewritten_glb_count"], 0)
            self.assertEqual(second["embedded_image_count"], 0)
            self.assertEqual(second["shared_texture_count"], 1)
            self.assertEqual(before, {p: p.read_bytes() for p in assets.rglob("*") if p.is_file()})
            self.assertEqual(glb.read_bytes(), original_external)

    def test_invalid_mime_bounds_uri_and_role_collision_fail_before_writes(self):
        for scenario in ("mime", "bounds", "outside", "remote", "missing", "roles"):
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                assets = root / "assets"
                document, binary = fixture()
                if scenario == "mime":
                    document["images"][0]["mimeType"] = "image/jpeg"
                elif scenario == "bounds":
                    document["bufferViews"][1]["byteLength"] += 100
                elif scenario in ("outside", "remote", "missing"):
                    (root / "outside.png").write_bytes(PNG)
                    uri = {"outside": "../outside.png", "remote": "https://example.com/a.png",
                           "missing": "missing.png"}[scenario]
                    document["images"] = [{"uri": uri}]
                else:
                    document["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"] = {"index": 0}
                glb = assets / "model.glb"
                write_glb(glb, document, binary)
                before = glb.read_bytes()
                with self.assertRaises(ValueError):
                    externalize_textures(assets)
                self.assertEqual(glb.read_bytes(), before)
                self.assertFalse((assets / "shared_textures").exists())


if __name__ == "__main__":
    unittest.main()
