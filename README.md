<div align="center">
  <img src="assets/icon/icon.jpg" width="128" height="128" alt="CatsKit Logo">
  <h1>CatsKit</h1>
  <p>🐱 猫猫车工具 — C.A.T.S. 游戏辅助工具</p>
</div>

<p align="center">
  <img alt="版本" src="https://img.shields.io/github/v/tag/InspiraFinder/CatsKit?style=flat-square">
  <img alt="stars" src="https://img.shields.io/github/stars/InspiraFinder/CatsKit?style=flat-square">
  <img alt="downloads" src="https://img.shields.io/github/downloads/InspiraFinder/CatsKit/total?style=flat-square">
  <img alt="License" src="https://img.shields.io/github/license/InspiraFinder/CatsKit?style=flat-square">
  <img alt="Last Commit" src="https://img.shields.io/github/last-commit/InspiraFinder/CatsKit?style=flat-square">
</p>

---

## 📖 简介

- Meow 🐱 — 基于 Flutter 的跨平台 C.A.T.S. 游戏辅助工具。

## 📖 测试群

- QQ Group: 791499287

## 📦 未签名应用安装指南

> iOS 版为**未签名 IPA**（`CatsKit-ios-*.ipa`），无法直接安装到未越狱设备，需用以下工具自行签名安装。Android APK 和 Windows 版可直接安装使用。

### 方式一：爱思助手（最简单，推荐）

1. 电脑安装 [爱思助手](https://www.i4.cn/)（Windows / macOS 均可），手机用数据线连接并点击「信任此电脑」
2. 打开爱思助手 → 「工具箱」→「IPA 签名」
3. 导入 `CatsKit-ios-*.ipa`，登录你的 Apple ID（免费账号即可）
4. 点击「开始签名」，完成后在「我的设备 → 应用游戏」中找到 CatsKit 点击安装
5. 手机上到 **设置 → 通用 → VPN 与设备管理** 中信任你的 Apple ID 描述文件

### 方式二：Sideloadly（Windows / macOS）

1. 下载并安装 [Sideloadly](https://sideloadly.io/)
2. 手机连接电脑并解锁屏幕
3. 将 `CatsKit-ios-*.ipa` 拖入 Sideloadly 窗口
4. 输入 Apple ID 和密码（开启双重验证时建议使用「专用密码」），点击 **Start**
5. 安装完成后，在 **设置 → 通用 → VPN 与设备管理** 中信任对应描述文件

### 方式三：AltStore（适合长期使用）

1. 电脑安装 [AltServer](https://altstore.io/)，手机安装 AltStore
2. 用数据线连接电脑，通过 AltStore 导入并安装 IPA
3. 之后每 7 天需连接电脑刷新一次签名，否则应用将无法打开

### ⚠️ 注意事项

- 免费 Apple ID 自签的 IPA **有效期 7 天**，到期后需重新签名安装
- 首次打开提示「未受信任的开发者」时，先到 **设置 → 通用 → VPN 与设备管理** 信任对应描述文件
- 自签会占用 Apple ID 的 App ID 名额（免费账号名额有限，用完需删除旧应用后释放）
- 如提示「无法验证开发者」，请删除 App 后重新信任描述文件，再安装一次
- Windows 版：解压 `CatsKit-windows-*.zip` 后运行 `catskit.exe`（OCR 识别需先安装 Python 及依赖）

## 💖 鸣谢

- 感谢 [SAK-20744/Navimoe](https://github.com/SAK-20744/Navimoe) 项目的数据参考与算法支持。
- 感谢 "威廉博士" 国际服限定部件的图片。
- 感谢 "防防猫" 提供的国服数据。
- 感谢 "三体老鸽子", "木小七" 对本项目的贡献。
- 感谢各位反馈者对本项目的支持。

## 📖 开发及贡献

### 如果想贡献自己的想法和建议，不参与开发：
- 请加入测试群

### 如果想参与开发：
- 需要了解git的基本操作，知道如何提交代码，如何创建及合并分支
- 开发主分支：develop，禁止直接推送或合并到 main 分支
- 请加入测试群