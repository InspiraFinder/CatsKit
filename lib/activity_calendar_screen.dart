import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 活动名称（中英文）
class ActivityInfo {
  final String id;
  final String nameZh;
  final String nameEn;
  final String iconAsset;
  /// 是否属于小活动类别（图标固定放左上角；即使占用大活动周期也是如此）
  final bool isMini;
  const ActivityInfo({
    required this.id,
    required this.nameZh,
    required this.nameEn,
    required this.iconAsset,
    this.isMini = false,
  });
}

/// 活动定义表
///
/// 颜色存档（v1.4 起取消颜色显示，仅用图标 + 三角标记区分活动）：
///   gp      = Color(0xFF20A21D)  rgb(32, 162, 29)        绿
///   space   = Color(0xFFC6FDF9)  rgb(198, 253, 249)      浅青
///   scrap   = Color(0xFFFDDE53)  rgb(253, 222, 83)       黄
///   allstar = Color(0xFFCF0097)  rgb(207, 0, 151)        品红
///   gear    = Color(0xFFC1D0DF)  rgb(193, 208, 223)      浅灰蓝
///   champ   = Color(0xFFB55924)  rgb(181, 89, 36)        棕
///   tavern  = Color(0xFFC5554E)  rgb(197, 85, 78)        砖红
///   joker   = Color(0xFFFFFE4C)  rgb(255, 254, 76)       亮黄
const Map<String, ActivityInfo> kActivities = {
  'gp': ActivityInfo(
    id: 'gp',
    nameZh: 'GP',
    nameEn: 'Grand Prix',
    iconAsset: 'assets/cats_icons/grand_prix.png',
  ),
  'space': ActivityInfo(
    id: 'space',
    nameZh: '太空',
    nameEn: 'Mega Build',
    iconAsset: 'assets/cats_icons/mega_build.png',
  ),
  'scrap': ActivityInfo(
    id: 'scrap',
    nameZh: '废铁行动',
    nameEn: 'Scrap Run',
    iconAsset: 'assets/cats_icons/scrap_run.png',
  ),
  'allstar': ActivityInfo(
    id: 'allstar',
    nameZh: '全明星',
    nameEn: 'ALL-STARS!',
    iconAsset: 'assets/cats_icons/all_stars.png',
  ),
  'gear': ActivityInfo(
    id: 'gear',
    nameZh: '齿轮奔袭',
    nameEn: 'Gear Run',
    iconAsset: 'assets/cats_icons/gear_run.png',
  ),
  // ===== 小活动（短周期） =====
  'champ': ActivityInfo(
    id: 'champ',
    nameZh: '24h锦标赛+黑市',
    nameEn: '24h Championship + Black Market',
    iconAsset: 'assets/cats_icons/championship.png',
    isMini: true,
  ),
  'tavern': ActivityInfo(
    id: 'tavern',
    nameZh: '酒馆',
    nameEn: 'Tarven',
    iconAsset: 'assets/cats_icons/tavern.png',
    isMini: true,
  ),
  'joker': ActivityInfo(
    id: 'joker',
    nameZh: '王牌',
    nameEn: 'Joker Card',
    iconAsset: 'assets/cats_icons/joker_card.png',
    isMini: true,
  ),
};

/// 活动日历数据
///
/// 每周分为两个时段：
/// - 长周期（4天）：周四 19:00 → 周一 19:00
/// - 短周期（3天）：周一 19:00 → 周四 19:00
///
/// 长周期（4天）的活动按周轮换（每个活动周期一个活动）：
/// - 国服：GP → 废铁 → 太空 → 全明星（循环）
/// - 国际服：GP → 废铁 → 全明星 → GP → 废铁 → 齿轮（循环）
///
/// 短周期（3天）的小活动按槽位轮换：
/// - 国服：酒馆 → 王牌（3天普通小活动）→ 24h锦标赛+黑市（循环）
/// - 国际服：王牌（10天，占2槽）→ 酒馆 → 太空 → 24h锦标赛+黑市（循环）
/// 注意：国际服的王牌为持续 10 天的活动，占 两个小活动周期 + 中间 1 个大活动周期
/// （3 + 4 + 3 = 10 天）；国服的王牌为普通 3 天小活动（仅占 1 槽）。
/// 王牌定位为小活动（图标左上角），中间那个大活动周期的大活动照常进行，
/// 日历上同时显示：右上角正常大活动、左上角王牌（王牌在大活动进行期间继续存在）。
///
/// 锚点：2026-08-20（周四）19:00 所在活动周期为 weekIndex 0，
/// 该周期 4 天时段：国服 = GP，国际服 = 废铁（下周齿轮）。
/// 短周期锚点：2026-08-24（周一）19:00 所在短周期为 shortIndex 0，
/// 该短周期：国服 = 王牌，国际服 = 24h锦标赛+黑市（上一个小活动：国际服 = 太空）。
class ActivityCalendar {
  /// 锚点：2026-08-20（周四）19:00
  static final DateTime _anchor = DateTime(2026, 8, 20, 19, 0);

  /// 短周期锚点：2026-08-24（周一）19:00
  static final DateTime _shortAnchor = DateTime(2026, 8, 24, 19, 0);

  /// 国服 4 天时段活动序列（从锚点周开始）
  /// GP → 废铁 → 太空 → 全明星（循环，废铁与太空顺序已调换）
  static const List<String> _cn4dSequence = [
    'gp',
    'scrap',
    'space',
    'allstar',
  ];

  /// 国际服 4 天时段活动序列（用户给定顺序）
  /// GP-废铁-全明星-GP-废铁-齿轮，当前（锚点周）为废铁（索引4），下周齿轮（索引5）
  static const List<String> _intl4dSequence = [
    'gp',
    'scrap',
    'allstar',
    'gp',
    'scrap',
    'gear',
  ];

  /// 国服短周期（小活动）槽位序列（从 shortIndex 0 开始）
  /// 王牌 → 酒馆 → 24h锦标赛+黑市 → 王牌 → ...（王牌占1槽，3天普通小活动）
  /// shortIndex 0 = 王牌（锚点短周期，今天开启）
  static const List<String> _cnShortSequence = [
    'joker',
    'tavern',
    'champ',
  ];

  /// 国际服短周期（小活动）槽位序列（从 shortIndex 0 开始）
  /// 24h锦标赛+黑市 → 王牌（占2槽，10天）→ 酒馆 → 太空 → 24h锦标赛+黑市 → ...
  /// shortIndex 0 = 24h锦标赛+黑市（锚点短周期，今天开启），shortIndex -1 = 太空
  static const List<String> _intlShortSequence = [
    'champ',
    'joker',
    'joker',
    'tavern',
    'space',
  ];

  /// 国服 4 天时段轮换顺序（公开，用于展示）
  static List<String> get cnSequence => List.unmodifiable(_cn4dSequence);

  /// 国际服 4 天时段轮换顺序（公开，用于展示）
  static List<String> get intlSequence => List.unmodifiable(_intl4dSequence);

  /// 国服短周期轮换顺序（公开，用于展示）
  static List<String> get cnShortSequence => List.unmodifiable(_cnShortSequence);

  /// 国际服短周期轮换顺序（公开，用于展示）
  static List<String> get intlShortSequence =>
      List.unmodifiable(_intlShortSequence);

  /// 国际服序列中锚点周（weekIndex 0）对应的起始索引
  static const int _intlStartIndex = 4;

  /// 计算当前时间所在的 weekIndex（相对锚点周）
  static int weekIndex(DateTime now) {
    final diff = now.difference(_anchor);
    final days = diff.inDays;
    // Dart 的 ~/ 是向零取整，负数天数需向下取整
    final weeks = days ~/ 7;
    if (days < 0 && days % 7 != 0) {
      return weeks - 1;
    }
    return weeks;
  }

  /// 判断当前处于 4 天时段还是 3 天时段
  /// 返回 true = 4天时段（周四19:00-周一19:00），false = 3天时段（周一19:00-周四19:00）
  static bool is4DayPeriod(DateTime now) {
    // 找到本周四 19:00
    final daysSinceThu = (now.weekday - DateTime.thursday) % 7;
    final thisThu = DateTime(
      now.year,
      now.month,
      now.day,
      19,
      0,
    ).subtract(Duration(days: daysSinceThu));
    if (now.isBefore(thisThu)) {
      // 周四19:00之前，属于上一周期的3天时段
      return false;
    }
    final monday = thisThu.add(const Duration(days: 4));
    return now.isBefore(monday);
  }

  /// 获取指定服务器、指定 weekIndex 的 4 天时段活动 id
  static String activityForWeek(String server, int weekIdx) {
    if (server == 'cn') {
      return _cn4dSequence[weekIdx % _cn4dSequence.length];
    }
    // 国际服
    final seq = _intl4dSequence;
    return seq[(_intlStartIndex + weekIdx) % seq.length];
  }

  /// 获取指定服务器当前 4 天时段活动 id
  static String currentActivity(String server, DateTime now) {
    return activityForWeek(server, weekIndex(now));
  }

  /// 获取指定服务器下周 4 天时段活动 id
  static String nextActivity(String server, DateTime now) {
    return activityForWeek(server, weekIndex(now) + 1);
  }

  /// 当前 4 天时段的开始时间（本周四 19:00）
  static DateTime current4dStart(DateTime now) {
    final daysSinceThu = (now.weekday - DateTime.thursday) % 7;
    return DateTime(
      now.year,
      now.month,
      now.day,
      19,
      0,
    ).subtract(Duration(days: daysSinceThu));
  }

  /// 当前 4 天时段的结束时间（下周一 19:00）
  static DateTime current4dEnd(DateTime now) {
    return current4dStart(now).add(const Duration(days: 4));
  }

  /// 当前 3 天时段的开始时间（本周一 19:00）
  static DateTime current3dStart(DateTime now) {
    final daysSinceMon = (now.weekday - DateTime.monday) % 7;
    return DateTime(
      now.year,
      now.month,
      now.day,
      19,
      0,
    ).subtract(Duration(days: daysSinceMon));
  }

  /// 当前 3 天时段的结束时间（本周四 19:00）
  static DateTime current3dEnd(DateTime now) {
    return current3dStart(now).add(const Duration(days: 3));
  }

  /// 某一天所属活动周期的周四 19:00 起点
  /// 若当天在周四19:00之前，返回上一周期的周四19:00
  static DateTime periodThursday(DateTime date) {
    final daysSinceThu = (date.weekday - DateTime.thursday) % 7;
    final thisThu = DateTime(
      date.year,
      date.month,
      date.day,
      19,
      0,
    ).subtract(Duration(days: daysSinceThu));
    // 当天在周四19:00之前 → 属于上一周期
    if (date.isBefore(thisThu)) {
      return thisThu.subtract(const Duration(days: 7));
    }
    return thisThu;
  }

  /// 某一天所属活动周期的 weekIndex
  static int weekIndexForDate(DateTime date) {
    return weekIndex(periodThursday(date));
  }

  /// 某一天处于 4 天时段还是 3 天时段
  static bool is4DayForDate(DateTime date) {
    final thu = periodThursday(date);
    final monday = thu.add(const Duration(days: 4));
    return !date.isBefore(thu) && date.isBefore(monday);
  }

  /// 计算某一天所在的短周期索引（相对短周期锚点）
  /// 短周期：周一 19:00 → 周四 19:00
  static int shortIndexForDate(DateTime date) {
    // 找到该天所在短周期的周一 19:00
    final daysSinceMon = (date.weekday - DateTime.monday) % 7;
    final thisMon = DateTime(
      date.year,
      date.month,
      date.day,
      19,
      0,
    ).subtract(Duration(days: daysSinceMon));
    // 若当天在周一19:00之前（即周日），属于上一短周期
    final start = date.isBefore(thisMon)
        ? thisMon.subtract(const Duration(days: 7))
        : thisMon;
    final diff = start.difference(_shortAnchor);
    final days = diff.inDays;
    final weeks = days ~/ 7;
    if (days < 0 && days % 7 != 0) {
      return weeks - 1;
    }
    return weeks;
  }

  /// 获取指定服务器、指定 shortIndex 的短周期（小活动）活动 id
  static String shortActivityForIndex(String server, int shortIdx) {
    if (server == 'cn') {
      final seq = _cnShortSequence;
      return seq[shortIdx % seq.length];
    }
    // 国际服
    final seq = _intlShortSequence;
    return seq[shortIdx % seq.length];
  }

  /// 获取某一天的活动 id（长周期返回大活动，短周期返回小活动）
  static String? activityForDate(String server, DateTime date) {
    if (is4DayForDate(date)) {
      return activityForWeek(server, weekIndexForDate(date));
    }
    // 短周期（小活动）
    return shortActivityForIndex(server, shortIndexForDate(date));
  }

  /// 某一天 19:00 之前（00:00-19:00）覆盖的活动 id
  /// 与 activityForDate 等价（都按当天 00:00 判断时段），即当天的主导活动
  static String? activityBefore19(String server, DateTime date) {
    return activityForDate(server, date);
  }

  /// 某一天 19:00 之后（19:00-24:00）覆盖的活动 id
  /// 周一/周四 19:00 换活动时会与 activityBefore19 不同，其余日期两者相同
  static String? activityFrom19(String server, DateTime date) {
    return activityForDate(
      server,
      DateTime(date.year, date.month, date.day, 19, 0),
    );
  }

  /// 当天 19:00 是否发生活动切换（换活动日：周一/周四）
  /// 19:00 前与 19:00 后覆盖的活动不同 → 当天既是旧活动的结束日，也是新活动的开始日
  static bool has19Transition(String server, DateTime date) {
    final before = activityBefore19(server, date);
    final after = activityFrom19(server, date);
    return before != null && after != null && before != after;
  }

  /// 是否处于「王牌 10 天排期」的中间大活动周期
  /// 该大活动周期的前后两个小活动槽位都是王牌（如国服 9/3~9/7 废铁，两端连着王牌小活动）
  /// 覆盖 大活动周期所在的大活动开始日（周四）至结束日（周一）；
  /// 此期间日历右上角显示正常大活动，左上角叠加显示持续中的王牌
  static bool isJokerMainPeriod(String server, DateTime date) {
    DateTime? thu;
    if (is4DayForDate(date)) {
      thu = periodThursday(date); // 所在大活动周期开始的周四 19:00
    } else if (date.weekday == DateTime.thursday) {
      // 周四 19:00 开启的大活动周期，当天（00:00-24:00）也算该周期的展示范围
      thu = DateTime(date.year, date.month, date.day, 19);
    } else {
      return false;
    }
    final thuDay = DateTime(thu.year, thu.month, thu.day);
    // 周四当天所属的小活动槽 = 该大活动周期之前的小活动
    final idx = shortIndexForDate(thuDay);
    return shortActivityForIndex(server, idx) == 'joker' &&
        shortActivityForIndex(server, idx + 1) == 'joker';
  }

  /// 第 w 周的周四（长周期起点，19:00）
  static DateTime weekThursday(int w) => _anchor.add(Duration(days: 7 * w));

  /// 第 w 周的长周期结束日（下一周的周一，日历日）
  /// 长周期：周四 19:00 → 下周一 19:00，结束日为下周一
  static DateTime weekEndMonday(int w) =>
      weekThursday(w).add(const Duration(days: 4));

  /// 是否为「终级联赛关闭活动」：全明星 / 齿轮奔袭
  /// 这两种活动期间联赛关闭（+X），结束后分组循环重置
  static bool _isLeagueClosing(String activityId) =>
      activityId == 'allstar' || activityId == 'gear';

  /// 终级联赛分组标记（显示在日期格左下角）：返回 '+0'/'+1'/'+2'/'+3'/'+X'
  ///
  /// 规则：
  /// - 联赛关闭活动（全明星 / 齿轮奔袭）长周期内：中间（周五/六/日）为 +X（联赛关闭）；
  ///   结束日（下周一）为 +0（分组循环重置）；开始日（周四）仍按正常循环计算
  /// - 其余日子：从最近一次联赛关闭活动结束日（下周一）起，按 +0,+1,+2,+3 每 4 天循环，
  ///   直至下一次联赛关闭活动；+X 表示联赛关闭
  static String leagueMark(String server, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final at19 = DateTime(date.year, date.month, date.day, 19, 0);
    // 以 19:00 后的时段为准（与日历显示的活动一致）
    final weekIdx = weekIndexForDate(at19);
    final weekActivity = activityForWeek(server, weekIdx);
    final isClosingWeek = _isLeagueClosing(weekActivity);
    final isLong = is4DayForDate(at19);

    if (isClosingWeek && isLong) {
      // 联赛关闭活动长周期内
      if (day.weekday == DateTime.monday) return '+0'; // 结束日：重置
      if (day.weekday != DateTime.thursday) return '+X'; // 中间：联赛关闭
      // 开始日（周四）：仍按正常循环计算，从上一个联赛关闭活动结束日算起
      int w = weekIdx - 1;
      while (!_isLeagueClosing(activityForWeek(server, w))) {
        w--;
      }
      final prevEnd = weekEndMonday(w);
      final prevDays = at19.difference(prevEnd).inDays;
      return '+${prevDays % 4}';
    }

    // 非关闭活动长周期 / 短周期：
    // 从最近一次联赛关闭活动结束日（下周一）算起
    int w = weekIdx;
    while (!_isLeagueClosing(activityForWeek(server, w))) {
      w--;
    }
    final endDay = weekEndMonday(w);
    final days = at19.difference(endDay).inDays;
    return '+${days % 4}';
  }
}

/// 活动日历界面
class ActivityCalendarScreen extends StatefulWidget {
  final String locale;
  final String server;
  const ActivityCalendarScreen({
    super.key,
    this.locale = 'zh',
    this.server = 'cn',
  });

  @override
  State<ActivityCalendarScreen> createState() => _ActivityCalendarScreenState();
}

class _ActivityCalendarScreenState extends State<ActivityCalendarScreen> {
  late String _locale;
  late String _server;
  late DateTime _displayedMonth; // 当前显示的月份（取当月1号）

  String _t(String zh, String en) => _locale == 'zh' ? zh : en;

  String _activityName(String id) {
    final a = kActivities[id];
    if (a == null) return id;
    return _locale == 'zh' ? a.nameZh : a.nameEn;
  }

  String _weekdayZh(int weekday) {
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    return names[weekday - 1];
  }

  @override
  void initState() {
    super.initState();
    _locale = widget.locale;
    _server = widget.server;
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month, 1);
    _loadServer();
  }

  /// 从通用设置读取当前服务器（国服/国际服）
  Future<void> _loadServer() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('appServer') ?? 'cn';
    if (mounted && saved != _server) {
      setState(() => _server = saved);
    }
  }

  /// 切换显示月份
  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + delta,
        1,
      );
    });
  }

  /// 返回上个月
  DateTime _prevMonth(DateTime m) => DateTime(m.year, m.month - 1, 1);

  /// 返回下个月
  DateTime _nextMonth(DateTime m) => DateTime(m.year, m.month + 1, 1);

  /// 生成月历格子日期列表（含前后月补位，共 6 行 × 7 列）
  List<DateTime> _buildMonthCells(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    // 周一为一周开始：weekday 1=Mon...7=Sun，前面补 (weekday-1) 个空
    final leading = firstDay.weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = <DateTime>[];
    // 前月补位
    final prev = _prevMonth(month);
    final prevDays = DateTime(prev.year, prev.month + 1, 0).day;
    for (int i = leading - 1; i >= 0; i--) {
      cells.add(DateTime(prev.year, prev.month, prevDays - i));
    }
    // 当月
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(month.year, month.month, d));
    }
    // 后月补位到 42 格
    final next = _nextMonth(month);
    int i = 1;
    while (cells.length < 42) {
      cells.add(DateTime(next.year, next.month, i));
      i++;
    }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cells = _buildMonthCells(_displayedMonth);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('活动日历', 'Activity Calendar')),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, {'locale': _locale}),
          tooltip: _t('返回主菜单', 'Back'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- 当前服务器提示 ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0E1026) : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _server == 'cn' ? Icons.public : Icons.language,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _t(
                      '当前服务器：${_server == 'cn' ? '国服' : '国际服'}',
                      'Server: ${_server == 'cn' ? 'CN' : 'Intl'}',
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ---- 可信度指示灯 ----
            _buildCredibilityCard(isDark),
            const SizedBox(height: 12),

            // ---- 月份导航 ----
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: _t('上个月', 'Prev Month'),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  '${_displayedMonth.year} ${_t('年', '')}${_displayedMonth.month}${_t('月', '')}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: _t('下个月', 'Next Month'),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ---- 月历（自适应，横屏时完整显示一个月） ----
            _buildCalendarGrid(cells, today, isDark),
            const SizedBox(height: 12),

            // ---- 图例 ----
            _buildLegend(isDark),
            const SizedBox(height: 12),

            // ---- 轮换顺序说明 ----
            _buildRotationInfo(isDark),
          ],
        ),
      ),
    );
  }

  /// 可信度指示灯：国际服 = 黄色（中）、国服 = 黄色（中）
  /// 说明：活动排期以官方为准，本日历仅为根据以往规律的推断
  Widget _buildCredibilityCard(bool isDark) {
    // 国际服与国服当前可信度均为「中」（黄色）
    final lightColor = isDark
        ? Colors.amberAccent
        : Colors.amber.shade600;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1026) : Colors.orange[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.orange.shade400 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 指示灯（带光晕的圆点）
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: lightColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: lightColor.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _t('可信度：中', 'Credibility: Medium'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              '活动排期以官方为准，本日历仅为根据以往规律的推断，'
              '但官方可以修改活动排期。可信度指示灯展示近期活动日历的可信度。',
              'Official schedule prevails; this calendar is only an inference '
              'based on past patterns, and officials may change the schedule. '
              'The indicator shows the credibility of the recent activity '
              'calendar.',
            ),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// 月历网格（自适应：横屏时完整显示一个月，居中且两边留白）
  Widget _buildCalendarGrid(
    List<DateTime> cells,
    DateTime today,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 可用宽度
        final availWidth = constraints.maxWidth;
        // 屏幕高度与方向
        final screenH = MediaQuery.of(context).size.height;
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;

        // 横屏时限制网格高度，确保 6 行能完整显示
        // 竖屏时也限制高度，让格子更扁更紧凑
        final maxGridHeight = isLandscape ? screenH * 0.5 : screenH * 0.55;

        // 格子尺寸 = min(宽度/7, 高度/6)
        final cellW = availWidth / 7;
        final cellHByHeight = maxGridHeight / 6;
        final cellSize = cellW < cellHByHeight ? cellW : cellHByHeight;
        final gridWidth = cellSize * 7;
        final gridHeight = cellSize * 6;

        return Center(
          child: SizedBox(
            width: gridWidth,
            height: gridHeight + 34, // + 表头高度
            child: Column(
              children: [
                // 星期表头
                SizedBox(
                  height: 30,
                  child: Row(
                    children: [
                      for (int w = 1; w <= 7; w++)
                        Expanded(
                          child: Center(
                            child: Text(
                              _weekdayZh(w),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: w >= 6
                                    ? Colors.red[400]
                                    : (isDark
                                          ? Colors.white70
                                          : Colors.grey[700]),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // 日期格子
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisExtent: cellSize,
                    ),
                    itemCount: cells.length,
                    itemBuilder: (context, index) {
                      final date = cells[index];
                      final inMonth =
                          date.month == _displayedMonth.month &&
                          date.year == _displayedMonth.year;
                      return _buildDayCell(
                        date,
                        today,
                        inMonth,
                        isDark,
                        cellSize,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 单个日期格子：统一背景 + 活动图标 + 换活动日双图标/三角标记
  /// 大活动（长周期）图标嵌在右上角，小活动（短周期）图标嵌在左上角，大小统一；
  /// 周一/周四 19:00 换活动：当天同时显示旧活动（红▼ = 结束）与新活动（绿▲ = 开始）
  Widget _buildDayCell(
    DateTime date,
    DateTime today,
    bool inMonth,
    bool isDark,
    double cellSize,
  ) {
    final isToday = date == today;
    final isWeekend = date.weekday >= 6;
    final at19 = DateTime(date.year, date.month, date.day, 19, 0);

    // 旧活动（19:00 前）与新活动（19:00 起）——周一/周四 19:00 换活动
    final oldId = ActivityCalendar.activityBefore19(_server, date);
    final newId = ActivityCalendar.activityFrom19(_server, date);
    final oldA = oldId != null ? kActivities[oldId]! : null;
    final newA = newId != null ? kActivities[newId]! : null;
    final isChangeDay = ActivityCalendar.has19Transition(_server, date);
    final isLongBefore = ActivityCalendar.is4DayForDate(date);
    final isLongAfter = ActivityCalendar.is4DayForDate(at19);
    // 王牌10天排期的中间大活动周期：右上角该大活动周期的正常大活动
    // （周四大活动开始▲、周一大活动结束▼），左上角王牌持续显示（窗口内无开始/结束标记）
    final isJokerMain = ActivityCalendar.isJokerMainPeriod(_server, date);
    // 该大活动周期的正常大活动（用 19:00 定位，避免周四 00:00 取到上一周期）
    final jokerMainA = isJokerMain
        ? kActivities[
            ActivityCalendar.activityForWeek(
              _server,
              ActivityCalendar.weekIndexForDate(
                DateTime(date.year, date.month, date.day, 19),
              ),
            )]!
        : null;

    // 统一背景：所有日期一致，仅用图标区分活动（今天用边框+数字突出）
    final bg = isDark ? Colors.grey.shade900 : Colors.grey.shade100;

    return Container(
      margin: const EdgeInsets.all(0.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: isToday
              ? Colors.blue
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: Stack(
        children: [
          // 日期数字
          Center(
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: !inMonth
                    ? (isDark ? Colors.grey.shade600 : Colors.grey[400])
                    : (isToday
                          ? (isDark ? Colors.lightBlueAccent : Colors.blue)
                          : (isWeekend
                                ? Colors.red[400]
                                : (isDark ? Colors.white : Colors.black87))),
              ),
            ),
          ),
          // 王牌10天排期的中间大活动周期：右上角正常大活动（周四大活动开始▲、
          // 周一大活动结束▼），左上角王牌持续显示（窗口内无开始/结束标记）
          if (isJokerMain) ...[
            if (jokerMainA != null)
              _activityIcon(
                a: jokerMainA,
                isLong: true,
                inMonth: inMonth,
                isDark: isDark,
                bg: bg,
                cellSize: cellSize,
                showStart: date.weekday == DateTime.thursday,
                showEnd: date.weekday == DateTime.monday,
              ),
            _activityIcon(
              a: kActivities['joker']!,
              isLong: true,
              inMonth: inMonth,
              isDark: isDark,
              bg: bg,
              cellSize: cellSize,
            ),
            // 换活动日：同显新旧两个图标（旧活动红▼结束、新活动绿▲开始）
          ] else if (isChangeDay) ...[
            if (oldA != null)
              _activityIcon(
                a: oldA,
                isLong: isLongBefore,
                inMonth: inMonth,
                isDark: isDark,
                bg: bg,
                cellSize: cellSize,
                showEnd: true,
              ),
            if (newA != null)
              _activityIcon(
                a: newA,
                isLong: isLongAfter,
                inMonth: inMonth,
                isDark: isDark,
                bg: bg,
                cellSize: cellSize,
                showStart: true,
              ),
            // 普通日期：显示当天活动（19:00 起的活动）
          ] else if (newA != null)
            _activityIcon(
              a: newA,
              isLong: isLongAfter,
              inMonth: inMonth,
              isDark: isDark,
              bg: bg,
              cellSize: cellSize,
            ),
          // 左下角：终级联赛分组标记（+0/+1/+2/+3/+X）
          Positioned(
            left: 2,
            bottom: 1,
            child: Opacity(
              opacity: inMonth ? 1.0 : 0.35,
              child: Text(
                ActivityCalendar.leagueMark(_server, date),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 单个活动图标：大活动右上角、小活动左上角，大小统一；
  /// 换活动日可加三角标记（绿▲ 图标右下角 = 该活动当天 19:00 开始；
  /// 红▼ = 该活动当天 19:00 结束），三角边长 = 图标长度的一半
  Widget _activityIcon({
    required ActivityInfo a,
    required bool isLong,
    required bool inMonth,
    required bool isDark,
    required Color bg,
    required double cellSize,
    bool showStart = false,
    bool showEnd = false,
  }) {
    final iconSize = cellSize * 0.32; // 图标统一大小
    final markSize = iconSize * 0.5; // 三角边长 = 图标长度的一半
    // 角位：大活动右上角、小活动左上角（小活动类活动即使占用大活动周期也放左上角）
    final rightCorner = isLong && !a.isMini;
    return Positioned(
      top: 1,
      left: rightCorner ? null : 1,
      right: rightCorner ? 1 : null,
      child: Opacity(
        opacity: inMonth ? 1.0 : 0.35,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Image.asset(
              a.iconAsset,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
            ),
            if (showStart || showEnd)
              Positioned(
                right: -markSize * 0.3,
                bottom: -markSize * 0.3,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showStart)
                      _triangleMark(
                        up: true,
                        isDark: isDark,
                        bg: bg,
                        size: markSize,
                      ),
                    if (showEnd)
                      _triangleMark(
                        up: false,
                        isDark: isDark,
                        bg: bg,
                        size: markSize,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 换活动日三角标记：绿色向上▲ = 当天 19:00 新活动开始；
  /// 红色向下▼ = 当天 19:00 旧活动结束；size 为三角形边长
  Widget _triangleMark({
    required bool up,
    required bool isDark,
    required Color bg,
    double size = 6,
  }) {
    final color = up
        ? (isDark ? Colors.greenAccent : Colors.green.shade700)
        : (isDark ? Colors.redAccent : Colors.red.shade700);
    return CustomPaint(
      size: Size(size, size),
      painter: _TrianglePainter(up: up, color: color, borderColor: bg),
    );
  }

  /// 图例
  Widget _buildLegend(bool isDark) {
    // 长周期活动（大活动）
    const longIds = ['gp', 'space', 'scrap', 'allstar', 'gear'];
    // 短周期活动（小活动）
    const shortIds = ['champ', 'tavern', 'space', 'joker'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1026) : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('图例', 'Legend'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _t('右上角：大活动（长周期）', 'Top-right: Main (long cycle)'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              for (final id in longIds)
                _legendItem(kActivities[id]!, _activityName(id)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _t('左上角：小活动（短周期）', 'Top-left: Mini (short cycle)'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              for (final id in shortIds)
                _legendItem(kActivities[id]!, _activityName(id)),
            ],
          ),
          const SizedBox(height: 8),
          // 左下角：终级联赛分组标记
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('左下角：', 'Bottom-left: '),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              Expanded(
                child: Text(
                  _t(
                    '终级联赛分组，本日 20:00 之前进入联赛时的联赛分组，+X 则表示联赛关闭',
                    'Ultimate League group when entering before 20:00 today; +X means league closed',
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 三角标记含义（▲ 开始 / ▼ 结束，同一行显示）
          Row(
            children: [
              _triangleMark(up: true, isDark: isDark, bg: Colors.transparent),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  _t('活动本日开始', 'Activity starts today'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(width: 12),
              _triangleMark(up: false, isDark: isDark, bg: Colors.transparent),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  _t('活动本日结束', 'Activity ends today'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(ActivityInfo a, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          a.iconAsset,
          width: 16,
          height: 16,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  /// 轮换顺序说明（仅显示当前服务器）
  Widget _buildRotationInfo(bool isDark) {
    List<String> names(List<String> ids) => [
      for (final id in ids)
        _locale == 'zh' ? kActivities[id]!.nameZh : kActivities[id]!.nameEn,
    ];
    final isCn = _server == 'cn';
    final serverLabel = isCn ? _t('国服', 'CN') : _t('国际服', 'Intl');
    final longSeq = names(
      isCn ? ActivityCalendar.cnSequence : ActivityCalendar.intlSequence,
    );
    final shortSeq = names(
      isCn ? ActivityCalendar.cnShortSequence : ActivityCalendar.intlShortSequence,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1026) : Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.green.shade400 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('长周期轮换顺序', 'Long-cycle Rotation'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _rotationRow(serverLabel, longSeq),
          const SizedBox(height: 10),
          Text(
            _t('短周期轮换顺序', 'Short-cycle Rotation'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _rotationRow(serverLabel, shortSeq),
          const SizedBox(height: 6),
          Text(
            _t(
              '王牌为持续 10 天的活动：两个小活动周期加中间一个大活动周期（共 10 天）',
              'Joker Card lasts 10 days: 2 mini cycles plus the middle main cycle (10 days total)',
            ),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            _t(
              '活动一般在 19:00 开始和结束，但是有时会调整为 20:00',
              'Activities usually start/end at 19:00, but sometimes adjust to 20:00',
            ),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _rotationRow(String label, List<String> names) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final name in names)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(name, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 三角标记绘制：绿▲（新活动开始）/ 红▼（旧活动结束）
class _TrianglePainter extends CustomPainter {
  final bool up;
  final Color color;
  final Color borderColor;
  _TrianglePainter({
    required this.up,
    required this.color,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    if (up) {
      path.moveTo(0, h);
      path.lineTo(w, h);
      path.lineTo(w / 2, 0);
    } else {
      path.moveTo(0, 0);
      path.lineTo(w, 0);
      path.lineTo(w / 2, h);
    }
    path.close();
    // 先描边（与格子背景同色）再填充，保证三角在各种图标上清晰可辨
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = borderColor,
    );
    canvas.drawPath(path, Paint()..style = PaintingStyle.fill..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.up != up ||
      oldDelegate.color != color ||
      oldDelegate.borderColor != borderColor;
}