#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["fonttools==4.60.1"]
# ///
import math
import os
from pathlib import Path

os.environ["SOURCE_DATE_EPOCH"] = "0"

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

FAMILY = "Dotfiles Symbols"
OUTPUT = Path(__file__).with_name("DotfilesSymbols.ttf")
UPM = 1000
CELL = 620
LEFT, RIGHT = 0.40, 1.21
X0, X1 = round(CELL * LEFT), round(CELL * RIGHT)
CENTER_Y = 350


def circle(pen, cx, cy, r):
    step = math.pi / 4
    ctrl = r / math.cos(step / 2)
    point = lambda radius, a: (round(cx + radius * math.cos(a)), round(cy + radius * math.sin(a)))
    pen.moveTo(point(r, 0))
    for i in range(1, 9):
        pen.qCurveTo(point(ctrl, -(i - 0.5) * step), point(r, -i * step))
    pen.closePath()


def polygon(pen, points):
    pen.moveTo(points[0])
    for p in points[1:]:
        pen.lineTo(p)
    pen.closePath()


def check():
    pen = TTGlyphPen(None)
    t = 88
    d = round(t / math.sqrt(2))
    elbow_x, elbow_y = X0 + 162 + d // 2, 120
    short = elbow_x - X0 - d
    long = X1 - elbow_x - d
    polygon(pen, [
        (elbow_x, elbow_y),
        (elbow_x - short - d, elbow_y + short + d),
        (elbow_x - short, elbow_y + short + 2 * d),
        (elbow_x, elbow_y + 2 * d),
        (elbow_x + long, elbow_y + long + 2 * d),
        (elbow_x + long + d, elbow_y + long + d),
    ])
    return pen.glyph()


def ellipsis():
    pen = TTGlyphPen(None)
    r = 56
    for cx in (X0 + r, (X0 + X1) // 2, X1 - r):
        circle(pen, cx, r, r)
    return pen.glyph()


def dot():
    pen = TTGlyphPen(None)
    circle(pen, (X0 + X1) // 2, CENTER_Y, (X1 - X0) // 2)
    return pen.glyph()


def notdef():
    pen = TTGlyphPen(None)
    polygon(pen, [(60, 0), (60, 700), (560, 700), (560, 0)])
    polygon(pen, [(120, 60), (500, 60), (500, 640), (120, 640)])
    return pen.glyph()


glyphs = {".notdef": notdef(), "check": check(), "ellipsis": ellipsis(), "dot": dot()}
cmap = {0x10F100: "check", 0x10F101: "ellipsis", 0x10F102: "dot"}

fb = FontBuilder(UPM, isTTF=True)
fb.setupGlyphOrder(list(glyphs))
fb.setupCharacterMap(cmap)
fb.setupGlyf(glyphs)
fb.setupHorizontalMetrics({n: (CELL, g.xMin) for n, g in glyphs.items()})
fb.setupHorizontalHeader(ascent=950, descent=-250)
fb.setupOS2(sTypoAscender=950, sTypoDescender=-250, usWinAscent=950, usWinDescent=250, achVendID="DOTF")
fb.setupNameTable({
    "familyName": FAMILY,
    "styleName": "Regular",
    "uniqueFontIdentifier": f"{FAMILY} Regular",
    "fullName": FAMILY,
    "version": "Version 1.000",
    "psName": "DotfilesSymbols-Regular",
})
fb.setupPost(isFixedPitch=1)
fb.font.recalcTimestamp = False
fb.font["head"].created = fb.font["head"].modified = 0
fb.save(OUTPUT)
print(f"{OUTPUT} ({OUTPUT.stat().st_size} bytes)")
