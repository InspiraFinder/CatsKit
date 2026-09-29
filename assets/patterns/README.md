# 周期性图案贴片

界面里用的两张**无缝平铺**背景贴片，都由离线脚本从游戏素材生成（不需要联网）：

| 文件 | 用途 | 素材 | 生成方式 |
|---|---|---|---|
| `game_pattern.png` (160×160) | **主界面背景**（低透明度水印） | `src/*.png`（游戏内图标：宝箱 / 齿轮 / 奖杯 / 星星 / 皇冠 / 盾牌 / 猫头骨 / 闪电 / 放大镜） | 9 个图标缩放 34-44px → 旋转 -16°~18° → 每行错开半格摆放（其中一个贴接缝，平铺后自动拼回完整图形） |
| `activity_pattern.png` (160×160) | 「猫生重开」横幅按钮背景 | `assets/cats_icons/*.png`（活动图标） | 取 废铁 / 大奖赛 / 全明星 / 齿轮 四个图标 → 缩放 34-48px → 旋转 -20°/18°/8°/-14° → 斜向摆放 |

两张图都是**单块贴片**，用法是在 Flutter 里
`DecorationImage(repeat: ImageRepeat.repeat)` 平铺，靠 `opacity` 控制强弱，
所以不需要出大图（每张约 20KB）。主界面的透明度在 `lib/main.dart` 的
`_gamePattern` 用法处（浅色 0.07 / 深色 0.10，配 `ColorFilter(srcIn)` 染成黑/白）。

## 无缝做法

把贴纸按 3×3 重复画在大画布上，再裁中间一块 —— 跨边界的贴纸会被正确「绕回」，
平铺时看不到接缝。

## 主界面图标贴片（重新生成）

```bash
python assets/patterns/src/generate_pattern.py
```

脚本读 `src/` 里的 9 张图标 → 输出 `game_pattern.png`，并把**按真实透明度合成**的
预览图写到 `build/pattern_preview/`（`light.png` / `dark.png` 是纯图案，
`*_ui.png` 叠了个粗略的主界面做对照），改完看一眼预览图即可。

素材来源（游戏安装包解出的图标，`D:\projects\cats\extract\game_images\icons_split`）：

| `src/` 文件名 | 原文件名 | 游戏内含义 |
|---|---|---|
| `chest.png` | `common_icons_icon216_125x99.png` | 宝箱（奖励） |
| `gear.png` | `common_icons_icon263_137x135.png` | 齿轮（部件 / 活动） |
| `trophy.png` | `common_icons_icon298_149x110.png` | 奖杯（排行榜 / 联赛） |
| `star.png` | `common_icons_icon327_150x150.png` | 星星（稀有度） |
| `crown.png` | `common_settings_icon023_88x74.png` | 皇冠（城市之王） |
| `shield.png` | `common_icons_icon303_92x108.png` | 盾牌（帮派） |
| `skull_cat.png` | `common_fx_icon048_96x84.png` | 猫头骨（战斗） |
| `bolt.png` | `common_icons_icon044_75x106.png` | 闪电（精力 / 速度） |
| `magnifier.png` | `common_hud_buttons_icon049_98x106.png` | 放大镜（查车 / 查询） |

`src/` 是**子目录**：Flutter 打包资源时只列入所声明目录**本层**的文件
（`flutter_tools/lib/src/asset.dart` 里是 `directory.listSync()`，不递归），
所以子目录里的素材与生成脚本不会进安装包。

> 贴片里的颜色其实用不到：Flutter 侧用 `ColorFilter.mode(黑/白, BlendMode.srcIn)`
> 把整张图染成单色水印，所以**只有 alpha（形状）有意义**，换素材时更要看剪影是否好认。
