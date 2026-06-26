#!/usr/bin/env python3
"""방 가구 스프라이트 일괄 누끼(투명화) + 콘텐츠 크롭.

cutout_noa.py 의 edge flood-fill 방식을 가구 9종 배치 처리로 일반화한 도구.
이미 투명 PNG면 크롭만, 단색 배경이면 네 모서리에서 배경색을 추정해 '바깥 배경만'
제거(가구 내부 같은 색은 보존)한다.

워크플로
  1) PROMPT.txt 로 가구 이미지를 생성한다.
     - 투명 PNG로 나오면 best (이 스크립트는 크롭만 한다)
     - 단색(마젠타 #FF00FF 권장) 배경으로 나오면 이 스크립트가 배경을 키잉한다
  2) 생성 이미지를 app/assets/room/_raw/ 에 둔다.
     - 개별 파일: 파일명 = 가구 이름(bed.png, sofa.png ...). jpg/png/webp 가능
     - 또는 3x3 시트 한 장: _raw/sheet.png 로 두고  --sheet  옵션 사용(스타일 일관성↑)
  3) 실행
       python3 scripts/cutout_furniture.py            # 개별 파일 모드
       python3 scripts/cutout_furniture.py --sheet     # _raw/sheet.png 를 3x3 분할
     → app/assets/room/<name>.png (투명, 콘텐츠 크롭) 생성
  4) furniture.dart 의 kUseFurnitureSprites=true 로 바꾸고 앱 실행
     (pubspec 의 assets/room/ 등록은 이미 되어 있음)

옵션
  --tol N      배경색 허용 오차(채널별 max diff, 기본 28). halo 남으면 키우고,
               가구가 파먹히면 줄인다.
  --sheet      _raw/sheet.png 를 rows x cols(기본 3x3)로 분할해 NAMES 순서로 매핑
  --rows R --cols C   시트 분할 격자(기본 3 3)
  --pad P      크롭 후 사방 여백 px(기본 6) — 외곽선이 잘리지 않게 약간 둠
"""
import argparse
import os
from collections import deque

from PIL import Image

ROOM = os.path.join(os.path.dirname(__file__), "..", "app", "assets", "room")
RAW = os.path.join(ROOM, "_raw")
# 비율 매니페스트 출력 위치(_spritePiece 가 폭만 제어하고 높이는 실제 비율을 따르도록)
MANIFEST = os.path.join(os.path.dirname(__file__), "..", "app", "lib", "room", "sprite_sizes.dart")

# 처리한 가구별 최종 (w, h) — 매니페스트 생성용
SIZES = {}

# SPEC.md / PROMPT.txt 와 동일한 순서·이름 (시트 분할 시 row-major 매핑에 사용)
NAMES = ["bed", "desk", "sofa", "lamp", "plant", "fridge",
         "counter", "table", "rug"]

IMG_EXT = (".png", ".jpg", ".jpeg", ".webp")


def corner_bg(px, w, h, patch=6):
    """네 모서리 patch×patch 영역 픽셀들의 중앙값(median)으로 배경색 추정."""
    samples = []
    for cx, cy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        for dx in range(patch):
            for dy in range(patch):
                x = min(max(cx + (dx if cx == 0 else -dx), 0), w - 1)
                y = min(max(cy + (dy if cy == 0 else -dy), 0), h - 1)
                samples.append(px[x, y])
    samples.sort()
    return samples[len(samples) // 2]


def near(p, c, tol):
    return abs(p[0] - c[0]) <= tol and abs(p[1] - c[1]) <= tol and abs(p[2] - c[2]) <= tol


def already_transparent(px, w, h):
    """모서리 어디든 알파 0이면 이미 투명 배경으로 본다."""
    for cx, cy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        if px[cx, cy][3] == 0:
            return True
    return False


def keyout(im, tol):
    """edge flood-fill 로 가장자리에 연결된 배경만 투명화 + halo 정리."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()

    if already_transparent(px, w, h):
        return crop(im)

    bg = corner_bg(px, w, h)

    # 1) 테두리에서 BFS — 바깥 배경(가장자리에 연결된 bg색)만 제거
    visited = bytearray(w * h)
    q = deque()

    def push(x, y):
        i = y * w + x
        if not visited[i] and near(px[x, y], bg, tol):
            visited[i] = 1
            q.append((x, y))

    for x in range(w):
        push(x, 0)
        push(x, h - 1)
    for y in range(h):
        push(0, y)
        push(w - 1, y)

    while q:
        x, y = q.popleft()
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                push(nx, ny)

    # 2) halo 정리: 투명에 인접 + 배경색에 가까운 픽셀도 제거(살짝 느슨하게)
    htol = int(tol * 1.6)
    to_clear = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            if not near(px[x, y], bg, htol):
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0:
                    to_clear.append((x, y))
                    break
    for x, y in to_clear:
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, 0)

    return crop(im)


def crop(im, pad=6):
    bbox = im.getbbox()
    if not bbox:
        return im
    l, t, r, b = bbox
    l, t = max(l - pad, 0), max(t - pad, 0)
    r, b = min(r + pad, im.width), min(b + pad, im.height)
    return im.crop((l, t, r, b))


def process_file(src, name, tol, pad):
    im = Image.open(src)
    out_im = keyout(im, tol)
    if pad != 6:
        out_im = crop(out_im, pad)  # pad 옵션 반영(keyout 내부 기본 crop 후 재적용)
    out = os.path.join(ROOM, f"{name}.png")
    out_im.save(out)
    SIZES[name] = out_im.size
    print(f"  ✓ {name:8s} {os.path.basename(src):20s} → {name}.png {out_im.size}")


def run_individual(tol, pad):
    found = 0
    for fn in sorted(os.listdir(RAW)):
        stem, ext = os.path.splitext(fn)
        if ext.lower() not in IMG_EXT:
            continue
        if stem not in NAMES:
            print(f"  · skip {fn} (이름이 {NAMES} 중 하나가 아님)")
            continue
        process_file(os.path.join(RAW, fn), stem, tol, pad)
        found += 1
    if not found:
        print(f"  (입력 없음) {RAW} 에 bed.png/sofa.png 등 가구 이미지를 넣어주세요.")
        print(f"   또는 3x3 시트 한 장이면: _raw/sheet.png 두고  --sheet  실행")


def run_sheet(rows, cols, tol, pad):
    sheet = None
    for ext in IMG_EXT:
        p = os.path.join(RAW, f"sheet{ext}")
        if os.path.exists(p):
            sheet = p
            break
    if not sheet:
        print(f"  _raw/sheet.png 가 없습니다. 3x3 시트 한 장을 거기에 두세요.")
        return
    im = Image.open(sheet).convert("RGBA")
    w, h = im.size
    cw, ch = w // cols, h // rows
    print(f"  시트 {os.path.basename(sheet)} {im.size} → {rows}x{cols} 분할")
    idx = 0
    for r in range(rows):
        for c in range(cols):
            if idx >= len(NAMES):
                break
            cell = im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
            out_im = keyout(cell, tol)
            out_im = crop(out_im, pad)
            name = NAMES[idx]
            out_im.save(os.path.join(ROOM, f"{name}.png"))
            SIZES[name] = out_im.size
            print(f"  ✓ cell[{r},{c}] → {name}.png {out_im.size}")
            idx += 1


def write_manifest():
    """처리한 가구들의 종횡비(imgW/imgH)를 Dart 상수로 출력. _spritePiece 가 이를 읽어
    '폭 = tileW*wMul' 만 정하고 높이는 비율로 따라가게 한다(가구 왜곡 방지)."""
    if not SIZES:
        return
    # 기존 값 보존 위해 머지: 일부 가구만 다시 돌려도 나머지 비율은 유지
    existing = {}
    if os.path.exists(MANIFEST):
        import re
        with open(MANIFEST, encoding="utf-8") as f:
            for k, v in re.findall(r"'(\w+)':\s*([0-9.]+)", f.read()):
                existing[k] = float(v)
    for name, (w, h) in SIZES.items():
        existing[name] = round(w / h, 4)
    lines = ["// 자동 생성 — scripts/cutout_furniture.py. 직접 수정하지 말 것.",
             "// 값 = 스프라이트 PNG 의 가로/세로 비율(crop 후).",
             "const Map<String, double> kSpriteAspect = {"]
    for name in NAMES:
        if name in existing:
            lines.append(f"  '{name}': {existing[name]},")
    lines.append("};")
    with open(MANIFEST, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"  매니페스트 → {os.path.relpath(MANIFEST)} ({len(existing)}종)")


def main():
    ap = argparse.ArgumentParser(description="방 가구 스프라이트 일괄 누끼")
    ap.add_argument("--tol", type=int, default=28, help="배경색 허용 오차(기본 28)")
    ap.add_argument("--sheet", action="store_true", help="_raw/sheet.* 를 격자 분할")
    ap.add_argument("--rows", type=int, default=3)
    ap.add_argument("--cols", type=int, default=3)
    ap.add_argument("--pad", type=int, default=6, help="크롭 여백 px(기본 6)")
    args = ap.parse_args()

    os.makedirs(RAW, exist_ok=True)
    print(f"누끼 처리 → {os.path.relpath(ROOM)}")
    if args.sheet:
        run_sheet(args.rows, args.cols, args.tol, args.pad)
    else:
        run_individual(args.tol, args.pad)
    write_manifest()
    print("완료. furniture.dart 의 kUseFurnitureSprites=true 로 바꾸고 앱 실행하세요.")


if __name__ == "__main__":
    main()
