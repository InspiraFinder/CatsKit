# -*- coding: utf-8 -*-
"""主界面周期性背景贴片生成器（离线跑一次即可，输出已提交到仓库）

素材：`assets/patterns/src/*.png` —— 从游戏安装包解出的图标（宝箱 / 齿轮 / 奖杯 /
      星星 / 皇冠 / 盾牌 / 猫头骨 / 闪电 / 放大镜），原始出处见 assets/patterns/README.md
输出：`assets/patterns/game_pattern.png`（160×160 无缝贴片，21KB 左右）

为什么只保留 alpha：Flutter 侧用 `ColorFilter.mode(黑/白, BlendMode.srcIn)` 把贴片
染成单色水印，所以贴片里的颜色其实用不到，只有形状（alpha）有意义。

无缝做法：把 9 个图标在 3×3 的大画布上重复画一遍，再裁中间那块 —— 跨边界的图标
会被自动「绕回」，平铺时看不到接缝。

用法：
    python assets/patterns/src/generate_pattern.py
预览图输出到 build/pattern_preview/（含浅色/深色按真实透明度合成的效果图）。
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))   # 仓库根目录
OUT = os.path.join(ROOT, "assets", "patterns", "game_pattern.png")
PREVIEW_DIR = os.path.join(ROOT, "build", "pattern_preview")

TILE = 160                                             # 贴片边长（像素）
BOOST = (30, 255)                                      # alpha 对比度提升区间

# 贴片里的 9 个位置：(中心 x, 中心 y, 目标大小, 旋转角度)
# 每行错开半格 + 大小/角度不一，避免死板的网格感
SLOTS = [
    (27, 26, 42, -14),
    (80, 30, 34, 12),
    (133, 26, 44, -8),
    (54, 80, 36, 18),
    (107, 80, 44, -16),
    (0, 82, 40, 6),        # 贴着接缝，平铺后与右边缘拼成完整图形
    (27, 134, 44, 10),
    (80, 132, 36, -12),
    (133, 134, 42, 16),
]

# 9 个图标（顺序即摆放顺序，文件名与游戏内含义的对应关系见 README）
ICONS = [
    "chest.png",        # 宝箱 / 奖励
    "gear.png",         # 齿轮 / 部件与活动
    "trophy.png",       # 奖杯 / 排行榜与联赛
    "star.png",         # 星星 / 稀有度
    "crown.png",        # 皇冠 / 城市之王
    "shield.png",       # 盾牌 / 帮派
    "skull_cat.png",    # 猫头骨 / 战斗
    "bolt.png",         # 闪电 / 精力与速度
    "magnifier.png",    # 放大镜 / 查车与查询
]


def prep_icon(path, size, angle):
    """裁到 alpha 外框 → 提升 alpha 对比（去掉毛边光晕）→ 旋转 → 缩放到目标大小。"""
    im = Image.open(path).convert("RGBA")
    bbox = im.getchannel("A").getbbox()
    if bbox:
        im = im.crop(bbox)
    im.putalpha(im.getchannel("A").point(
        lambda v: 0 if v <= BOOST[0]
        else min(255, int((v - BOOST[0]) * 255 / (BOOST[1] - BOOST[0])))
    ))
    im = im.rotate(angle, resample=Image.BICUBIC, expand=True)
    w, h = im.size
    s = size / max(w, h)
    return im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)


def build_tile():
    canvas = Image.new("RGBA", (TILE * 3, TILE * 3), (0, 0, 0, 0))
    for slot, name in zip(SLOTS, ICONS):
        cx, cy, size, angle = slot
        icon = prep_icon(os.path.join(HERE, name), size, angle)
        for dx in (-TILE, 0, TILE):
            for dy in (-TILE, 0, TILE):
                canvas.alpha_composite(icon, (cx + TILE + dx - icon.width // 2,
                                              cy + TILE + dy - icon.height // 2))
    return canvas.crop((TILE, TILE, TILE * 2, TILE * 2))


def render_preview(tile, w, h, dark):
    """模拟 Flutter 的 DecorationImage(repeat, opacity, colorFilter srcIn)。"""
    base = (18, 18, 18) if dark else (250, 249, 252)
    tint = (255, 255, 255) if dark else (0, 0, 0)
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
    d.text((16, 20), "CatsKit", fill=(20, 20, 20) if not dark else (235, 235, 235))
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
    print("预览图 →", PREVIEW_DIR)
