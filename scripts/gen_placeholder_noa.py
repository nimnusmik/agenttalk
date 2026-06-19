#!/usr/bin/env python3
"""노아 플레이스홀더 스프라이트 아틀라스 생성기.

진짜 도트는 sprite-gen(베이스 이미지 필요)으로 만든다. 이 스크립트는 그 전까지
CharacterView↔manifest↔채팅 연동을 검증하기 위한 *임시* 아틀라스를 그린다.
출력 manifest 는 app/lib/character/sprite_manifest.dart 가 읽는 스키마와 동일.

실행: python3 scripts/gen_placeholder_noa.py
"""
import json
import math
import os

from PIL import Image, ImageDraw

CELL = 128
STATES = [
    # (state, frames, fps, loop)
    ("idle", 4, 4, True),
    ("talk", 4, 8, True),
    ("thinking", 4, 4, True),
    ("happy", 4, 8, False),
    ("sad", 4, 4, False),
    ("surprised", 4, 8, False),
]
MAX_FRAMES = max(s[1] for s in STATES)
OUT = os.path.join(os.path.dirname(__file__), "..", "app", "assets", "sprites", "noa")
OUT = os.path.abspath(OUT)
os.makedirs(OUT, exist_ok=True)

W, H = MAX_FRAMES * CELL, len(STATES) * CELL

RED = (214, 42, 52, 255)
SEED = (250, 224, 120, 255)
GREEN = (74, 168, 86, 255)
CREAM = (250, 236, 212, 255)
NOSE = (243, 150, 160, 255)
INK = (43, 28, 32, 255)
WHITE = (255, 255, 255, 255)


def draw_noa(d, ox, oy, state, fi, frames):
    cx = ox + CELL // 2
    base_y = oy + CELL // 2 + 8
    t = fi / max(1, frames - 1)

    dy, squash, stem_dx, ear_dy = 0, 1.0, 0, 0
    if state in ("idle", "talk", "thinking"):
        dy = int(-2 * math.sin(t * math.pi))
        stem_dx = int(3 * math.sin(t * 2 * math.pi))
    if state == "happy":
        dy = [0, -8, -3, -8][fi % 4]; ear_dy = -3
        stem_dx = int(4 * math.sin(t * 2 * math.pi))
    if state == "sad":
        dy = [0, 2, 3, 2][fi % 4]; ear_dy = 4
    if state == "surprised":
        squash = [1.0, 1.12, 1.1, 1.0][fi % 4]; dy = [0, -5, -4, 0][fi % 4]
    cy = base_y + dy

    bw, bh = 46, int(52 * squash)
    d.ellipse([cx - bw, cy - bh // 2, cx + bw, cy + bh // 2], fill=RED, outline=INK, width=3)
    d.polygon([(cx - 18, cy + bh // 2 - 4), (cx + 18, cy + bh // 2 - 4), (cx, cy + bh // 2 + 14)],
              fill=RED, outline=INK)
    for sx, sy in [(-22, 6), (0, 16), (20, 6), (-10, 26), (12, 26)]:
        d.ellipse([cx + sx - 2, cy + sy - 3, cx + sx + 2, cy + sy + 3], fill=SEED)

    sx0 = cx + stem_dx
    d.polygon([(sx0 - 12, cy - bh // 2 + 2), (sx0 + 12, cy - bh // 2 + 2), (sx0, cy - bh // 2 - 14)],
              fill=GREEN, outline=INK)

    fcx, fcy, fr = cx, cy - 6, 26
    d.polygon([(fcx - fr + 4, fcy - fr + 10 + ear_dy), (fcx - fr - 8, fcy - fr - 12 + ear_dy),
               (fcx - fr + 18, fcy - fr - 2 + ear_dy)], fill=CREAM, outline=INK)
    d.polygon([(fcx + fr - 4, fcy - fr + 10 + ear_dy), (fcx + fr + 8, fcy - fr - 12 + ear_dy),
               (fcx + fr - 18, fcy - fr - 2 + ear_dy)], fill=CREAM, outline=INK)
    d.ellipse([fcx - fr, fcy - fr, fcx + fr, fcy + fr], fill=CREAM, outline=INK, width=3)

    ex, ey = 10, -2
    if state == "happy":
        for sgn in (-1, 1):
            bx = fcx + sgn * ex
            d.line([(bx - 5, fcy + ey + 2), (bx, fcy + ey - 3), (bx + 5, fcy + ey + 2)],
                   fill=INK, width=3, joint="curve")
    elif state == "surprised":
        for sgn in (-1, 1):
            bx = fcx + sgn * ex
            d.ellipse([bx - 4, fcy + ey - 5, bx + 4, fcy + ey + 5], fill=WHITE, outline=INK, width=2)
            d.ellipse([bx - 2, fcy + ey - 2, bx + 2, fcy + ey + 2], fill=INK)
    elif state == "sad":
        for sgn in (-1, 1):
            bx = fcx + sgn * ex
            d.ellipse([bx - 3, fcy + ey + 1, bx + 3, fcy + ey + 6], fill=INK)
    elif state == "thinking":
        for sgn in (-1, 1):
            bx = fcx + sgn * ex
            d.ellipse([bx - 3, fcy + ey - 6, bx + 3, fcy + ey - 1], fill=INK)
    else:  # idle / talk = deadpan dots
        for sgn in (-1, 1):
            bx = fcx + sgn * ex
            d.ellipse([bx - 3, fcy + ey - 3, bx + 3, fcy + ey + 3], fill=INK)

    d.polygon([(fcx - 3, fcy + 8), (fcx + 3, fcy + 8), (fcx, fcy + 12)], fill=NOSE)
    if state == "talk":
        if fi % 2 == 0:
            d.ellipse([fcx - 5, fcy + 13, fcx + 5, fcy + 21], fill=INK)
        else:
            d.line([(fcx - 5, fcy + 15), (fcx + 5, fcy + 15)], fill=INK, width=2)
    elif state == "surprised":
        d.ellipse([fcx - 4, fcy + 13, fcx + 4, fcy + 22], fill=INK)


sheet = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(sheet)
frame_layout_rows, animation_rows = {}, {}
for r, (state, frames, fps, loop) in enumerate(STATES):
    rects = []
    for i in range(frames):
        ox, oy = i * CELL, r * CELL
        draw_noa(d, ox, oy, state, i, frames)
        rects.append({"x": ox, "y": oy, "w": CELL, "h": CELL})
    frame_layout_rows[state] = rects
    animation_rows[state] = {"row": r, "frames": frames, "fps": fps, "loop": loop}

sheet.save(os.path.join(OUT, "sprite-sheet-alpha.png"))
manifest = {
    "characterId": "noa",
    "engine": "placeholder",
    "game_input": "sprite-sheet-alpha.png",
    "degraded_static_fallback": False,
    "cell": {"shape": "square", "width": CELL, "height": CELL, "size": CELL, "safe_margin": 8},
    "animation": {"cellWidth": CELL, "cellHeight": CELL, "columns": MAX_FRAMES, "rows": animation_rows},
    "frame_layout": {"sheetWidth": W, "sheetHeight": H, "cellWidth": CELL, "cellHeight": CELL,
                     "rows": frame_layout_rows},
}
with open(os.path.join(OUT, "manifest.json"), "w") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)
print(f"wrote {W}x{H} atlas + manifest -> {OUT}")
print("states:", list(animation_rows.keys()))
