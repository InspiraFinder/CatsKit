# 周期性图案贴片

界面里用的两张**无缝平铺**背景贴片，都由离线脚本从游戏素材生成（不需要联网）。
一大一小、刻意做出层次：

| 文件 | 用途 | 元素 | 素材 | 生成方式 |
|---|---|---|---|---|
| `game_pattern.png` (200×200) | **主界面背景**（低透明度水印） | **大元素**：方块徽章 72-84px ×4 | `src/badge_*.png`（游戏内方块徽章 0101 / 0102 / 0201 / 0301） | 方块面板压到很浅 + 内部线条（圆盘/图形/边角装饰的**边缘**）实心 → 2×2 交错网格摆放 |
| `activity_pattern.png` (160×160) | 「猫生重开」横幅按钮背景 | **小元素**：活动图标 34-48px ×4 | `assets/cats_icons/*.png`（废铁 / 大奖赛 / 全明星 / 齿轮） | 缩放 → 旋转 -20°/18°/8°/-14° → 斜向摆放 |

两张图都是**单块贴片**，用法是在 Flutter 里
`DecorationImage(repeat: ImageRepeat.repeat)` 平铺，靠 `opacity` 控制强弱，
所以不需要出大图（每张 20-35KB）。主界面的透明度在 `lib/main.dart` 的
`_gamePattern` 用法处（浅色 0.07 / 深色 0.10，配 `ColorFilter(srcIn)` 染成黑/白）。

## 无缝做法

把贴纸按 3×3 重复画在大画布上，再裁中间一块 —— 跨边界的贴纸会被正确「绕回」，
平铺时看不到接缝（`game_pattern` 里左下那块就贴在接缝上，平铺后自动拼成完整方块）。

## 主界面方块徽章贴片（重新生成）

```bash
python assets/patterns/src/generate_pattern.py
```

脚本读 `src/badge_*.png` → 输出 `game_pattern.png`，并把**按真实透明度合成**的
预览图写到 `build/pattern_preview/`：

- `light.png` / `dark.png`：纯图案（浅色 0.07 / 深色 0.10）
- `light_ui.png` / `dark_ui.png`：叠了个粗略主界面（标题 + 置顶横幅 + 5 个按钮）做对照
- `light_strong.png` / `dark_strong.png`：透明度调大一号（0.10 / 0.13），用来判断
  「要不要更明显一点」

**为什么不是直接把徽章当贴图**：徽章是一整块不透明方块，直接染成单色就是一坨实心
方块，看不出内容。所以拆成两层 alpha：

- 方块面板本体 → 浅（`PANEL_ALPHA = 0.22`），平铺后是一层若隐若现的方块底；
- 内部线条 → 实心，用「先轻微高斯模糊再做 Sobel，取三通道最大梯度」得到边缘
  （`EDGE_TOL = 58`、`EDGE_BLUR = 1.3`），比填色透气，凑近能认出圆盘里的红 V、
  宝石、纹章等图案。

素材来源（游戏安装包解出的方块徽章，`D:\projects\cats\extract\game_images\gp`，
文件名 `0?0?.png` = 家族 01/02/03 × 等级 01-07，刻意选最早的那几级：只有方框 + 圆 +
图形，没有后面的花纹与金边）：

| `src/` 文件名 | 原文件名 | 内容 |
|---|---|---|
| `badge_chevron.png` | `0101.png` | 方块 + 圆盘 + 红 V 形箭头 |
| `badge_chevron2.png` | `0102.png` | 同上，多了边角装饰 |
| `badge_gem.png` | `0201.png` | 方块 + 圆盘 + 宝石/扳手十字 |
| `badge_crest.png` | `0301.png` | 方块 + 圆盘 + 紫色纹章 |

`src/` 是**子目录**：Flutter 打包资源时只列入所声明目录**本层**的文件
（`flutter_tools/lib/src/asset.dart` 里是 `directory.listSync()`，不递归），
所以子目录里的素材与生成脚本不会进安装包。

> Flutter 侧用 `ColorFilter.mode(黑/白, BlendMode.srcIn)` 把整张图染成单色水印，
> 所以贴片里的颜色用不到 —— **只有 alpha（形状与深浅）有意义**，换素材时先看剪影/线稿
> 好不好认。
