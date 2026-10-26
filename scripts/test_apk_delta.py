"""차등 패치 원본 보존·손상 거부 회귀 검사."""
import gzip
import hashlib
import os
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import apk_delta


class ApkDeltaTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.base, self.target = root / 'old.apk', root / 'new.apk'
        self.patch, self.output = root / 'update.delta', root / 'restored.apk'
        stable = os.urandom(200_000)
        self.make_zip(self.base, [('removed', b'old'), ('stable', stable), ('changed', b'before')])
        self.make_zip(self.target, [('added', b'new prefix' * 100), ('stable', stable), ('changed', b'after')])

    def make_zip(self, path, entries):
        with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            for name, data in entries:
                archive.writestr(name, data)

    def create(self):
        apk_delta.create_patch(self.base, self.target, self.patch)

    def rewrite(self, raw):
        self.patch.write_bytes(gzip.compress(raw, mtime=0))

    def assert_rejected(self):
        self.output.write_bytes(b'preserved')
        with self.assertRaises((ValueError, OSError, EOFError)):
            apk_delta.apply_patch(self.base, self.patch, self.output)
        self.assertEqual(self.output.read_bytes(), b'preserved')
        self.assertFalse(list(self.output.parent.glob('.apk-delta-*')))

    def test_shifted_entries_roundtrip_and_deterministic_savings(self):
        self.create()
        first = self.patch.read_bytes()
        self.create()
        self.assertEqual(first, self.patch.read_bytes())
        apk_delta.apply_patch(self.base, self.patch, self.output)
        self.assertEqual(self.target.read_bytes(), self.output.read_bytes())
        self.assertLess(self.patch.stat().st_size, self.target.stat().st_size // 10)

    def make_pack(self, files):
        base = 112
        data, rows = b'', []
        for name, payload in files:
            path = name.encode()
            path += b'\0' * (-len(path) % 4)
            rows.append(struct.pack('<I', len(path)) + path + struct.pack(
                '<2Q16sI', len(data), len(payload), hashlib.md5(payload).digest(), 0))
            data += payload + b'\0' * (-len(payload) % 16)
        header = struct.pack('<6I2Q', 0x43504447, 4, 4, 7, 2, 2, base, base + len(data))
        return header.ljust(base, b'\0') + data + struct.pack('<I', len(files)) + b''.join(rows)

    def test_pack_files_shifted_by_resized_file_are_reused(self):
        # 앞쪽 파일 크기 변화로 뒤 파일이 밀려도 PCK 파일 단위로 재사용해야 한다
        stable, tail = os.urandom(400_000), os.urandom(300_000)
        for path, config, ending in [(self.base, b'a' * 100, b'old!'), (self.target, b'b' * 133, b'new!')]:
            pack = self.make_pack([('res://config.cfg', config), ('res://stable.bin', stable),
                                   ('res://tail.bin', tail[:-4] + ending)])
            with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
                archive.writestr('classes.dex', b'code' * 1000)
                archive.writestr(zipfile.ZipInfo('assets/game.pck'), pack, compress_type=zipfile.ZIP_STORED)
        self.create()
        apk_delta.apply_patch(self.base, self.patch, self.output)
        self.assertEqual(self.target.read_bytes(), self.output.read_bytes())
        self.assertLess(self.patch.stat().st_size, 80_000)

    def test_stored_entries_and_zip_comments(self):
        stable = os.urandom(150_000)
        for path, prefix in [(self.base, b'old'), (self.target, b'new-prefix')]:
            with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_STORED) as archive:
                archive.writestr('prefix', prefix)
                archive.writestr('stable', stable)
                archive.comment = prefix * 100
        self.create()
        apk_delta.apply_patch(self.base, self.patch, self.output)
        self.assertEqual(self.target.read_bytes(), self.output.read_bytes())
        self.assertLess(self.patch.stat().st_size, self.target.stat().st_size // 10)

    def test_wrong_base(self):
        self.create()
        with self.base.open('r+b') as stream:
            stream.write(b'NO')
        self.assert_rejected()

    def test_truncated_and_tampered(self):
        self.create()
        original = self.patch.read_bytes()
        for data in [original[:-8], original[:20]]:
            self.patch.write_bytes(data)
            self.assert_rejected()
        self.patch.write_bytes(original)
        raw = bytearray(gzip.decompress(original))
        raw[56] ^= 1  # 대상 해시 손상
        self.rewrite(raw)
        self.assert_rejected()

    def test_invalid_operations_and_bounds(self):
        self.create()
        header = gzip.decompress(self.patch.read_bytes())[:88]
        invalid = [
            b'\x02',
            b'\x00' + struct.pack('>QQ', self.base.stat().st_size, 1),
            b'\x01' + struct.pack('>Q', 0),
            b'\x01' + struct.pack('>Q', apk_delta.MAX_SIZE + 1),
            b'\xff',
        ]
        for operation in invalid:
            self.rewrite(header + operation + b'\xff')
            self.assert_rejected()

    def test_trailing_data_and_oversized_header(self):
        self.create()
        raw = gzip.decompress(self.patch.read_bytes())
        self.rewrite(raw + b'x')
        self.assert_rejected()
        self.rewrite(raw[:16] + struct.pack('>Q', apk_delta.MAX_SIZE + 1) + raw[24:])
        self.assert_rejected()

    def test_operation_and_input_limits(self):
        self.create()
        with patch.object(apk_delta, 'MAX_OPERATIONS', 1):
            self.assert_rejected()
            with self.assertRaises(ValueError):
                self.create()
        with patch.object(apk_delta, 'MAX_SIZE', 1):
            with self.assertRaises(ValueError):
                self.create()

    def test_never_overwrites_input(self):
        self.create()
        digest = hashlib.sha256(self.base.read_bytes()).digest()
        for output in [self.base, self.patch]:
            with self.assertRaises(ValueError):
                apk_delta.apply_patch(self.base, self.patch, output)
        with self.assertRaises(ValueError):
            apk_delta.create_patch(self.base, self.target, self.target)
        alias = self.base.parent / 'alias.apk'
        os.link(self.base, alias)
        with self.assertRaises(ValueError):
            apk_delta.apply_patch(self.base, self.patch, alias)
        self.assertEqual(digest, hashlib.sha256(self.base.read_bytes()).digest())


if __name__ == '__main__':
    unittest.main()
