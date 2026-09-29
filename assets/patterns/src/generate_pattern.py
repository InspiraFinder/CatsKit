# -*- coding: utf-8 -*-
"""主界面周期性背景贴片生成器（离线跑一次即可，输出已提交到仓库）

素材：`assets/patterns/src/badge_*.png` —— 游戏安装包里的 **方块徽章**
（`D:\\projects\\cats\\extract\\game_images\\gp`，取 0101 / 0102 / 0201 / 0301 四张：
红 V 形箭头 / 宝石+扳手 / 紫色纹章），刻意选最早的那几级：只有方框 + 圆 + 图形，
没有后面的花纹与金边。

输出：`assets/patterns/game_pattern.png`
      —— 200×200 无缝贴片，**大元素**（方块徽章 72-84px）；
      「猫生重开」横幅按钮里的 `activity_pattern.png` 是**小元素**（活动图标 34-48px），
      一大一小形成层次感（本脚本不动那张图）。

关键处理：徽章原本是一整块不透明方块，直接染成单色就是一坨实心方块，看不出内容。
所以拆成两层 alpha：
  · 方块面板本体 → 很浅（PANEL_ALPHA ≈ 0.22），平铺后是一层若隐若现的方块底；
  · 内部线条（圆盘 / 图形 / 边角装饰的**边缘**）→ 实心，凑近看能认出红 V、宝石、
    纹章等游戏图案，而且比填色更透气。
边缘用「先轻微高斯模糊再做 Sobel，取三通道最大梯度」得到，避免噪点。

无缝做法：按 3×3 重复画在大画布上，再裁中间一块 —— 跨边界的徽章会自动「绕回」。

用法：
    python assets/patterns/src/generate_pattern.py
预览图输出到 build/pattern_preview/（按真实 opacity + ColorFilter(srcIn) 合成）。
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))   # 仓库根目录
OUT = os.path.join(ROOT, "assets", "patterns", "game_pattern.png")
PREVIEW_DIR = os.path.join(ROOT, "build", "pattern_preview")

TILE = 200                     # 贴片边长（像素）
PANEL_ALPHA = 0.22             # 方块面板本体的不透明度
EDGE_TOL = 58.0                # 边缘强度阈值（越小线条越粗）
EDGE_BLUR = 1.3                # 求边缘前的轻微模糊（去噪）

# 4 个摆放位置：(中心 x, 中心 y, 目标大小, 旋转角度)
# 2×2 交错网格（第二行错开半格，其中一个贴着接缝，平铺后自动拼回完整方块）
SLOTS = [
    (50, 50, 80, -4),
    (150, 52, 72, 3),
    (0, 150, 84, 5),
    (100, 148, 74, -2),
]
ICONS = ["badge_chevron.png", "badge_gem.png", "badge_crest.png", "badge_chevron2.png"]


def edge_strength(rgb, blur=EDGE_BLUR):
    """Sobel 边缘强度（三通道取最大），先轻微模糊去噪。"""
    im = Image.fromarray(rgb.astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))
    a = np.asarray(im).astype(np.float32)
    mag = np.zeros(a.shape[:2], np.float32)
    for c in range(3):
        ch = a[..., c]
        gx = np.zeros_like(ch)
        gy = np.zeros_like(ch)
        gx[:, 1:-1] = (ch[:, 2:] - ch[:, :-2]) / 2
        gy[1:-1, :] = (ch[2:, :] - ch[:-2, :]) / 2
        mag = np.maximum(mag, np.hypot(gx, gy))
    return mag


def to_alpha(im, panel=PANEL_ALPHA, tol=EDGE_TOL):
    """徽章 → 水印 alpha：方块面板浅 + 内部线条实心（线条只出现在方块范围内）。"""
    a = np.asarray(im.convert("RGBA")).astype(np.float32)
    shape = (a[..., 3] > 128).astype(np.float32)
    v = np.maximum(np.clip(edge_strength(a[..., :3]) / tol, 0, 1), panel * shape)
    out = im.convert("RGBA")
    out.putalpha(Image.fromarray((np.clip(v * shape, 0, 1) * 255).astype(np.uint8), "L"))
    return out


def prep_icon(path, size, angle):
    im = to_alpha(Image.open(path))
    bbox = im.getchannel("A").getbbox()
    if bbox:
        im = im.crop(bbox)
    im = im.rotate(angle, resample=Image.BICUBIC, expand=True)
    w, h = im.size
    s = size / max(w, h)
    return im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)


def build_tile():
    canvas = Image.new("RGBA", (TILE * 3, TILE * 3), (0, 0, 0, 0))
    for (cx, cy, size, angle), name in zip(SLOTS, ICONS):
        icon = prep_icon(os.path.join(HERE, name), size, angle)
        for dx in (-TILE, 0, TILE):
            for dy in (-TILE, 0, TILE):
                canvas.alpha_composite(icon, (cx + TILE + dx - icon.width // 2,
                                              cy + TILE + dy - icon.height // 2))
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
