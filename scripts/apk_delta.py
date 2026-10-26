"""APK 원본 바이트를 보존하는 스트리밍 차등 패치 생성·검증."""
import argparse
import gzip
import hashlib
import os
from pathlib import Path
import struct
import tempfile
import zipfile

from audit_godot_pack import PackError, read_directory

MAGIC = b"RNDELTA1"
MAX_SIZE = 512 * 1024 * 1024
MAX_OPERATIONS = 100_000
CHUNK_SIZE = 64 * 1024
# 연속 리터럴을 한 연산으로 묶되 메모리에 쌓는 양은 제한
LITERAL_FLUSH = 16 * 1024 * 1024


def _size(path):
    size = path.stat().st_size
    if not 1 <= size <= MAX_SIZE:
        raise ValueError("APK size must be between 1 byte and 512 MiB")
    return size


def _hash(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(CHUNK_SIZE), b""):
            digest.update(chunk)
    return digest.digest()


def _read(stream, size):
    data = stream.read(size)
    if len(data) != size:
        raise ValueError("Truncated patch or APK")
    return data


def _u64(stream):
    return struct.unpack(">Q", _read(stream, 8))[0]


def _intervals(path):
    """로컬 헤더에서 압축 데이터의 실제 위치 계산."""
    return [(start, end) for start, end, _ in _entries(path)]


def _entries(path):
    intervals = []
    size = _size(path)
    with zipfile.ZipFile(path) as archive, path.open("rb") as stream:
        for entry in archive.infolist():
            stream.seek(entry.header_offset)
            header = _read(stream, 30)
            if header[:4] != b"PK\x03\x04":
                raise ValueError("Invalid ZIP local header")
            name_size, extra_size = struct.unpack_from("<HH", header, 26)
            start = entry.header_offset + 30 + name_size + extra_size
            end = start + entry.compress_size
            if start < 0 or end > size:
                raise ValueError("ZIP entry exceeds APK bounds")
            if end > start:
                intervals.append((start, end, entry))
    intervals.sort(key=lambda item: item[:2])
    previous = 0
    for start, end, _ in intervals:
        if start < previous:
            raise ValueError("Overlapping ZIP entries")
        previous = end
    return intervals


class _Window:
    """APK 안 무압축 항목을 독립 파일처럼 읽는 창."""

    def __init__(self, stream, start, size):
        self.stream, self.start, self.size, self.position = stream, start, size, 0

    def seek(self, offset, whence=0):
        self.position = {0: offset, 1: self.position + offset, 2: self.size + offset}[whence]
        return self.position

    def tell(self):
        return self.position

    def read(self, count):
        count = max(0, min(count, self.size - self.position))
        self.stream.seek(self.start + self.position)
        data = self.stream.read(count)
        self.position += len(data)
        return data


def _pack_payloads(stream, entries):
    """무압축 Godot PCK의 파일별 payload 범위(APK 절대 위치).

    PCK 안 파일 하나의 크기가 바뀌면 뒤 바이트가 모두 밀려 고정 64KB 청크가
    어긋난다. 파일 단위 범위로 재사용하면 밀림과 무관하게 같은 파일을 찾는다.
    """
    ranges = set()
    for start, end, entry in entries:
        if not entry.filename.endswith(".pck") or entry.compress_type != zipfile.ZIP_STORED:
            continue
        try:
            pack = read_directory(_Window(stream, start, end - start))
        except PackError:
            continue
        ranges.update((start + item["offset"], start + item["offset"] + item["bytes"])
                      for item in pack["entries"] if item["bytes"])
    payloads, previous = [], 0
    for start, end in sorted(ranges):
        if start >= previous:
            payloads.append((start, end))
            previous = end
    return payloads


def _chunks(stream, start, end):
    stream.seek(start)
    while start < end:
        data = _read(stream, min(CHUNK_SIZE, end - start))
        yield start, data
        start += len(data)


def _output_temp(output, inputs):
    output = Path(output)
    for source in inputs:
        if output.resolve() == source.resolve() or (
            output.exists() and os.path.samefile(output, source)
        ):
            raise ValueError("Output must not overwrite an input")
    handle = tempfile.NamedTemporaryFile(dir=output.parent, prefix=".apk-delta-", delete=False)
    return handle, Path(handle.name)


class _Operations:
    """인접 COPY·리터럴을 합쳐 연산 수와 패치 크기 축소."""

    def __init__(self, patch):
        self.patch, self.count, self.copy, self.literal, self.literal_size = patch, 0, None, [], 0

    def _emit(self, header, data=b""):
        self.count += 1
        if self.count > MAX_OPERATIONS:
            raise ValueError("Too many patch operations")
        self.patch.write(header + data)

    def _flush_copy(self):
        if self.copy:
            self._emit(b"\x00" + struct.pack(">QQ", *self.copy))
            self.copy = None

    def _flush_literal(self):
        if self.literal:
            self._emit(b"\x01" + struct.pack(">Q", self.literal_size), b"".join(self.literal))
            self.literal, self.literal_size = [], 0

    def copy_from(self, offset, length):
        self._flush_literal()
        if self.copy and self.copy[0] + self.copy[1] == offset:
            self.copy[1] += length
        else:
            self._flush_copy()
            self.copy = [offset, length]

    def add(self, data):
        self._flush_copy()
        self.literal.append(data)
        self.literal_size += len(data)
        if self.literal_size >= LITERAL_FLUSH:
            self._flush_literal()

    def finish(self):
        self._flush_copy()
        self._flush_literal()


def _same(original, offset, stream, start, length):
    """해시 일치 후보를 실제 바이트로 재확인."""
    stream.seek(start)
    for position in range(0, length, CHUNK_SIZE):
        original.seek(offset + position)
        size = min(CHUNK_SIZE, length - position)
        if _read(original, size) != _read(stream, size):
            return False
    return True


def _range_hash(stream, start, end, index=None):
    digest = hashlib.sha256()
    for offset, data in _chunks(stream, start, end):
        digest.update(data)
        if index is not None:
            index.setdefault((len(data), hashlib.sha256(data).digest()), offset)
    return digest.digest()


def create_patch(base: Path, target: Path, output: Path) -> None:
    """ZIP 데이터·PCK 파일 단위로 원본을 재사용하는 결정론적 gzip 패치 생성."""
    base, target, output = Path(base), Path(target), Path(output)
    base_size, target_size = _size(base), _size(target)
    base_entries, target_entries = _entries(base), _entries(target)
    index, payload_index = {}, {}
    with base.open("rb") as stream:
        for start, end, _ in base_entries:
            for offset, data in _chunks(stream, start, end):
                index.setdefault((len(data), hashlib.sha256(data).digest()), offset)
        # 바뀐 파일도 같은 파일 시작 기준 청크로 앞부분을 재사용
        for start, end in _pack_payloads(stream, base_entries):
            payload_index.setdefault((end - start, _range_hash(stream, start, end, index)), start)
    handle, temporary = _output_temp(output, [base, target])
    try:
        with handle, gzip.GzipFile(filename="", mode="wb", fileobj=handle, mtime=0) as patch:
            patch.write(MAGIC + struct.pack(">QQ", base_size, target_size) + _hash(base) + _hash(target))
            operations = _Operations(patch)
            with target.open("rb") as stream, base.open("rb") as original:
                payloads = _pack_payloads(stream, target_entries)
                # 헤더·서명 블록·중앙 디렉터리도 바이트 그대로 보존
                regions, position = [], 0
                for start, end, _ in target_entries:
                    if position < start:
                        regions.append((position, start, False))
                    regions.append((start, end, True))
                    position = end
                if position < target_size:
                    regions.append((position, target_size, False))
                split, cursor = [], 0
                for start, end, reusable in regions:
                    while cursor < len(payloads) and payloads[cursor][1] <= end:
                        payload_start, payload_end = payloads[cursor]
                        if payload_start >= start:
                            if start < payload_start:
                                split.append((start, payload_start, reusable, False))
                            split.append((payload_start, payload_end, reusable, True))
                            start = payload_end
                        cursor += 1
                    if start < end:
                        split.append((start, end, reusable, False))
                for start, end, reusable, payload in split:
                    if payload:
                        offset = payload_index.get((end - start, _range_hash(stream, start, end)))
                        if offset is not None and _same(original, offset, stream, start, end - start):
                            operations.copy_from(offset, end - start)
                            continue
                    for chunk_start, data in _chunks(stream, start, end):
                        offset = index.get((len(data), hashlib.sha256(data).digest())) if reusable else None
                        if offset is not None:
                            original.seek(offset)
                            if _read(original, len(data)) != data:
                                offset = None
                        if offset is None:
                            operations.add(data)
                        else:
                            operations.copy_from(offset, len(data))
                operations.finish()
            patch.write(b"\xff")
        os.replace(temporary, output)
    finally:
        temporary.unlink(missing_ok=True)


def apply_patch(base: Path, patch: Path, output: Path) -> None:
    """크기·범위·해시 검증 후 복원 APK 원자적 게시."""
    base, patch, output = Path(base), Path(patch), Path(output)
    actual_size = _size(base)
    handle, temporary = _output_temp(output, [base, patch])
    try:
        with handle as result, gzip.open(patch, "rb") as source, base.open("rb") as original:
            if _read(source, 8) != MAGIC:
                raise ValueError("Invalid patch magic")
            base_size, target_size = _u64(source), _u64(source)
            base_hash, target_hash = _read(source, 32), _read(source, 32)
            if base_size != actual_size or not 1 <= target_size <= MAX_SIZE:
                raise ValueError("Invalid APK size")
            if _hash(base) != base_hash:
                raise ValueError("Base APK hash mismatch")
            written, count = 0, 0
            digest = hashlib.sha256()
            while True:
                opcode = _read(source, 1)[0]
                if opcode == 255:
                    break
                count += 1
                if count > MAX_OPERATIONS:
                    raise ValueError("Too many patch operations")
                if opcode == 0:
                    offset, length = _u64(source), _u64(source)
                    if offset > base_size or length > base_size - offset:
                        raise ValueError("COPY exceeds base APK bounds")
                    original.seek(offset)
                    data_source = original
                elif opcode == 1:
                    length = _u64(source)
                    data_source = source
                else:
                    raise ValueError("Invalid patch operation")
                if length == 0 or length > target_size - written:
                    raise ValueError("Operation exceeds target APK bounds")
                remaining = length
                while remaining:
                    data = _read(data_source, min(remaining, CHUNK_SIZE))
                    result.write(data)
                    digest.update(data)
                    remaining -= len(data)
                written += length
            if source.read(1):
                raise ValueError("Trailing patch data")
            if written != target_size or digest.digest() != target_hash:
                raise ValueError("Target APK size or hash mismatch")
        os.replace(temporary, output)
    finally:
        temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["create", "apply"])
    parser.add_argument("base", type=Path)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    (create_patch if args.command == "create" else apply_patch)(args.base, args.input, args.output)
