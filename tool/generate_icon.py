#!/usr/bin/env python3
"""Render an original SELQUARO Q app icon using only Python stdlib.

The generated icon is used for Android and iOS launcher images. No Flutter logo,
third-party branding, account avatar or screenshot mock data is included.
"""
import json
import math
import struct
import zlib
from pathlib import Path


def create_master(size=1024):
    pixels = bytearray(size * size * 4)
    for y in range(size):
        py = (y + .5) / size
        for x in range(size):
            px = (x + .5) / size
            # Deep-navy background, blue upper-right accent, subtle diagonal light.
            sheen = max(0.0, 1.0 - math.hypot(px - .76, py - .19) * 1.4)
            r = int(5 + 9 * sheen + 4 * (1 - py))
            g = int(17 + 29 * sheen + 7 * (1 - py))
            b = int(29 + 42 * sheen + 10 * (1 - py))

            dist = math.hypot(px - .48, py - .47)
            ring = abs(dist - .275)
            # Brand Q glyph: open neon ring with a lower-right tail.
            tail_a = (.58, .58)
            tail_b = (.76, .77)
            vx, vy = tail_b[0] - tail_a[0], tail_b[1] - tail_a[1]
            t = max(0.0, min(1.0, ((px - tail_a[0]) * vx + (py - tail_a[1]) * vy) / (vx * vx + vy * vy)))
            td = math.hypot(px - (tail_a[0] + t * vx), py - (tail_a[1] + t * vy))
            core = min(ring, td)
            glow = math.exp(-((core / .062) ** 2)) * .38
            body = max(0.0, min(1.0, (.046 - core) / .008))
            blend = min(1.0, body + glow)
            r = int(r * (1 - blend) + 50 * blend)
            g = int(g * (1 - blend) + 227 * blend)
            b = int(b * (1 - blend) + 231 * blend)
            i = (y * size + x) * 4
            pixels[i:i+4] = bytes((r, g, b, 255))
    return pixels


def write_png(path, master, pixels):
    path.parent.mkdir(parents=True, exist_ok=True)
    def chunk(name, data):
        return struct.pack('>I', len(data)) + name + data + struct.pack('>I', zlib.crc32(name + data) & 0xffffffff)
    scanlines = bytearray()
    for y in range(pixels):
        scanlines.append(0)
        srcy = min(master - 1, round((y + .5) * master / pixels - .5))
        for x in range(pixels):
            srcx = min(master - 1, round((x + .5) * master / pixels - .5))
            index = (srcy * master + srcx) * 4
            scanlines.extend(DATA[index:index+4])
    data = (bytes((137, 80, 78, 71, 13, 10, 26, 10)) +
            chunk(b'IHDR', struct.pack('>2I5B', pixels, pixels, 8, 6, 0, 0, 0)) +
            chunk(b'IDAT', zlib.compress(scanlines, 8)) +
            chunk(b'IEND', b''))
    path.write_bytes(data)


DATA = create_master()
android = Path('android/app/src/main/res')
for qualifier, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    directory = android / f'mipmap-{qualifier}'
    write_png(directory / 'ic_launcher.png', 1024, size)
    write_png(directory / 'ic_launcher_round.png', 1024, size)

icons = Path('ios/Runner/Assets.xcassets/AppIcon.appiconset')
manifest = icons / 'Contents.json'
if manifest.exists():
    contents = json.loads(manifest.read_text())
    for image in contents.get('images', []):
        filename = image.get('filename')
        if not filename:
            continue
        base = float(image['size'].split('x')[0])
        scale = int(image['scale'].rstrip('x'))
        write_png(icons / filename, 1024, round(base * scale))
