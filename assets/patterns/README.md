# 周期性图案贴片

主界面用的两张**无缝平铺**背景贴片，都由仓库里已有的素材离线生成（不需要联网）：

| 文件 | 用途 | 素材 | 生成方式 |
|---|---|---|---|
| `cat_pattern.png` | 主界面背景（低透明度水印） | `assets/icon/icon.png`（吉祥物） | 抠掉近白背景 → 缩放到 44-60px → 旋转 -18°/16°/-6° → 三个错位摆放 |
| `activity_pattern.png` | 「猫生重开」横幅按钮背景 | `assets/cats_icons/*.png`（活动图标） | 取 废铁/大奖赛/全明星/齿轮 四个图标 → 缩放 34-48px → 旋转 -20°/18°/8°/-14° → 斜向摆放 |

两张图都是 **128×128 / 160×160 的单块贴片**，用法是在 Flutter 里
`DecorationImage(repeat: ImageRepeat.repeat)` 平铺，靠 `opacity` 控制强弱，
所以不需要出大图（每张约 12KB）。

无缝做法：把贴纸按 3×3 重复画在大画布上，再裁中间一块 —— 跨边界的贴纸会被
正确「绕回」，平铺时看不到接缝。

重新生成的脚本（Python + Pillow）：

```python
from PIL import Image, ImageDraw
# 1) 抠掉近白背景（保留角色颜色）：alpha = 255 时完全不透明
def knockout_white(img, t1=242, t2=252):
    img = img.convert("RGBA")
    gray = img.convert("L")
    img.putalpha(gray.point(
        lambda v: 255 if v <= t1 else (0 if v >= t2 else int(255 * (t2 - v) / (t2 - t1)))
    ))
    return img
# 2) 缩放 + 旋转，然后 3×3 画到大画布上，裁中间一块即可
```

需要调整时改一下放大倍数、旋转角度与摆放位置即可；主界面里的透明度在
`lib/main.dart` 的 `_catPattern` / `_activityPattern` 用法处（`opacity:` 参数）。
