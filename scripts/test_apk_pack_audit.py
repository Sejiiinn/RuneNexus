"""PCK audit fixtures; no Godot or production asset writes."""
import hashlib
import io
from pathlib import Path
import struct
import tempfile
import unittest
import zipfile

from audit_godot_pack import PackError, audit_path, audit_stream


def pack_fixture(alias=False):
    payload = b"same payload"
    base = 112
    data = payload if alias else payload * 2
    directory = base + len(data)
    header = struct.pack("<6I2Q", 0x43504447, 4, 4, 7, 2, 2, base, directory)
    rows = []
    for i in range(2):
        path = f"res://fixture{i}.bin".encode()
        path += b"\0" * (-len(path) % 4)
        rows.append(struct.pack("<I", len(path)) + path + struct.pack(
            "<2Q16sI", 0 if alias else i * len(payload), len(payload), hashlib.md5(payload).digest(), 0))
    return header.ljust(base, b"\0") + data + struct.pack("<I", 2) + b"".join(rows)


class PackAuditTest(unittest.TestCase):
    def test_exact_duplicates_and_offset_aliases_are_distinguished(self):
        for alias in (False, True):
            report = audit_stream(io.BytesIO(pack_fixture(alias)))
            self.assertEqual(report["entry_count"], 2)
            self.assertEqual(report["logical_duplicate_bytes"], 12)
            self.assertEqual(report["distinct_range_duplicate_bytes"], 0 if alias else 12)
            self.assertEqual(report["entries"][0]["sha256"], hashlib.sha256(b"same payload").hexdigest())

    def test_apk_matches_standalone_without_extraction(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pack = root / "game.pck"
            apk = root / "game.apk"
            data = pack_fixture()
            pack.write_bytes(data)
            with zipfile.ZipFile(apk, "w", zipfile.ZIP_DEFLATED) as archive:
                archive.writestr("assets/game.pck", data)
            self.assertEqual(audit_path(pack)["entries"], audit_path(apk)["entries"])
            self.assertEqual(pack.read_bytes(), data)
            self.assertEqual(set(root.iterdir()), {pack, apk})
            with self.assertRaises(PackError):
                audit_path(apk, "assets/missing.pck")

    def test_malformed_and_unsupported_pack_rejected(self):
        data = pack_fixture()
        directory, = struct.unpack_from("<Q", data, 32)
        path_length, = struct.unpack_from("<I", data, directory + 4)
        file_fields = directory + 8 + path_length
        mutations = [(4, "<I", 3), (20, "<I", 1), (32, "<Q", len(data) + 1),
                     (directory, "<I", 1000000), (directory + 4, "<I", 0xFFFFFFFF),
                     (file_fields, "<Q", len(data)), (file_fields + 8, "<Q", len(data)),
                     (file_fields + 32, "<I", 4)]
        for offset, fmt, value in mutations:
            with self.subTest(offset=offset, value=value):
                changed = bytearray(data)
                struct.pack_into(fmt, changed, offset, value)
                with self.assertRaises(PackError):
                    audit_stream(io.BytesIO(changed))
        with self.assertRaises(PackError):
            audit_stream(io.BytesIO(data[:30]))


if __name__ == "__main__":
    unittest.main()
