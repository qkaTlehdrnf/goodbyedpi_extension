#!/usr/bin/env python3
"""Generate simple shield PNG icons (no external deps) for the extension."""
import struct, zlib, os

OUT = os.path.join(os.path.dirname(__file__), "..", "extension", "icons")
os.makedirs(OUT, exist_ok=True)


def in_rounded(x, y, w, h, r):
    # rounded-rect mask in pixel space
    if x < r and y < r:
        return (r - x) ** 2 + (r - y) ** 2 <= r * r
    if x > w - r and y < r:
        return (x - (w - r)) ** 2 + (r - y) ** 2 <= r * r
    if x < r and y > h - r:
        return (r - x) ** 2 + (y - (h - r)) ** 2 <= r * r
    if x > w - r and y > h - r:
        return (x - (w - r)) ** 2 + (y - (h - r)) ** 2 <= r * r
    return True


def in_shield(nx, ny):
    # nx, ny normalized to [-1, 1], origin at center, +y up
    if ny > 0.82 or ny < -0.9:
        return False
    if ny >= -0.25:
        hw = 0.66
    else:
        t = (ny + 0.25) / (-0.65)
        hw = 0.66 * (1 - t)
    return abs(nx) <= hw


def in_check(nx, ny):
    # a bold check mark, coordinates normalized
    # segment 1: (-0.35,-0.02) -> (-0.08,-0.30) ; segment 2: (-0.08,-0.30) -> (0.40,0.34)
    def near_seg(px, py, ax, ay, bx, by, thick):
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy
        t = 0 if L2 == 0 else ((px - ax) * dx + (py - ay) * dy) / L2
        t = max(0, min(1, t))
        cx, cy = ax + t * dx, ay + t * dy
        return (px - cx) ** 2 + (py - cy) ** 2 <= thick * thick
    return near_seg(nx, ny, -0.34, 0.02, -0.06, -0.28, 0.11) or \
        near_seg(nx, ny, -0.06, -0.28, 0.40, 0.36, 0.11)


def make(size):
    w = h = size
    px = bytearray()
    r = size * 0.18
    for y in range(h):
        px.append(0)  # PNG filter byte per row
        for x in range(w):
            # gradient background top->bottom (indigo -> teal)
            g = y / max(1, h - 1)
            bg = (
                int(37 + (16 - 37) * g),      # R
                int(99 + (185 - 99) * g),     # G
                int(235 + (160 - 235) * g),   # B
            )
            inside_rr = in_rounded(x + 0.5, y + 0.5, w, h, r)
            # normalized coords, shield occupies central area
            nx = (x + 0.5 - w / 2) / (w * 0.42)
            ny = -(y + 0.5 - h / 2) / (h * 0.42)
            if not inside_rr:
                px.extend((0, 0, 0, 0))
            elif in_check(nx, ny) and in_shield(nx, ny):
                px.extend((37, 99, 235, 255))   # indigo check
            elif in_shield(nx, ny):
                px.extend((255, 255, 255, 255))  # white shield
            else:
                px.extend((*bg, 255))
    raw = bytes(px)

    def chunk(typ, data):
        c = struct.pack(">I", len(data)) + typ + data
        return c + struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF)

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    out = sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path = os.path.join(OUT, f"icon{size}.png")
    with open(path, "wb") as f:
        f.write(out)
    print("wrote", path)


for s in (16, 32, 48, 128):
    make(s)
