/// 机制指南：游戏玩法机制的**文字版 wiki** 数据源。
///
/// 本文件只放内容数据，渲染逻辑在 `mechanism_guide_screen.dart`：
/// 每个 [GuideChapter] 是「一章」= 一个玩法/主题；章内用 [GuideBlock.heading]
/// 分小节（会自动生成章内目录、可以点击跳转），小节里按顺序堆块：
/// 段落、要点列表、提示框、配图行或表格。
///
/// 新增一章：在 [kGuideChapters] 里加一个 [GuideChapter]；
/// 新增小节：在章内加 `GuideBlock.heading(...)`（文件末尾有模板）。
library;

import 'package:flutter/material.dart';

/// 指南里的一条要点（中英各一份）
class GuideBullet {
  final String zh;
  final String en;
  const GuideBullet(this.zh, this.en);
}

/// 指南里的一张配图
class GuideFigure {
  /// 图片资源路径（与 [diagram] 二选一）
  final String? asset;

  /// 内置示意图 id，二选一：
  /// `carLayout`（车辆结构） / `partSample`（四类部件示例） / `sponsors`（赞助商）
  /// / `activityIcons`（活动图标一览） / `jokerTiers`（王牌 R1-R5）
  /// / `chestTypes`（自选箱 / 固定箱） / `gangTiers`（帮派四个组别）
  /// / `seasonFlow`（赛季收尾流程） / `battleBuildings`（战斗建筑与车位）
  /// / `statPipeline`（单车数值乘区链路）
  final String? diagram;

  final String captionZh;
  final String captionEn;

  const GuideFigure.asset(
    this.asset, {
    required this.captionZh,
    required this.captionEn,
  }) : diagram = null;

  const GuideFigure.diagram(
    this.diagram, {
    required this.captionZh,
    required this.captionEn,
  }) : asset = null;
}

/// 指南里的一张表格（表头 + 数据行，中英各一份）
///
/// 每行的单元格数量必须与表头一致（渲染时按 [headZh] 的列数建表）。
class GuideTable {
  final List<String> headZh;
  final List<String> headEn;
  final List<List<String>> rowsZh;
  final List<List<String>> rowsEn;

  const GuideTable({
    required this.headZh,
    required this.headEn,
    required this.rowsZh,
    required this.rowsEn,
  });
}

/// 指南里的一个内容块
class GuideBlock {
  /// 小节标题（wiki 的小节；章内目录由它生成）
  final String? headingZh;
  final String? headingEn;

  /// 段落文字
  final String? textZh;
  final String? textEn;

  /// 要点列表
  final List<GuideBullet> bullets;

  /// 提示框（高亮小块，用来放「注意」「小技巧」）
  final String? tipZh;
  final String? tipEn;

  /// 配图行
  final List<GuideFigure> figures;

  /// 表格
  final GuideTable? table;

  const GuideBlock._({
    this.headingZh,
    this.headingEn,
    this.textZh,
    this.textEn,
    this.bullets = const <GuideBullet>[],
    this.tipZh,
    this.tipEn,
    this.figures = const <GuideFigure>[],
    this.table,
  });

  /// 小节标题
  const GuideBlock.heading(String zh, String en)
      : this._(headingZh: zh, headingEn: en);

  /// 一段正文
  const GuideBlock.text(String zh, String en)
      : this._(textZh: zh, textEn: en);

  /// 一组要点
  const GuideBlock.bullets(List<GuideBullet> bullets) : this._(bullets: bullets);

  /// 一个提示框
  const GuideBlock.tip(String zh, String en) : this._(tipZh: zh, tipEn: en);

  /// 一行配图
  const GuideBlock.figures(List<GuideFigure> figures)
      : this._(figures: figures);

  /// 一张表格
  const GuideBlock.table(GuideTable table) : this._(table: table);
}

/// 指南的一章（一个玩法/主题）
class GuideChapter {
  /// 稳定 id（以后做深链接/收藏用，别改）
  final String id;

  final String titleZh;
  final String titleEn;

  /// 目录里显示的一句话摘要
  final String summaryZh;
  final String summaryEn;

  final IconData icon;
  final Color color;

  /// 搜索用的补充关键词（标题与正文以外的同义词）
  final List<String> keywords;

  final List<GuideBlock> blocks;

  const GuideChapter({
    required this.id,
    required this.titleZh,
    required this.titleEn,
    required this.summaryZh,
    required this.summaryEn,
    this.icon = Icons.menu_book,
    this.color = Colors.blueGrey,
    this.keywords = const <String>[],
    this.blocks = const <GuideBlock>[],
  });

  String title(String locale) => locale == 'zh' ? titleZh : titleEn;
  String summary(String locale) => locale == 'zh' ? summaryZh : summaryEn;

  /// 章内小节：(该小节标题所在的块下标, 标题中英)——渲染时按它生成目录并支持点击跳转
  List<(int, String, String)> get sections {
    final out = <(int, String, String)>[];
    for (var i = 0; i < blocks.length; i++) {
      final h = blocks[i].headingZh;
      if (h != null) {
        out.add((i, h, blocks[i].headingEn ?? h));
      }
    }
    return out;
  }

  /// 是否命中搜索词（标题 / 摘要 / 关键词 / 正文 / 表格都能搜）
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final buf = StringBuffer()
      ..write(titleZh)
      ..write(titleEn)
      ..write(summaryZh)
      ..write(summaryEn)
      ..write(keywords.join(' '));
    for (final b in blocks) {
      buf
        ..write(b.headingZh ?? '')
        ..write(b.headingEn ?? '')
        ..write(b.textZh ?? '')
        ..write(b.textEn ?? '')
        ..write(b.tipZh ?? '')
        ..write(b.tipEn ?? '');
      for (final item in b.bullets) {
        buf
          ..write(item.zh)
          ..write(item.en);
      }
      for (final f in b.figures) {
        buf
          ..write(f.captionZh)
          ..write(f.captionEn);
      }
      final t = b.table;
      if (t != null) {
        buf
          ..write(t.headZh.join(' '))
          ..write(t.headEn.join(' '));
        for (final r in t.rowsZh) {
          buf.write(r.join(' '));
        }
        for (final r in t.rowsEn) {
          buf.write(r.join(' '));
        }
      }
    }
    return buf.toString().toLowerCase().contains(q);
  }
}

/// 赛季结算表的数据行（列：名次 / 自选箱 / 固定箱 / 紫票 / 代币；中英通用）
const List<List<String>> _settleGold = <List<String>>[
  <String>['1', '20', '20', '500000', '130'],
  <String>['2-3', '18', '18', '395000', '102'],
  <String>['4-6', '16', '16', '311000', '80'],
  <String>['7-10', '14', '14', '245000', '63'],
  <String>['11-20', '13', '13', '193000', '50'],
  <String>['21-45', '12', '12', '152000', '39'],
  <String>['46-80', '11', '11', '120000', '31'],
  <String>['80+', '4', '4', '35000', '10'],
];

const List<List<String>> _settleSilver = <List<String>>[
  <String>['1', '15', '15', '160000', '44'],
  <String>['2-3', '12', '12', '122000', '32'],
  <String>['4-6', '11', '11', '94000', '26'],
  <String>['7-10', '10', '10', '74000', '20'],
  <String>['11-20', '9', '9', '58000', '16'],
  <String>['21-45', '8', '8', '45000', '12'],
  <String>['46-80', '7', '7', '33000', '9'],
  <String>['80+', '2', '2', '10000', '3'],
];

const List<List<String>> _settleBronze = <List<String>>[
  <String>['1', '10', '10', '50000', '12'],
  <String>['2-3', '8', '8', '40000', '9'],
  <String>['4-6', '7', '7', '31000', '7'],
  <String>['7-10', '6', '6', '24000', '6'],
  <String>['11-20', '5', '5', '20000', '5'],
  <String>['21-45', '4', '4', '18000', '4'],
  <String>['46-80', '3', '3', '15000', '3'],
  <String>['80+', '0', '0', '4000', '1'],
];

const List<List<String>> _settleWood = <List<String>>[
  <String>['1', '5', '5', '22000', '4'],
  <String>['2-3', '4', '4', '16500', '3'],
  <String>['4-6', '3', '3', '13500', '2'],
  <String>['7-10', '3', '2', '11000', '2'],
  <String>['11-20', '2', '2', '9000', '1'],
  <String>['21-50', '2', '1', '7500', '1'],
  <String>['51-120', '1', '0', '6000', '1'],
  <String>['121-200', '0', '0', '2000', '0'],
];

/// 全部章节 —— **内容都加在这里**
///
/// 模板（复制一份改内容即可；`GuideBlock.heading` 会生成章内目录）：
///
/// ```dart
/// GuideChapter(
///   id: 'activities',
///   titleZh: '活动与周期', titleEn: 'Activities & Cycles',
///   summaryZh: '大活动 4 天、小活动 24h，精力与氪金倍率怎么算',
///   summaryEn: '4-day majors, 24h minis, energy and cash multipliers',
///   icon: Icons.event, color: Colors.purple,
///   keywords: <String>['活动', '周期', '精力', 'event'],
///   blocks: <GuideBlock>[
///     GuideBlock.text('开头一段…', 'Opening paragraph…'),
///     GuideBlock.heading('小节一', 'Section one'),
///     GuideBlock.bullets(<GuideBullet>[GuideBullet('要点', 'Point')]),
///     GuideBlock.figures(<GuideFigure>[
///       GuideFigure.diagram('activityIcons',
///           captionZh: '图注', captionEn: 'Caption'),
///     ]),
///     GuideBlock.table(GuideTable(
///       headZh: <String>['列 1', '列 2'], headEn: <String>['A', 'B'],
///       rowsZh: <List<String>>[<String>['a', 'b']],
///       rowsEn: <List<String>>[<String>['a', 'b']],
///     )),
///     GuideBlock.tip('小提示…', 'Tip…'),
///   ],
/// ),
/// ```
const List<GuideChapter> kGuideChapters = <GuideChapter>[
  // ==================== 城市之王（含战斗规则） ====================
  GuideChapter(
    id: 'city_king',
    titleZh: '城市之王',
    titleEn: 'City King',
    summaryZh: '赛季节奏、战斗规则（建筑 / 车位 / 链接 / 高回报 / 结算系数）、升降级与胜场 · 地区 · 赛季结算奖励',
    summaryEn:
        'Season flow, battle rules (buildings, slots, links, high reward), promotion / demotion and the win / region / season rewards',
    icon: Icons.emoji_events,
    color: Colors.amber,
    keywords: <String>[
      '城市之王',
      '战斗',
      '建筑',
      '车位',
      '占领',
      '链接',
      '高回报',
      '赛季',
      '胜场',
      '地区',
      '工具箱',
      '阶段奖励',
      '结算',
      '王牌',
      'city king',
      'battle',
      'building',
      'slot',
      'link',
      'high reward',
      'region',
      'toolbox',
    ],
    blocks: <GuideBlock>[
      GuideBlock.text(
        '城市之王是帮派之间的日常对抗：赛季没有固定天数，每天可以挑战同组别的帮派。'
        '胜场会推进你本赛季所处的「地区」，地区越高、胜场奖励越好；每征服一个地区，还会额外发放一份阶段奖励。',
        'A day-by-day gang battle mode: a season has no fixed length and you may challenge gangs of your own division every day. '
            'Wins advance your "region" this season — higher regions pay better win rewards, and conquering a region grants a stage reward.',
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '战斗：每场一般 6 个建筑，占位过半即占领，计时器结算分数（链接与高回报加成见「特殊机制」）',
          'Battle: usually 6 buildings, hold over half the slots to occupy, scored on the timer (links and high reward: see "Special mechanics")',
        ),
        GuideBullet(
          '赛季节奏：不按固定天数 —— 10 个帮派打满 30 胜就进入收尾',
          'Season pacing: no fixed length — the season wraps up once 10 gangs reach 30 wins',
        ),
        GuideBullet(
          '奖励：胜场奖励（工具箱，等阶随地区）、地区奖励（征服地区给）、赛季结算奖励（按组别 + 名次）',
          'Rewards: win reward (toolboxes, tier depends on region), region reward (on conquering), season settlement (by division + rank)',
        ),
      ]),
      // ---------- 1. 战斗怎么打 ----------
      GuideBlock.heading('战斗怎么打', 'How a battle works'),
      GuideBlock.text(
        '每场战斗一般有 6 个建筑，每个建筑里有若干个车位（奇数个）。',
        'A battle usually has 6 buildings, and each building has an odd number of parking slots.',
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '占领：一方占据某座建筑的车位总数的一半以上，就占领了这座建筑（例如 5 车位占 3 个、3 车位占 2 个）',
          'Occupation: a side holding more than half of a building\'s slots occupies it (3 of 5 slots, 2 of 3 slots, ...)',
        ),
        GuideBullet(
          '得分：分钟计时器归零时，从所有已占领的建筑获得「该建筑车位数」的分数',
          'Scoring: when the minute timer hits zero you score, for each occupied building, points equal to that building\'s slot count',
        ),
      ]),
      GuideBlock.figures(<GuideFigure>[
        GuideFigure.diagram(
          'battleBuildings',
          captionZh:
              '建筑与车位示意（蓝＝我方车、红＝对方帮派的车、灰＝人机车；带「链接」/「×5」的是特殊加成建筑）',
          captionEn:
              'Buildings and slots (blue = ours, red = the opposing gang, grey = bots; "link" and "×5" mark special bonuses)',
        ),
      ]),
      // ---------- 2. 车位争夺 ----------
      GuideBlock.heading('车位争夺：一辆车怎么打', 'Taking a slot: how a single fight works'),
      GuideBlock.text(
        '战斗开始时，所有建筑的所有车位都被人机占着；人机**不属于任何一方**，只是让车位一开始就处于'
        '「已被占领、可以被选中攻击」的状态。之后车位上的车可能是人机，也可能是对方帮派成员的车，'
        '我方成员各自派空闲的车去抢车位，流程是：挑一个「还没被我方占领」的车位发起攻击 → '
        '派一辆空闲的车跟车位上的车单挑 → 一方 HP 归零则战斗结束。车位不会出现空着的情况：'
        '要么是我方的车在防守，要么还是对方（人机或对方帮派）占着。',
        'When a battle starts every slot is held by a bot; bots **belong to neither side** — they only put the slot into an '
            '"occupied, attackable" state from the start. From then on a slot may hold a bot or a car belonging to the opposing gang. '
            'Our members send idle cars to take slots: pick a slot that is not held by our side → send one idle car to duel the car on that slot → '
            'the duel ends when one side\'s HP reaches zero. A slot is never left empty: either one of our cars defends it or the opposing side still holds it.',
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '我方打赢（车位上的车被打爆）→ 我方出战的车**以战斗结束时的血量占领车位**，进入防守状态',
          'If we win (the car on the slot is destroyed) → our attacking car **occupies the slot with the HP it has when the duel ends** and enters the defending state',
        ),
        GuideBullet(
          '我方打输（我方出战的车被打爆）→ 车位上的那辆车（人机或对方帮派的车）'
          '**以战斗结束时的血量留在车位上**，并持续回血直到满血',
          'If we lose (our car is destroyed) → the car on the slot (a bot or a car of the opposing gang) '
              '**stays there with the HP it has when the duel ends** and keeps regenerating until full HP',
        ),
        GuideBullet(
          '人机占着的车位不属于任何一方，我方和对方都可以攻击它',
          'A slot held by a bot belongs to neither side, so both we and the opposing gang may attack it',
        ),
        GuideBullet(
          '攻击锁定：某个车位正在被攻击时，**在战斗结果结算之前谁都不能再攻击这个车位**'
          '（我方其他成员、对方成员都一样）—— 只能改选其它可攻击的车位，或者等这次攻击结算完',
          'Attack lock: while a slot is being attacked, **nobody else may attack that slot until the result is resolved** '
          '(neither our other members nor the opposing gang) — they must pick another attackable slot or wait for the result',
        ),
        GuideBullet(
          '战斗结束时记录胜方的**当前 HP** 并保存状态 —— 车不会因为打赢就回满血',
          'When the duel ends the winner\'s **current HP** is recorded and saved — winning does not refill the car',
        ),
        GuideBullet(
          'HP 归零的车会爆炸、暂时无法使用，需要 2 小时才能回满 HP',
          'A car whose HP hits zero explodes and becomes unusable; it needs 2 hours to refill',
        ),
        GuideBullet(
          '没满血的车（双方都一样）也会慢慢回血，速度就是「2 小时回满」',
          'Damaged cars on both sides also regenerate, at the rate of "full HP in 2 hours"',
        ),
      ]),
      GuideBlock.table(GuideTable(
        headZh: <String>['车辆状态', '说明'],
        headEn: <String>['Car state', 'Notes'],
        rowsZh: <List<String>>[
          <String>['空闲', '可以挑选「未被我方占领」的车位发起攻击'],
          <String>['防守', '车辆占领车位时的状态'],
          <String>['爆炸', 'HP 归零后爆炸；等生命值回满（2 小时）后变回空闲'],
        ],
        rowsEn: <List<String>>[
          <String>['Idle', 'Can attack a slot that is not held by your side'],
          <String>['Defending', 'The state while the car holds a slot'],
          <String>['Exploded', 'HP hit zero: it explodes and turns back to idle once HP is full (2 hours)'],
        ],
      )),
      GuideBlock.text(
        '状态流转：空闲 →（占领车位）→ 防守；防守 →（HP 归零）→ 爆炸 →（生命值回满）→ 空闲。',
        'State flow: idle → (takes a slot) → defending; defending → (HP reaches zero) → exploded → (HP refills) → idle.',
      ),
      // ---------- 3. 特殊机制 ----------
      GuideBlock.heading('特殊机制：链接与高回报加成', 'Special mechanics: links & high reward'),
      GuideBlock.text(
        '链接：每场战斗通常会有两个建筑获得链接。如果同时占据了多个链接建筑（n 个），'
        '这些链接建筑获得的分数会 ×n（只作用于链接建筑）。',
        'Link: usually two buildings in a battle are linked. If you occupy several linked buildings (n of them), '
            'those linked buildings score ×n (only the linked ones).',
      ),
      GuideBlock.text(
        '高回报加成：在赛季准备结束的时间点之后开启的战斗里，每隔一段时间会随机挑一个建筑，'
        '该建筑的分数获得 5 倍加成（例如原来 +21，加成后变成 +105）；加成持续 2 小时，'
        '且与链接相互独立 —— 链接建筑也可以同时吃到高回报加成。',
        'High reward: in battles started after the season wrap-up point, one random building periodically gets a 5x score bonus '
            '(e.g. +21 becomes +105). It lasts 2 hours and is independent of links — a linked building can also carry the high-reward bonus.',
      ),
      GuideBlock.tip(
        '高回报加成只在「赛季收尾之后」开启的战斗里出现（收尾的触发条件见下一节）。',
        'The high-reward bonus only appears in battles started after the season wrap-up point (see the next section for the trigger).',
      ),
      // ---------- 3.5 战斗分数与结算系数 ----------
      GuideBlock.heading('战斗分数与结算系数', 'Battle score & settlement multiplier'),
      GuideBlock.text(
        '一场战斗最终算多少分，是「战斗分 × 结算系数」：战斗分是战斗里打出来的分数，'
        '结算系数只看**本场之前**已经拿到的赛季胜场数 —— 胜场越多系数越高。',
        'What a battle finally earns is "battle score × settlement multiplier". The battle score is what you '
            'scored in the fight; the multiplier depends only on the season wins you already had **before** this battle — '
            'the more wins, the higher it is.',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['赛前已有胜场', '结算系数'],
          headEn: <String>['Wins before the battle', 'Multiplier'],
          rowsZh: <List<String>>[
            <String>['0 - 1', '×1'],
            <String>['2 - 3', '×2'],
            <String>['4 - 5', '×3'],
            <String>['6 - 8', '×4'],
            <String>['9 - 11', '×5'],
            <String>['12 - 15', '×6'],
            <String>['16 - 19', '×8'],
            <String>['20 - 24', '×10'],
            <String>['25 - 29', '×15'],
            <String>['30 及以上', '×20'],
          ],
          rowsEn: <List<String>>[
            <String>['0 - 1', '×1'],
            <String>['2 - 3', '×2'],
            <String>['4 - 5', '×3'],
            <String>['6 - 8', '×4'],
            <String>['9 - 11', '×5'],
            <String>['12 - 15', '×6'],
            <String>['16 - 19', '×8'],
            <String>['20 - 24', '×10'],
            <String>['25 - 29', '×15'],
            <String>['30+', '×20'],
          ],
        ),
      ),
      GuideBlock.tip(
        '系数只按本场之前的胜场算，所以同一档里连胜不会马上提高系数，跨到下一档才会提高。'
        '在「赛季统计」里只要填好赛前胜场和本场胜负，系数与本场得分会自动算出来。',
        'The multiplier is read from your wins before the battle, so wins inside one band do not raise it — '
            'you have to cross into the next band. In Season Stats, filling in your wins before the battle and '
            'the result is enough — the multiplier and the score gained are computed for you.',
      ),
      // ---------- 3. 赛季什么时候结束 ----------
      GuideBlock.heading('赛季什么时候结束', 'When a season ends'),
      GuideBlock.text(
        '赛季不按固定天数，而是看「有多少个帮派打满 30 胜」——统计的是所有组别、任何帮派：'
        '只要有帮派达到 30 胜场，30 胜帮派计数就 +1；计数达到 10 时，赛季准备结束：'
        '再过 7 天关闭战斗入口（之后不能加入新战斗）→ 再过 1 天所有帮派战斗完成 → '
        '发放赛季结算奖励 → 1 天缓冲（领奖励、换帮派）→ 开启新赛季。',
        'A season is not measured in days but in gangs reaching 30 wins — any gang, in any division: '
            'every gang that hits 30 wins bumps the counter by 1, and when it reaches 10 the season starts to end: '
            '7 more days until battle entry closes (no new battles), then 1 more day for every gang to finish its battles, '
            'then season rewards are granted, then a 1-day buffer (claim rewards, switch gangs) and a new season begins.',
      ),
      GuideBlock.figures(<GuideFigure>[
        GuideFigure.diagram(
          'seasonFlow',
          captionZh: '赛季收尾流程（T = 有 10 个帮派达到 30 胜的那天）',
          captionEn: 'Season wrap-up flow (T = the day the 10th gang reaches 30 wins)',
        ),
      ]),
      GuideBlock.tip(
        '单场战斗不一定是严格意义上的一天，最长 1 天；具体时长可以看「时间计算」模块。',
        'A single battle is not strictly one day — it lasts up to 1 day; check the "Timer" module for the duration.',
      ),
      // ---------- 4. 胜场奖励 ----------
      GuideBlock.heading('胜场奖励（工具箱）', 'Win reward (toolboxes)'),
      GuideBlock.text(
        '每赢一场给 1 个工具箱，工具箱的等阶由你当前的地区决定，对照如下：',
        'Every win gives 1 toolbox; its tier depends on your current region:',
      ),
      GuideBlock.table(GuideTable(
        headZh: <String>['地区', '进入所需胜场', '胜场奖励'],
        headEn: <String>['Region', 'Wins to enter', 'Win reward'],
        rowsZh: <List<String>>[
          <String>['1', '0 胜', 'R1 工具箱'],
          <String>['2', '1 胜', 'R1 工具箱'],
          <String>['3', '2 胜', 'R1 工具箱'],
          <String>['4', '4 胜', 'R1 工具箱'],
          <String>['5', '6 胜', 'R2 工具箱'],
          <String>['6', '9 胜', 'R2 工具箱'],
          <String>['7', '12 胜', 'R2 工具箱'],
          <String>['8', '16 胜', 'R3 工具箱'],
          <String>['9', '20 胜', 'R3 工具箱'],
          <String>['10', '25 胜', 'R4 工具箱'],
          <String>['10（新一档）', '30 胜起', 'R4 工具箱'],
        ],
        rowsEn: <List<String>>[
          <String>['1', '0 wins', 'R1 toolbox'],
          <String>['2', '1 win', 'R1 toolbox'],
          <String>['3', '2 wins', 'R1 toolbox'],
          <String>['4', '4 wins', 'R1 toolbox'],
          <String>['5', '6 wins', 'R2 toolbox'],
          <String>['6', '9 wins', 'R2 toolbox'],
          <String>['7', '12 wins', 'R2 toolbox'],
          <String>['8', '16 wins', 'R3 toolbox'],
          <String>['9', '20 wins', 'R3 toolbox'],
          <String>['10', '25 wins', 'R4 toolbox'],
          <String>['10 (new tier)', '30+ wins', 'R4 toolbox'],
        ],
      )),
      GuideBlock.tip(
        '工具箱等阶：地区 1-4（征服地区 4 之前）→ R1；地区 5-7 → R2；地区 8-9 → R3；'
        '地区 10 以及 30 胜之后的新一档 → R4。地区 10 的 30 胜档虽然还是「地区 10」，但算新的一档。',
        'Toolbox tiers: regions 1-4 (before conquering region 4) → R1; regions 5-7 → R2; '
            'regions 8-9 → R3; region 10 and the new tier after 30 wins → R4. '
            'The 30-win tier is still "region 10" but counts as a new tier.',
      ),
      GuideBlock.text(
        '工具箱分「+ATK」与「+HP」两种，等阶越高加成越高：',
        'Toolboxes come in "+ATK" and "+HP" versions; the higher the tier, the bigger the bonus:',
      ),
      GuideBlock.table(GuideTable(
        headZh: <String>['工具箱等阶', '加成'],
        headEn: <String>['Toolbox tier', 'Bonus'],
        rowsZh: <List<String>>[
          <String>['R1', '+10%'],
          <String>['R2', '+20%'],
          <String>['R3', '+30%'],
          <String>['R4', '+40%'],
        ],
        rowsEn: <List<String>>[
          <String>['R1', '+10%'],
          <String>['R2', '+20%'],
          <String>['R3', '+30%'],
          <String>['R4', '+40%'],
        ],
      )),
      // ---------- 5. 地区奖励 ----------
      GuideBlock.heading('地区奖励（征服地区）', 'Region reward (conquering a region)'),
      GuideBlock.text(
        '每到达一个新地区，就等于征服了上一个地区，发放下面的阶段奖励（代币 + 王牌 + 随机部件）：',
        'Each time you reach a new region you have conquered the previous one and receive the stage reward below (tokens + jokers + random parts):',
      ),
      GuideBlock.table(GuideTable(
        headZh: <String>['征服地区', '代币', '奖励部件'],
        headEn: <String>['Region', 'Tokens', 'Part rewards'],
        rowsZh: <List<String>>[
          <String>['1', '1', '15 × R1 王牌 + 5 × R3-5 车轮'],
          <String>['2', '1', '10 × R2 王牌 + 5 × R3-5 车身'],
          <String>['3', '2', '10 × R2 王牌 + 3 × R4-5 武器'],
          <String>['4', '2', '4 × R3 王牌 + 3 × R4-5 配件'],
          <String>['5', '3', '7 × R3 王牌 + 3 × R4-6 车轮'],
          <String>['6', '3', '2 × R4 王牌 + 3 × R4-6 车身'],
          <String>['7', '4', '4 × R4 王牌 + 3 × R5-6 武器'],
          <String>['8', '4', '1 × R5 王牌 + 3 × R5-6 任意部件'],
          <String>['9', '5', '2 × R5 王牌 + 3 × R6 任意部件'],
          <String>['10', '5', '2 × R5 王牌 + 4 × R6'],
        ],
        rowsEn: <List<String>>[
          <String>['1', '1', '15 x R1 Joker + 5 x R3-5 wheel'],
          <String>['2', '1', '10 x R2 Joker + 5 x R3-5 body'],
          <String>['3', '2', '10 x R2 Joker + 3 x R4-5 weapon'],
          <String>['4', '2', '4 x R3 Joker + 3 x R4-5 gadget'],
          <String>['5', '3', '7 x R3 Joker + 3 x R4-6 wheel'],
          <String>['6', '3', '2 x R4 Joker + 3 x R4-6 body'],
          <String>['7', '4', '4 x R4 Joker + 3 x R5-6 weapon'],
          <String>['8', '4', '1 x R5 Joker + 3 x R5-6 any part'],
          <String>['9', '5', '2 x R5 Joker + 3 x R6 any part'],
          <String>['10', '5', '2 x R5 Joker + 4 x R6'],
        ],
      )),
      GuideBlock.figures(<GuideFigure>[
        GuideFigure.diagram(
          'jokerTiers',
          captionZh: '王牌（地区奖励的第一项）分 R1-R5，依次为银 / 绿 / 蓝 / 紫 / 金',
          captionEn:
              'Jokers (the first item of every region reward) come in R1-R5: silver / green / blue / purple / gold',
        ),
      ]),
      GuideBlock.tip(
        '征服地区 10（达到 30 胜场）时，额外获得 25000 紫票与赛季专属小猫装扮。',
        'Conquering region 10 (30 wins) additionally grants 25,000 purple tickets and a season-exclusive kitty outfit.',
      ),
      // ---------- 6. 赛季结算奖励 ----------
      GuideBlock.heading('赛季结算奖励', 'Season settlement'),
      GuideBlock.text(
        '所有帮派战斗完成后发放（发完有 1 天缓冲用来领奖励、换帮派），'
        '按「组别 + 名次」结算，一共给四种东西——自选箱、固定箱、代币、紫票。',
        'Granted once every gang has finished its battles (followed by a 1-day buffer to claim rewards and switch gangs). '
            'Rewards are paid by division + rank: choice chests, fixed chests, tokens and purple tickets.',
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '自选箱：箱子里的每一项都会弹出两个选项二选一，选完可能再弹出两个选项继续选'
          '（例如含两个部件的自选箱，会连着让你二选一两次）',
          'Choice chest: every item pops up two options and you take one; after choosing, two more may appear '
          '(a chest holding two parts asks you to pick 1-of-2 twice)',
        ),
        GuideBullet(
          '固定箱：内容固定，没有选项',
          'Fixed chest: contents are fixed, no choices',
        ),
      ]),
      GuideBlock.figures(<GuideFigure>[
        GuideFigure.diagram(
          'chestTypes',
          captionZh: '自选箱（可二选一）与固定箱',
          captionEn: 'Choice chest (pick 1 of 2) and fixed chest',
        ),
      ]),
      GuideBlock.text(
        '各「组别 + 名次」的结算奖励（自选箱 / 固定箱 / 紫票 / 代币）：',
        'Settlement by division and rank (choice chests / fixed chests / purple tickets / tokens):',
      ),
      GuideBlock.table(GuideTable(
        headZh: <String>['金组 · 名次', '自选箱', '固定箱', '紫票', '代币'],
        headEn: <String>['Gold · Rank', 'Choice', 'Fixed', 'Tickets', 'Tokens'],
        rowsZh: _settleGold,
        rowsEn: _settleGold,
      )),
      GuideBlock.table(GuideTable(
        headZh: <String>['银组 · 名次', '自选箱', '固定箱', '紫票', '代币'],
        headEn: <String>['Silver · Rank', 'Choice', 'Fixed', 'Tickets', 'Tokens'],
        rowsZh: _settleSilver,
        rowsEn: _settleSilver,
      )),
      GuideBlock.table(GuideTable(
        headZh: <String>['铜组 · 名次', '自选箱', '固定箱', '紫票', '代币'],
        headEn: <String>['Bronze · Rank', 'Choice', 'Fixed', 'Tickets', 'Tokens'],
        rowsZh: _settleBronze,
        rowsEn: _settleBronze,
      )),
      GuideBlock.table(GuideTable(
        headZh: <String>['木组 · 名次', '自选箱', '固定箱', '紫票', '代币'],
        headEn: <String>['Wood · Rank', 'Choice', 'Fixed', 'Tickets', 'Tokens'],
        rowsZh: _settleWood,
        rowsEn: _settleWood,
      )),
      GuideBlock.tip(
        '木组的帮派比其它组多（200 家以上），所以后三档的名次区间不一样（21-50 / 51-120 / 121-200）。',
        'The wood league holds more gangs (200+), so its last three rank bands differ (21-50 / 51-120 / 121-200).',
      ),
      // ---------- 7. 晋级与退级 ----------
      GuideBlock.heading('晋级与退级', 'Promotion & demotion'),
      GuideBlock.text(
        '赛季结束时，除了发结算奖励，还会按组内名次决定下个赛季待在哪个组别：'
        '前 20 名晋级到上一组，第 81 名及之后退级到下一组，中间名次（21-80）留在原组。',
        'When a season ends, besides the settlement rewards your rank in the division decides where you play next season: '
            'the top 20 are promoted, rank 81 and below are demoted, and the middle ranks (21-80) stay put.',
      ),
      GuideBlock.table(GuideTable(
        headZh: <String>['组别', '前 20 名', '第 81 名及之后'],
        headEn: <String>['Division', 'Top 20', 'Rank 81+'],
        rowsZh: <List<String>>[
          <String>['金组', '不再晋级（最高组别）', '退到银组'],
          <String>['银组', '晋级到金组', '退到铜组'],
          <String>['铜组', '晋级到银组', '退到木组'],
          <String>['木组', '晋级到铜组', '不再退级（最低组别）'],
        ],
        rowsEn: <List<String>>[
          <String>['Gold', 'No promotion (top league)', 'Demoted to Silver'],
          <String>['Silver', 'Promoted to Gold', 'Demoted to Bronze'],
          <String>['Bronze', 'Promoted to Silver', 'Demoted to Wood'],
          <String>['Wood', 'Promoted to Bronze', 'No demotion (lowest league)'],
        ],
      )),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '自建帮派从木组起步；加入帮派可以加入任意组别',
          'A gang you found starts in the wood league; joining an existing gang can put you in any division',
        ),
        GuideBullet(
          '成员不足 5 人的帮派无法参战；整季未参战的帮派不上榜（自然也不参与升降级）',
          'Gangs with fewer than 5 members cannot fight; a gang that never fights during the season never appears on the board '
          '(and therefore is not promoted or demoted)',
        ),
        GuideBullet(
          '金 / 银 / 铜三组各约 100 家，木组更多（200 家以上），所以木组的后段名次区间和其它组不一样',
          'Gold / Silver / Bronze hold around 100 gangs each while Wood holds more (200+), so the lower rank bands differ there',
        ),
      ]),
      // ---------- 8. 赛季城市与头像奖励 ----------
      GuideBlock.heading('赛季城市与帮派头像', 'Season city & gang avatars'),
      GuideBlock.text(
        '每个赛季会绑定一座「城市」，城市一共有 5 座；下一个赛季会换成另一座城市，'
        '但城市之间的轮换顺序不确定（不是固定的循环顺序）。城市的主题会体现在赛季专属装扮等内容里。',
        'Each season is tied to a city, and there are 5 cities in total. The next season switches to another city, '
            'but the rotation order between cities is not fixed (it is not a deterministic cycle). '
            'The city theme shows up in things like the season-exclusive outfit.',
      ),
      GuideBlock.table(GuideTable(
        headZh: <String>['组别', '前 20 名的帮派头像'],
        headEn: <String>['Division', 'Avatar for the top 20'],
        rowsZh: <List<String>>[
          <String>['金组', '彩色（当季城市主题）'],
          <String>['银组', '金色（当季城市主题）'],
          <String>['铜组', '蓝色（当季城市主题）'],
        ],
        rowsEn: <List<String>>[
          <String>['Gold', 'Colourful (current city theme)'],
          <String>['Silver', 'Golden (current city theme)'],
          <String>['Bronze', 'Blue (current city theme)'],
        ],
      )),
      GuideBlock.tip(
        '头像奖励只有金 / 银 / 铜三组的前 20 名有；头像与赛季专属装扮用的都是当季城市的主题。',
        'The avatar reward is only for the top 20 of Gold / Silver / Bronze; both avatars and the season-exclusive outfit use the current city theme.',
      ),
    ],
  ),
  // ==================== 终极联赛战车 ====================
  GuideChapter(
    id: 'ultimate_car',
    titleZh: '终极联赛战车',
    titleEn: 'Ultimate League Car',
    summaryZh: '一辆战车的 HP / ATK 是怎么算出来的：等级成长、分类 / 额外 / 工具箱 / 赞助乘区、电力校验',
    summaryEn:
        'How a battle car\'s HP / ATK are computed: level growth, category / extra / toolbox / sponsor multipliers and the power check',
    icon: Icons.build_circle,
    color: Colors.teal,
    keywords: <String>[
      '战车',
      '组车',
      '数值',
      'HP',
      'ATK',
      '电力',
      '分类加成',
      '额外加成',
      '赞助',
      '工具箱',
      '成长',
      '等级',
      'car',
      'build',
      'power',
      'bonus',
      'sponsor',
      'level',
    ],
    blocks: <GuideBlock>[
      GuideBlock.text(
        '终极联赛里出场的战车，就是「组车工具」（个人功能 → 组车工具）里拼出来的那辆车。'
        '这一章把它的数值拆开讲清楚：先看一辆车由什么组成，再看每个部件的数值怎么来，'
        '最后看整车 HP / ATK 是怎么乘出来的、以及出车要过哪些校验。',
        'The car you field in the league is exactly the car built with the "Build Tool" (Personal → Build Tool). '
            'This chapter breaks its numbers down: what a car is made of, how each part\'s stats grow with level, '
            'how the whole car\'s HP / ATK are multiplied together, and which checks a car must pass.',
      ),
      // ---------- 1. 战车由什么组成 ----------
      GuideBlock.heading('战车由什么组成', 'What a car is made of'),
      GuideBlock.text(
        '1 个车身 + 最多 1 个特殊武器（额外武器）+ 若干武器 / 车轮 / 配件；'
        '后三者的数量上限由车身的插槽数决定，不能超装。',
        '1 body + up to 1 special (extra) weapon + weapons / wheels / gadgets. '
            'The maximum counts of the last three come from the body\'s slots and cannot be exceeded.',
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '车身：提供基础 HP，并决定武器 / 车轮 / 配件各有几个插槽',
          'Body: gives base HP and decides how many weapon / wheel / gadget slots you have',
        ),
        GuideBullet(
          '武器（含特殊武器）：主要提供 ATK；车轮：提供 HP（有些也带 ATK）；配件：提供 HP 或 ATK',
          'Weapons (including the special one): mainly ATK; wheels: HP (some also ATK); gadgets: HP or ATK',
        ),
        GuideBullet(
          '特殊武器不占武器的插槽，也**不耗电**',
          'The special weapon does not use a weapon slot and **does not consume power**',
        ),
      ]),
      GuideBlock.figures(<GuideFigure>[
        GuideFigure.diagram(
          'carLayout',
          captionZh: '车辆结构：车身（橙）、武器（红）、车轮（绿）、配件（紫）、特殊武器（棕）',
          captionEn:
              'Car layout: body (orange), weapons (red), wheels (green), gadgets (purple), special weapon (brown)',
        ),
      ]),
      // ---------- 2. 部件数值随等级成长 ----------
      GuideBlock.heading('部件数值随等级成长', 'How part stats grow with level'),
      GuideBlock.text(
        '每个部件的 HP / ATK 都由「1 级基础值」和等级算出来：1 级就是基础值，等级越高涨得越快。'
        '不同稀有度的等级上限不一样。',
        'Every part\'s HP / ATK is derived from its level-1 base value and its level: level 1 is the base value, and higher levels grow faster. '
            'Different rarities have different level caps.',
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '普通部件（绝大多数）：2~16 级每一级把当前值 ×1.2 向下取整；17 级起改为固定步长'
          '（约等于 16 级值的 8.75%）继续加，最高 20 级',
          'Normal parts (the vast majority): from level 2 to 16 each level multiplies the current value by 1.2 (rounded down); '
          'from level 17 on it adds a fixed step (about 8.75% of the level-16 value), up to level 20',
        ),
        GuideBullet(
          'R6 旧版部件（少数早期 R6）：每级增量本身还会递增 —— '
          'delta = 向下取整(基础值 × 0.19163)、delta2 = 向下取整(基础值 ÷ 15)（固定），'
          '每级「值 += delta；delta += delta2」，最高 18 级',
          'Legacy R6 parts (a few early R6s): the increment itself grows — '
          'delta = floor(base × 0.19163), delta2 = floor(base ÷ 15) (fixed), each level does "value += delta; delta += delta2", up to level 18',
        ),
      ]),
      GuideBlock.table(GuideTable(
        headZh: <String>['稀有度', '最高等级'],
        headEn: <String>['Rarity', 'Max level'],
        rowsZh: <List<String>>[
          <String>['R1 - R5', '20 级'],
          <String>['R6', '18 级'],
        ],
        rowsEn: <List<String>>[
          <String>['R1 - R5', 'Level 20'],
          <String>['R6', 'Level 18'],
        ],
      )),
      // ---------- 3. 整车 HP/ATK ----------
      GuideBlock.heading('一辆车的 HP / ATK 怎么算', 'How the car\'s HP / ATK are computed'),
      GuideBlock.text(
        '整车的 HP / ATK 是「逐个部件算完再相加」，而每个部件的贡献由下面几个乘区相乘得到：',
        'The car\'s HP / ATK is the sum over all parts, and each part\'s contribution is the product of the multipliers below:',
      ),
      GuideBlock.figures(<GuideFigure>[
        GuideFigure.diagram(
          'statPipeline',
          captionZh: '单车数值链路：裸值 × 分类加成 × 额外加成 × 工具箱 × 赞助加成 = 整车数值',
          captionEn:
              'Stat pipeline: base × category × extra × toolbox × sponsor = car stats',
        ),
      ]),
      GuideBlock.table(GuideTable(
        headZh: <String>['乘区', '来源与算法'],
        headEn: <String>['Multiplier', 'Where it comes from'],
        rowsZh: <List<String>>[
          <String>['裸值', '该部件在当前等级下的 HP / ATK（见上一节）'],
          <String>[
            '分类加成',
            '全车部件里「加成类型」等于该部件分类的百分比之和'
                '（车身 / 武器 / 车轮 / 配件 各一份；看的是部件提供的加成类型，不是部件自身分类）',
          ],
          <String>['额外加成', '每个部件自己的独立乘区，0-150%、10% 一档（组车工具里逐部件选）'],
          <String>[
            '工具箱加成',
            '城市之王掉的生命 / 攻击工具箱，只加对应数值：R1 +10% / R2 +20% / R3 +30% / R4 +40%',
          ],
          <String>[
            '赞助加成',
            '整车最后再乘一次：同一赞助商有 3 个及以上部件时 +10%，每再多 1 个 +5%'
                '（多个赞助商各自算，再加起来）',
          ],
        ],
        rowsEn: <List<String>>[
          <String>['Base', 'The part\'s HP / ATK at its current level (see the previous section)'],
          <String>[
            'Category',
            'Sum of the percentages whose "bonus type" equals that part\'s category '
                '(one sum each for body / weapon / wheel / gadget; it is the bonus a part gives, not the part\'s own category)',
          ],
          <String>['Extra', 'Per-part independent multiplier, 0-150% in steps of 10% (chosen per part in the Build Tool)'],
          <String>[
            'Toolbox',
            'Life / attack toolboxes from City King, each only boosts its own stat: R1 +10% / R2 +20% / R3 +30% / R4 +40%',
          ],
          <String>[
            'Sponsor',
            'Applied once to the whole car at the end: 3 or more parts of the same sponsor gives +10%, plus +5% for every extra one '
                '(each sponsor counts separately, then they add up)',
          ],
        ],
      )),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '车轮特殊：车轮的 HP 与 ATK 都用「车轮加成」这一个百分比',
          'Wheels are special: both their HP and ATK use the single "wheel" percentage',
        ),
        GuideBullet(
          '随从（随车的小帮手）的 HP **不吃任何加成**，只按裸值显示',
          'A minion\'s HP gets **no bonus at all** — only its base value is used',
        ),
        GuideBullet(
          '把这些贡献加起来就是整车的 HP 与 ATK；本程序把一辆车的「战力」粗略记作 HP + ATK',
          'Adding all contributions up gives the car\'s HP and ATK; this app roughly treats a car\'s "power" as HP + ATK',
        ),
      ]),
      // ---------- 4. 电力与出车校验 ----------
      GuideBlock.heading('电力与出车校验', 'Power and car checks'),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '电力：所有部件里正的电力相加是「供电」，负的电力绝对值相加是「耗电」；特殊武器不耗电',
          'Power: positive power of all parts is the supply, the absolute value of negative power is the consumption; the special weapon consumes none',
        ),
        GuideBullet(
          '校验顺序（和组车工具的报错一致）：缺少车身 → 车身过多 → 武器过多 → 车轮过多 → 配件过多 → 电力不足',
          'Check order (same as the Build Tool errors): no body → too many bodies → too many weapons → too many wheels → too many gadgets → not enough power',
        ),
        GuideBullet(
          '耗电超过供电就出不了车，只能换更省电的部件或降低等级需求',
          'If consumption exceeds supply the car cannot be used — swap in more efficient parts',
        ),
      ]),
      GuideBlock.tip(
        '组车工具里改任何一处（等级、额外加成、部位）都会立刻重算整车 HP / ATK 与电力，'
        '报错就是上面那几种。',
        'Any change in the Build Tool (level, extra bonus, parts) immediately recomputes the car\'s HP / ATK and power; '
            'the errors are exactly the ones listed above.',
      ),
      // ---------- 5. 在组车工具里怎么看 ----------
      GuideBlock.heading('在组车工具里怎么看这些数', 'Reading these numbers in the Build Tool'),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '组车区里每个部件展开后是「裸值 → 分类加成 → 额外加成 → 赞助加成 → 最终」，和上面的公式一一对应',
          'Each part in the build area expands to "base → category → extra → sponsor → final", matching the formula above',
        ),
        GuideBullet(
          '等级和额外加成（0-150%、10% 一档）都是逐部件选的，改完实时重算',
          'Level and extra bonus (0-150%, steps of 10%) are per part and recompute instantly',
        ),
        GuideBullet(
          '保存到车位后：「我的车库」看整车数值与重量，「升级计划」算材料需求，「碎片计算」算碎片',
          'After saving to a garage slot: "My Garage" shows the car\'s stats and weight, "Upgrade Plan" works out materials and "Fragment Calc" works out fragments',
        ),
        GuideBullet(
          '三辆车不能重复使用同一个部件（猫生重开里要凑三辆车）',
          'The three cars cannot share a part (Life Restart needs three cars)',
        ),
      ]),
    ],
  ),
];
