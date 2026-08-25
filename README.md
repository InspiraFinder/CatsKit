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

> iOS 版为**未签名 IPA**（`CatsKit-ios-*.ipa`），无法直接安装到未越狱设备。以下为手机端安装方法，按 iOS 版本选择合适方案即可。

### 方法速查表

| 方法 | 是否需电脑 | 是否需 Apple ID | 有效期 | 支持 iOS | 难度 |
|------|--------|-------------|--------|---------|------|
| **TrollStore**（巨魔商店） | 否 | 否 | ⭐ 永久 | 14.0 - 16.6.1 / 17.0 | 中等 |
| **SideStore** | ⚠️ 首次需要 | ✅ 免费 | 7 天（可自动续签） | 14.0 - 18.4+ | 中等 |
| **轻松签 / 全能签** | 否 | ✅ 免费 | 7 天 | 13.0+ | 简单 |
| **Scarlet**（猩红商店） | 否 | 否 | 不稳定（企业证书） | 较广 | 非常简单 |
| **越狱 + AppSync** | 否 | 否 | ⭐ 永久 | 取决于越狱工具 | 较难 |

### 🎯 推荐方案（按 iOS 版本）

- **iOS 14.0 - 16.6.1 / 17.0** → **TrollStore**（永久安装，最佳体验）
- **iOS 16.7.x / 17.0.1+** → **SideStore** 或 **轻松签**
- **iOS 18.x** → **SideStore**（配合 VPN 自动续签）
- **已越狱** → **AppSync + Filza**（最自由）

### 方法说明

**TrollStore（巨魔商店）— 强烈推荐（若版本支持）**
- 利用 CoreTrust 漏洞永久安装未签名 IPA，无需 Apple ID、无需证书、无需越狱
- 安装 IPA：在「文件」App 中点击 IPA → 共享 → TrollStore，自动安装
- ⚠️ 仅支持 iOS 14.0-16.6.1 和 17.0；建议安装 OTADisabler 屏蔽系统更新，防止漏洞被修复

**SideStore — 适合长期使用**
- AltStore 分支，首次设置需电脑（AltServer + JitterbugPair），之后可完全手机端操作
- 通过 WireGuard VPN 自动续签（每 7 天），也可用快捷指令每天自动刷新
- ⚠️ 免费 Apple ID 同时活跃的签名应用数量有限

**轻松签 / 全能签 — 纯手机端**
- 无需电脑，在手机上登录 Apple ID 直接签名安装
- ⚠️ 需从在线安装链接下载描述文件并信任，有一定风险；到期（7 天）后需重新签名

**Scarlet（猩红商店）— 临时使用**
- 共享企业证书，Safari 直接安装，无需 Apple ID
- ⚠️ 企业证书极不稳定，可能被苹果随时吊销，掉签后所有应用同时失效，仅适合临时使用

**越狱 + AppSync — 最自由**
- 安装 AppSync Unified 后可全局绕过签名验证，用 Filza 直接安装 IPA
- ⚠️ 越狱有风险，可能导致设备不稳定或失去保修，银行/支付类 App 可能拒绝运行

### ⚠️ 注意事项 / 安全提示

- 免费 Apple ID 自签的 IPA **有效期 7 天**，到期后需重新签名；TrollStore 除外（永久）
- 首次打开提示「未受信任的开发者」时，到 **设置 → 通用 → VPN 与设备管理** 信任对应描述文件
- **仅从可信来源下载 IPA**，避免安装来路不明的应用
- **不要将 Apple ID 密码分享给任何第三方签名工具**
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