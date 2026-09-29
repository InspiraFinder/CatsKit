/// 机制指南：游戏玩法机制的**文字版 wiki** 数据源。
///
/// 本文件只放内容数据，渲染逻辑在 `mechanism_guide_screen.dart`：
/// 每个 [GuideChapter] 是「一章」= 一个玩法/主题，章内按顺序堆 [GuideBlock]，
/// 块可以是段落、要点列表、提示框或配图行，配图既可以用 assets 图片，
/// 也可以用程序内置的示意图（见 [GuideFigure.diagram] 的 id 说明）。
///
/// 新增一章：直接在 [kGuideChapters] 里加一个 [GuideChapter]
/// （文件末尾有现成模板，复制改内容即可），不需要改界面代码。
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
    this.textZh,
    this.textEn,
    this.bullets = const <GuideBullet>[],
    this.tipZh,
    this.tipEn,
    this.figures = const <GuideFigure>[],
    this.table,
  });

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

  /// 是否命中搜索词（标题 / 摘要 / 关键词 / 正文都能搜）
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

/// 城市之王赛季结算表的数据行（列：名次 / 自选箱 / 固定箱 / 紫票 / 代币；中英通用）
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
/// 目前有「城市之王」一章（胜场奖励 / 地区奖励 / 赛季结算奖励）；
/// 下面是新增章节的模板，复制一份、去掉注释即可：
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
///     GuideBlock.text('正文第一段…', 'First paragraph…'),
///     GuideBlock.figures(<GuideFigure>[
///       GuideFigure.diagram('activityIcons',
///           captionZh: '主要活动图标', captionEn: 'Main activities'),
///     ]),
///     GuideBlock.bullets(<GuideBullet>[
///       GuideBullet('要点一', 'Point one'),
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
  // ==================== 城市之王 ====================
  GuideChapter(
    id: 'city_king',
    titleZh: '城市之王',
    titleEn: 'City King',
    summaryZh: '40 天一赛季：胜场推进「地区」，地区决定工具箱等阶，征服地区发阶段奖励',
    summaryEn:
        'A 40-day season: wins push you through regions for toolboxes, and each region conquered pays a stage reward',
    icon: Icons.emoji_events,
    color: Colors.amber,
    keywords: <String>[
      '城市之王',
      '胜场',
      '地区',
      '工具箱',
      '阶段奖励',
      '赛季结算',
      'city king',
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
          '胜场奖励：每赢一场给 1 个工具箱，等阶由当前地区决定',
          'Win reward: every win gives 1 toolbox whose tier depends on your current region',
        ),
        GuideBullet(
          '地区奖励：征服一个地区时发放，含代币与随机部件',
          'Region reward: paid when a region is conquered, includes tokens and random parts',
        ),
        GuideBullet(
          '赛季结算奖励：赛季结束时按最终成绩结算（细则待补充）',
          'Season settlement: paid at the end of the season (details TBD)',
        ),
      ]),
      GuideBlock.text(
        '胜场与地区、胜场奖励工具箱等阶的对照：',
        'Region progress and the toolbox tier you get for winning:',
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
      GuideBlock.text(
        '征服地区（地区奖励／阶段奖励）：每到达一个新地区，就等于征服了上一个地区，发放下面的阶段奖励。',
        'Conquering a region (region / stage rewards): each time you reach a new region you have conquered the previous one and receive the reward below.',
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
      GuideBlock.text(
        '赛季什么时候结束：不按固定天数，而是看「有多少个帮派打满 30 胜」——'
        '统计的是**所有组别、任何帮派**：只要有帮派达到 30 胜场，30 胜帮派计数就 +1；'
        '计数达到 10 时，赛季准备结束：'
        '再过 7 天关闭战斗入口（之后不能加入新战斗）→ 再过 1 天所有帮派战斗完成 → '
        '发放赛季结算奖励 → 1 天缓冲（领奖励、换帮派）→ 开启新赛季。',
        'How a season ends: not by a fixed number of days but by counting gangs that reach 30 wins — '
            'any gang, in any division: every gang that hits 30 wins bumps the counter by 1, and when it reaches 10 the season starts to end: '
            '7 more days until battle entry closes (no new battles), then 1 more day for every gang to finish its battles, '
            'then season rewards are granted, then a 1-day buffer (claim rewards, switch gangs) and a new season begins.',
      ),
      GuideBlock.figures(<GuideFigure>[
        GuideFigure.diagram(
          'seasonFlow',
          captionZh: '赛季收尾流程（T = 有 10 个帮派达到 30 胜的那天）',
          captionEn:
              'Season wrap-up flow (T = the day the 10th gang reaches 30 wins)',
        ),
      ]),
      GuideBlock.tip(
        '单场战斗不一定是严格意义上的一天，最长 1 天；具体时长可以看「时间计算」模块。'
        '战斗怎么打（6 个建筑、车位、占领、链接与高回报加成）见「战斗规则」一章。',
        'A single battle is not strictly one day — it lasts up to 1 day; check the "Timer" module for the duration. '
            'See the "Battle Rules" chapter for how a battle works (6 buildings, slots, occupation, links, high reward).',
      ),
      GuideBlock.text(
        '赛季结算奖励：所有帮派战斗完成后发放（发完有 1 天缓冲用来领奖励、换帮派），'
        '按「组别 + 名次」结算，一共给四种东西——自选箱、固定箱、代币、紫票。',
        'Season settlement: granted once every gang has finished its battles (followed by a 1-day buffer to claim rewards and switch gangs). '
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
        '各「组别 + 名次」的赛季结算奖励（自选箱 / 固定箱 / 紫票 / 代币）：',
        'Season settlement by division and rank (choice chests / fixed chests / purple tickets / tokens):',
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
    ],
  ),
  // ==================== 战斗规则 ====================
  GuideChapter(
    id: 'battle',
    titleZh: '战斗规则',
    titleEn: 'Battle Rules',
    summaryZh: '6 个建筑、车位过半即占领；链接与高回报加成怎么算',
    summaryEn:
        'Six buildings, occupy by holding over half the slots, plus link and high-reward bonuses',
    icon: Icons.location_city,
    color: Colors.indigo,
    keywords: <String>[
      '战斗',
      '建筑',
      '车位',
      '占领',
      '链接',
      '高回报',
      'battle',
      'building',
      'slot',
      'link',
      'high reward',
    ],
    blocks: <GuideBlock>[
      GuideBlock.text(
        '城市之王的战斗是「夺建筑」：每场战斗一般有 6 个建筑，每个建筑里有若干个车位（奇数个）。',
        'A City King battle is a fight over buildings: a battle usually has 6 buildings, and each building has an odd number of parking slots.',
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
          captionZh: '建筑与车位示意（蓝＝我方、红＝对方、灰＝空车位；带「链接」/「×5」的是特殊加成建筑）',
          captionEn:
              'Buildings and slots (blue = ours, red = theirs, grey = empty; "link" and "×5" mark special bonuses)',
        ),
      ]),
      GuideBlock.text(
        '特殊机制 1 · 链接：每场战斗通常会有两个建筑获得链接。'
        '如果同时占据了多个链接建筑（n 个），这些链接建筑获得的分数会 ×n（只作用于链接建筑）。',
        'Special 1 · Link: usually two buildings in a battle are linked. '
            'If you occupy several linked buildings (n of them), those linked buildings score ×n (only the linked ones).',
      ),
      GuideBlock.text(
        '特殊机制 2 · 高回报加成：在赛季准备结束的时间点之后开启的战斗里，'
        '每隔一段时间会随机挑一个建筑，该建筑的分数获得 5 倍加成（例如原来 +21，加成后变成 +105）；'
        '加成持续 2 小时，且与链接相互独立 —— 链接建筑也可以同时吃到高回报加成。',
        'Special 2 · High reward: in battles started after the season wrap-up point, '
            'one random building periodically gets a 5x score bonus (e.g. +21 becomes +105). '
            'It lasts 2 hours and is independent of links — a linked building can also carry the high-reward bonus.',
      ),
      GuideBlock.tip(
        '高回报加成只在「赛季收尾之后」开启的战斗里出现（收尾的触发条件见「城市之王」一章）。',
        'The high-reward bonus only appears in battles started after the season wrap-up point (see the City King chapter for the trigger).',
      ),
    ],
  ),
];
