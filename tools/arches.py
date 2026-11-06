#!/usr/bin/env python3
"""Traces a table's outline for the hero row. Pass the 600x1560 table PNGs from the game's
headless harness (SKINPNG=dir MINUTES=0 ./pinsim all 1). Prints each table's CSS polygon: the
convex hull of everything that isn't the corner background, so the cut sits just outside the
rim. Paste each one into that table's --outline in index.html. macOS only (uses sips)."""
import pathlib, struct, subprocess, sys, tempfile
W, H = 600, 1560

def pixels(path):
    with tempfile.TemporaryDirectory() as d:
        bmp = pathlib.Path(d) / 'x.bmp'
        subprocess.run(['sips', '-s', 'format', 'bmp', str(path), '--out', str(bmp)], check=True, capture_output=True)
        b = bmp.read_bytes()
    off, w, h, bpp = struct.unpack_from('<I', b, 10)[0], *struct.unpack_from('<ii', b, 18), struct.unpack_from('<H', b, 28)[0]
    step, row = bpp // 8, ((w * bpp + 31) // 32) * 4
    def at(x, y):
        o = off + ((abs(h) - 1 - y) if h > 0 else y) * row + x * step
        return b[o + 2], b[o + 1], b[o]
    return at

def hull(points):
    pts = sorted(set(points))
    def half(seq):
        out = []
        for p in seq:
            while len(out) > 1 and (out[-1][0]-out[-2][0])*(p[1]-out[-2][1]) - (out[-1][1]-out[-2][1])*(p[0]-out[-2][0]) <= 0:
                out.pop()
            out.append(p)
        return out[:-1]
    return half(pts) + half(pts[::-1])

for path in sys.argv[1:]:
    at = pixels(path)
    bg = at(1, 1)
    differs = lambda x, y: sum(abs(a - b) for a, b in zip(at(x, y), bg)) > 24
    pts = []
    for y in range(260):
        xs = [x for x in range(W) if differs(x, y)]
        if xs:
            pts += [(max(0, xs[0] - 1), max(0, y - 1)), (min(W, xs[-1] + 2), max(0, y - 1))]
    left, right = min(x for x, _ in pts), max(x for x, _ in pts)
    shape = hull(pts + [(left, H), (right, H)])
    print(pathlib.Path(path).stem, 'polygon(' + ','.join(f'{x/W*100:.2f}% {y/H*100:.2f}%' for x, y in shape) + ')')
