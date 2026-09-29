import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 一条「赛季统计」记录：开始时间 / 结束时间 / 持续时间 / 最终分数
///
/// 持续时间**不单独存储**，一律由「结束时间 - 开始时间」推导，
/// 这样表格里不会出现三者互相矛盾的数据。
class SeasonStatRecord {
  /// 唯一 id（创建时刻的微秒时间戳）
  final String id;

  /// 开始时间
  final DateTime startTime;

  /// 结束时间
  final DateTime endTime;

  /// 最终分数（战斗结算时我方的最终分数）
  final int finalScore;

  /// 来源：`timer` = 由「时间计算」模块导入，`manual` = 在表格里手动新增
  final String source;

  const SeasonStatRecord({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.finalScore,
    this.source = 'manual',
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
    DateTime? startTime,
    DateTime? endTime,
    int? finalScore,
    String? source,
  }) => SeasonStatRecord(
    id: id ?? this.id,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    finalScore: finalScore ?? this.finalScore,
    source: source ?? this.source,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': startTime.millisecondsSinceEpoch,
    'end': endTime.millisecondsSinceEpoch,
    'score': finalScore,
    'source': source,
  };

  factory SeasonStatRecord.fromJson(Map<String, dynamic> json) =>
      SeasonStatRecord(
        id: json['id'] as String? ?? '',
        startTime: DateTime.fromMillisecondsSinceEpoch(
          (json['start'] as num?)?.toInt() ?? 0,
        ),
        endTime: DateTime.fromMillisecondsSinceEpoch(
          (json['end'] as num?)?.toInt() ?? 0,
        ),
        finalScore: (json['score'] as num?)?.toInt() ?? 0,
        source: json['source'] as String? ?? 'manual',
      );

  /// 由「时间计算」的结果生成记录：
  /// 开始时间 = 计算那一刻，结束时间 = 计算那一刻 + 实际结束分钟数，
  /// 于是「持续时间」正好等于本次计算的时长。
  factory SeasonStatRecord.fromTimer({
    String? id,
    required DateTime calcTime,
    required int endMinutes,
    required int finalScore,
  }) => SeasonStatRecord(
    id: id ?? newSeasonStatId(),
    startTime: calcTime,
    endTime: calcTime.add(Duration(minutes: endMinutes < 0 ? 0 : endMinutes)),
    finalScore: finalScore,
    source: 'timer',
  );
}

/// 生成一个新的记录 id
String newSeasonStatId() =>
    DateTime.now().microsecondsSinceEpoch.toString();

/// 赛季统计存储：全部记录序列化成一条 JSON 放进 SharedPreferences
class SeasonStatsStore {
  static const String prefsKey = 'season_stats_records';

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
}

/// 表格排序依据
enum SeasonStatSortKey { startTime, endTime, duration, finalScore }

/// 表格时间范围筛选
enum SeasonStatRange { all, today, last7, last30, custom }

/// 表格统计摘要
class SeasonStatsSummary {
  final int count;
  final int totalMinutes;
  final int totalScore;
  final int bestScore;
  final int worstScore;
  final double averageScore;
  final double averageMinutes;

  const SeasonStatsSummary({
    required this.count,
    required this.totalMinutes,
    required this.totalScore,
    required this.bestScore,
    required this.worstScore,
    required this.averageScore,
    required this.averageMinutes,
  });

  static const SeasonStatsSummary empty = SeasonStatsSummary(
    count: 0,
    totalMinutes: 0,
    totalScore: 0,
    bestScore: 0,
    worstScore: 0,
    averageScore: 0,
    averageMinutes: 0,
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

/// 按关键词 + 时间范围筛选，再按指定列排序（纯函数，便于测试）
///
/// [from] / [to] 为闭区间，按记录的**开始时间**过滤；[to] 为空表示不设上限。
List<SeasonStatRecord> filterAndSortSeasonStats(
  List<SeasonStatRecord> records, {
  String query = '',
  DateTime? from,
  DateTime? to,
  SeasonStatSortKey sortKey = SeasonStatSortKey.startTime,
  bool ascending = false,
}) {
  final q = query.trim().toLowerCase();
  final filtered = <SeasonStatRecord>[];
  for (final r in records) {
    if (from != null && r.startTime.isBefore(from)) continue;
    if (to != null && r.startTime.isAfter(to)) continue;
    if (q.isNotEmpty && !seasonStatHaystack(r).contains(q)) continue;
    filtered.add(r);
  }

  int compare(SeasonStatRecord a, SeasonStatRecord b) {
    int c;
    switch (sortKey) {
      case SeasonStatSortKey.startTime:
        c = a.startTime.compareTo(b.startTime);
      case SeasonStatSortKey.endTime:
        c = a.endTime.compareTo(b.endTime);
      case SeasonStatSortKey.duration:
        c = a.durationMinutes.compareTo(b.durationMinutes);
      case SeasonStatSortKey.finalScore:
        c = a.finalScore.compareTo(b.finalScore);
    }
    // 同值时按开始时间兜底，保证顺序稳定
    if (c == 0) c = a.startTime.compareTo(b.startTime);
    return ascending ? c : -c;
  }

  filtered.sort(compare);
  return filtered;
}

/// 记录的可搜索文本（开始/结束/持续时间/分数/来源都能被搜到）
String seasonStatHaystack(SeasonStatRecord r) => [
  formatSeasonStatFullTime(r.startTime),
  formatSeasonStatTime(r.startTime),
  formatSeasonStatFullTime(r.endTime),
  formatSeasonStatTime(r.endTime),
  '${r.durationMinutes}',
  formatSeasonStatDuration(r.durationMinutes, zh: true),
  formatSeasonStatDuration(r.durationMinutes, zh: false),
  '${r.finalScore}',
  formatSeasonStatScore(r.finalScore),
  r.fromTimer ? 'timer 时间计算 导入' : 'manual 手动',
].join(' ').toLowerCase();

/// 汇总统计
SeasonStatsSummary summarizeSeasonStats(List<SeasonStatRecord> records) {
  if (records.isEmpty) return SeasonStatsSummary.empty;
  var totalMinutes = 0;
  var totalScore = 0;
  var best = records.first.finalScore;
  var worst = records.first.finalScore;
  for (final r in records) {
    totalMinutes += r.durationMinutes;
    totalScore += r.finalScore;
    if (r.finalScore > best) best = r.finalScore;
    if (r.finalScore < worst) worst = r.finalScore;
  }
  return SeasonStatsSummary(
    count: records.length,
    totalMinutes: totalMinutes,
    totalScore: totalScore,
    bestScore: best,
    worstScore: worst,
    averageScore: totalScore / records.length,
    averageMinutes: totalMinutes / records.length,
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
