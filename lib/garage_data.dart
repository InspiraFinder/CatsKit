import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'parts_data.dart';

/// 部件 id → 短索引（合并国际服 + 国服所有部件）
final Map<String, int> _partIndex = () {
  final m = <String, int>{};
  int i = 0;
  for (final p in [...PartDatabase.allParts, ...PartDatabase.cnAllParts]) {
    if (!m.containsKey(p.id)) m[p.id] = i++;
  }
  return m;
}();

/// 短索引 → 部件 id
final List<String> _indexToPartId = () {
  final entries = _partIndex.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  return [for (final e in entries) e.key];
}();

/// 车库中保存的一辆车
/// 只存部件 id 与等级/额外加成，部件详情运行时从数据库解析。
class GarageVehicle {
  String? name; // 车位名称（可空，用于玩家自定义命名）
  String? bodyId;
  String? extraWeaponId; // 额外武器（特殊武器槽）
  List<String?> weaponSlots; // 武器槽位（元素=部件id或null，长度=车身武器槽数）
  List<String?> wheelSlots; // 车轮槽位
  List<String?> gadgetSlots; // 配件槽位
  final Map<String, int> levels; // partId -> 等级
  final Map<String, int> bonuses; // partId -> 额外加成百分比

  GarageVehicle({
    this.name,
    this.bodyId,
    this.extraWeaponId,
    List<String?>? weaponSlots,
    List<String?>? wheelSlots,
    List<String?>? gadgetSlots,
    Map<String, int>? levels,
    Map<String, int>? bonuses,
  }) : weaponSlots = weaponSlots ?? [],
       wheelSlots = wheelSlots ?? [],
       gadgetSlots = gadgetSlots ?? [],
       levels = levels ?? {},
       bonuses = bonuses ?? {};

  /// 是否为空（没有车身）
  bool get isEmpty => bodyId == null || bodyId!.isEmpty;

  /// 紧凑列表（去空位），供统计等使用
  List<String> get weaponIds => weaponSlots.whereType<String>().toList();
  List<String> get wheelIds => wheelSlots.whereType<String>().toList();
  List<String> get gadgetIds => gadgetSlots.whereType<String>().toList();

  Map<String, dynamic> toJson() => {
    'name': name,
    'body': bodyId,
    'extraWeapon': extraWeaponId,
    'weaponSlots': weaponSlots,
    'wheelSlots': wheelSlots,
    'gadgetSlots': gadgetSlots,
    'levels': levels,
    'bonuses': bonuses,
  };

  factory GarageVehicle.fromJson(Map<String, dynamic> json) {
    // 兼容旧格式（weapons/wheels/gadgets 紧凑列表）
    List<String?> readSlots(String newKey, String oldKey) {
      final v = json[newKey];
      if (v is List) return v.map((e) => e as String?).toList();
      final old = json[oldKey];
      if (old is List) return old.map((e) => e.toString()).toList();
      return <String?>[];
    }

    return GarageVehicle(
      name: json['name'] as String?,
      bodyId: json['body'] as String?,
      extraWeaponId: json['extraWeapon'] as String?,
      weaponSlots: readSlots('weaponSlots', 'weapons'),
      wheelSlots: readSlots('wheelSlots', 'wheels'),
      gadgetSlots: readSlots('gadgetSlots', 'gadgets'),
      levels: ((json['levels'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      ),
      bonuses: ((json['bonuses'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      ),
    );
  }

  /// 编码为车辆码（紧凑文本，非人类可读，尽量短）
  static String encode(GarageVehicle v) {
    int idx(String? id) =>
        (id == null || id.isEmpty) ? -1 : (_partIndex[id] ?? -1);
    int lvOf(String? id) => (id == null || id.isEmpty)
        ? 0
        : (v.levels[id] ?? 1).clamp(1, 20).toInt();
    int exOf(String? id) => (id == null || id.isEmpty)
        ? 0
        : (v.bonuses[id] ?? 0).clamp(0, 150).toInt();

    List<dynamic> slotList(List<String?> slots) => [
      for (final id in slots)
        if (id == null || id.isEmpty) -1 else [idx(id), lvOf(id), exOf(id)],
    ];

    return jsonEncode([
      1, // 版本号
      idx(v.bodyId),
      lvOf(v.bodyId),
      exOf(v.bodyId),
      idx(v.extraWeaponId),
      lvOf(v.extraWeaponId),
      exOf(v.extraWeaponId),
      slotList(v.weaponSlots),
      slotList(v.wheelSlots),
      slotList(v.gadgetSlots),
    ]);
  }

  /// 从车辆码解码（失败返回 null）
  static GarageVehicle? decode(String code) {
    try {
      final data = jsonDecode(code.trim());
      if (data is! List || data.isEmpty || data[0] != 1) return null;

      String? idOf(dynamic idx) {
        if (idx is! num) return null;
        final i = idx.toInt();
        return (i >= 0 && i < _indexToPartId.length) ? _indexToPartId[i] : null;
      }

      int asInt(dynamic v) => v is num ? v.toInt() : 0;

      final bodyId = idOf(data[1]);
      final extraWeaponId = idOf(data[4]);

      final levels = <String, int>{};
      final bonuses = <String, int>{};
      void setMaps(String? id, int lv, int ex) {
        if (id == null) return;
        levels[id] = lv;
        bonuses[id] = ex;
      }

      setMaps(bodyId, asInt(data[2]), asInt(data[3]));
      setMaps(extraWeaponId, asInt(data[5]), asInt(data[6]));

      List<String?> parseSlots(dynamic raw) {
        if (raw is! List) return <String?>[];
        final result = <String?>[];
        for (final e in raw) {
          if (e is num && e < 0) {
            result.add(null);
          } else if (e is List && e.isNotEmpty) {
            final id = idOf(e[0]);
            result.add(id);
            if (id != null) {
              setMaps(
                id,
                asInt(e.length > 1 ? e[1] : 1),
                asInt(e.length > 2 ? e[2] : 0),
              );
            }
          } else {
            result.add(null);
          }
        }
        return result;
      }

      return GarageVehicle(
        bodyId: bodyId,
        extraWeaponId: extraWeaponId,
        weaponSlots: data.length > 7 ? parseSlots(data[7]) : [],
        wheelSlots: data.length > 8 ? parseSlots(data[8]) : [],
        gadgetSlots: data.length > 9 ? parseSlots(data[9]) : [],
        levels: levels,
        bonuses: bonuses,
      );
    } catch (_) {
      return null;
    }
  }
}

/// 车库存储：10 个车位（slot 1~10），持久化到 SharedPreferences
class GarageStore {
  static const String _prefsKey = 'garage_slots';
  static const int slotCount = 10;

  /// 读取全部车位
  static Future<List<GarageVehicle?>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return List<GarageVehicle?>.filled(slotCount, null);
    }
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      return List<GarageVehicle?>.generate(slotCount, (i) {
        if (i >= list.length || list[i] == null) return null;
        final m = list[i] as Map;
        return GarageVehicle.fromJson(m.cast<String, dynamic>());
      });
    } catch (_) {
      return List<GarageVehicle?>.filled(slotCount, null);
    }
  }

  /// 保存全部车位
  static Future<void> save(List<GarageVehicle?> slots) async {
    final prefs = await SharedPreferences.getInstance();
    final list = slots.map((v) => v?.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(list));
  }
}
