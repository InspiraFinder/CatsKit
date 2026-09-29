# 周期性图案贴片

界面里用的两张**无缝平铺**背景贴片，一大一小、刻意做出层次：

| 文件 | 用途 | 元素 | 生成方式 |
|---|---|---|---|
| `game_pattern.png` (200×200) | **主界面背景**（低透明度水印） | **大元素**：纯色圆角**方块** 62-74px ×4 | 脚本几何生成（见下）→ 2×2 交错网格摆放 |
| `activity_pattern.png` (160×160) | 「猫生重开」横幅按钮背景 | **小元素**：活动图标 34-48px ×4 | `assets/cats_icons/*.png`（废铁 / 大奖赛 / 全明星 / 齿轮）→ 缩放旋转后斜向摆放 |

两张图都是**单块贴片**，用法是在 Flutter 里
`DecorationImage(repeat: ImageRepeat.repeat)` 平铺，靠 `opacity` 控制强弱，
所以不需要出大图（game 2KB / activity 13KB）。主界面的透明度在 `lib/main.dart` 的
`_gamePattern` 用法处（浅色 0.07 / 深色 0.10，配 `ColorFilter(srcIn)` 染成黑/白）。

## 无缝做法

把元素按 3×3 重复画在大画布上，再裁中间一块 —— 跨边界的元素会被正确「绕回」，
平铺时看不到接缝（`game_pattern` 里左下那块就贴在接缝上，平铺后自动拼成完整方块）。

## 主界面「纯色方块」贴片（重新生成）

```bash
python assets/patterns/src/generate_pattern.py
```

脚本几何生成 4 个圆角方块（`RADIUS = 0.14` 圆角占边长比例、先放大 4 倍再缩小保证
边缘平滑），按 `SLOTS` 摆好位置/大小/角度，输出 `game_pattern.png`；并把
**按真实透明度合成**的预览图写到 `build/pattern_preview/`：

- `light.png` / `dark.png`：纯图案（浅色 0.07 / 深色 0.10）
- `light_ui.png` / `dark_ui.png`：叠了个粗略主界面（标题 + 置顶横幅 + 5 个按钮）做对照
- `light_strong.png` / `dark_strong.png`：透明度调大一号（0.10 / 0.13），用来判断
  「要不要更明显一点」

常见调整：`RADIUS`（圆角大小）、`SLOTS`（方块位置/边长/角度）、`SOLID_ALPHA`（方块深浅），
界面里的整体强弱改 `lib/main.dart` 的 `opacity`。

### 为什么是纯色方块

- 方块**不带任何内部图案**：贴片会被 `ColorFilter.mode(黑/白, BlendMode.srcIn)`
  染成单色，所以**只有 alpha（形状与深浅）有意义**，素材里的颜色/花纹用不上；
  纯色方块平铺出来最干净，也和「纯色」的诉求一致。
- 边长 62-74（大元素）明显大于横幅里的活动图标 34-48（小元素），拉开层次。
- 大小交替 + 轻微倾斜（±3°）+ 第二行错开半格，既有规律又不死板。
- 历史：先试过「游戏内图标」贴片（宝箱/齿轮/奖杯…），再试过 `game_images/gp` 里的
  「方块徽章」贴片（把徽章拆成面板 + 内部线条两层 alpha），都不够理想，
  最终定为纯色方块（git 历史里都能翻到那两版）。

`src/` 是**子目录**：Flutter 打包资源时只列入所声明目录**本层**的文件
（`flutter_tools/lib/src/asset.dart` 里是 `directory.listSync()`，不递归），
所以生成脚本不会进安装包。
