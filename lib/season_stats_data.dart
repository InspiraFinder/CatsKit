import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 一条「赛季统计」记录：对战 / 开始时间 / 结束时间 / 持续时间 / 战斗分数
///
/// 还带上「赛前胜场」与「本场结果」两个手动填写的字段：
/// - 结算系数只由 [winsBefore]（赛前已有胜场）决定
/// - 赛后胜场 = 赛前胜场 +（本场获胜 ? 1 : 0）
/// 「场次 / 赛后胜场 / 与上场间隔 / 结算系数 / 本场得分」都由相邻记录推导，
/// 见 [buildSeasonStatRows]。
///
/// 持续时间**不单独存储**，一律由「结束时间 - 开始时间」推导，
/// 这样表格里不会出现三者互相矛盾的数据。
class SeasonStatRecord {
  /// 唯一 id（创建时刻的微秒时间戳）
  final String id;

  /// 本场战斗的敌方 ID（手动填，可空）
  final String enemyId;

  /// 开始时间
  final DateTime startTime;

  /// 结束时间
  final DateTime endTime;

  /// 战斗分数（战斗里打出来的那个分数，尚未乘结算系数）
  final int finalScore;

  /// 来源：`timer` = 由「时间计算」模块导入，`manual` = 在表格里手动新增
  final String source;

  /// 本场之前已有的赛季胜场数（决定结算系数）；null = 还没填
  final int? winsBefore;

  /// 本场结果：true = 获胜，false = 未获胜，null = 还没填
  final bool? won;

  const SeasonStatRecord({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.finalScore,
    this.enemyId = '',
    this.source = 'manual',
    this.winsBefore,
    this.won,
  });

  /// 持续时间（分钟）；结束时间早于开始时间时按 0 处理
  int get durationMinutes {
    final d = endTime.difference(startTime).inMinutes;
    return d < 0 ? 0 : d;
  }

  /// 是否由「时间计算」导入
  bool get fromTimer => source == 'timer';

  SeasonStatRecord copyWith({
    String? id,
    String? enemyId,
    DateTime? startTime,
    DateTime? endTime,
    int? finalScore,
    String? source,
    int? winsBefore,
    bool? won,
  }) => SeasonStatRecord(
    id: id ?? this.id,
    enemyId: enemyId ?? this.enemyId,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    finalScore: finalScore ?? this.finalScore,
    source: source ?? this.source,
    winsBefore: winsBefore ?? this.winsBefore,
    won: won ?? this.won,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'enemy': enemyId,
    'start': startTime.millisecondsSinceEpoch,
    'end': endTime.millisecondsSinceEpoch,
    'score': finalScore,
    'source': source,
    'winsBefore': winsBefore,
    'won': won,
  };

  factory SeasonStatRecord.fromJson(Map<String, dynamic> json) {
    // 兼容旧数据：早期存的是「赛后胜场」（winsAfter），按「本场获胜」回推赛前胜场
    final legacyAfter = (json['winsAfter'] as num?)?.toInt();
    var winsBefore = (json['winsBefore'] as num?)?.toInt();
    var won = json['won'] as bool?;
    if (winsBefore == null && legacyAfter != null) {
      winsBefore = legacyAfter > 0 ? legacyAfter - 1 : 0;
      won ??= true;
    }
    return SeasonStatRecord(
      id: json['id'] as String? ?? '',
      enemyId: json['enemy'] as String? ?? '',
      startTime: DateTime.fromMillisecondsSinceEpoch(
        (json['start'] as num?)?.toInt() ?? 0,
      ),
      endTime: DateTime.fromMillisecondsSinceEpoch(
        (json['end'] as num?)?.toInt() ?? 0,
      ),
      finalScore: (json['score'] as num?)?.toInt() ?? 0,
      source: json['source'] as String? ?? 'manual',
      winsBefore: winsBefore,
      won: won,
    );
  }

  /// 由「时间计算」的结果生成记录。
  ///
  /// 一场战斗最长 [kSeasonBattleMinutes]（24 小时），而「时间计算」识别到的是**剩余时间**：
  /// - 已经经过的时间 = 24h − 剩余时间
  /// - 开始时间 = 计算那一刻 − 已经经过的时间
  /// - 结束时间 = 计算那一刻 + **实际**结束分钟数
  ///
  /// 注意：结束时间不一定是开始时间 + 24h。一方提前达到分数线就会提前结束，
  /// 此时 [endMinutes] < [remainingMinutes]，战斗时长也就不到 24 小时。
  factory SeasonStatRecord.fromTimer({
    String? id,
    String enemyId = '',
    required DateTime calcTime,
    required int remainingMinutes,
    required int endMinutes,
    required int finalScore,
    int? winsBefore,
    bool? won,
  }) {
    // 剩余时间钳制到 [0, 24h]：脏数据也不会算出反的区间
    var remain = remainingMinutes;
    if (remain < 0) remain = 0;
    if (remain > kSeasonBattleMinutes) remain = kSeasonBattleMinutes;
    final elapsed = kSeasonBattleMinutes - remain;
    // 实际结束时间不可能晚于 24 小时窗口的末尾
    var end = endMinutes;
    if (end < 0) end = 0;
    if (end > remain) end = remain;
    return SeasonStatRecord(
      id: id ?? newSeasonStatId(),
      enemyId: enemyId,
      startTime: calcTime.subtract(Duration(minutes: elapsed)),
      endTime: calcTime.add(Duration(minutes: end)),
      finalScore: finalScore,
      source: 'timer',
      winsBefore: winsBefore,
      won: won,
    );
  }
}

/// 一场战斗的固定时长：24 小时（1440 分钟）
const int kSeasonBattleMinutes = 24 * 60;

/// 战斗分数的结算系数的一档：按**本场之前的赛季胜场数**取
class SeasonScoreMultiplier {
  /// 赛前胜场下限（含）
  final int minWins;

  /// 赛前胜场上限（含）；null = 无上限
  final int? maxWins;

  /// 这一档的结算系数
  final int multiplier;

  const SeasonScoreMultiplier({
    required this.minWins,
    this.maxWins,
    required this.multiplier,
  });

  /// 区间文案：`0 - 1` / `30 及以上`
  String winsLabel(bool zh) {
    if (maxWins == null) return zh ? '$minWins 及以上' : '$minWins+';
    if (minWins == maxWins) return '$minWins';
    return '$minWins - $maxWins';
  }
}

/// 战斗分数的结算系数表（按赛前胜场升序）
///
/// 赛前 0-1 胜 ×1、2-3 胜 ×2、4-5 胜 ×3、6-8 胜 ×4、9-11 胜 ×5、12-15 胜 ×6、
/// 16-19 胜 ×8、20-24 胜 ×10、25-29 胜 ×15、30 胜及以上 ×20。
///
/// ⚠️ 机制指南里的那张表要与本表保持一致（`test/season_stats_test.dart` 有对拍）。
const List<SeasonScoreMultiplier> kSeasonScoreMultipliers =
    <SeasonScoreMultiplier>[
      SeasonScoreMultiplier(minWins: 0, maxWins: 1, multiplier: 1),
      SeasonScoreMultiplier(minWins: 2, maxWins: 3, multiplier: 2),
      SeasonScoreMultiplier(minWins: 4, maxWins: 5, multiplier: 3),
      SeasonScoreMultiplier(minWins: 6, maxWins: 8, multiplier: 4),
      SeasonScoreMultiplier(minWins: 9, maxWins: 11, multiplier: 5),
      SeasonScoreMultiplier(minWins: 12, maxWins: 15, multiplier: 6),
      SeasonScoreMultiplier(minWins: 16, maxWins: 19, multiplier: 8),
      SeasonScoreMultiplier(minWins: 20, maxWins: 24, multiplier: 10),
      SeasonScoreMultiplier(minWins: 25, maxWins: 29, multiplier: 15),
      SeasonScoreMultiplier(minWins: 30, multiplier: 20),
    ];

/// 按**赛前胜场**取结算系数（胜场未知时返回 null）
int? seasonScoreMultiplierOf(int? winsBefore) {
  if (winsBefore == null || winsBefore < 0) return null;
  for (final band in kSeasonScoreMultipliers) {
    if (winsBefore < band.minWins) continue;
    if (band.maxWins != null && winsBefore > band.maxWins!) continue;
    return band.multiplier;
  }
  return null;
}

/// 表格里的一行：把依赖「战斗先后顺序」的派生字段一次算好
class SeasonStatRow {
  /// 原始记录
  final SeasonStatRecord record;

  /// 所属赛季名（跨赛季查询时用来区分；空 = 未指定）
  final String seasonName;

  /// 所属赛季的稳定 id（`''` = 当前赛季，其余 = 归档 id）
  final String seasonId;

  /// 场次（**在所属赛季内**按开始时间升序，从 1 开始）
  final int order;

  /// 赛前胜场（记录里填的值；没填就接上一条的赛后胜场，第一条按 0）
  final int? winsBefore;

  /// 赛后胜场（= 赛前胜场 +（本场获胜 ? 1 : 0））；胜场或结果未知时为 null
  final int? winsAfter;

  /// 结算系数（只看赛前胜场）
  final int? multiplier;

  /// 本场得分 = 战斗分数 × 结算系数
  final int? gainedScore;

  /// 与上一场的间隔分钟数（本场开始 − 上场结束）；赛季第一场为 null
  final int? gapMinutes;

  const SeasonStatRow({
    required this.record,
    required this.order,
    required this.winsBefore,
    required this.winsAfter,
    required this.multiplier,
    required this.gainedScore,
    required this.gapMinutes,
    this.seasonName = '',
    this.seasonId = '',
  });

  String get id => record.id;
  String get enemyId => record.enemyId;
  DateTime get startTime => record.startTime;
  DateTime get endTime => record.endTime;
  int get finalScore => record.finalScore;
  int get durationMinutes => record.durationMinutes;
  bool get fromTimer => record.fromTimer;
  bool? get won => record.won;
}

/// 把记录按开始时间排序，并算出「场次 / 赛前胜场 / 赛后胜场 / 系数 / 本场得分 / 与上场间隔」
///
/// ⚠️ 这些字段依赖战斗的先后顺序，所以要用**同一赛季的全部记录**算（见
/// [buildSeasonStatRowsForGroups]），再拿去筛选 / 排序（筛选排序不会改变已算好的场次与间隔）。
List<SeasonStatRow> buildSeasonStatRows(
  List<SeasonStatRecord> records, {
  String seasonName = '',
  String seasonId = '',
}) {
  final sorted = records.toList()
    ..sort((a, b) {
      final c = a.startTime.compareTo(b.startTime);
      return c != 0 ? c : a.id.compareTo(b.id);
    });

  final rows = <SeasonStatRow>[];
  for (var i = 0; i < sorted.length; i++) {
    final r = sorted[i];
    final prev = i > 0 ? rows[i - 1] : null;
    // 记录自己填了就用它，否则接上一条的赛后胜场（第一条按 0）
    final winsBefore = r.winsBefore ?? (prev == null ? 0 : prev.winsAfter);
    // 赛后胜场 = 赛前 +（本场获胜 ? 1 : 0）
    final won = r.won;
    final winsAfter = (winsBefore == null || won == null)
        ? null
        : winsBefore + (won ? 1 : 0);
    // 结算系数只看「本场之前」的胜场
    final multiplier = seasonScoreMultiplierOf(winsBefore);
    int? gap;
    if (prev != null) {
      final raw = r.startTime.difference(prev.endTime).inMinutes;
      gap = raw < 0 ? 0 : raw;
    }
    rows.add(
      SeasonStatRow(
        record: r,
        seasonName: seasonName,
        seasonId: seasonId,
        order: i + 1,
        winsBefore: winsBefore,
        winsAfter: winsAfter,
        multiplier: multiplier,
        gainedScore: multiplier == null ? null : r.finalScore * multiplier,
        gapMinutes: gap,
      ),
    );
  }
  return rows;
}

/// 一个可查询的「赛季」：当前赛季（[archived] = false）或一个归档
class SeasonGroup {
  /// 当前赛季用 `''`，归档用归档 id
  final String id;

  /// 展示用名称，如「第 1 赛季」「2026-09 赛季」
  final String name;

  /// 是否是已归档的赛季
  final bool archived;

  /// 归档时间（当前赛季为 null）
  final DateTime? archivedAt;

  /// 备注（归档才有）
  final String note;

  final List<SeasonStatRecord> records;

  const SeasonGroup({
    required this.id,
    required this.name,
    required this.records,
    this.archived = false,
    this.archivedAt,
    this.note = '',
  });

  bool get isEmpty => records.isEmpty;

  /// 首场开始时间
  DateTime? get startTime => records.isEmpty
      ? null
      : records.map((r) => r.startTime).reduce((a, b) => a.isBefore(b) ? a : b);

  /// 末场结束时间
  DateTime? get endTime => records.isEmpty
      ? null
      : records.map((r) => r.endTime).reduce((a, b) => a.isAfter(b) ? a : b);
}

/// 把多个赛季的记录各自建行后合并（**每个赛季的场次从 1 重新开始**）
List<SeasonStatRow> buildSeasonStatRowsForGroups(List<SeasonGroup> groups) {
  final rows = <SeasonStatRow>[];
  for (final g in groups) {
    rows.addAll(
      buildSeasonStatRows(g.records, seasonName: g.name, seasonId: g.id),
    );
  }
  return rows;
}

/// 一个赛季的汇总（用于归档确认、归档列表、赛季选择器）
class SeasonGroupSummary {
  final int battleCount;
  final int winCount;
  final int totalGained;
  final DateTime? startTime;
  final DateTime? endTime;

  const SeasonGroupSummary({
    required this.battleCount,
    required this.winCount,
    required this.totalGained,
    this.startTime,
    this.endTime,
  });

  static const SeasonGroupSummary empty = SeasonGroupSummary(
    battleCount: 0,
    winCount: 0,
    totalGained: 0,
  );
}

/// 汇总一个赛季：场数 / 胜场 / 本场得分合计 / 起止时间
SeasonGroupSummary summarizeSeasonGroup(List<SeasonStatRecord> records) {
  if (records.isEmpty) return SeasonGroupSummary.empty;
  final rows = buildSeasonStatRows(records);
  var wins = 0;
  for (final r in rows) {
    if (r.won == true) wins++;
  }
  var gained = 0;
  for (final r in rows) {
    if (r.gainedScore != null) gained += r.gainedScore!;
  }
  return SeasonGroupSummary(
    battleCount: rows.length,
    winCount: wins,
    totalGained: gained,
    startTime: records
        .map((r) => r.startTime)
        .reduce((a, b) => a.isBefore(b) ? a : b),
    endTime: records
        .map((r) => r.endTime)
        .reduce((a, b) => a.isAfter(b) ? a : b),
  );
}

/// 一个已归档的赛季：名称 + 备注 + 归档时间 + 当时的全部记录
///
/// 「首场 / 末场时间、场数、胜场、得分合计」都不单独存储，一律从 [records] 推导，
/// 避免存两份互相矛盾的数据。
class SeasonArchive {
  /// 唯一 id
  final String id;

  /// 赛季名称，如「第 1 赛季」「2026-09 赛季」（用来确定是哪个赛季）
  final String name;

  /// 备注（可空）
  final String note;

  /// 归档时间
  final DateTime archivedAt;

  /// 归档时的赛季记录
  final List<SeasonStatRecord> records;

  const SeasonArchive({
    required this.id,
    required this.name,
    required this.records,
    required this.archivedAt,
    this.note = '',
  });

  int get battleCount => records.length;

  DateTime? get startTime => records.isEmpty
      ? null
      : records.map((r) => r.startTime).reduce((a, b) => a.isBefore(b) ? a : b);

  DateTime? get endTime => records.isEmpty
      ? null
      : records.map((r) => r.endTime).reduce((a, b) => a.isAfter(b) ? a : b);

  SeasonGroup toGroup() => SeasonGroup(
    id: id,
    name: name,
    archived: true,
    archivedAt: archivedAt,
    note: note,
    records: records,
  );

  SeasonArchive copyWith({
    String? id,
    String? name,
    String? note,
    DateTime? archivedAt,
    List<SeasonStatRecord>? records,
  }) => SeasonArchive(
    id: id ?? this.id,
    name: name ?? this.name,
    note: note ?? this.note,
    archivedAt: archivedAt ?? this.archivedAt,
    records: records ?? this.records,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'note': note,
    'archivedAt': archivedAt.millisecondsSinceEpoch,
    'records': [for (final r in records) r.toJson()],
  };

  factory SeasonArchive.fromJson(Map<String, dynamic> json) => SeasonArchive(
    id: json['id'] as String? ?? newSeasonStatId(),
    name: json['name'] as String? ?? '',
    note: json['note'] as String? ?? '',
    archivedAt: DateTime.fromMillisecondsSinceEpoch(
      (json['archivedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    ),
    records: <SeasonStatRecord>[
      for (final m in (json['records'] as List?) ?? const <dynamic>[])
        if (m != null)
          SeasonStatRecord.fromJson((m as Map).cast<String, dynamic>()),
    ],
  );
}

/// 生成一个新的记录 id
String newSeasonStatId() =>
    DateTime.now().microsecondsSinceEpoch.toString();

/// 根据记录的时间范围提出一个默认赛季名：
/// 同月 → `2026-09 赛季`；跨月 → `2026-09~10 赛季`；跨年 → `2026 赛季`。
String suggestSeasonName(List<SeasonStatRecord> records, {int? index}) {
  if (records.isEmpty) {
    return index == null ? '' : '第 $index 赛季';
  }
  final start = records
      .map((r) => r.startTime)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  final end = records
      .map((r) => r.endTime)
      .reduce((a, b) => a.isAfter(b) ? a : b);
  String two(int v) => v.toString().padLeft(2, '0');
  if (start.year != end.year) return '${start.year} 赛季';
  if (start.month == end.month) {
    return '${start.year}-${two(start.month)} 赛季';
  }
  return '${start.year}-${two(start.month)}~${two(end.month)} 赛季';
}

/// 赛季统计存储：全部记录序列化成一条 JSON 放进 SharedPreferences
class SeasonStatsStore {
  static const String prefsKey = 'season_stats_records';

  /// 归档列表
  static const String archivesKey = 'season_stats_archives';

  /// 当前赛季的名称
  static const String currentNameKey = 'season_stats_current_name';

  /// 自定义导出目录（空 = 用默认目录）
  static const String exportDirKey = 'season_stats_export_dir';

  /// 表格列顺序（存列名列表）
  static const String columnOrderKey = 'season_stats_column_order';

  /// 当前赛季的默认名称
  static const String defaultCurrentName = '当前赛季';

  static Future<List<SeasonStatRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return <SeasonStatRecord>[];
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      return <SeasonStatRecord>[
        for (final m in list)
          if (m != null)
            SeasonStatRecord.fromJson((m as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      return <SeasonStatRecord>[];
    }
  }

  static Future<void> save(List<SeasonStatRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKey,
      jsonEncode([for (final r in records) r.toJson()]),
    );
  }

  /// 追加一条记录，返回保存后的完整列表
  static Future<List<SeasonStatRecord>> add(SeasonStatRecord record) async {
    final list = await load();
    list.add(record);
    await save(list);
    return list;
  }

  /// 按 id 覆盖一条记录，返回保存后的完整列表
  static Future<List<SeasonStatRecord>> update(SeasonStatRecord record) async {
    final list = await load();
    final i = list.indexWhere((r) => r.id == record.id);
    if (i >= 0) list[i] = record;
    await save(list);
    return list;
  }

  /// 按 id 删除一条记录，返回保存后的完整列表
  static Future<List<SeasonStatRecord>> remove(String id) async {
    final list = await load();
    list.removeWhere((r) => r.id == id);
    await save(list);
    return list;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }

  // ==================== 赛季名称 ====================

  static Future<String> loadCurrentName() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(currentNameKey);
    return (v == null || v.trim().isEmpty) ? defaultCurrentName : v;
  }

  static Future<void> saveCurrentName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final v = name.trim();
    if (v.isEmpty) {
      await prefs.remove(currentNameKey);
    } else {
      await prefs.setString(currentNameKey, v);
    }
  }

  // ==================== 导出目录 / 列顺序 ====================

  /// 读取自定义导出目录（空串 = 用默认目录）
  static Future<String> loadExportDir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(exportDirKey)?.trim() ?? '';
  }

  static Future<void> saveExportDir(String dir) async {
    final prefs = await SharedPreferences.getInstance();
    final v = dir.trim();
    if (v.isEmpty) {
      await prefs.remove(exportDirKey);
    } else {
      await prefs.setString(exportDirKey, v);
    }
  }

  /// 读取表格列顺序（列名列表；没存过返回空列表 = 用默认顺序）
  static Future<List<String>> loadColumnOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(columnOrderKey);
    return raw ?? <String>[];
  }

  static Future<void> saveColumnOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    if (order.isEmpty) {
      await prefs.remove(columnOrderKey);
    } else {
      await prefs.setStringList(columnOrderKey, order);
    }
  }

  // ==================== 归档 ====================

  /// 读取全部归档（归档时间新的在前）
  static Future<List<SeasonArchive>> loadArchives() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(archivesKey);
    if (raw == null || raw.isEmpty) return <SeasonArchive>[];
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      final out = <SeasonArchive>[
        for (final m in list)
          if (m != null) SeasonArchive.fromJson((m as Map).cast<String, dynamic>()),
      ];
      out.sort((a, b) => b.archivedAt.compareTo(a.archivedAt));
      return out;
    } catch (_) {
      return <SeasonArchive>[];
    }
  }

  static Future<void> saveArchives(List<SeasonArchive> archives) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      archivesKey,
      jsonEncode([for (final a in archives) a.toJson()]),
    );
  }

  /// 归档：把当前记录移入一个新归档，并清空当前表格
  static Future<List<SeasonArchive>> archiveCurrent({
    required String name,
    String note = '',
    DateTime? archivedAt,
  }) async {
    final records = await load();
    final archives = await loadArchives();
    archives.insert(
      0,
      SeasonArchive(
        id: newSeasonStatId(),
        name: name.trim().isEmpty ? suggestSeasonName(records) : name.trim(),
        note: note.trim(),
        archivedAt: archivedAt ?? DateTime.now(),
        records: records,
      ),
    );
    await saveArchives(archives);
    await clear();
    return archives;
  }

  /// 新增 / 覆盖一个归档（按 id）
  static Future<List<SeasonArchive>> upsertArchive(SeasonArchive archive) async {
    final archives = await loadArchives();
    final i = archives.indexWhere((a) => a.id == archive.id);
    if (i >= 0) {
      archives[i] = archive;
    } else {
      archives.insert(0, archive);
    }
    await saveArchives(archives);
    return archives;
  }

  /// 删除一个归档
  static Future<List<SeasonArchive>> removeArchive(String id) async {
    final archives = await loadArchives();
    archives.removeWhere((a) => a.id == id);
    await saveArchives(archives);
    return archives;
  }

  /// 清空归档（测试 / 重置用）
  static Future<void> clearArchives() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(archivesKey);
  }

  /// 把归档里的记录取回当前表格（归档保持不动），返回追加后的当前记录
  static Future<List<SeasonStatRecord>> restoreFromArchive(
    SeasonArchive archive, {
    bool replace = false,
  }) async {
    final existing = replace ? <SeasonStatRecord>[] : await load();
    final usedIds = <String>{for (final r in existing) r.id};
    for (final r in archive.records) {
      // 重新分配重复的 id，避免互相覆盖
      final rec = usedIds.contains(r.id)
          ? r.copyWith(id: newSeasonStatId())
          : r;
      usedIds.add(rec.id);
      existing.add(rec);
    }
    await save(existing);
    return existing;
  }
}

/// 表格排序依据（点表头切换）
enum SeasonStatSortKey {
  season,
  order,
  enemyId,
  startTime,
  endTime,
  duration,
  gap,
  finalScore,
  winsBefore,
  winsAfter,
  multiplier,
  gainedScore,
}

/// 表格时间范围筛选
enum SeasonStatRange { all, today, last7, last30, custom }

/// 表格统计摘要
class SeasonStatsSummary {
  final int count;
  final int totalMinutes;
  final int totalScore;
  /// 已算出的「本场得分」之和（系数未知的场次不计入）
  final int totalGained;
  /// 已算出的「本场得分」的场次数
  final int gainedCount;
  final int bestScore;
  final int worstScore;
  final double averageScore;
  final double averageMinutes;
  /// 最后一场的赛后胜场（表格里最新的那个胜场数）
  final int? lastWins;

  const SeasonStatsSummary({
    required this.count,
    required this.totalMinutes,
    required this.totalScore,
    required this.totalGained,
    required this.gainedCount,
    required this.bestScore,
    required this.worstScore,
    required this.averageScore,
    required this.averageMinutes,
    required this.lastWins,
  });

  static const SeasonStatsSummary empty = SeasonStatsSummary(
    count: 0,
    totalMinutes: 0,
    totalScore: 0,
    totalGained: 0,
    gainedCount: 0,
    bestScore: 0,
    worstScore: 0,
    averageScore: 0,
    averageMinutes: 0,
    lastWins: null,
  );
}

/// 计算某个时间范围的起点（配合 [SeasonStatRange] 使用）
DateTime? rangeStart(SeasonStatRange range, {DateTime? now}) {
  final n = now ?? DateTime.now();
  switch (range) {
    case SeasonStatRange.all:
      return null;
    case SeasonStatRange.today:
      return DateTime(n.year, n.month, n.day);
    case SeasonStatRange.last7:
      return DateTime(n.year, n.month, n.day).subtract(
        const Duration(days: 6),
      );
    case SeasonStatRange.last30:
      return DateTime(n.year, n.month, n.day).subtract(
        const Duration(days: 29),
      );
    case SeasonStatRange.custom:
      return null;
  }
}

/// 按「对方 ID」+ 时间范围筛选，再按指定列排序（纯函数，便于测试）
///
/// - [query]：只匹配**对方 ID**（不区分大小写、包含即命中）；空串 = 不按对方筛
/// - [from] / [to]：闭区间，按记录的**开始时间**过滤；为空表示不设该侧上限
List<SeasonStatRow> filterAndSortSeasonStatRows(
  List<SeasonStatRow> rows, {
  String query = '',
  DateTime? from,
  DateTime? to,
  SeasonStatSortKey sortKey = SeasonStatSortKey.startTime,
  bool ascending = false,
}) {
  final q = query.trim().toLowerCase();
  final filtered = <SeasonStatRow>[];
  for (final r in rows) {
    if (from != null && r.startTime.isBefore(from)) continue;
    if (to != null && r.startTime.isAfter(to)) continue;
    if (q.isNotEmpty && !r.enemyId.toLowerCase().contains(q)) continue;
    filtered.add(r);
  }

  int byNum(int? a, int? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1; // 没填的排在后面
    if (b == null) return -1;
    return a.compareTo(b);
  }

  int compare(SeasonStatRow a, SeasonStatRow b) {
    int c;
    switch (sortKey) {
      case SeasonStatSortKey.season:
        c = a.seasonName.compareTo(b.seasonName);
        // 同一赛季内仍然按开始时间排（下面兜底那一行完成）
      case SeasonStatSortKey.order:
        c = a.order.compareTo(b.order);
      case SeasonStatSortKey.enemyId:
        c = a.enemyId.toLowerCase().compareTo(b.enemyId.toLowerCase());
      case SeasonStatSortKey.startTime:
        c = a.startTime.compareTo(b.startTime);
      case SeasonStatSortKey.endTime:
        c = a.endTime.compareTo(b.endTime);
      case SeasonStatSortKey.duration:
        c = a.durationMinutes.compareTo(b.durationMinutes);
      case SeasonStatSortKey.gap:
        c = byNum(a.gapMinutes, b.gapMinutes);
      case SeasonStatSortKey.finalScore:
        c = a.finalScore.compareTo(b.finalScore);
      case SeasonStatSortKey.winsBefore:
        c = byNum(a.winsBefore, b.winsBefore);
      case SeasonStatSortKey.winsAfter:
        c = byNum(a.winsAfter, b.winsAfter);
      case SeasonStatSortKey.multiplier:
        c = byNum(a.multiplier, b.multiplier);
      case SeasonStatSortKey.gainedScore:
        c = byNum(a.gainedScore, b.gainedScore);
    }
    // 同值时按开始时间兜底，保证顺序稳定
    if (c == 0) c = a.startTime.compareTo(b.startTime);
    return ascending ? c : -c;
  }

  filtered.sort(compare);
  return filtered;
}

/// 搜索方式：目前只支持按「对方」或按「时间范围」两种
enum SeasonStatSearchMode { opponent, time }

/// 汇总统计
SeasonStatsSummary summarizeSeasonStats(List<SeasonStatRow> rows) {
  if (rows.isEmpty) return SeasonStatsSummary.empty;
  var totalMinutes = 0;
  var totalScore = 0;
  var totalGained = 0;
  var gainedCount = 0;
  var best = rows.first.finalScore;
  var worst = rows.first.finalScore;
  int? lastWins;
  var lastStart = rows.first.startTime;
  for (final r in rows) {
    totalMinutes += r.durationMinutes;
    totalScore += r.finalScore;
    if (r.gainedScore != null) {
      totalGained += r.gainedScore!;
      gainedCount++;
    }
    if (r.finalScore > best) best = r.finalScore;
    if (r.finalScore < worst) worst = r.finalScore;
    // 取「开始时间最新」的那一条的赛后胜场
    if (!r.startTime.isBefore(lastStart)) {
      lastStart = r.startTime;
      lastWins = r.winsAfter ?? lastWins;
    }
  }
  return SeasonStatsSummary(
    count: rows.length,
    totalMinutes: totalMinutes,
    totalScore: totalScore,
    totalGained: totalGained,
    gainedCount: gainedCount,
    bestScore: best,
    worstScore: worst,
    averageScore: totalScore / rows.length,
    averageMinutes: totalMinutes / rows.length,
    lastWins: lastWins,
  );
}

// ==================== 展示格式化（两个界面共用） ====================

String _p2(int v) => v.toString().padLeft(2, '0');

/// `MM-dd HH:mm`
String formatSeasonStatTime(DateTime dt) =>
    '${_p2(dt.month)}-${_p2(dt.day)} ${_p2(dt.hour)}:${_p2(dt.minute)}';

/// `yyyy-MM-dd HH:mm`
String formatSeasonStatFullTime(DateTime dt) =>
    '${dt.year}-${formatSeasonStatTime(dt)}';

/// 分数千分位：`1234567` → `1,234,567`
String formatSeasonStatScore(int score) {
  final neg = score < 0;
  final s = score.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return neg ? '-$buf' : buf.toString();
}

/// 时长文本：`1 时 23 分` / `45 分` / `2 天 3 时`
String formatSeasonStatDuration(int minutes, {bool zh = true}) {
  final m = minutes < 0 ? 0 : minutes;
  final days = m ~/ 1440;
  final hours = (m % 1440) ~/ 60;
  final mins = m % 60;
  if (zh) {
    if (days > 0) return '$days 天 $hours 时';
    if (hours > 0) return mins > 0 ? '$hours 时 $mins 分' : '$hours 时';
    return '$mins 分';
  }
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  return '${mins}m';
}

/// 只保留 `yyyy-MM-dd HH:mm`（导出用，秒/毫秒不入档）
String formatSeasonStatExportTime(DateTime dt) =>
    '${dt.year}-${_p2(dt.month)}-${_p2(dt.day)} '
    '${_p2(dt.hour)}:${_p2(dt.minute)}';

/// 文件名里的时间戳：`20260930-1412`
String formatSeasonStatFileStamp(DateTime dt) =>
    '${dt.year}${_p2(dt.month)}${_p2(dt.day)}-'
    '${_p2(dt.hour)}${_p2(dt.minute)}';

// ==================== 文件导入 / 导出 ====================

/// 导出文件的 `kind` 标记，用来识别是不是赛季统计的存档
const String kSeasonStatsExportKind = 'catskit.seasonStats';

/// 导出 / 导入的整包数据（一个 JSON 文件）
class SeasonStatsBundle {
  /// 当前赛季的名称
  final String currentSeasonName;

  /// 当前赛季的记录
  final List<SeasonStatRecord> records;

  /// 所有归档
  final List<SeasonArchive> archives;

  const SeasonStatsBundle({
    required this.currentSeasonName,
    required this.records,
    required this.archives,
  });

  bool get isEmpty => records.isEmpty && archives.isEmpty;

  int get totalRecords =>
      records.length + archives.fold<int>(0, (s, a) => s + a.records.length);

  Map<String, dynamic> toJson() => {
    'app': 'CatsKit',
    'kind': kSeasonStatsExportKind,
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'currentSeasonName': currentSeasonName,
    'records': [for (final r in records) r.toJson()],
    'archives': [for (final a in archives) a.toJson()],
  };
}

/// 解析导出文件的内容；格式不对时抛 [FormatException]
SeasonStatsBundle decodeSeasonStatsBundle(String text) {
  dynamic data;
  try {
    data = jsonDecode(text);
  } catch (_) {
    throw const FormatException('不是合法的 JSON 文件');
  }
  if (data is! Map) {
    throw const FormatException('文件内容不是赛季统计存档（应为 JSON 对象）');
  }
  final map = data.cast<String, dynamic>();
  final kind = map['kind'] as String?;
  // 也允许直接导入一个「记录数组」
  if (kind != null && kind != kSeasonStatsExportKind) {
    throw FormatException('不是赛季统计存档（kind = $kind）');
  }
  final records = <SeasonStatRecord>[
    for (final m in (map['records'] as List?) ?? const <dynamic>[])
      if (m != null)
        SeasonStatRecord.fromJson((m as Map).cast<String, dynamic>()),
  ];
  final archives = <SeasonArchive>[
    for (final m in (map['archives'] as List?) ?? const <dynamic>[])
      if (m != null)
        SeasonArchive.fromJson((m as Map).cast<String, dynamic>()),
  ];
  if (kind == null && records.isEmpty && archives.isEmpty) {
    throw const FormatException('文件里没有任何赛季记录');
  }
  return SeasonStatsBundle(
    currentSeasonName: map['currentSeasonName'] as String? ?? '',
    records: records,
    archives: archives,
  );
}

/// 把一整个赛季生成表格文本（TSV，Excel 可直接打开）
///
/// 第一行表头，之后每场一行；列与界面上的表格一致。
String seasonGroupToTsv(SeasonGroup group, {bool zh = true}) {
  final rows = buildSeasonStatRows(
    group.records,
    seasonName: group.name,
    seasonId: group.id,
  );
  final buf = StringBuffer();
  buf.writeln(
    <String>[
      zh ? '赛季' : 'Season',
      zh ? '场次' : 'No.',
      zh ? '对战' : 'Opponent',
      zh ? '开始' : 'Start',
      zh ? '结束' : 'End',
      zh ? '持续' : 'Duration',
      zh ? '间隔' : 'Gap',
      zh ? '战斗分' : 'Battle',
      zh ? '赛前胜场' : 'Wins before',
      zh ? '赛后胜场' : 'Wins after',
      zh ? '系数' : 'Multiplier',
      zh ? '本场得分' : 'Gained',
    ].join('\t'),
  );
  for (final r in rows) {
    buf.writeln(
      <String>[
        group.name,
        r.order.toString(),
        r.enemyId,
        formatSeasonStatExportTime(r.startTime),
        formatSeasonStatExportTime(r.endTime),
        formatSeasonStatDuration(r.durationMinutes, zh: zh),
        r.gapMinutes == null
            ? ''
            : formatSeasonStatDuration(r.gapMinutes!, zh: zh),
        r.finalScore.toString(),
        r.winsBefore?.toString() ?? '',
        r.winsAfter?.toString() ?? '',
        r.multiplier?.toString() ?? '',
        r.gainedScore?.toString() ?? '',
      ].join('\t'),
    );
  }
  return buf.toString();
}

/// 把多个赛季拼成一份 TSV（每个赛季之间空一行，并加一行赛季小计）
String seasonGroupsToTsv(List<SeasonGroup> groups, {bool zh = true}) {
  final buf = StringBuffer();
  for (final g in groups) {
    if (g.records.isEmpty) continue;
    if (buf.isNotEmpty) buf.writeln();
    buf.write(seasonGroupToTsv(g, zh: zh));
    final s = summarizeSeasonGroup(g.records);
    buf.writeln(
      <String>[
        zh ? '${g.name} 小计' : '${g.name} total',
        '${s.battleCount}',
        '',
        s.startTime == null ? '' : formatSeasonStatExportTime(s.startTime!),
        s.endTime == null ? '' : formatSeasonStatExportTime(s.endTime!),
        '',
        '',
        '',
        '',
        '${s.winCount}',
        '',
        '${s.totalGained}',
      ].join('\t'),
    );
  }
  return buf.toString();
}
