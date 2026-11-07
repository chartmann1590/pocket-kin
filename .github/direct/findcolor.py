#!/usr/bin/env python3
# Reads a raw `screencap` (no -p) on stdin and prints "x y" of a band of a given flat colour.
# args: hex tol min_px ymin_permille ymax_permille first|last dy
import sys, struct
hexc, tol, minpx, ymin, ymax, which, dy = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5]), sys.argv[6], int(sys.argv[7])
c = tuple(int(hexc[i:i+2], 16) for i in (0, 2, 4))
buf = sys.stdin.buffer.read()
w, h = struct.unpack('<II', buf[:8]); hdr = len(buf) - w*h*4
y0, y1 = h*ymin//1000, h*ymax//1000
rows = []
for y in range(y0, y1):
    o = hdr + y*w*4; xs = []
    for x in range(0, w, 2):
        p = o + x*4
        if abs(buf[p]-c[0]) <= tol and abs(buf[p+1]-c[1]) <= tol and abs(buf[p+2]-c[2]) <= tol: xs.append(x)
    if len(xs)*2 >= minpx: rows.append((y, xs[len(xs)//2]))
runs = []
for y, x in rows:
    if runs and y - runs[-1][-1][0] <= 6: runs[-1].append((y, x))
    else: runs.append([(y, x)])
runs = [r for r in runs if len(r) >= 8 and r[-1][0] < y1 - 4]
sys.stderr.write("runs: %s\n" % [(r[0][0], r[-1][0]) for r in runs])
if runs:
    r = runs[0] if which == 'first' else runs[-1]
    yy = (r[0][0] + r[-1][0])//2 if dy == 0 else r[-1][0] - dy
    print(r[len(r)//2][1] if dy == 0 else w//2, yy)
