#!/usr/bin/env python3
"""生成 PWA 图标（纯标准库，无需第三方依赖）。

输出：
  web/icons/Icon-192.png
  web/icons/Icon-512.png
样式：teal 底 + 白色圆角卡片 + teal 横线（账本意象）。
"""
import os
import struct
import zlib

SIZE_192 = 192
SIZE_512 = 512
BG = (0, 137, 123)   # teal #00897B
FG = (255, 255, 255)  # white


def chunk(typ: bytes, data: bytes) -> bytes:
    return (struct.pack(">I", len(data)) + typ + data +
            struct.pack(">I", zlib.crc32(typ + data) & 0xffffffff))


def make_png(size: int, path: str) -> None:
    raw = bytearray()
    cx = cy = size / 2.0
    rw = size * 0.60
    rh = size * 0.74
    x0 = (size - rw) / 2.0
    y0 = (size - rh) / 2.0
    rad = size * 0.16

    # 卡片内三条横线（账本行）
    bars = []
    for fy in (0.34, 0.52, 0.70):
        by = y0 + rh * fy
        bh = size * 0.045
        bw = rw * 0.62
        bx = cx - bw / 2.0
        bars.append((bx, by, bw, bh))

    for y in range(size):
        raw.append(0)  # 每行过滤字节
        for x in range(size):
            r, g, b, a = BG[0], BG[1], BG[2], 255
            if x0 <= x <= x0 + rw and y0 <= y <= y0 + rh:
                # 圆角裁剪
                in_corner = False
                cx_c = x0 + rad if x < x0 + rw / 2 else x0 + rw - rad
                cy_c = y0 + rad if y < y0 + rh / 2 else y0 + rh - rad
                in_corner_zone = (
                    (x - x0 < rad and y - y0 < rad) or
                    (x0 + rw - x < rad and y - y0 < rad) or
                    (x - x0 < rad and y0 + rh - y < rad) or
                    (x0 + rw - x < rad and y0 + rh - y < rad)
                )
                if in_corner_zone and (x - cx_c) ** 2 + (y - cy_c) ** 2 > rad * rad:
                    in_corner = True
                if not in_corner:
                    r, g, b = FG
                    for (bx, by, bw, bh) in bars:
                        if bx <= x <= bx + bw and by <= y <= by + bh:
                            r, g, b = BG
            raw.extend((r, g, b, a))

    sig = b'\x89PNG\r\n\x1a\n'
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)  # 8-bit RGBA
    idat = zlib.compress(bytes(raw), 9)
    out = sig + chunk(b'IHDR', ihdr) + chunk(b'IDAT', idat) + chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(out)
    print("wrote", path)


if __name__ == "__main__":
    out_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                          "web", "icons")
    os.makedirs(out_dir, exist_ok=True)
    make_png(SIZE_192, os.path.join(out_dir, "Icon-192.png"))
    make_png(SIZE_512, os.path.join(out_dir, "Icon-512.png"))
