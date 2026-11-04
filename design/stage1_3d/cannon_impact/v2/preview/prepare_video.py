"""렌더 원본의 프레임 간격을 보존하고 반복 사이에 빈 장면을 배치."""
import json
import shutil
from pathlib import Path

root = Path(__file__).resolve().parent
for index in range(1, 33):
    if not (root / 'render' / f'{index:04d}.png').is_file():
        raise RuntimeError(f'누락된 렌더 프레임: {index}')
sequence = ([32] * 10 + list(range(1, 33)) + [32] * 20) * 3
frames = [
    {'file': f'render/{frame:04d}.png', 'time': index * 11 / 320}
    for index, frame in enumerate(sequence)
]
(root / 'frames.json').write_text(json.dumps(frames))
shutil.copyfile(root / 'render' / '0008.png', root / 'effect-preview.png')
print(f'{len(frames)} frames, normal speed 1.1s, 3 repetitions')
