# -*- coding: utf-8 -*-
"""主界面周期性背景贴片生成器（离线跑一次即可，输出已提交到仓库）

设计（按用户要求）：
  · 主界面背景 = **纯色方块**拼成的周期构图（大元素）；方块本身不带任何图案，
    颜色由 Flutter 侧的 `ColorFilter(黑/白, srcIn)` 决定，深浅由 `opacity` 决定，
    所以这张贴片**只有 alpha 有意义**。
  · 「猫生重开」横幅按钮里是 `activity_pattern.png`（活动图标 34-48px，小元素），
    本脚本不动它 —— 一大一小形成层次。

构图：200×200 无缝贴片，2×2 交错网格放 4 个圆角方块（72-84px，旋转 ±2~5°），
      其中一个特意压在接缝上，平铺后与另一侧拼成一块完整方块。

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

TILE = 200          # 贴片边长（像素）
SOLID_ALPHA = 1.0   # 方块自身不透明度（界面里再乘 0.07 / 0.10）
RADIUS = 0.14       # 圆角占边长的比例
SUPERSAMPLE = 4     # 先放大 4 倍画圆角再缩小，边缘更平滑

# 4 个方块：(中心 x, 中心 y, 边长, 旋转角度)
# 2×2 交错网格（第二行错开半格，其中一个贴着接缝）；大小交替 + 轻微倾斜，
# 既有规律又不死板（边长 62-74，明显大于横幅里的活动图标 34-48）
SLOTS = [
    (50, 50, 70, -3),
    (150, 52, 62, 3),
    (0, 150, 74, 3),
    (100, 148, 64, -3),
]


def rounded_square(side, radius_ratio=RADIUS, alpha=SOLID_ALPHA):
    """纯色圆角方块（只关心 alpha）。"""
    s = side * SUPERSAMPLE
    big = Image.new("L", (s, s), 0)
    ImageDraw.Draw(big).rounded_rectangle(
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
                canvas.alpha_composite(sq, (cx + TILE + dx - sq.width // 2,
                                            cy + TILE + dy - sq.height // 2))
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
