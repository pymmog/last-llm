#!/usr/bin/env python3
"""Generate the RUSTPULSE application icon from committed sprite assets.

This script intentionally uses only the Python standard library so it can run
without ImageMagick, Pillow, or Godot.
"""

from __future__ import annotations

import math
import random
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "sprites"
OUT = ROOT / "icon.png"

ICON_SIZE = 1024
RENDER_SCALE = 2
W = ICON_SIZE * RENDER_SCALE
H = ICON_SIZE * RENDER_SCALE


def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def read_png(path: Path) -> dict[str, object]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG")

    offset = 8
    width = height = bit_depth = color_type = None
    idat = bytearray()

    while offset < len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        chunk_type = data[offset + 4 : offset + 8]
        chunk_data = data[offset + 8 : offset + 8 + length]
        offset += 12 + length

        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _compression, _filter, interlace = struct.unpack(
                ">IIBBBBB", chunk_data
            )
            if bit_depth != 8 or color_type not in (2, 6) or interlace != 0:
                raise ValueError(f"{path} uses an unsupported PNG format")
        elif chunk_type == b"IDAT":
            idat.extend(chunk_data)
        elif chunk_type == b"IEND":
            break

    if width is None or height is None or color_type is None:
        raise ValueError(f"{path} is missing IHDR data")

    bytes_per_pixel = 4 if color_type == 6 else 3
    stride = width * bytes_per_pixel
    raw = zlib.decompress(bytes(idat))
    rows: list[bytearray] = []
    pos = 0
    prev = bytearray(stride)

    for _y in range(height):
        filter_type = raw[pos]
        pos += 1
        row = bytearray(raw[pos : pos + stride])
        pos += stride

        for x in range(stride):
            left = row[x - bytes_per_pixel] if x >= bytes_per_pixel else 0
            up = prev[x]
            up_left = prev[x - bytes_per_pixel] if x >= bytes_per_pixel else 0

            if filter_type == 1:
                row[x] = (row[x] + left) & 0xFF
            elif filter_type == 2:
                row[x] = (row[x] + up) & 0xFF
            elif filter_type == 3:
                row[x] = (row[x] + ((left + up) >> 1)) & 0xFF
            elif filter_type == 4:
                row[x] = (row[x] + paeth(left, up, up_left)) & 0xFF
            elif filter_type != 0:
                raise ValueError(f"{path} has unsupported filter type {filter_type}")

        rows.append(row)
        prev = row

    pixels = bytearray(width * height * 4)
    out = 0
    for row in rows:
        if color_type == 6:
            pixels[out : out + width * 4] = row
            out += width * 4
        else:
            src = 0
            for _x in range(width):
                pixels[out] = row[src]
                pixels[out + 1] = row[src + 1]
                pixels[out + 2] = row[src + 2]
                pixels[out + 3] = 255
                src += 3
                out += 4

    return {"w": width, "h": height, "pixels": pixels}


def write_png(path: Path, image: dict[str, object]) -> None:
    width = int(image["w"])
    height = int(image["h"])
    pixels = image["pixels"]
    assert isinstance(pixels, bytearray)

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + kind
            + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
        )

    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        start = y * stride
        raw.extend(pixels[start : start + stride])

    png = bytearray(b"\x89PNG\r\n\x1a\n")
    png.extend(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
    png.extend(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
    png.extend(chunk(b"IEND", b""))
    path.write_bytes(png)


def image(width: int, height: int, color: tuple[int, int, int, int] = (0, 0, 0, 0)) -> dict[str, object]:
    pixels = bytearray(width * height * 4)
    if color != (0, 0, 0, 0):
        for i in range(0, len(pixels), 4):
            pixels[i : i + 4] = bytes(color)
    return {"w": width, "h": height, "pixels": pixels}


def over(pixels: bytearray, width: int, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if x < 0 or x >= width or y < 0:
        return
    idx = (y * width + x) * 4
    if idx < 0 or idx + 3 >= len(pixels):
        return

    sr, sg, sb, sa = color
    if sa <= 0:
        return
    if sa >= 255:
        pixels[idx : idx + 4] = bytes((sr, sg, sb, 255))
        return

    dr, dg, db, da = pixels[idx], pixels[idx + 1], pixels[idx + 2], pixels[idx + 3]
    inv = 255 - sa
    oa = sa + (da * inv + 127) // 255
    if oa == 0:
        pixels[idx : idx + 4] = b"\x00\x00\x00\x00"
        return

    pixels[idx] = min(255, (sr * sa + dr * da * inv // 255 + oa // 2) // oa)
    pixels[idx + 1] = min(255, (sg * sa + dg * da * inv // 255 + oa // 2) // oa)
    pixels[idx + 2] = min(255, (sb * sa + db * da * inv // 255 + oa // 2) // oa)
    pixels[idx + 3] = oa


def rounded_inside(x: int, y: int, x0: int, y0: int, width: int, height: int, radius: int) -> bool:
    x1 = x0 + width - 1
    y1 = y0 + height - 1
    cx = min(max(x, x0 + radius), x1 - radius)
    cy = min(max(y, y0 + radius), y1 - radius)
    return (x - cx) * (x - cx) + (y - cy) * (y - cy) <= radius * radius


def draw_rounded_rect(canvas: dict[str, object], x: int, y: int, width: int, height: int, radius: int, color: tuple[int, int, int, int]) -> None:
    pixels = canvas["pixels"]
    assert isinstance(pixels, bytearray)
    canvas_width = int(canvas["w"])

    x_min = max(0, x)
    y_min = max(0, y)
    x_max = min(canvas_width, x + width)
    y_max = min(int(canvas["h"]), y + height)
    for yy in range(y_min, y_max):
        for xx in range(x_min, x_max):
            if rounded_inside(xx, yy, x, y, width, height, radius):
                over(pixels, canvas_width, xx, yy, color)


def draw_radial(canvas: dict[str, object], cx: int, cy: int, radius: int, color: tuple[int, int, int], alpha: int) -> None:
    pixels = canvas["pixels"]
    assert isinstance(pixels, bytearray)
    canvas_width = int(canvas["w"])
    radius_sq = radius * radius
    x_min = max(0, cx - radius)
    x_max = min(canvas_width - 1, cx + radius)
    y_min = max(0, cy - radius)
    y_max = min(int(canvas["h"]) - 1, cy + radius)
    for y in range(y_min, y_max + 1):
        dy = y - cy
        for x in range(x_min, x_max + 1):
            dx = x - cx
            distance_sq = dx * dx + dy * dy
            if distance_sq <= radius_sq:
                falloff = 1.0 - math.sqrt(distance_sq) / radius
                a = int(alpha * falloff * falloff)
                if a:
                    over(pixels, canvas_width, x, y, (color[0], color[1], color[2], a))


def draw_ring(canvas: dict[str, object], cx: int, cy: int, radius: int, thickness: int, color: tuple[int, int, int, int]) -> None:
    pixels = canvas["pixels"]
    assert isinstance(pixels, bytearray)
    canvas_width = int(canvas["w"])
    outer = radius + thickness // 2
    x_min = max(0, cx - outer)
    x_max = min(canvas_width - 1, cx + outer)
    y_min = max(0, cy - outer)
    y_max = min(int(canvas["h"]) - 1, cy + outer)
    for y in range(y_min, y_max + 1):
        dy = y - cy
        for x in range(x_min, x_max + 1):
            dx = x - cx
            distance = math.sqrt(dx * dx + dy * dy)
            edge = abs(distance - radius)
            if edge <= thickness / 2:
                a = int(color[3] * (1.0 - edge / (thickness / 2)))
                if a:
                    over(pixels, canvas_width, x, y, (color[0], color[1], color[2], a))


def draw_line(canvas: dict[str, object], x0: int, y0: int, x1: int, y1: int, width: int, color: tuple[int, int, int, int]) -> None:
    pixels = canvas["pixels"]
    assert isinstance(pixels, bytearray)
    canvas_width = int(canvas["w"])
    half = width / 2.0
    xmin = max(0, min(x0, x1) - width)
    xmax = min(canvas_width - 1, max(x0, x1) + width)
    ymin = max(0, min(y0, y1) - width)
    ymax = min(int(canvas["h"]) - 1, max(y0, y1) + width)
    vx = x1 - x0
    vy = y1 - y0
    length_sq = vx * vx + vy * vy

    for y in range(ymin, ymax + 1):
        for x in range(xmin, xmax + 1):
            t = ((x - x0) * vx + (y - y0) * vy) / length_sq
            t = max(0.0, min(1.0, t))
            px = x0 + t * vx
            py = y0 + t * vy
            distance = math.hypot(x - px, y - py)
            if distance <= half:
                a = int(color[3] * (1.0 - distance / half))
                if a:
                    over(pixels, canvas_width, x, y, (color[0], color[1], color[2], a))


def trim_alpha(sprite: dict[str, object], threshold: int = 4) -> dict[str, object]:
    width = int(sprite["w"])
    height = int(sprite["h"])
    pixels = sprite["pixels"]
    assert isinstance(pixels, bytearray)
    min_x, min_y = width, height
    max_x, max_y = -1, -1
    for y in range(height):
        row = y * width * 4
        for x in range(width):
            if pixels[row + x * 4 + 3] > threshold:
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
    if max_x < min_x or max_y < min_y:
        return sprite

    new_w = max_x - min_x + 1
    new_h = max_y - min_y + 1
    out = image(new_w, new_h)
    out_pixels = out["pixels"]
    assert isinstance(out_pixels, bytearray)
    for y in range(new_h):
        src_start = ((min_y + y) * width + min_x) * 4
        dst_start = y * new_w * 4
        out_pixels[dst_start : dst_start + new_w * 4] = pixels[src_start : src_start + new_w * 4]
    return out


def scale_nearest(sprite: dict[str, object], target_w: int, target_h: int) -> dict[str, object]:
    src_w = int(sprite["w"])
    src_h = int(sprite["h"])
    src = sprite["pixels"]
    assert isinstance(src, bytearray)
    out = image(target_w, target_h)
    dst = out["pixels"]
    assert isinstance(dst, bytearray)
    for y in range(target_h):
        src_y = min(src_h - 1, y * src_h // target_h)
        for x in range(target_w):
            src_x = min(src_w - 1, x * src_w // target_w)
            src_idx = (src_y * src_w + src_x) * 4
            dst_idx = (y * target_w + x) * 4
            dst[dst_idx : dst_idx + 4] = src[src_idx : src_idx + 4]
    return out


def paste(
    canvas: dict[str, object],
    sprite: dict[str, object],
    x: int,
    y: int,
    opacity: float = 1.0,
    tint: tuple[int, int, int] | None = None,
) -> None:
    canvas_pixels = canvas["pixels"]
    sprite_pixels = sprite["pixels"]
    assert isinstance(canvas_pixels, bytearray)
    assert isinstance(sprite_pixels, bytearray)
    canvas_width = int(canvas["w"])
    canvas_height = int(canvas["h"])
    sprite_width = int(sprite["w"])
    sprite_height = int(sprite["h"])

    for yy in range(sprite_height):
        cy = y + yy
        if cy < 0 or cy >= canvas_height:
            continue
        for xx in range(sprite_width):
            cx = x + xx
            if cx < 0 or cx >= canvas_width:
                continue
            src_idx = (yy * sprite_width + xx) * 4
            alpha = int(sprite_pixels[src_idx + 3] * opacity)
            if alpha <= 0:
                continue
            if tint is None:
                color = (
                    sprite_pixels[src_idx],
                    sprite_pixels[src_idx + 1],
                    sprite_pixels[src_idx + 2],
                    alpha,
                )
            else:
                color = (tint[0], tint[1], tint[2], alpha)
            over(canvas_pixels, canvas_width, cx, cy, color)


def sprite_fit(name: str, max_width: int, max_height: int) -> dict[str, object]:
    sprite = trim_alpha(read_png(SPRITES / name))
    width = int(sprite["w"])
    height = int(sprite["h"])
    scale = min(max_width / width, max_height / height)
    return scale_nearest(sprite, max(1, round(width * scale)), max(1, round(height * scale)))


def downsample_2x(src: dict[str, object]) -> dict[str, object]:
    src_w = int(src["w"])
    src_h = int(src["h"])
    src_pixels = src["pixels"]
    assert isinstance(src_pixels, bytearray)
    out = image(src_w // 2, src_h // 2)
    dst_pixels = out["pixels"]
    assert isinstance(dst_pixels, bytearray)
    dst_w = int(out["w"])

    for y in range(0, src_h, 2):
        for x in range(0, src_w, 2):
            totals = [0, 0, 0, 0]
            for oy in (0, 1):
                for ox in (0, 1):
                    idx = ((y + oy) * src_w + x + ox) * 4
                    totals[0] += src_pixels[idx]
                    totals[1] += src_pixels[idx + 1]
                    totals[2] += src_pixels[idx + 2]
                    totals[3] += src_pixels[idx + 3]
            dst_idx = ((y // 2) * dst_w + x // 2) * 4
            dst_pixels[dst_idx : dst_idx + 4] = bytes(v // 4 for v in totals)
    return out


def s(value: int | float) -> int:
    return round(value * RENDER_SCALE)


def main() -> None:
    canvas = image(W, H)
    random.seed(7)

    draw_rounded_rect(canvas, 0, 0, W, H, s(176), (18, 15, 13, 255))
    draw_rounded_rect(canvas, s(42), s(42), W - s(84), H - s(84), s(132), (30, 23, 18, 255))
    draw_rounded_rect(canvas, s(68), s(68), W - s(136), H - s(136), s(108), (23, 21, 20, 190))

    pixels = canvas["pixels"]
    assert isinstance(pixels, bytearray)
    for y in range(s(90), H - s(90)):
        for x in range(s(90), W - s(90)):
            if not rounded_inside(x, y, s(42), s(42), W - s(84), H - s(84), s(132)):
                continue
            band = ((x - y + s(220)) // s(88)) % 5
            if band == 0:
                over(pixels, W, x, y, (72, 44, 25, 42))
            elif band == 2:
                over(pixels, W, x, y, (20, 68, 70, 18))

    for _ in range(1600):
        x = random.randrange(s(82), W - s(82))
        y = random.randrange(s(82), H - s(82))
        if rounded_inside(x, y, s(42), s(42), W - s(84), H - s(84), s(132)):
            r = random.randrange(1, 4)
            color = random.choice(((106, 53, 24, 34), (210, 99, 37, 24), (8, 201, 194, 18)))
            draw_radial(canvas, x, y, r, color[:3], color[3])

    draw_radial(canvas, s(512), s(545), s(470), (12, 226, 216), 96)
    draw_radial(canvas, s(585), s(435), s(250), (228, 92, 30), 72)
    draw_ring(canvas, s(514), s(546), s(388), s(26), (49, 236, 224, 135))
    draw_ring(canvas, s(514), s(546), s(282), s(10), (234, 111, 35, 118))
    draw_line(canvas, s(172), s(790), s(876), s(260), s(86), (229, 104, 32, 82))
    draw_line(canvas, s(190), s(828), s(904), s(292), s(18), (47, 238, 228, 88))

    saw = sprite_fit("projectile_saw_blade.png", s(470), s(470))
    paste(canvas, saw, s(566), s(124), opacity=0.30, tint=(0, 0, 0))
    paste(canvas, saw, s(536), s(92), opacity=0.76)

    rivet = sprite_fit("projectile_rivet.png", s(350), s(260))
    paste(canvas, rivet, s(70), s(650), opacity=0.35, tint=(0, 0, 0))
    paste(canvas, rivet, s(48), s(616), opacity=0.70)

    gem = sprite_fit("xp_gem.png", s(92), s(116))
    for gx, gy, opacity in ((s(136), s(184), 0.85), (s(812), s(756), 0.72), (s(226), s(812), 0.58)):
        draw_radial(canvas, gx + s(38), gy + s(48), s(62), (32, 235, 228), 84)
        paste(canvas, gem, gx, gy, opacity=opacity)

    unit = sprite_fit("unit7_ps1.png", s(700), s(735))
    unit_x = s(172)
    unit_y = s(230)
    paste(canvas, unit, unit_x + s(34), unit_y + s(46), opacity=0.42, tint=(0, 0, 0))
    paste(canvas, unit, unit_x + s(14), unit_y + s(22), opacity=0.18, tint=(33, 238, 228))
    paste(canvas, unit, unit_x, unit_y, opacity=1.0)

    draw_rounded_rect(canvas, s(46), s(46), W - s(92), H - s(92), s(124), (255, 183, 74, 24))
    draw_rounded_rect(canvas, s(72), s(72), W - s(144), H - s(144), s(100), (0, 0, 0, 38))

    final_icon = downsample_2x(canvas)
    write_png(OUT, final_icon)


if __name__ == "__main__":
    main()
