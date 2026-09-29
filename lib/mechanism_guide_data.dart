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
  /// / `activityIcons`（活动图标一览） / `gangTiers`（帮派四个组别）
  /// / `seasonTimeline`（40 天赛季时间轴）
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
        '城市之王是帮派之间的日常对抗：40 天为一个赛季，每天可以挑战同组别的帮派。'
        '胜场会推进你本赛季所处的「地区」，地区越高、胜场奖励越好；每征服一个地区，还会额外发放一份阶段奖励。',
        'A day-by-day gang battle mode: a season lasts 40 days and you may challenge gangs of your own division every day. '
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
        '征服地区（地区奖励／阶段奖励）：每到达一个新地区，就等于征服了上一个地区，发放下面的阶段奖励。',
        'Conquering a region (region / stage rewards): each time you reach a new region you have conquered the previous one and receive the reward below.',
      ),
      GuideBlock.table(GuideTable(
        headZh: <String>['征服地区', '代币', '奖励部件'],
        headEn: <String>['Region', 'Tokens', 'Part rewards'],
        rowsZh: <List<String>>[
          <String>['1', '1', '15 × R1 王牌 + 5 × R3-5 车轮'],
          <String>['2', '1', '10 × R2 + 5 × R3-5 车身'],
          <String>['3', '2', '10 × R2 + 3 × R4-5 武器'],
          <String>['4', '2', '4 × R3 + 3 × R4-5 配件'],
          <String>['5', '3', '7 × R3 + 3 × R4-6 车轮'],
          <String>['6', '3', '2 × R4 + 3 × R4-6 车身'],
          <String>['7', '4', '4 × R4 + 3 × R5-6 武器'],
          <String>['8', '4', '1 × R5 + 3 × R5-6 任意部件'],
          <String>['9', '5', '2 × R5 + 3 × R6 任意部件'],
          <String>['10', '5', '2 × R5 + 4 × R6'],
        ],
        rowsEn: <List<String>>[
          <String>['1', '1', '15 x R1 Joker + 5 x R3-5 wheel'],
          <String>['2', '1', '10 x R2 + 5 x R3-5 body'],
          <String>['3', '2', '10 x R2 + 3 x R4-5 weapon'],
          <String>['4', '2', '4 x R3 + 3 x R4-5 gadget'],
          <String>['5', '3', '7 x R3 + 3 x R4-6 wheel'],
          <String>['6', '3', '2 x R4 + 3 x R4-6 body'],
          <String>['7', '4', '4 x R4 + 3 x R5-6 weapon'],
          <String>['8', '4', '1 x R5 + 3 x R5-6 any part'],
          <String>['9', '5', '2 x R5 + 3 x R6 any part'],
          <String>['10', '5', '2 x R5 + 4 x R6'],
        ],
      )),
      GuideBlock.tip(
        '征服地区 10（达到 30 胜场）时，额外获得 25000 紫票与赛季专属小猫装扮。',
        'Conquering region 10 (30 wins) additionally grants 25,000 purple tickets and a season-exclusive kitty outfit.',
      ),
      GuideBlock.figures(<GuideFigure>[
        GuideFigure.diagram(
          'seasonTimeline',
          captionZh: '赛季 40 天：地区推进节点（胜场）与对应的结算分数倍率',
          captionEn:
              'The 40-day season: region milestones (wins) and their score multipliers',
        ),
      ]),
      GuideBlock.text(
        '赛季结算奖励：赛季结束后按最终成绩结算（具体奖励与算法待补充）。',
        'Season settlement: rewards are paid out at the end of the season based on your final result (what and how is TBD).',
      ),
    ],
  ),
];
