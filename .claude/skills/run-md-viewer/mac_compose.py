#!/usr/bin/env python3
"""Center a captured app-window PNG on a 2560x1600 App Store canvas.
Uses the capture's alpha (rounded window corners) so corners blend into the canvas."""
import sys
from PIL import Image

CANVAS = (2560, 1600)
BG = (245, 245, 247)

src = Image.open(sys.argv[1])
src = src.convert("RGBA")

maxw, maxh = CANVAS[0] - 200, CANVAS[1] - 160
if src.width > maxw or src.height > maxh:
    r = min(maxw / src.width, maxh / src.height)
    src = src.resize((int(src.width * r), int(src.height * r)), Image.LANCZOS)

canvas = Image.new("RGB", CANVAS, BG)
x = (CANVAS[0] - src.width) // 2
y = (CANVAS[1] - src.height) // 2
canvas.paste(src, (x, y), src)  # third arg = alpha mask
canvas.save(sys.argv[2])
print(f"{sys.argv[2]} {canvas.size}")
