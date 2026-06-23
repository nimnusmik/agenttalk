#!/usr/bin/env python3
"""노아 누끼 마감: 흰 테두리(안티에일리어싱 fringe) 정리 + 여백 크롭.
- 알파 1px 침식(MinFilter) 으로 흰 halo 링 제거
- 알파 살짝 blur 로 경계 부드럽게
- 완전 투명 여백 crop 으로 타이트하게(배치 일관성)
원본은 scratchpad 에 noa_cut.orig.png 로 백업."""
import os
import shutil

from PIL import Image, ImageFilter

HERE = os.path.dirname(__file__)
SRC = os.path.join(HERE, "..", "app", "assets", "character", "noa_cut.png")
BACKUP = "/private/tmp/claude-501/-Users-bkan/d3b58606-e034-4f69-9479-14cf245f0714/scratchpad/noa_cut.orig.png"

shutil.copy2(SRC, BACKUP)

im = Image.open(SRC).convert("RGBA")
a = im.getchannel("A")
# 1px 침식 → 바깥 fringe 링 제거
a = a.filter(ImageFilter.MinFilter(3))
# 경계 살짝 부드럽게
a = a.filter(ImageFilter.GaussianBlur(0.6))
im.putalpha(a)
# 투명 여백 crop
bbox = im.getbbox()
if bbox:
    im = im.crop(bbox)

im.save(SRC)
print("refined", SRC, im.size, "(backup:", BACKUP, ")")
