# -*- coding: utf-8 -*-
"""主界面周期性背景贴片生成器（离线跑一次即可，输出已提交到仓库）

设计（按用户要求）：
  · 主界面背景**沿用 2.0.0 版那张贴片的构图**（128×128，3 个带倾斜的方块），
    但把方块里的内容（当时那 3 个吉祥物贴纸的图案）清掉 —— 只留纯色方块；
    当时的形状/位置/倾斜角度是从 git 历史里的 `cat_pattern.png` 量出来的，没有改。
  · 方块本身不带任何图案，颜色由 Flutter 侧的 `ColorFilter(黑/白, srcIn)` 决定，
    深浅由 `opacity` 决定，所以这张贴片**只有 alpha 有意义**。
  · 「猫生重开」横幅按钮里是 `activity_pattern.png`（活动图标 34-48px，小元素），
    本脚本不动它 —— 方块（大元素）与它们形成层次。

构图：128×128 无缝贴片，3 个纯色**直角**方块（边长 40 / 47 / 43，倾斜 -5°/-17°/+17.5°），
      位置就是 2.0.0 版那三个贴纸的位置；其中一个跨上边界，靠 3×3 画布自动绕回。

无缝做法：把方块按 3×3 重复画在大画布上，再裁中间一块 —— 跨边界的方块会自动「绕回」。

用法：
    python assets/patterns/src/generate_pattern.py
预览图输出到 build/pattern_preview/（按真实 opacity + ColorFilter(srcIn) 合成）。
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))   # 仓库根目录
OUT = os.path.join(ROOT, "assets", "patterns", "game_pattern.png")
PREVIEW_DIR = os.path.join(ROOT, "build", "pattern_preview")

TILE = 128          # 贴片边长（与 2.0.0 版一致）
SOLID_ALPHA = 1.0   # 方块自身不透明度（界面里再乘 0.07 / 0.10）
RADIUS = 0.0        # 圆角占边长的比例（0 = 直角/有棱角）
SUPERSAMPLE = 4     # 先放大 4 倍画再缩小，边缘平滑不毛糙

# 3 个方块：(中心 x, 中心 y, 边长, 旋转角度)
# ↓ 位置/边长/角度是从 2.0.0 版 `cat_pattern.png` 的 alpha 里量出来的
#   （角度是当时贴纸的倾斜角：+5° / +17° / -17.5° 的镜像）
SLOTS = [
    (91.3, 20.8, 40, -5.0),
    (33.2, 32.8, 47, -17.0),
    (96.7, 90.8, 43, 17.5),
]


def rounded_square(side, radius_ratio=RADIUS, alpha=SOLID_ALPHA):
    """纯色方块（只关心 alpha）；radius_ratio 为 0 时是直角（有棱角）。"""
    s = side * SUPERSAMPLE
    big = Image.new("L", (s, s), 0)
    draw = ImageDraw.Draw(big)
    if radius_ratio <= 0:
        draw.rectangle([0, 0, s - 1, s - 1], fill=255)
    else:
        draw.rounded_rectangle(
            [0, 0, s - 1, s - 1], radius=max(1, int(s * radius_ratio)), fill=255)
    small = big.resize((side, side), Image.LANCZOS).point(
        lambda v: min(255, int(v * alpha)))
    im = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    im.putalpha(small)
    return im


def build_tile():
    canvas = Image.new("RGBA", (TILE * 3, TILE * 3), (0, 0, 0, 0))
    for cx, cy, side, angle in SLOTS:
        sq = rounded_square(side).rotate(angle, resample=Image.BICUBIC, expand=True)
        for dx in (-TILE, 0, TILE):
            for dy in (-TILE, 0, TILE):
                pos = (int(round(cx + TILE + dx - sq.width / 2)),
                       int(round(cy + TILE + dy - sq.height / 2)))
                canvas.alpha_composite(sq, pos)
    return canvas.crop((TILE, TILE, TILE * 2, TILE * 2))


def render_preview(tile, w, h, dark, opacity=None):
    """模拟 Flutter 的 DecorationImage(repeat, opacity, colorFilter srcIn)。"""
    base = (18, 18, 18) if dark else (250, 249, 252)
    tint = (255, 255, 255) if dark else (0, 0, 0)
    if opacity is None:
        opacity = 0.10 if dark else 0.07
    out = Image.new("RGB", (w, h), base)
    px = out.load()
    ta = tile.getchannel("A")
    for y in range(h):
        for x in range(w):
            a = ta.getpixel((x % TILE, y % TILE)) / 255 * opacity
            if a > 0:
                c = px[x, y]
                px[x, y] = tuple(round(c[i] * (1 - a) + tint[i] * a) for i in range(3))
    return out


def mock_menu(img, dark):
    """在预览上画个粗略的主界面（标题 + 置顶横幅 + 5 个一级按钮）做对照。"""
    d = ImageDraw.Draw(img, "RGBA")
    w, h = img.size
    d.rectangle([0, 0, w, 56], fill=(255, 255, 255, 235) if not dark else (30, 30, 30, 235))
    d.rounded_rectangle([20, 84, w - 20, 208], 16,
                        fill=(233, 30, 99, 220) if not dark else (190, 24, 93, 220))
    y = 232
    for _ in range(5):
        d.rounded_rectangle([20, y, w - 20, y + 62], 14,
                            fill=(255, 255, 255, 235) if not dark else (38, 38, 38, 235))
        y += 74
    return img


if __name__ == "__main__":
    tile = build_tile()
    tile.save(OUT, optimize=True)
    print(f"wrote {OUT}  {tile.size[0]}x{tile.size[1]}  {os.path.getsize(OUT)} bytes")

    os.makedirs(PREVIEW_DIR, exist_ok=True)
    for dark, name in ((False, "light"), (True, "dark")):
        p = render_preview(tile, 420, 700, dark)
        p.save(os.path.join(PREVIEW_DIR, f"{name}.png"))
        mock_menu(p, dark).save(os.path.join(PREVIEW_DIR, f"{name}_ui.png"))
        # 备选透明度（大一号），方便对比后决定
        render_preview(tile, 420, 700, dark, 0.10 if not dark else 0.13).save(
            os.path.join(PREVIEW_DIR, f"{name}_strong.png"))
    print("预览图 →", PREVIEW_DIR)
