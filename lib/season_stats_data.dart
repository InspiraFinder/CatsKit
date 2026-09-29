import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'life_sim/life_sim_data.dart';

/// 一条「赛季统计」记录：开始时间 / 结束时间 / 持续时间 / 战斗分数
///
/// 除了下面四个核心字段，还有两个可选字段参与表格里的派生计算：
/// [winsAfter]（赛后胜场）与 [settleMultiplier]（结算系数）。
/// 「赛前胜场 / 场次 / 与上场间隔 / 本场得分」都由相邻记录推导，见 [buildSeasonStatRows]。
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

  /// 战斗分数（战斗里打出来的那个分数，尚未乘结算系数）
  final int finalScore;

  /// 来源：`timer` = 由「时间计算」模块导入，`manual` = 在表格里手动新增
  final String source;

  /// 本场结束之后的赛季胜场数；null = 还没填
  final int? winsAfter;

  /// 战斗分数的结算系数（手动覆盖）；null = 按 [winsAfter] 从胜场里程碑自动取
  final int? settleMultiplier;

  const SeasonStatRecord({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.finalScore,
    this.source = 'manual',
    this.winsAfter,
    this.settleMultiplier,
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
    int? winsAfter,
    int? settleMultiplier,
    bool clearMultiplier = false,
  }) => SeasonStatRecord(
    id: id ?? this.id,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    finalScore: finalScore ?? this.finalScore,
    source: source ?? this.source,
    winsAfter: winsAfter ?? this.winsAfter,
    settleMultiplier: clearMultiplier
        ? null
        : (settleMultiplier ?? this.settleMultiplier),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': startTime.millisecondsSinceEpoch,
    'end': endTime.millisecondsSinceEpoch,
    'score': finalScore,
    'source': source,
    'winsAfter': winsAfter,
    'multiplier': settleMultiplier,
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
        winsAfter: (json['winsAfter'] as num?)?.toInt(),
        settleMultiplier: (json['multiplier'] as num?)?.toInt(),
      );

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
    required DateTime calcTime,
    required int remainingMinutes,
    required int endMinutes,
    required int finalScore,
    int? winsAfter,
    int? settleMultiplier,
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
      startTime: calcTime.subtract(Duration(minutes: elapsed)),
      endTime: calcTime.add(Duration(minutes: end)),
      finalScore: finalScore,
      source: 'timer',
      winsAfter: winsAfter,
      settleMultiplier: settleMultiplier,
    );
  }
}

/// 一场战斗的固定时长：24 小时（1440 分钟）
const int kSeasonBattleMinutes = 24 * 60;

/// 按「赛后胜场」取战斗分数的结算系数（未填胜场时返回 null）
int? seasonStatMultiplierOf(int? winsAfter) =>
    winsAfter == null ? null : cityScoreMultiplier(winsAfter);

/// 表格里的一行：把依赖「战斗先后顺序」的派生字段一次算好
class SeasonStatRow {
  /// 原始记录
  final SeasonStatRecord record;

  /// 场次（按开始时间升序，从 1 开始）
  final int order;

  /// 赛前胜场（上一条的赛后胜场；第一场为 0）
  final int? winsBefore;

  /// 结算系数（手动覆盖优先，否则按胜场里程碑自动取）
  final int? multiplier;

  /// 本场得分 = 战斗分数 × 结算系数
  final int? gainedScore;

  /// 与上一场的间隔分钟数（本场开始 − 上场结束）；第一场为 null
  final int? gapMinutes;

  const SeasonStatRow({
    required this.record,
    required this.order,
    required this.winsBefore,
    required this.multiplier,
    required this.gainedScore,
    required this.gapMinutes,
  });

  String get id => record.id;
  DateTime get startTime => record.startTime;
  DateTime get endTime => record.endTime;
  int get finalScore => record.finalScore;
  int get durationMinutes => record.durationMinutes;
  bool get fromTimer => record.fromTimer;
  int? get winsAfter => record.winsAfter;
}

/// 把记录按开始时间排序，并算出「场次 / 赛前胜场 / 结算系数 / 本场得分 / 与上场间隔」
///
/// ⚠️ 这些字段依赖战斗的先后顺序，所以要用**全部记录**算，
/// 再拿去筛选 / 排序（筛选排序不会改变已算好的场次与间隔）。
List<SeasonStatRow> buildSeasonStatRows(List<SeasonStatRecord> records) {
  final sorted = records.toList()
    ..sort((a, b) {
      final c = a.startTime.compareTo(b.startTime);
      return c != 0 ? c : a.id.compareTo(b.id);
    });

  final rows = <SeasonStatRow>[];
  for (var i = 0; i < sorted.length; i++) {
    final r = sorted[i];
    final prev = i > 0 ? rows[i - 1] : null;
    final winsBefore = prev == null ? 0 : prev.winsAfter;
    final multiplier = r.settleMultiplier ?? seasonStatMultiplierOf(r.winsAfter);
    int? gap;
    if (prev != null) {
      final raw = r.startTime.difference(prev.endTime).inMinutes;
      gap = raw < 0 ? 0 : raw;
    }
    rows.add(
      SeasonStatRow(
        record: r,
        order: i + 1,
        winsBefore: winsBefore,
        multiplier: multiplier,
        gainedScore: multiplier == null ? null : r.finalScore * multiplier,
        gapMinutes: gap,
      ),
    );
  }
  return rows;
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

/// 表格排序依据（点表头切换）
enum SeasonStatSortKey {
  order,
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

/// 按关键词 + 时间范围筛选，再按指定列排序（纯函数，便于测试）
///
/// [from] / [to] 为闭区间，按记录的**开始时间**过滤；[to] 为空表示不设上限。
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
    if (q.isNotEmpty && !seasonStatHaystack(r).contains(q)) continue;
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
      case SeasonStatSortKey.order:
        c = a.order.compareTo(b.order);
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

/// 一行的可搜索文本（时间 / 时长 / 间隔 / 分数 / 胜场 / 系数 / 来源都能被搜到）
String seasonStatHaystack(SeasonStatRow r) => [
  formatSeasonStatFullTime(r.startTime),
  formatSeasonStatTime(r.startTime),
  formatSeasonStatFullTime(r.endTime),
  formatSeasonStatTime(r.endTime),
  '${r.durationMinutes}',
  formatSeasonStatDuration(r.durationMinutes, zh: true),
  formatSeasonStatDuration(r.durationMinutes, zh: false),
  if (r.gapMinutes != null) '${r.gapMinutes}',
  if (r.gapMinutes != null)
    formatSeasonStatDuration(r.gapMinutes!, zh: true),
  '${r.finalScore}',
  formatSeasonStatScore(r.finalScore),
  if (r.winsAfter != null) '${r.winsAfter}胜',
  if (r.winsBefore != null) '${r.winsBefore}',
  if (r.multiplier != null) 'x${r.multiplier} ×${r.multiplier}',
  if (r.gainedScore != null) formatSeasonStatScore(r.gainedScore!),
  '第${r.order}场',
  r.fromTimer ? 'timer 时间计算 导入' : 'manual 手动',
].join(' ').toLowerCase();

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
