"""Encode the raw RGB frames from capture_support_core.gd (--gif) into a looping GIF.

python3 make_gif.py <gif-frames dir> <output.gif>
Standard library only: one global palette (the 255 most used 5-bit-per-channel colours,
nearest match for the rest) and plain GIF LZW.
"""
import json, struct, sys
from collections import Counter
from pathlib import Path


def key(r, g, b):
    return (r >> 3) << 10 | (g >> 3) << 5 | (b >> 3)


def palette_of(frames):
    counts = Counter()
    for data in frames:
        for i in range(0, len(data), 3 * 7):  # sample every 7th pixel
            counts[key(data[i], data[i + 1], data[i + 2])] += 1
    chosen = [k for k, _ in counts.most_common(256)]
    colours = [((k >> 10) << 3 | 4, ((k >> 5) & 31) << 3 | 4, (k & 31) << 3 | 4) for k in chosen]
    while len(colours) < 256: colours.append((0, 0, 0))
    return colours, {k: i for i, k in enumerate(chosen)}


def index_frame(data, colours, lookup):
    cache = dict(lookup)
    out = bytearray(len(data) // 3)
    for p in range(len(out)):
        i = p * 3
        k = key(data[i], data[i + 1], data[i + 2])
        index = cache.get(k)
        if index is None:
            r, g, b = (k >> 10) << 3, ((k >> 5) & 31) << 3, (k & 31) << 3
            index = min(range(len(colours)), key=lambda c: (colours[c][0] - r) ** 2 + (colours[c][1] - g) ** 2 + (colours[c][2] - b) ** 2)
            cache[k] = index
        out[p] = index
    return out


def lzw(indices, min_size=8):
    clear, end = 1 << min_size, (1 << min_size) + 1
    table = {bytes([i]): i for i in range(clear)}
    size, next_code = min_size + 1, end + 1
    bits, nbits, out = 0, 0, bytearray()

    def emit(code):
        nonlocal bits, nbits
        bits |= code << nbits; nbits += size
        while nbits >= 8:
            out.append(bits & 255); bits >>= 8; nbits -= 8

    emit(clear)
    word = bytes([indices[0]])
    for value in indices[1:]:
        candidate = word + bytes([value])
        if candidate in table:
            word = candidate
            continue
        emit(table[word])
        if next_code < 4095:
            table[candidate] = next_code; next_code += 1
            if next_code > (1 << size) and size < 12: size += 1
        else:
            emit(clear)
            table = {bytes([i]): i for i in range(clear)}
            size, next_code = min_size + 1, end + 1
        word = bytes([value])
    emit(table[word]); emit(end)
    if nbits: out.append(bits & 255)
    return bytes(out)


def main(source, target):
    info = json.loads((source / 'frames.json').read_text())
    w, h, count, fps = info['width'], info['height'], info['count'], info['fps']
    frames = [(source / f'{i:03d}.rgb').read_bytes() for i in range(count)]
    colours, lookup = palette_of(frames)
    gif = bytearray(b'GIF89a' + struct.pack('<HHBBB', w, h, 0xF7, 0, 0))
    for c in colours: gif += bytes(c)
    gif += b'\x21\xFF\x0BNETSCAPE2.0\x03\x01\x00\x00\x00'  # loop forever
    delay = round(100 / fps)
    for data in frames:
        gif += b'\x21\xF9\x04\x00' + struct.pack('<H', delay) + b'\x00\x00'
        gif += b'\x2C' + struct.pack('<HHHHB', 0, 0, w, h, 0) + b'\x08'
        stream = lzw(index_frame(data, colours, lookup))
        for i in range(0, len(stream), 255):
            chunk = stream[i:i + 255]; gif += bytes([len(chunk)]) + chunk
        gif += b'\x00'
    gif += b'\x3B'
    target.write_bytes(gif)
    print('GIF', target, w, h, count, len(gif))


if __name__ == '__main__':
    main(Path(sys.argv[1]), Path(sys.argv[2]))
