"""승인된 체크 배경 원본에서 외부 연결 회색 영역만 제거."""
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent
NAMES = ['aimSpeed', 'chain', 'explosion', 'multipleProjectiles', 'physicalDamage']


def extract(name):
    im = Image.open(ROOT / f'{name}-opaque.png').convert('RGB')
    rgb = np.asarray(im)
    # 색이 없는 배경 후보. 내부 광택은 외부와 연결되지 않으면 보존.
    neutral = np.ptp(rgb.astype(np.int16), axis=2) <= 2
    h, w = neutral.shape
    visited = np.zeros((h, w), dtype=bool)
    queue = deque()
    for y, x in [(0, x) for x in range(w)] + [(h-1, x) for x in range(w)] + [(y, 0) for y in range(h)] + [(y, w-1) for y in range(h)]:
        if neutral[y, x] and not visited[y, x]:
            visited[y, x] = True
            queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for yy, xx in ((y-1, x), (y+1, x), (y, x-1), (y, x+1)):
            if 0 <= yy < h and 0 <= xx < w and neutral[yy, xx] and not visited[yy, xx]:
                visited[yy, xx] = True
                queue.append((yy, xx))
    # 외부 체크 질감의 고립 점을 제외하고 하나로 이어진 젬 본체 보존.
    remaining = ~visited
    seen = np.zeros_like(remaining)
    largest = []
    for y, x in zip(*np.nonzero(remaining)):
        if seen[y, x]:
            continue
        seen[y, x] = True
        component = [(y, x)]
        queue = deque(component)
        while queue:
            yy, xx = queue.popleft()
            for ny, nx in ((yy-1, xx), (yy+1, xx), (yy, xx-1), (yy, xx+1)):
                if 0 <= ny < h and 0 <= nx < w and remaining[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    component.append((ny, nx))
                    queue.append((ny, nx))
        if len(component) > len(largest):
            largest = component
    body = np.zeros((h, w), dtype=np.uint8)
    ys, xs = zip(*largest)
    body[ys, xs] = 255
    alpha = Image.fromarray(body)
    # 원본 픽셀을 유지하고 경계만 반 픽셀 안티앨리어싱.
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.45))
    out = im.convert('RGBA')
    out.putalpha(alpha)
    out.save(ROOT / f'{name}-transparent.png')
    print(name, 'removed', int(visited.sum()), 'bbox', alpha.getbbox())
    return out


if __name__ == '__main__':
    sheet = Image.new('RGB', (512 * len(NAMES), 544), '#101920')
    draw = ImageDraw.Draw(sheet)
    for i, name in enumerate(NAMES):
        out = extract(name)
        out.thumbnail((480, 480), Image.Resampling.LANCZOS)
        sheet.paste(out, (i*512 + (512-out.width)//2, 8+(480-out.height)//2), out)
        draw.text((i*512+16, 510), name, fill='white')
    sheet.save(ROOT / 'transparency-contact-sheet.png')
