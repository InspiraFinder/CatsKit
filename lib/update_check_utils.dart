import 'dart:io';

// ==================== 更新检查用的纯函数（便于单测） ====================

/// 当前平台标识（用于挑 release 附件 / 拼接直链）
String currentPlatformKey() {
  if (Platform.isAndroid) return 'android';
  if (Platform.isWindows) return 'windows';
  if (Platform.isIOS) return 'ios';
  if (Platform.isLinux) return 'linux';
  return 'other';
}

/// 按平台拼出 release 附件直链。
///
/// 附件命名见 `.github/workflows/release.yml`：
/// `app-arm64-v8a-release.apk` / `CatsKit-windows-<tag>.zip` /
/// `CatsKit-ios-<tag>.ipa` / `CatsKit-linux-x64-<tag>.tar.gz`
String releaseAssetUrlFor(String tag, String platform) {
  const base = 'https://github.com/InspiraFinder/CatsKit/releases/download';
  switch (platform) {
    case 'android':
      return '$base/$tag/app-arm64-v8a-release.apk';
    case 'windows':
      return '$base/$tag/CatsKit-windows-$tag.zip';
    case 'ios':
      return '$base/$tag/CatsKit-ios-$tag.ipa';
    case 'linux':
      return '$base/$tag/CatsKit-linux-x64-$tag.tar.gz';
  }
  return 'https://github.com/InspiraFinder/CatsKit/releases/tag/$tag';
}

/// 从 release 页面的跳转地址里取出 tag：
/// `…/releases/tag/v2.2.4` → `v2.2.4`（取不到返回 null）
String? latestTagFromLocation(String? location) {
  if (location == null || location.isEmpty) return null;
  final m = RegExp('/releases/tag/([^/?#]+)').firstMatch(location);
  return m?.group(1);
}

/// 从附件名列表里挑出当前平台要用的那一个（返回下标，挑不到返回 null）。
///
/// 先按「严格」规则找（Android 优先 arm64、Windows 认 windows、iOS 认 ipa、
/// Linux 认 linux），再按「宽松」规则兜底（只看后缀）。
int? pickAssetIndexForPlatform(List<String> names, String platform) {
  bool strict(String n) {
    switch (platform) {
      case 'android':
        return n.endsWith('.apk') && n.contains('arm64');
      case 'windows':
        return n.contains('windows');
      case 'ios':
        return n.endsWith('.ipa');
      case 'linux':
        return n.contains('linux');
    }
    return false;
  }

  bool loose(String n) {
    switch (platform) {
      case 'android':
        return n.endsWith('.apk');
      case 'windows':
        return n.endsWith('.zip');
      case 'ios':
        return n.endsWith('.ipa');
      case 'linux':
        return n.endsWith('.tar.gz');
    }
    return false;
  }

  for (final fn in <bool Function(String)>[strict, loose]) {
    for (var i = 0; i < names.length; i++) {
      if (fn(names[i].toLowerCase())) return i;
    }
  }
  return null;
}
