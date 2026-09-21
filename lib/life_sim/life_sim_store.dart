/// 「猫生重开」模拟器（CatsKit 2.0） —— 存档读写
///
/// 存到 SharedPreferences（key: `life_sim_save`），JSON 结构与
/// `LifeSimSave.toJson` 完全对应。解析失败时返回 null（由界面决定要不要新建存档）。
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'life_sim_models.dart';

class LifeSimStore {
  static const String prefsKey = 'life_sim_save';

  /// 读取存档（无存档或解析失败返回 null）
  static Future<LifeSimSave?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return LifeSimSave.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// 写入存档
  static Future<void> save(LifeSimSave save) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(save.toJson()));
  }

  /// 删除存档（重新开始）
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }
}
