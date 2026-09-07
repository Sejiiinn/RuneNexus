"""APK 원본 바이트를 보존하는 스트리밍 차등 패치 생성·검증."""
import argparse
import gzip
import hashlib
import os
from pathlib import Path
import struct
import tempfile
import zipfile

MAGIC = b"RNDELTA1"
MAX_SIZE = 512 * 1024 * 1024
MAX_OPERATIONS = 100_000
CHUNK_SIZE = 64 * 1024


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
                intervals.append((start, end))
    intervals.sort()
    previous = 0
    for start, end in intervals:
        if start < previous:
            raise ValueError("Overlapping ZIP entries")
        previous = end
    return intervals


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


def create_patch(base: Path, target: Path, output: Path) -> None:
    """ZIP 데이터 청크를 재사용하며 결정론적 gzip 패치 생성."""
    base, target, output = Path(base), Path(target), Path(output)
    base_size, target_size = _size(base), _size(target)
    base_intervals, target_intervals = _intervals(base), _intervals(target)
    index = {}
    with base.open("rb") as stream:
        for start, end in base_intervals:
            for offset, data in _chunks(stream, start, end):
                index.setdefault((len(data), hashlib.sha256(data).digest()), offset)
    handle, temporary = _output_temp(output, [base, target])
    try:
        with handle, gzip.GzipFile(filename="", mode="wb", fileobj=handle, mtime=0) as patch:
            patch.write(MAGIC + struct.pack(">QQ", base_size, target_size) + _hash(base) + _hash(target))
            count = 0
            with target.open("rb") as stream, base.open("rb") as original:
                position = 0
                # 헤더·서명 블록·중앙 디렉터리도 바이트 그대로 보존
                regions = []
                for start, end in target_intervals:
                    if position < start:
                        regions.append((position, start, False))
                    regions.append((start, end, True))
                    position = end
                if position < target_size:
                    regions.append((position, target_size, False))
                for start, end, reusable in regions:
                    for _, data in _chunks(stream, start, end):
                        count += 1
                        if count > MAX_OPERATIONS:
                            raise ValueError("Too many patch operations")
                        offset = index.get((len(data), hashlib.sha256(data).digest())) if reusable else None
                        if offset is not None:
                            original.seek(offset)
                            if _read(original, len(data)) != data:
                                offset = None
                        if offset is None:
                            patch.write(b"\x01" + struct.pack(">Q", len(data)) + data)
                        else:
                            patch.write(b"\x00" + struct.pack(">QQ", offset, len(data)))
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
