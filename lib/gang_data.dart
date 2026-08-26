import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 一个帮派成员的车辆数据（一个账号 3 辆车）
class GangMember {
  final String userId;
  final List<int?> hp; // 3 辆车
  final List<int?> atk; // 3 辆车

  GangMember({required this.userId, required this.hp, required this.atk});

  int get totalHp => hp.fold(0, (s, v) => s + (v ?? 0));
  int get totalAtk => atk.fold(0, (s, v) => s + (v ?? 0));

  Map<String, dynamic> toJson() => {'userId': userId, 'hp': hp, 'atk': atk};

  factory GangMember.fromJson(Map<String, dynamic> json) => GangMember(
    userId: json['userId'] as String? ?? '',
    hp: ((json['hp'] as List?) ?? const [])
        .map((e) => (e as num?)?.toInt())
        .toList(),
    atk: ((json['atk'] as List?) ?? const [])
        .map((e) => (e as num?)?.toInt())
        .toList(),
  );
}

/// 一个帮派（我的帮派一个槽位）：名称 + 成员列表
class GangData {
  String name;
  List<GangMember> members;

  GangData({required this.name, required this.members});

  bool get isEmpty => members.isEmpty;
  int get memberCount => members.length;
  int get totalHp => members.fold(0, (s, m) => s + m.totalHp);
  int get totalAtk => members.fold(0, (s, m) => s + m.totalAtk);

  Map<String, dynamic> toJson() => {
    'name': name,
    'members': [for (final m in members) m.toJson()],
  };

  factory GangData.fromJson(Map<String, dynamic> json) => GangData(
    name: json['name'] as String? ?? '',
    members: ((json['members'] as List?) ?? const [])
        .map(
          (m) => GangMember.fromJson((m as Map).cast<String, dynamic>()),
        )
        .toList(),
  );
}

/// 帮派存储：5 个帮派槽位（slot 1~5），持久化到 SharedPreferences
class GangStore {
  static const String _prefsKey = 'my_gangs';
  static const int slotCount = 5;

  /// 读取全部槽位
  static Future<List<GangData?>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return List<GangData?>.filled(slotCount, null);
    }
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      return List<GangData?>.generate(slotCount, (i) {
        if (i >= list.length || list[i] == null) return null;
        final m = list[i] as Map;
        return GangData.fromJson(m.cast<String, dynamic>());
      });
    } catch (_) {
      return List<GangData?>.filled(slotCount, null);
    }
  }

  /// 保存全部槽位
  static Future<void> save(List<GangData?> slots) async {
    final prefs = await SharedPreferences.getInstance();
    final list = slots.map((v) => v?.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(list));
  }
}
