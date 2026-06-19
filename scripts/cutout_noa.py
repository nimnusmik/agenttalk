#!/usr/bin/env python3
"""노아 사진 흰 배경 제거(누끼) → 투명 PNG. 방 장면에 올리려면 필요.
모서리에서 near-white flood fill(연결된 외부 배경만 제거 → 캐릭터 내부 밝은 색 보존),
이후 흰 halo 1~2px 정리. 출력: app/assets/character/noa_cut.png
"""
import os
from collections import deque

from PIL import Image

SRC = os.path.join(os.path.dirname(__file__), "..", "app", "assets", "character", "noa.jpg")
OUT = os.path.join(os.path.dirname(__file__), "..", "app", "assets", "character", "noa_cut.png")

im = Image.open(SRC).convert("RGBA")
W, Hh = im.size
px = im.load()


def near_white(p, thr=234):
    return p[0] >= thr and p[1] >= thr and p[2] >= thr


# 1) 모서리/테두리에서 flood fill
visited = bytearray(W * Hh)
q = deque()
for x in range(W):
    for y in (0, Hh - 1):
        if near_white(px[x, y]) and not visited[y * W + x]:
            visited[y * W + x] = 1
            q.append((x, y))
for y in range(Hh):
    for x in (0, W - 1):
        if near_white(px[x, y]) and not visited[y * W + x]:
            visited[y * W + x] = 1
            q.append((x, y))

while q:
    x, y = q.popleft()
    px[x, y] = (px[x, y][0], px[x, y][1], px[x, y][2], 0)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = x + dx, y + dy
        if 0 <= nx < W and 0 <= ny < Hh and not visited[ny * W + nx]:
            if near_white(px[nx, ny]):
                visited[ny * W + nx] = 1
                q.append((nx, ny))

# 2) halo 정리: 투명에 인접한 아주 밝은 픽셀도 투명으로 (2 pass)
for _ in range(2):
    to_clear = []
    for y in range(Hh):
        for x in range(W):
            p = px[x, y]
            if p[3] == 0:
                continue
            if p[0] >= 240 and p[1] >= 240 and p[2] >= 240:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < Hh and px[nx, ny][3] == 0:
                        to_clear.append((x, y))
                        break
    for x, y in to_clear:
        px[x, y] = (px[x, y][0], px[x, y][1], px[x, y][2], 0)

# 3) 투명 영역 bbox 로 크롭(여백 제거) → 방에서 다루기 쉽게
bbox = im.getbbox()
if bbox:
    im = im.crop(bbox)
im.save(OUT)
print("wrote", OUT, im.size)
