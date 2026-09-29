# 周期性图案贴片

界面里用的两张**无缝平铺**背景贴片：

| 文件 | 用途 | 元素 | 生成方式 |
|---|---|---|---|
| `game_pattern.png` (128×128) | **主界面背景**（低透明度水印） | **纯色圆角方块** ×3：边长 40 / 47 / 43，倾斜 -5° / -17° / +17.5° | 脚本几何生成（见下），构图沿用 2.0.0 版 |
| `activity_pattern.png` (160×160) | 「猫生重开」横幅按钮背景 | 活动图标 34-48px ×4 | `assets/cats_icons/*.png`（废铁 / 大奖赛 / 全明星 / 齿轮）→ 缩放旋转后斜向摆放 |

两张图都是**单块贴片**，用法是在 Flutter 里
`DecorationImage(repeat: ImageRepeat.repeat)` 平铺，靠 `opacity` 控制强弱，
所以不需要出大图（game 1.2KB / activity 13KB）。主界面的透明度在 `lib/main.dart` 的
`_gamePattern` 用法处（浅色 0.07 / 深色 0.10，配 `ColorFilter(srcIn)` 染成黑/白）。

## 主界面：2.0.0 的构图 + 方块里的内容清空

2.0.0 那版主界面背景的**构图**（128×128 贴片、3 个带倾斜的方块、各自的位置）用户觉得不错，
缺点是方块是用当时的 app icon（一张方图）做的，所以方块里带着吉祥物图案。
现在**构图原样保留，只把内容清掉**：

- 位置 / 边长 / 倾斜角度是从 git 历史里的 `assets/patterns/cat_pattern.png`
  （2.0.0 时期，如 `git show 0934803^:assets/patterns/cat_pattern.png`）
  的 alpha 通道里量出来的：三个方块边长 40 / 47 / 43、倾斜约 -5° / -17° / +17.5°、
  中心分别在 (91.3, 20.8) / (33.2, 32.8) / (96.7, 90.8)（都是 128 坐标系）。
- 方块本体改成**纯色圆角方块**（圆角占边长 `RADIUS = 0.12`，先放大 4 倍画再缩小保证边缘平滑），
  内部不再有任何图案。
- 为什么可以不放素材：贴片会被 `ColorFilter.mode(黑/白, BlendMode.srcIn)` 染成单色，
  **只有 alpha（形状与深浅）有意义**，纯色方块平铺出来最贴近「把内容清掉」的效果。

```bash
python assets/patterns/src/generate_pattern.py     # 重新生成贴片
```

脚本同时把**按真实透明度合成**的预览图写到 `build/pattern_preview/`：

- `light.png` / `dark.png`：纯图案（浅色 0.07 / 深色 0.10）
- `light_ui.png` / `dark_ui.png`：叠了个粗略主界面（标题 + 置顶横幅 + 5 个按钮）做对照
- `light_strong.png` / `dark_strong.png`：透明度调大一号（0.10 / 0.13）

常见调整：`SLOTS`（方块位置/边长/角度）、`RADIUS`（圆角）、`SOLID_ALPHA`（方块深浅），
界面里的整体强弱改 `lib/main.dart` 的 `opacity`。

## 无缝做法

把方块按 3×3 重复画在大画布上，再裁中间一块 —— 跨边界的方块会被正确「绕回」，
平铺时看不到接缝（三个方块里有一个就压在贴片上边界上）。

`src/` 是**子目录**：Flutter 打包资源时只列入所声明目录**本层**的文件
（`flutter_tools/lib/src/asset.dart` 里是 `directory.listSync()`，不递归），
所以生成脚本不会进安装包。
