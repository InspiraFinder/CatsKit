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
///
/// 需要两级表头时用 [groupZh]/[groupEn]：与表头等长，**同一组的首列填组名、
/// 其余列留空字符串**（例如 `<String>['', '', '基础 HP', '', '', '供电', '', '']`），
/// 渲染时会在这张表最上面多出一行分组名。
class GuideTable {
  final List<String> headZh;
  final List<String> headEn;
  final List<List<String>> rowsZh;
  final List<List<String>> rowsEn;

  /// 一级表头（分组行），可选
  final List<String>? groupZh;
  final List<String>? groupEn;

  const GuideTable({
    required this.headZh,
    required this.headEn,
    required this.rowsZh,
    required this.rowsEn,
    this.groupZh,
    this.groupEn,
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
  const GuideBlock.text(String zh, String en) : this._(textZh: zh, textEn: en);

  /// 一组要点
  const GuideBlock.bullets(List<GuideBullet> bullets)
    : this._(bullets: bullets);

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

/// 废铁行动的节点与奖励（列：螺栓数 / 奖励）——中英各一份
///
/// ⚠️ 原文里 1175 那条写的是「95000代币」，按上下文（其它 9 万级奖励都是紫票）
/// 按**紫票**处理，如与游戏内不符请改这里。
const List<List<String>> _scrapNodesZh = <List<String>>[
  <String>['5', '锦标赛箱子 ×2'],
  <String>['10', '钻石 ×10'],
  <String>['15', '终极部件箱（R4-R5）×2'],
  <String>['20', 'R6 部件 k1 ×1'],
  <String>['25', '活动代币 ×50'],
  <String>['30', '终极部件箱（R4-R5）×2'],
  <String>['35', '锦标赛箱子 ×2'],
  <String>['40', 'R6 部件 k2 ×1'],
  <String>['50', '活动代币 ×50'],
  <String>['60', '终极部件箱（R4-R5）×3'],
  <String>['70', '紫票 ×25000'],
  <String>['80', 'R6 部件 k1 ×2'],
  <String>['90', '锦标赛箱子 ×3'],
  <String>['100', '终极部件箱（R4-R5）×3'],
  <String>['110', '钻石 ×10'],
  <String>['120', 'R6 部件 k1 ×2'],
  <String>['130', '紫票 ×50000'],
  <String>['140', '终极部件箱（R6）×2'],
  <String>['150', '锦标赛箱子 ×3'],
  <String>['160', 'R6 部件 k2 ×2'],
  <String>['170', '活动代币 ×75'],
  <String>['180', '终极部件箱（R6）×2'],
  <String>['190', '代币 ×5'],
  <String>['200', 'R6 部件 k1 ×2'],
  <String>['220', '锦标赛箱子 ×2'],
  <String>['240', 'R6 部件 k3 ×2'],
  <String>['260', '钻石 ×20'],
  <String>['280', 'R6 部件 k4 ×2'],
  <String>['300', '紫票 ×55000'],
  <String>['320', 'R6 部件 k5 ×2'],
  <String>['340', 'R4 工具箱 ×2'],
  <String>['360', 'R6 部件 k3 ×3'],
  <String>['380', '活动代币 ×100'],
  <String>['400', 'R6 部件 k4 ×3'],
  <String>['420', '紫票 ×60000'],
  <String>['440', 'R6 部件 k5 ×3'],
  <String>['460', '锦标赛箱子 ×2'],
  <String>['480', 'R6 部件 k6 ×2'],
  <String>['500', '钻石 ×20'],
  <String>['520', 'R6 部件 k7 ×2'],
  <String>['540', '活动代币 ×125'],
  <String>['560', 'R6 部件 k8 ×2'],
  <String>['580', 'R4 工具箱 ×3'],
  <String>['600', 'R6 部件 k9 ×2'],
  <String>['620', '活动代币 ×150'],
  <String>['640', 'R6 部件 k6 ×3'],
  <String>['660', '代币 ×5'],
  <String>['680', '终极部件箱（R6）×3'],
  <String>['700', '钻石 ×40'],
  <String>['720', 'R6 部件 k7 ×3'],
  <String>['740', '紫票 ×60000'],
  <String>['760', 'R6 部件 k8 ×3'],
  <String>['780', '活动代币 ×200'],
  <String>['800', 'R6 部件 k9 ×3'],
  <String>['820', '紫票 ×65000'],
  <String>['840', 'R6 部件 k6 ×5'],
  <String>['860', '代币 ×10'],
  <String>['880', 'R6 部件 k7 ×5'],
  <String>['900', '活动代币 ×200'],
  <String>['920', 'R6 部件 k8 ×5'],
  <String>['940', '代币 ×10'],
  <String>['960', 'R6 部件 k9 ×5'],
  <String>['980', '紫票 ×90000'],
  <String>['1000', 'R6 部件 k10 ×2'],
  <String>['1025', '代币 ×10'],
  <String>['1050', 'R6 部件 k11 ×2'],
  <String>['1075', '活动代币 ×250'],
  <String>['1100', 'R6 部件 k12 ×2'],
  <String>['1125', '代币 ×20'],
  <String>['1150', 'R6 部件 k13 ×2'],
  <String>['1175', '紫票 ×95000'],
  <String>['1200', 'R6 部件 k14 ×2'],
  <String>['1225', '活动代币 ×250'],
  <String>['1250', 'R6 部件 k10 ×3'],
  <String>['1275', '紫票 ×100000'],
  <String>['1300', 'R6 部件 k11 ×3'],
  <String>['1325', '紫票 ×110000'],
  <String>['1350', 'R6 部件 k12 ×3'],
  <String>['1375', '紫票 ×120000'],
  <String>['1400', 'R6 部件 k13 ×3'],
  <String>['1425', '活动代币 ×300'],
  <String>['1450', 'R6 部件 k14 ×3'],
  <String>['1475', '紫票 ×130000'],
  <String>['1500', 'R6 部件 k10 ×5'],
  <String>['1525', '代币 ×20'],
  <String>['1550', 'R6 部件 k11 ×5'],
  <String>['1575', '活动代币 ×500'],
  <String>['1600', 'R6 部件 k12 ×5'],
  <String>['1625', '代币 ×20'],
  <String>['1650', 'R6 部件 k13 ×5'],
  <String>['1675', '紫票 ×140000'],
  <String>['1700', 'R6 部件 k14 ×5'],
  <String>['1725', '代币 ×25'],
  <String>['1750', 'R6 部件 k10 ×10'],
  <String>['1775', '活动代币 ×500'],
  <String>['1800', 'R6 部件 k11 ×10'],
  <String>['1825', '代币 ×25'],
  <String>['1850', 'R6 部件 k12 ×10'],
  <String>['1900', 'R6 部件 k13 ×10'],
  <String>['2000', 'R6 部件 k14 ×10'],
];

const List<List<String>> _scrapNodesEn = <List<String>>[
  <String>['5', 'Championship box ×2'],
  <String>['10', 'Diamonds ×10'],
  <String>['15', 'Ultimate part box (R4-R5) ×2'],
  <String>['20', 'R6 part k1 ×1'],
  <String>['25', 'Event tokens ×50'],
  <String>['30', 'Ultimate part box (R4-R5) ×2'],
  <String>['35', 'Championship box ×2'],
  <String>['40', 'R6 part k2 ×1'],
  <String>['50', 'Event tokens ×50'],
  <String>['60', 'Ultimate part box (R4-R5) ×3'],
  <String>['70', 'Purple tickets ×25000'],
  <String>['80', 'R6 part k1 ×2'],
  <String>['90', 'Championship box ×3'],
  <String>['100', 'Ultimate part box (R4-R5) ×3'],
  <String>['110', 'Diamonds ×10'],
  <String>['120', 'R6 part k1 ×2'],
  <String>['130', 'Purple tickets ×50000'],
  <String>['140', 'Ultimate part box (R6) ×2'],
  <String>['150', 'Championship box ×3'],
  <String>['160', 'R6 part k2 ×2'],
  <String>['170', 'Event tokens ×75'],
  <String>['180', 'Ultimate part box (R6) ×2'],
  <String>['190', 'Tokens ×5'],
  <String>['200', 'R6 part k1 ×2'],
  <String>['220', 'Championship box ×2'],
  <String>['240', 'R6 part k3 ×2'],
  <String>['260', 'Diamonds ×20'],
  <String>['280', 'R6 part k4 ×2'],
  <String>['300', 'Purple tickets ×55000'],
  <String>['320', 'R6 part k5 ×2'],
  <String>['340', 'R4 toolbox ×2'],
  <String>['360', 'R6 part k3 ×3'],
  <String>['380', 'Event tokens ×100'],
  <String>['400', 'R6 part k4 ×3'],
  <String>['420', 'Purple tickets ×60000'],
  <String>['440', 'R6 part k5 ×3'],
  <String>['460', 'Championship box ×2'],
  <String>['480', 'R6 part k6 ×2'],
  <String>['500', 'Diamonds ×20'],
  <String>['520', 'R6 part k7 ×2'],
  <String>['540', 'Event tokens ×125'],
  <String>['560', 'R6 part k8 ×2'],
  <String>['580', 'R4 toolbox ×3'],
  <String>['600', 'R6 part k9 ×2'],
  <String>['620', 'Event tokens ×150'],
  <String>['640', 'R6 part k6 ×3'],
  <String>['660', 'Tokens ×5'],
  <String>['680', 'Ultimate part box (R6) ×3'],
  <String>['700', 'Diamonds ×40'],
  <String>['720', 'R6 part k7 ×3'],
  <String>['740', 'Purple tickets ×60000'],
  <String>['760', 'R6 part k8 ×3'],
  <String>['780', 'Event tokens ×200'],
  <String>['800', 'R6 part k9 ×3'],
  <String>['820', 'Purple tickets ×65000'],
  <String>['840', 'R6 part k6 ×5'],
  <String>['860', 'Tokens ×10'],
  <String>['880', 'R6 part k7 ×5'],
  <String>['900', 'Event tokens ×200'],
  <String>['920', 'R6 part k8 ×5'],
  <String>['940', 'Tokens ×10'],
  <String>['960', 'R6 part k9 ×5'],
  <String>['980', 'Purple tickets ×90000'],
  <String>['1000', 'R6 part k10 ×2'],
  <String>['1025', 'Tokens ×10'],
  <String>['1050', 'R6 part k11 ×2'],
  <String>['1075', 'Event tokens ×250'],
  <String>['1100', 'R6 part k12 ×2'],
  <String>['1125', 'Tokens ×20'],
  <String>['1150', 'R6 part k13 ×2'],
  <String>['1175', 'Purple tickets ×95000'],
  <String>['1200', 'R6 part k14 ×2'],
  <String>['1225', 'Event tokens ×250'],
  <String>['1250', 'R6 part k10 ×3'],
  <String>['1275', 'Purple tickets ×100000'],
  <String>['1300', 'R6 part k11 ×3'],
  <String>['1325', 'Purple tickets ×110000'],
  <String>['1350', 'R6 part k12 ×3'],
  <String>['1375', 'Purple tickets ×120000'],
  <String>['1400', 'R6 part k13 ×3'],
  <String>['1425', 'Event tokens ×300'],
  <String>['1450', 'R6 part k14 ×3'],
  <String>['1475', 'Purple tickets ×130000'],
  <String>['1500', 'R6 part k10 ×5'],
  <String>['1525', 'Tokens ×20'],
  <String>['1550', 'R6 part k11 ×5'],
  <String>['1575', 'Event tokens ×500'],
  <String>['1600', 'R6 part k12 ×5'],
  <String>['1625', 'Tokens ×20'],
  <String>['1650', 'R6 part k13 ×5'],
  <String>['1675', 'Purple tickets ×140000'],
  <String>['1700', 'R6 part k14 ×5'],
  <String>['1725', 'Tokens ×25'],
  <String>['1750', 'R6 part k10 ×10'],
  <String>['1775', 'Event tokens ×500'],
  <String>['1800', 'R6 part k11 ×10'],
  <String>['1825', 'Tokens ×25'],
  <String>['1850', 'R6 part k12 ×10'],
  <String>['1900', 'R6 part k13 ×10'],
  <String>['2000', 'R6 part k14 ×10'],
];

/// 锦标赛战车：25 档（部件材质 × 星级 → 最高等级）
const List<List<String>> _champTierRowsZh = <List<String>>[
  <String>['1', '木质', '1 星', '6 级'],
  <String>['2', '木质', '2 星', '11 级'],
  <String>['3', '木质', '3 星', '16 级'],
  <String>['4', '木质', '4 星', '21 级'],
  <String>['5', '木质', '5 星', '26 级'],
  <String>['6', '金属', '1 星', '6 级'],
  <String>['7', '金属', '2 星', '11 级'],
  <String>['8', '金属', '3 星', '16 级'],
  <String>['9', '金属', '4 星', '21 级'],
  <String>['10', '金属', '5 星', '26 级'],
  <String>['11', '军用', '1 星', '6 级'],
  <String>['12', '军用', '2 星', '11 级'],
  <String>['13', '军用', '3 星', '16 级'],
  <String>['14', '军用', '4 星', '21 级'],
  <String>['15', '军用', '5 星', '26 级'],
  <String>['16', '黄金', '1 星', '6 级'],
  <String>['17', '黄金', '2 星', '11 级'],
  <String>['18', '黄金', '3 星', '16 级'],
  <String>['19', '黄金', '4 星', '21 级'],
  <String>['20', '黄金', '5 星', '26 级'],
  <String>['21', '碳钢', '1 星', '6 级'],
  <String>['22', '碳钢', '2 星', '11 级'],
  <String>['23', '碳钢', '3 星', '16 级'],
  <String>['24', '碳钢', '4 星', '21 级'],
  <String>['25', '碳钢', '5 星', '26 级'],
];

const List<List<String>> _champTierRowsEn = <List<String>>[
  <String>['1', 'Wood', '1 star', 'Level 6'],
  <String>['2', 'Wood', '2 stars', 'Level 11'],
  <String>['3', 'Wood', '3 stars', 'Level 16'],
  <String>['4', 'Wood', '4 stars', 'Level 21'],
  <String>['5', 'Wood', '5 stars', 'Level 26'],
  <String>['6', 'Metal', '1 star', 'Level 6'],
  <String>['7', 'Metal', '2 stars', 'Level 11'],
  <String>['8', 'Metal', '3 stars', 'Level 16'],
  <String>['9', 'Metal', '4 stars', 'Level 21'],
  <String>['10', 'Metal', '5 stars', 'Level 26'],
  <String>['11', 'Military', '1 star', 'Level 6'],
  <String>['12', 'Military', '2 stars', 'Level 11'],
  <String>['13', 'Military', '3 stars', 'Level 16'],
  <String>['14', 'Military', '4 stars', 'Level 21'],
  <String>['15', 'Military', '5 stars', 'Level 26'],
  <String>['16', 'Gold', '1 star', 'Level 6'],
  <String>['17', 'Gold', '2 stars', 'Level 11'],
  <String>['18', 'Gold', '3 stars', 'Level 16'],
  <String>['19', 'Gold', '4 stars', 'Level 21'],
  <String>['20', 'Gold', '5 stars', 'Level 26'],
  <String>['21', 'Carbon', '1 star', 'Level 6'],
  <String>['22', 'Carbon', '2 stars', 'Level 11'],
  <String>['23', 'Carbon', '3 stars', 'Level 16'],
  <String>['24', 'Carbon', '4 stars', 'Level 21'],
  <String>['25', 'Carbon', '5 stars', 'Level 26'],
];

/// 锦标赛战车：25 档车身的三种数值组合（每格 = 基础 HP / 供电）
/// 组合 1 = HP 最高 / 供电最低，组合 3 = HP 最低 / 供电最高
const List<List<String>> _champSupplyRowsZh = <List<String>>[
  <String>['1', '木质 1 星', '45 / 6', '45 / 6', '45 / 6'],
  <String>['2', '木质 2 星', '75 / 6', '60 / 7', '45 / 8'],
  <String>['3', '木质 3 星', '105 / 9', '90 / 10', '75 / 11'],
  <String>['4', '木质 4 星', '135 / 12', '120 / 13', '105 / 14'],
  <String>['5', '木质 5 星', '180 / 15', '158 / 16', '135 / 17'],
  <String>['6', '金属 1 星', '285 / 8', '233 / 9', '180 / 10'],
  <String>['7', '金属 2 星', '405 / 10', '345 / 11', '285 / 12'],
  <String>['8', '金属 3 星', '555 / 12', '480 / 13', '405 / 14'],
  <String>['9', '金属 4 星', '720 / 14', '645 / 15', '555 / 16'],
  <String>['10', '金属 5 星', '915 / 16', '818 / 17', '720 / 18'],
  <String>['11', '军用 1 星', '1380 / 8', '1148 / 9', '915 / 10'],
  <String>['12', '军用 2 星', '1935 / 10', '1658 / 11', '1380 / 12'],
  <String>['13', '军用 3 星', '2580 / 12', '2258 / 13', '1935 / 14'],
  <String>['14', '军用 4 星', '3330 / 14', '2955 / 15', '2580 / 16'],
  <String>['15', '军用 5 星', '4170 / 16', '3750 / 17', '3330 / 18'],
  <String>['16', '黄金 1 星', '6255 / 8', '5213 / 9', '4170 / 10'],
  <String>['17', '黄金 2 星', '8760 / 10', '7508 / 11', '6255 / 12'],
  <String>['18', '黄金 3 星', '11685 / 12', '10223 / 13', '8760 / 14'],
  <String>['19', '黄金 4 星', '15030 / 14', '13358 / 15', '11685 / 16'],
  <String>['20', '黄金 5 星', '18795 / 16', '16920 / 17', '15030 / 18'],
  <String>['21', '碳钢 1 星', '28215 / 8', '23505 / 9', '18795 / 10'],
  <String>['22', '碳钢 2 星', '39525 / 10', '33870 / 11', '28215 / 12'],
  <String>['23', '碳钢 3 星', '52725 / 12', '46125 / 13', '39525 / 14'],
  <String>['24', '碳钢 4 星', '67800 / 14', '60255 / 15', '52725 / 16'],
  <String>['25', '碳钢 5 星', '84780 / 16', '76290 / 17', '67800 / 18'],
];

const List<List<String>> _champSupplyRowsEn = <List<String>>[
  <String>['1', 'Wood 1 star', '45 / 6', '45 / 6', '45 / 6'],
  <String>['2', 'Wood 2 stars', '75 / 6', '60 / 7', '45 / 8'],
  <String>['3', 'Wood 3 stars', '105 / 9', '90 / 10', '75 / 11'],
  <String>['4', 'Wood 4 stars', '135 / 12', '120 / 13', '105 / 14'],
  <String>['5', 'Wood 5 stars', '180 / 15', '158 / 16', '135 / 17'],
  <String>['6', 'Metal 1 star', '285 / 8', '233 / 9', '180 / 10'],
  <String>['7', 'Metal 2 stars', '405 / 10', '345 / 11', '285 / 12'],
  <String>['8', 'Metal 3 stars', '555 / 12', '480 / 13', '405 / 14'],
  <String>['9', 'Metal 4 stars', '720 / 14', '645 / 15', '555 / 16'],
  <String>['10', 'Metal 5 stars', '915 / 16', '818 / 17', '720 / 18'],
  <String>['11', 'Military 1 star', '1380 / 8', '1148 / 9', '915 / 10'],
  <String>['12', 'Military 2 stars', '1935 / 10', '1658 / 11', '1380 / 12'],
  <String>['13', 'Military 3 stars', '2580 / 12', '2258 / 13', '1935 / 14'],
  <String>['14', 'Military 4 stars', '3330 / 14', '2955 / 15', '2580 / 16'],
  <String>['15', 'Military 5 stars', '4170 / 16', '3750 / 17', '3330 / 18'],
  <String>['16', 'Gold 1 star', '6255 / 8', '5213 / 9', '4170 / 10'],
  <String>['17', 'Gold 2 stars', '8760 / 10', '7508 / 11', '6255 / 12'],
  <String>['18', 'Gold 3 stars', '11685 / 12', '10223 / 13', '8760 / 14'],
  <String>['19', 'Gold 4 stars', '15030 / 14', '13358 / 15', '11685 / 16'],
  <String>['20', 'Gold 5 stars', '18795 / 16', '16920 / 17', '15030 / 18'],
  <String>['21', 'Carbon 1 star', '28215 / 8', '23505 / 9', '18795 / 10'],
  <String>['22', 'Carbon 2 stars', '39525 / 10', '33870 / 11', '28215 / 12'],
  <String>['23', 'Carbon 3 stars', '52725 / 12', '46125 / 13', '39525 / 14'],
  <String>['24', 'Carbon 4 stars', '67800 / 14', '60255 / 15', '52725 / 16'],
  <String>['25', 'Carbon 5 stars', '84780 / 16', '76290 / 17', '67800 / 18'],
];

/// 锦标赛战车：25 档武器的三种数值组合（每格 = 耗电 / 基础 ATK / 随从 HP）
/// 组合 1 = 耗电与基础 ATK 最低、随从 HP 最高；组合 3 = 耗电与基础 ATK 最高、随从 HP 最低
/// （随从 HP 与耗电反向：耗电越高，随从 HP 越低）
const List<List<String>> _champWeaponRowsZh = <List<String>>[
  <String>['1', '木质 1 星', '4 / 20 / 23', '5 / 25 / 23', '6 / 30 / 23'],
  <String>['2', '木质 2 星', '5 / 30 / 38', '6 / 40 / 30', '7 / 50 / 23'],
  <String>['3', '木质 3 星', '6 / 50 / 53', '7 / 60 / 45', '8 / 70 / 38'],
  <String>['4', '木质 4 星', '7 / 70 / 68', '8 / 80 / 60', '9 / 90 / 53'],
  <String>['5', '木质 5 星', '8 / 90 / 90', '9 / 105 / 79', '10 / 120 / 68'],
  <String>['6', '金属 1 星', '4 / 120 / 143', '5 / 155 / 117', '6 / 190 / 90'],
  <String>['7', '金属 2 星', '5 / 190 / 203', '6 / 230 / 173', '7 / 270 / 143'],
  <String>['8', '金属 3 星', '6 / 270 / 278', '7 / 320 / 240', '8 / 370 / 203'],
  <String>['9', '金属 4 星', '7 / 370 / 360', '8 / 430 / 323', '9 / 480 / 278'],
  <String>['10', '金属 5 星', '8 / 480 / 458', '9 / 545 / 409', '10 / 610 / 360'],
  <String>['11', '军用 1 星', '4 / 610 / 690', '5 / 765 / 574', '6 / 920 / 458'],
  <String>['12', '军用 2 星', '5 / 920 / 968', '6 / 1105 / 829', '7 / 1290 / 690'],
  <String>[
    '13',
    '军用 3 星',
    '6 / 1290 / 1290',
    '7 / 1505 / 1129',
    '8 / 1720 / 968',
  ],
  <String>[
    '14',
    '军用 4 星',
    '7 / 1720 / 1665',
    '8 / 1970 / 1478',
    '9 / 2220 / 1290',
  ],
  <String>[
    '15',
    '军用 5 星',
    '8 / 2220 / 2085',
    '9 / 2500 / 1875',
    '10 / 2780 / 1665',
  ],
  <String>[
    '16',
    '黄金 1 星',
    '4 / 2780 / 3128',
    '5 / 3475 / 2607',
    '6 / 4170 / 2085',
  ],
  <String>[
    '17',
    '黄金 2 星',
    '5 / 4170 / 4380',
    '6 / 5005 / 3754',
    '7 / 5840 / 3128',
  ],
  <String>[
    '18',
    '黄金 3 星',
    '6 / 5840 / 5843',
    '7 / 6815 / 5112',
    '8 / 7790 / 4380',
  ],
  <String>[
    '19',
    '黄金 4 星',
    '7 / 7790 / 7515',
    '8 / 8905 / 6679',
    '9 / 10020 / 5843',
  ],
  <String>[
    '20',
    '黄金 5 星',
    '8 / 10020 / 9398',
    '9 / 11280 / 8460',
    '10 / 12530 / 7515',
  ],
  <String>[
    '21',
    '碳钢 1 星',
    '4 / 12530 / 14108',
    '5 / 15670 / 11753',
    '6 / 18810 / 9398',
  ],
  <String>[
    '22',
    '碳钢 2 星',
    '5 / 18810 / 19763',
    '6 / 22580 / 16935',
    '7 / 26350 / 14108',
  ],
  <String>[
    '23',
    '碳钢 3 星',
    '6 / 26350 / 26363',
    '7 / 30750 / 23063',
    '8 / 35150 / 19763',
  ],
  <String>[
    '24',
    '碳钢 4 星',
    '7 / 35150 / 33900',
    '8 / 40170 / 30128',
    '9 / 45200 / 26363',
  ],
  <String>[
    '25',
    '碳钢 5 星',
    '8 / 45200 / 42390',
    '9 / 50860 / 38145',
    '10 / 56520 / 33900',
  ],
];

const List<List<String>> _champWeaponRowsEn = <List<String>>[
  <String>['1', 'Wood 1 star', '4 / 20 / 23', '5 / 25 / 23', '6 / 30 / 23'],
  <String>['2', 'Wood 2 stars', '5 / 30 / 38', '6 / 40 / 30', '7 / 50 / 23'],
  <String>['3', 'Wood 3 stars', '6 / 50 / 53', '7 / 60 / 45', '8 / 70 / 38'],
  <String>['4', 'Wood 4 stars', '7 / 70 / 68', '8 / 80 / 60', '9 / 90 / 53'],
  <String>['5', 'Wood 5 stars', '8 / 90 / 90', '9 / 105 / 79', '10 / 120 / 68'],
  <String>[
    '6',
    'Metal 1 star',
    '4 / 120 / 143',
    '5 / 155 / 117',
    '6 / 190 / 90',
  ],
  <String>[
    '7',
    'Metal 2 stars',
    '5 / 190 / 203',
    '6 / 230 / 173',
    '7 / 270 / 143',
  ],
  <String>[
    '8',
    'Metal 3 stars',
    '6 / 270 / 278',
    '7 / 320 / 240',
    '8 / 370 / 203',
  ],
  <String>[
    '9',
    'Metal 4 stars',
    '7 / 370 / 360',
    '8 / 430 / 323',
    '9 / 480 / 278',
  ],
  <String>[
    '10',
    'Metal 5 stars',
    '8 / 480 / 458',
    '9 / 545 / 409',
    '10 / 610 / 360',
  ],
  <String>[
    '11',
    'Military 1 star',
    '4 / 610 / 690',
    '5 / 765 / 574',
    '6 / 920 / 458',
  ],
  <String>[
    '12',
    'Military 2 stars',
    '5 / 920 / 968',
    '6 / 1105 / 829',
    '7 / 1290 / 690',
  ],
  <String>[
    '13',
    'Military 3 stars',
    '6 / 1290 / 1290',
    '7 / 1505 / 1129',
    '8 / 1720 / 968',
  ],
  <String>[
    '14',
    'Military 4 stars',
    '7 / 1720 / 1665',
    '8 / 1970 / 1478',
    '9 / 2220 / 1290',
  ],
  <String>[
    '15',
    'Military 5 stars',
    '8 / 2220 / 2085',
    '9 / 2500 / 1875',
    '10 / 2780 / 1665',
  ],
  <String>[
    '16',
    'Gold 1 star',
    '4 / 2780 / 3128',
    '5 / 3475 / 2607',
    '6 / 4170 / 2085',
  ],
  <String>[
    '17',
    'Gold 2 stars',
    '5 / 4170 / 4380',
    '6 / 5005 / 3754',
    '7 / 5840 / 3128',
  ],
  <String>[
    '18',
    'Gold 3 stars',
    '6 / 5840 / 5843',
    '7 / 6815 / 5112',
    '8 / 7790 / 4380',
  ],
  <String>[
    '19',
    'Gold 4 stars',
    '7 / 7790 / 7515',
    '8 / 8905 / 6679',
    '9 / 10020 / 5843',
  ],
  <String>[
    '20',
    'Gold 5 stars',
    '8 / 10020 / 9398',
    '9 / 11280 / 8460',
    '10 / 12530 / 7515',
  ],
  <String>[
    '21',
    'Carbon 1 star',
    '4 / 12530 / 14108',
    '5 / 15670 / 11753',
    '6 / 18810 / 9398',
  ],
  <String>[
    '22',
    'Carbon 2 stars',
    '5 / 18810 / 19763',
    '6 / 22580 / 16935',
    '7 / 26350 / 14108',
  ],
  <String>[
    '23',
    'Carbon 3 stars',
    '6 / 26350 / 26363',
    '7 / 30750 / 23063',
    '8 / 35150 / 19763',
  ],
  <String>[
    '24',
    'Carbon 4 stars',
    '7 / 35150 / 33900',
    '8 / 40170 / 30128',
    '9 / 45200 / 26363',
  ],
  <String>[
    '25',
    'Carbon 5 stars',
    '8 / 45200 / 42390',
    '9 / 50860 / 38145',
    '10 / 56520 / 33900',
  ],
];

/// 锦标赛战车：升级所需经验（基础值，实际数值再乘目标部件的 k）
const List<List<String>> _champExpRowsZh = <List<String>>[
  <String>['1', '2', '0'],
  <String>['2', '3', '2'],
  <String>['3', '4', '5'],
  <String>['4', '5', '9'],
  <String>['5', '6', '14'],
  <String>['6', '7', '20'],
  <String>['7', '8', '27'],
  <String>['8', '9', '35'],
  <String>['9', '10', '44'],
  <String>['10', '11', '54'],
  <String>['11', '12', '65'],
  <String>['12', '13', '77'],
  <String>['13', '14', '90'],
  <String>['14', '15', '104'],
  <String>['15', '16', '119'],
  <String>['16', '17', '135'],
  <String>['17', '18', '152'],
  <String>['18', '19', '170'],
  <String>['19', '20', '189'],
  <String>['20', '21', '209'],
  <String>['21', '22', '230'],
  <String>['22', '23', '252'],
  <String>['23', '24', '275'],
  <String>['24', '25', '299'],
  <String>['25', '10', '324'],
  <String>['26', '—', '334'],
];

const List<List<String>> _champExpRowsEn = <List<String>>[
  <String>['1', '2', '0'],
  <String>['2', '3', '2'],
  <String>['3', '4', '5'],
  <String>['4', '5', '9'],
  <String>['5', '6', '14'],
  <String>['6', '7', '20'],
  <String>['7', '8', '27'],
  <String>['8', '9', '35'],
  <String>['9', '10', '44'],
  <String>['10', '11', '54'],
  <String>['11', '12', '65'],
  <String>['12', '13', '77'],
  <String>['13', '14', '90'],
  <String>['14', '15', '104'],
  <String>['15', '16', '119'],
  <String>['16', '17', '135'],
  <String>['17', '18', '152'],
  <String>['18', '19', '170'],
  <String>['19', '20', '189'],
  <String>['20', '21', '209'],
  <String>['21', '22', '230'],
  <String>['22', '23', '252'],
  <String>['23', '24', '275'],
  <String>['24', '25', '299'],
  <String>['25', '10', '324'],
  <String>['26', '—', '334'],
];

/// 锦标赛战车：25 档 1 级部件的价值 / 融合花费 / 出售价（专业交易商、商人均满级）
const List<List<String>> _champValueRowsZh = <List<String>>[
  <String>['1', '木质 1 星', '469', '328', '213'],
  <String>['2', '木质 2 星', '750', '525', '341'],
  <String>['3', '木质 3 星', '1125', '788', '512'],
  <String>['4', '木质 4 星', '1688', '1182', '768'],
  <String>['5', '木质 5 星', '2438', '1707', '1110'],
  <String>['6', '金属 1 星', '3375', '2363', '1536'],
  <String>['7', '金属 2 星', '4500', '3150', '2048'],
  <String>['8', '金属 3 星', '5813', '4069', '2645'],
  <String>['9', '金属 4 星', '7313', '5119', '3327'],
  <String>['10', '金属 5 星', '9000', '6300', '4095'],
  <String>['11', '军用 1 星', '10875', '7612', '4948'],
  <String>['12', '军用 2 星', '12938', '9057', '5887'],
  <String>['13', '军用 3 星', '15188', '10632', '6911'],
  <String>['14', '军用 4 星', '17625', '12338', '8020'],
  <String>['15', '军用 5 星', '20250', '14175', '9214'],
  <String>['16', '黄金 1 星', '23063', '16144', '10494'],
  <String>['17', '黄金 2 星', '26063', '18244', '11859'],
  <String>['18', '黄金 3 星', '29250', '20475', '13309'],
  <String>['19', '黄金 4 星', '32625', '22838', '14845'],
  <String>['20', '黄金 5 星', '36188', '25332', '16466'],
  <String>['21', '碳钢 1 星', '39938', '27957', '18172'],
  <String>['22', '碳钢 2 星', '43875', '30712', '19963'],
  <String>['23', '碳钢 3 星', '48000', '33600', '21840'],
  <String>['24', '碳钢 4 星', '52313', '36619', '23802'],
  <String>['25', '碳钢 5 星', '56813', '39769', '25850'],
];

const List<List<String>> _champValueRowsEn = <List<String>>[
  <String>['1', 'Wood 1 star', '469', '328', '213'],
  <String>['2', 'Wood 2 stars', '750', '525', '341'],
  <String>['3', 'Wood 3 stars', '1125', '788', '512'],
  <String>['4', 'Wood 4 stars', '1688', '1182', '768'],
  <String>['5', 'Wood 5 stars', '2438', '1707', '1110'],
  <String>['6', 'Metal 1 star', '3375', '2363', '1536'],
  <String>['7', 'Metal 2 stars', '4500', '3150', '2048'],
  <String>['8', 'Metal 3 stars', '5813', '4069', '2645'],
  <String>['9', 'Metal 4 stars', '7313', '5119', '3327'],
  <String>['10', 'Metal 5 stars', '9000', '6300', '4095'],
  <String>['11', 'Military 1 star', '10875', '7612', '4948'],
  <String>['12', 'Military 2 stars', '12938', '9057', '5887'],
  <String>['13', 'Military 3 stars', '15188', '10632', '6911'],
  <String>['14', 'Military 4 stars', '17625', '12338', '8020'],
  <String>['15', 'Military 5 stars', '20250', '14175', '9214'],
  <String>['16', 'Gold 1 star', '23063', '16144', '10494'],
  <String>['17', 'Gold 2 stars', '26063', '18244', '11859'],
  <String>['18', 'Gold 3 stars', '29250', '20475', '13309'],
  <String>['19', 'Gold 4 stars', '32625', '22838', '14845'],
  <String>['20', 'Gold 5 stars', '36188', '25332', '16466'],
  <String>['21', 'Carbon 1 star', '39938', '27957', '18172'],
  <String>['22', 'Carbon 2 stars', '43875', '30712', '19963'],
  <String>['23', 'Carbon 3 stars', '48000', '33600', '21840'],
  <String>['24', 'Carbon 4 stars', '52313', '36619', '23802'],
  <String>['25', 'Carbon 5 stars', '56813', '39769', '25850'],
];

/// 锦标赛战车：25 档车轮 HP（3 种数值）
const List<List<String>> _champWheelRowsZh = <List<String>>[
  <String>['1', '木质 1 星', '10 / 13 / 15'],
  <String>['2', '木质 2 星', '15 / 20 / 25'],
  <String>['3', '木质 3 星', '25 / 30 / 35'],
  <String>['4', '木质 4 星', '35 / 40 / 45'],
  <String>['5', '木质 5 星', '45 / 53 / 60'],
  <String>['6', '金属 1 星', '60 / 78 / 95'],
  <String>['7', '金属 2 星', '95 / 115 / 135'],
  <String>['8', '金属 3 星', '135 / 160 / 185'],
  <String>['9', '金属 4 星', '185 / 215 / 240'],
  <String>['10', '金属 5 星', '240 / 273 / 305'],
  <String>['11', '军用 1 星', '305 / 383 / 460'],
  <String>['12', '军用 2 星', '460 / 553 / 645'],
  <String>['13', '军用 3 星', '645 / 753 / 860'],
  <String>['14', '军用 4 星', '860 / 985 / 1110'],
  <String>['15', '军用 5 星', '1110 / 1250 / 1390'],
  <String>['16', '黄金 1 星', '1390 / 1738 / 2085'],
  <String>['17', '黄金 2 星', '2085 / 2503 / 2920'],
  <String>['18', '黄金 3 星', '2920 / 3408 / 3895'],
  <String>['19', '黄金 4 星', '3895 / 4453 / 5010'],
  <String>['20', '黄金 5 星', '5010 / 5640 / 6265'],
  <String>['21', '碳钢 1 星', '6265 / 7835 / 9405'],
  <String>['22', '碳钢 2 星', '9405 / 11290 / 13175'],
  <String>['23', '碳钢 3 星', '13175 / 15375 / 17575'],
  <String>['24', '碳钢 4 星', '17575 / 20085 / 22600'],
  <String>['25', '碳钢 5 星', '22600 / 25430 / 28260'],
];

const List<List<String>> _champWheelRowsEn = <List<String>>[
  <String>['1', 'Wood 1 star', '10 / 13 / 15'],
  <String>['2', 'Wood 2 stars', '15 / 20 / 25'],
  <String>['3', 'Wood 3 stars', '25 / 30 / 35'],
  <String>['4', 'Wood 4 stars', '35 / 40 / 45'],
  <String>['5', 'Wood 5 stars', '45 / 53 / 60'],
  <String>['6', 'Metal 1 star', '60 / 78 / 95'],
  <String>['7', 'Metal 2 stars', '95 / 115 / 135'],
  <String>['8', 'Metal 3 stars', '135 / 160 / 185'],
  <String>['9', 'Metal 4 stars', '185 / 215 / 240'],
  <String>['10', 'Metal 5 stars', '240 / 273 / 305'],
  <String>['11', 'Military 1 star', '305 / 383 / 460'],
  <String>['12', 'Military 2 stars', '460 / 553 / 645'],
  <String>['13', 'Military 3 stars', '645 / 753 / 860'],
  <String>['14', 'Military 4 stars', '860 / 985 / 1110'],
  <String>['15', 'Military 5 stars', '1110 / 1250 / 1390'],
  <String>['16', 'Gold 1 star', '1390 / 1738 / 2085'],
  <String>['17', 'Gold 2 stars', '2085 / 2503 / 2920'],
  <String>['18', 'Gold 3 stars', '2920 / 3408 / 3895'],
  <String>['19', 'Gold 4 stars', '3895 / 4453 / 5010'],
  <String>['20', 'Gold 5 stars', '5010 / 5640 / 6265'],
  <String>['21', 'Carbon 1 star', '6265 / 7835 / 9405'],
  <String>['22', 'Carbon 2 stars', '9405 / 11290 / 13175'],
  <String>['23', 'Carbon 3 stars', '13175 / 15375 / 17575'],
  <String>['24', 'Carbon 4 stars', '17575 / 20085 / 22600'],
  <String>['25', 'Carbon 5 stars', '22600 / 25430 / 28260'],
];

/// 锦标赛战车：配件用的基础值（= 同段同档的「基础配件 HP」3 种数值 + 该档基础治疗量）
const List<List<String>> _champWheelBaseRowsZh = <List<String>>[
  <String>['1', '木质 1 星', '10 / 13 / 15', '19'],
  <String>['2', '木质 2 星', '15 / 20 / 25', '30'],
  <String>['3', '木质 3 星', '25 / 30 / 35', '45'],
  <String>['4', '木质 4 星', '35 / 40 / 45', '60'],
  <String>['5', '木质 5 星', '45 / 53 / 60', '79'],
  <String>['6', '金属 1 星', '60 / 78 / 95', '116'],
  <String>['7', '金属 2 星', '95 / 115 / 135', '173'],
  <String>['8', '金属 3 星', '135 / 160 / 185', '240'],
  <String>['9', '金属 4 星', '185 / 215 / 240', '323'],
  <String>['10', '金属 5 星', '240 / 273 / 305', '409'],
  <String>['11', '军用 1 星', '305 / 383 / 460', '574'],
  <String>['12', '军用 2 星', '460 / 553 / 645', '829'],
  <String>['13', '军用 3 星', '645 / 753 / 860', '1129'],
  <String>['14', '军用 4 星', '860 / 985 / 1110', '1478'],
  <String>['15', '军用 5 星', '1110 / 1250 / 1390', '1875'],
  <String>['16', '黄金 1 星', '1390 / 1738 / 2085', '2606'],
  <String>['17', '黄金 2 星', '2085 / 2503 / 2920', '3754'],
  <String>['18', '黄金 3 星', '2920 / 3408 / 3895', '5111'],
  <String>['19', '黄金 4 星', '3895 / 4453 / 5010', '6679'],
  <String>['20', '黄金 5 星', '5010 / 5640 / 6265', '8460'],
  <String>['21', '碳钢 1 星', '6265 / 7835 / 9405', '11753'],
  <String>['22', '碳钢 2 星', '9405 / 11290 / 13175', '16935'],
  <String>['23', '碳钢 3 星', '13175 / 15375 / 17575', '23063'],
  <String>['24', '碳钢 4 星', '17575 / 20085 / 22600', '30128'],
  <String>['25', '碳钢 5 星', '22600 / 25430 / 28260', '38145'],
];

/// Championship: the base value used by gadget HP (= base gadget HP of the same tier)
const List<List<String>> _champWheelBaseRowsEn = <List<String>>[
  <String>['1', 'Wood 1 star', '10 / 13 / 15', '19'],
  <String>['2', 'Wood 2 stars', '15 / 20 / 25', '30'],
  <String>['3', 'Wood 3 stars', '25 / 30 / 35', '45'],
  <String>['4', 'Wood 4 stars', '35 / 40 / 45', '60'],
  <String>['5', 'Wood 5 stars', '45 / 53 / 60', '79'],
  <String>['6', 'Metal 1 star', '60 / 78 / 95', '116'],
  <String>['7', 'Metal 2 stars', '95 / 115 / 135', '173'],
  <String>['8', 'Metal 3 stars', '135 / 160 / 185', '240'],
  <String>['9', 'Metal 4 stars', '185 / 215 / 240', '323'],
  <String>['10', 'Metal 5 stars', '240 / 273 / 305', '409'],
  <String>['11', 'Military 1 star', '305 / 383 / 460', '574'],
  <String>['12', 'Military 2 stars', '460 / 553 / 645', '829'],
  <String>['13', 'Military 3 stars', '645 / 753 / 860', '1129'],
  <String>['14', 'Military 4 stars', '860 / 985 / 1110', '1478'],
  <String>['15', 'Military 5 stars', '1110 / 1250 / 1390', '1875'],
  <String>['16', 'Gold 1 star', '1390 / 1738 / 2085', '2606'],
  <String>['17', 'Gold 2 stars', '2085 / 2503 / 2920', '3754'],
  <String>['18', 'Gold 3 stars', '2920 / 3408 / 3895', '5111'],
  <String>['19', 'Gold 4 stars', '3895 / 4453 / 5010', '6679'],
  <String>['20', 'Gold 5 stars', '5010 / 5640 / 6265', '8460'],
  <String>['21', 'Carbon 1 star', '6265 / 7835 / 9405', '11753'],
  <String>['22', 'Carbon 2 stars', '9405 / 11290 / 13175', '16935'],
  <String>['23', 'Carbon 3 stars', '13175 / 15375 / 17575', '23063'],
  <String>['24', 'Carbon 4 stars', '17575 / 20085 / 22600', '30128'],
  <String>['25', 'Carbon 5 stars', '22600 / 25430 / 28260', '38145'],
];

/// 锦标赛战车：25 档工具箱（基础花费 / 售价 = 基础花费 × 8 / 生命值与攻击力加成）
const List<List<String>> _champToolboxRowsZh = <List<String>>[
  <String>['1', '木质 1 星', '100', '800', '8', '4'],
  <String>['2', '木质 2 星', '150', '1200', '12', '6'],
  <String>['3', '木质 3 星', '225', '1800', '20', '10'],
  <String>['4', '木质 4 星', '325', '2600', '28', '14'],
  <String>['5', '木质 5 星', '450', '3600', '36', '18'],
  <String>['6', '金属 1 星', '600', '4800', '48', '24'],
  <String>['7', '金属 2 星', '775', '6200', '76', '38'],
  <String>['8', '金属 3 星', '975', '7800', '108', '54'],
  <String>['9', '金属 4 星', '1200', '9600', '148', '74'],
  <String>['10', '金属 5 星', '1450', '11600', '192', '96'],
  <String>['11', '军用 1 星', '1725', '13800', '244', '122'],
  <String>['12', '军用 2 星', '2025', '16200', '368', '184'],
  <String>['13', '军用 3 星', '2350', '18800', '516', '258'],
  <String>['14', '军用 4 星', '2700', '21600', '688', '344'],
  <String>['15', '军用 5 星', '3075', '24600', '888', '444'],
  <String>['16', '黄金 1 星', '3475', '27800', '1112', '556'],
  <String>['17', '黄金 2 星', '3900', '31200', '1668', '834'],
  <String>['18', '黄金 3 星', '4350', '34800', '2336', '1168'],
  <String>['19', '黄金 4 星', '4825', '38600', '3116', '1558'],
  <String>['20', '黄金 5 星', '5325', '42600', '4008', '2004'],
  <String>['21', '碳钢 1 星', '5850', '46800', '5012', '2506'],
  <String>['22', '碳钢 2 星', '6400', '51200', '7524', '3762'],
  <String>['23', '碳钢 3 星', '6975', '55800', '10540', '5270'],
  <String>['24', '碳钢 4 星', '7575', '60600', '14060', '7030'],
  <String>['25', '碳钢 5 星', '8137', '65096', '18080', '9040'],
];

const List<List<String>> _champToolboxRowsEn = <List<String>>[
  <String>['1', 'Wood 1 star', '100', '800', '8', '4'],
  <String>['2', 'Wood 2 stars', '150', '1200', '12', '6'],
  <String>['3', 'Wood 3 stars', '225', '1800', '20', '10'],
  <String>['4', 'Wood 4 stars', '325', '2600', '28', '14'],
  <String>['5', 'Wood 5 stars', '450', '3600', '36', '18'],
  <String>['6', 'Metal 1 star', '600', '4800', '48', '24'],
  <String>['7', 'Metal 2 stars', '775', '6200', '76', '38'],
  <String>['8', 'Metal 3 stars', '975', '7800', '108', '54'],
  <String>['9', 'Metal 4 stars', '1200', '9600', '148', '74'],
  <String>['10', 'Metal 5 stars', '1450', '11600', '192', '96'],
  <String>['11', 'Military 1 star', '1725', '13800', '244', '122'],
  <String>['12', 'Military 2 stars', '2025', '16200', '368', '184'],
  <String>['13', 'Military 3 stars', '2350', '18800', '516', '258'],
  <String>['14', 'Military 4 stars', '2700', '21600', '688', '344'],
  <String>['15', 'Military 5 stars', '3075', '24600', '888', '444'],
  <String>['16', 'Gold 1 star', '3475', '27800', '1112', '556'],
  <String>['17', 'Gold 2 stars', '3900', '31200', '1668', '834'],
  <String>['18', 'Gold 3 stars', '4350', '34800', '2336', '1168'],
  <String>['19', 'Gold 4 stars', '4825', '38600', '3116', '1558'],
  <String>['20', 'Gold 5 stars', '5325', '42600', '4008', '2004'],
  <String>['21', 'Carbon 1 star', '5850', '46800', '5012', '2506'],
  <String>['22', 'Carbon 2 stars', '6400', '51200', '7524', '3762'],
  <String>['23', 'Carbon 3 stars', '6975', '55800', '10540', '5270'],
  <String>['24', 'Carbon 4 stars', '7575', '60600', '14060', '7030'],
  <String>['25', 'Carbon 5 stars', '8137', '65096', '18080', '9040'],
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
          captionZh: '建筑与车位示意（蓝＝我方车、红＝对方帮派的车、灰＝人机车；带「链接」/「×5」的是特殊加成建筑）',
          captionEn:
              'Buildings and slots (blue = ours, red = the opposing gang, grey = bots; "link" and "×5" mark special bonuses)',
        ),
      ]),
      // ---------- 2. 车位争夺 ----------
      GuideBlock.heading(
        '车位争夺：一辆车怎么打',
        'Taking a slot: how a single fight works',
      ),
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
      GuideBlock.table(
        GuideTable(
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
            <String>[
              'Exploded',
              'HP hit zero: it explodes and turns back to idle once HP is full (2 hours)',
            ],
          ],
        ),
      ),
      GuideBlock.text(
        '状态流转：空闲 →（占领车位）→ 防守；防守 →（HP 归零）→ 爆炸 →（生命值回满）→ 空闲。',
        'State flow: idle → (takes a slot) → defending; defending → (HP reaches zero) → exploded → (HP refills) → idle.',
      ),
      // ---------- 3. 特殊机制 ----------
      GuideBlock.heading(
        '特殊机制：链接与高回报加成',
        'Special mechanics: links & high reward',
      ),
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
          captionEn:
              'Season wrap-up flow (T = the day the 10th gang reaches 30 wins)',
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
      GuideBlock.table(
        GuideTable(
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
        ),
      ),
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
      GuideBlock.table(
        GuideTable(
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
        ),
      ),
      // ---------- 5. 地区奖励 ----------
      GuideBlock.heading('地区奖励（征服地区）', 'Region reward (conquering a region)'),
      GuideBlock.text(
        '每到达一个新地区，就等于征服了上一个地区，发放下面的阶段奖励（代币 + 王牌 + 随机部件）：',
        'Each time you reach a new region you have conquered the previous one and receive the stage reward below (tokens + jokers + random parts):',
      ),
      GuideBlock.table(
        GuideTable(
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
        ),
      ),
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
      GuideBlock.table(
        GuideTable(
          headZh: <String>['金组 · 名次', '自选箱', '固定箱', '紫票', '代币'],
          headEn: <String>[
            'Gold · Rank',
            'Choice',
            'Fixed',
            'Tickets',
            'Tokens',
          ],
          rowsZh: _settleGold,
          rowsEn: _settleGold,
        ),
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['银组 · 名次', '自选箱', '固定箱', '紫票', '代币'],
          headEn: <String>[
            'Silver · Rank',
            'Choice',
            'Fixed',
            'Tickets',
            'Tokens',
          ],
          rowsZh: _settleSilver,
          rowsEn: _settleSilver,
        ),
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['铜组 · 名次', '自选箱', '固定箱', '紫票', '代币'],
          headEn: <String>[
            'Bronze · Rank',
            'Choice',
            'Fixed',
            'Tickets',
            'Tokens',
          ],
          rowsZh: _settleBronze,
          rowsEn: _settleBronze,
        ),
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['木组 · 名次', '自选箱', '固定箱', '紫票', '代币'],
          headEn: <String>[
            'Wood · Rank',
            'Choice',
            'Fixed',
            'Tickets',
            'Tokens',
          ],
          rowsZh: _settleWood,
          rowsEn: _settleWood,
        ),
      ),
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
      GuideBlock.table(
        GuideTable(
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
            <String>[
              'Wood',
              'Promoted to Bronze',
              'No demotion (lowest league)',
            ],
          ],
        ),
      ),
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
      GuideBlock.table(
        GuideTable(
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
        ),
      ),
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
      GuideBlock.table(
        GuideTable(
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
        ),
      ),
      // ---------- 3. 整车 HP/ATK ----------
      GuideBlock.heading(
        '一辆车的 HP / ATK 怎么算',
        'How the car\'s HP / ATK are computed',
      ),
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
      GuideBlock.table(
        GuideTable(
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
            <String>[
              'Base',
              'The part\'s HP / ATK at its current level (see the previous section)',
            ],
            <String>[
              'Category',
              'Sum of the percentages whose "bonus type" equals that part\'s category '
                  '(one sum each for body / weapon / wheel / gadget; it is the bonus a part gives, not the part\'s own category)',
            ],
            <String>[
              'Extra',
              'Per-part independent multiplier, 0-150% in steps of 10% (chosen per part in the Build Tool)',
            ],
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
        ),
      ),
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
      GuideBlock.heading(
        '在组车工具里怎么看这些数',
        'Reading these numbers in the Build Tool',
      ),
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

  // ==================== 废铁行动 ====================
  GuideChapter(
    id: 'scrap',
    titleZh: '废铁行动',
    titleEn: 'Scrap Action',
    summaryZh: '与锦标赛绑定：刷锦标赛对手抢螺栓，节点奖励表附 100 个节点',
    summaryEn:
        'A championship-linked event: farm bolts off your opponents; includes the full 100-node reward table',
    icon: Icons.handyman,
    color: Colors.brown,
    keywords: <String>[
      '废铁行动',
      '废铁',
      '螺栓',
      '螺栓收集器',
      '螺栓箱子',
      '节点',
      '锦标赛',
      '对手',
      '广告',
      '加速',
      '冷却',
      '种类',
      '氪金',
      '活动代币',
      '锦标赛箱子',
      '终极部件箱',
      '自选箱',
      '固定箱',
      '二选一',
      'R4 工具箱',
      '钻石',
      '紫票',
      'scrap',
      'bolt',
      'collector',
      'championship',
      'node',
      'milestone',
      'event token',
      'box',
      'toolbox',
      'ad',
    ],
    blocks: <GuideBlock>[
      GuideBlock.text(
        '废铁行动是**与锦标赛绑定**的活动：每 10 分钟刷新 1 个**螺栓**，它会落到某个锦标赛对手身上；'
            '你**只有击败持有螺栓的对手**才能把螺栓拿到手。螺栓累计成节点进度，攒到节点数就能领该节点的奖励。',
        'Scrap Action is tied to the **championship**: a **bolt** spawns every 10 minutes and lands on one of your '
            'championship opponents. You only get it by **defeating the opponent holding it**; bolts accumulate into node '
            'progress, and reaching a node lets you claim its reward.',
      ),

      // ---------- 1. 螺栓怎么来 ----------
      GuideBlock.heading('核心玩法：螺栓怎么来', 'Core loop: where bolts come from'),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '螺栓每 **10 分钟**刷新 1 个，会随机落到一个**当前身上没有螺栓**的锦标赛对手身上',
          'One bolt spawns every **10 minutes** and lands on a random championship opponent that **has no bolt right now**',
        ),
        GuideBullet(
          '**击败持有螺栓的对手**，螺栓才归你 —— 它会算进你的节点进度',
          '**Defeat the opponent holding the bolt** to take it - it counts towards your node progress',
        ),
        GuideBullet(
          '如果所有锦标赛对手身上都已经有螺栓了，新刷新的螺栓会先进**螺栓收集器**',
          'If every championship opponent already holds a bolt, the new bolt goes into the **bolt collector** first',
        ),
        GuideBullet(
          '**获得螺栓只有三种途径**：击败持有螺栓的锦标赛对手、看广告、氪金',
          'There are only **three ways** to obtain bolts: defeating a bolt-holding championship opponent, watching an ad, or topping up',
        ),
        GuideBullet(
          '刷新速度：每小时 6 个、一天最多 144 个（但能不能变成进度，还看有没有对手「接住」和有没有提取）',
          'Refresh rate: 6 per hour, at most 144 a day - but whether they turn into progress depends on something catching them and on extracting',
        ),
      ]),

      // ---------- 2. 收集器与箱子 ----------
      GuideBlock.heading('螺栓收集器 与 螺栓箱子', 'Bolt collector & bolt box'),
      GuideBlock.text(
        '螺栓收集器里的螺栓**不会自动算进度**，要先「提取」出来才能用：',
        'Bolts in the collector **do not count automatically** - they must be extracted first:',
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '螺栓收集器**最多存 30 个螺栓**',
          'The bolt collector holds **at most 30 bolts**',
        ),
        GuideBullet(
          '**看广告或氪金**，把螺栓收集器里的螺栓提取到**螺栓箱子**',
          '**Watch an ad or top up** to move bolts from the collector into the **bolt box**',
        ),
        GuideBullet(
          '螺栓箱子里的螺栓会**自动补充到没有螺栓的对手**身上，回到「可以被刷取」的状态',
          'Bolts in the box are **automatically placed onto opponents that have no bolt**, so they can be farmed again',
        ),
        GuideBullet(
          '整条链路是一个循环：刷新 → 落到对手 → 击败夺取 → 都满了就进收集器 → 广告 / 氪金提取到箱子 → 自动补回空对手',
          'The whole thing loops: spawn → land on an opponent → defeat it to take the bolt → collector once everyone holds one → extract by ad / top-up into the box → auto-placed back onto empty opponents',
        ),
      ]),
      GuideBlock.tip(
        '对手身上都刷满之后，光等刷新是拿不到螺栓的 —— 只能靠**看广告**或**氪金**提取。',
        'Once every opponent holds a bolt, waiting earns you nothing - the only ways forward are **ads** and **top-ups**.',
      ),

      // ---------- 3. 看广告 ----------
      GuideBlock.heading(
        '看广告的两种用法（都有 7 小时 50 分冷却）',
        'Two ways to spend an ad (both on a 7h 50m cooldown)',
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '**加速刷新**：看广告后获得 **2 分钟**加速，期间螺栓刷新速度是平时的 **15 倍**（约 40 秒 1 个）',
          '**Refresh boost**: an ad gives you **2 minutes** at **15x** the normal bolt refresh rate (about one bolt every 40 seconds)',
        ),
        GuideBullet(
          '**从收集器提取**：在螺栓收集器看广告，直接掉出 **3 个螺栓** 到**螺栓箱子**',
          '**Extract from the collector**: watching an ad in the bolt collector drops **3 bolts** straight into the **bolt box**',
        ),
        GuideBullet(
          '两种广告都是 **废铁行动专属** 的，而且**相互独立**：用完一个不影响另一个',
          'Both ads are **exclusive to Scrap Action** and **independent** - using one does not affect the other',
        ),
        GuideBullet(
          '每种广告看完后都要等 **7 小时 50 分** 才会再刷新出来',
          'Each ad needs a **7 hour 50 minute** wait before it appears again',
        ),
        GuideBullet(
          '氪金是另一条路（不用等广告冷却），同样把螺栓提到螺栓箱子',
          'Topping up is the other route (no ad cooldown) and also moves bolts into the bolt box',
        ),
      ]),
      GuideBlock.tip(
        '2 分钟 × 15 倍 ≈ 多刷出 3 个螺栓，和收集器广告给的 3 个差不多 —— '
            '两种广告挑一种用就行，但都要等 7 小时 50 分才能再用。',
        'Two minutes at 15x spawns about 3 extra bolts - roughly what the collector ad hands you. '
            'Pick either one, but both need a 7h 50m wait before they come back.',
      ),

      // ---------- 4. 两种「代币」----------
      GuideBlock.heading('「活动代币」和「代币」是两种东西', 'Event tokens are not tokens'),
      GuideBlock.text(
        '奖励表里出现的**活动代币**与**代币**是两种**不同**的货币，不要混为一谈：',
        'The **event tokens** and **tokens** in the reward table are two **different** currencies - do not mix them up:',
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '**活动代币**：本活动专属，奖励表里写作「活动代币 ×N」',
          '**Event tokens**: exclusive to this event, written as "Event tokens ×N"',
        ),
        GuideBullet(
          '**代币**：游戏里的常规代币，奖励表里写作「代币 ×N」',
          '**Tokens**: the regular in-game token, written as "Tokens ×N"',
        ),
      ]),
      GuideBlock.tip(
        '看奖励表时先看单位：写「活动代币」的才是本活动货币，写「代币」的是常规代币。',
        'Read the unit first: "event tokens" is this event\'s currency, "tokens" is the regular one.',
      ),

      // ---------- 5. 节点表 ----------
      GuideBlock.heading('节点与奖励一览', 'Node rewards'),
      GuideBlock.text(
        '螺栓数 → 奖励（共 100 个节点）：',
        'Bolts to reward (100 nodes in total):',
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '奖励里的 **R6 部件 k1 / k2 / …** 中的 **k 表示「种类」**：'
              '不同的 k 是**不同种类**的 R6 部件，相同的 k 就是**同一种**',
          'In **R6 part k1 / k2 / …** the **k is the kind**: different k means a different kind of R6 part, '
              'the same k means the same kind',
        ),
        GuideBullet(
          '例：`R6 部件 k1 ×2` = 第 1 种 R6 部件 2 个；`R6 部件 k10 ×5` = 第 10 种 5 个',
          'For example: `R6 part k1 x2` = 2 pieces of the 1st kind; `R6 part k10 x5` = 5 pieces of the 10th kind',
        ),
        GuideBullet(
          '这些箱子就是本指南里说的**终极部件箱**：分「**自选箱**（每项弹两个选项二选一）」'
              '与「**固定箱**（内容固定）」两种；本活动给的都是**自选箱**',
          'These are the **ultimate part boxes** described in this guide: a **choice box** '
              '(each item offers two options) or a **fixed box** (fixed contents); this event always gives the choice kind',
        ),
      ]),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['螺栓', '奖励'],
          headEn: <String>['Bolts', 'Reward'],
          rowsZh: _scrapNodesZh,
          rowsEn: _scrapNodesEn,
        ),
      ),
      GuideBlock.tip(
        '拿满全部节点的奖励总量：终极部件箱（R4-R5）×10、'
            '终极部件箱（R6）×7、锦标赛箱子 ×14、'
            'R4 工具箱 ×5、钻石 ×100、'
            '紫票 ×1100000、代币 ×150、活动代币 ×2750，'
            '以及 R6 部件 k1-k14 各若干（k = 种类，共 14 种）。',
        'Total rewards from every node: ultimate part boxes (R4-R5) x10, '
            'ultimate part boxes (R6) x7, championship boxes x14, R4 toolboxes x5, diamonds x100, '
            'purple tickets x1100000, tokens x150, event tokens x2750, '
            'plus several pieces of each of the 14 kinds of R6 parts.',
      ),
    ],
  ),

  // ==================== 待补充（先占目录位，内容后续补充） ====================
  GuideChapter(
    id: 'championship_car',
    titleZh: '锦标赛战车',
    titleEn: 'Championship Car',
    summaryZh:
        '锦标赛战车：25 档与等级上限、每级加成，车身 / 武器 / 车轮 / 配件四条同形的计算式'
        '（基础值 × 技能 × 倍数 + 等级项），以及升级与融合的经验、花费与售价',
    summaryEn:
        'The Championship car: the 25 tiers and level caps, the per-level bonuses, four formulas of the same '
        'shape for body / weapon / wheel / gadget (base value x skill x multiplier + the level term), plus the XP, '
        'cost and sale price of upgrading and fusing',
    icon: Icons.directions_car,
    color: Colors.teal,
    keywords: <String>[
      '锦标赛战车',
      '锦标赛',
      '战车',
      '车身',
      '武器',
      'ATK',
      '车轮',
      '配件',
      '随从',
      '治疗量',
      '每级加成',
      '电量',
      '电力',
      '配电',
      '供电',
      '耗电',
      '车身种类',
      '数值组合',
      '基础值',
      '附加技能',
      '基础每级加成',
      '最终每级加成',
      'HP/ATK 倍数',
      '治疗量系数',
      '基础 ATK',
      '基础车轮 HP',
      '基础配件 HP',
      '碰车',
      '撞车',
      '系数',
      'k 值',
      '类别',
      '原档',
      '大档',
      '电锯',
      '电钻',
      '激光',
      '火箭',
      '双管火箭',
      '长钉',
      '圆锯',
      '急救套件',
      '升降机',
      '叉车',
      '护盾',
      '镇静剂之枪',
      '反弹器',
      '古怪手套',
      '推进器',
      '反推器',
      '渔网',
      '渔叉',
      '深度冻结',
      '挂点',
      '插槽',
      '融合',
      '回收',
      '经验',
      '融合花费',
      '出售',
      '出售价',
      '价值',
      '部件价值',
      '金币',
      '阶梯',
      '专业交易商',
      '专业机械师',
      '商人',
      '固有价值',
      '综合价值',
      '经验价值',
      '金币价值',
      '融合获得经验',
      '魔法部件',
      '传奇部件',
      '技能',
      '段位',
      '威名',
      '经典',
      '泰坦',
      '浪板',
      '滑头',
      '磐石',
      '金字塔',
      '巨鲸',
      '钻石',
      '铁砧',
      '箭',
      '特殊车身',
      '档',
      '档位',
      '星级',
      '星',
      '木质',
      '金属',
      '军用',
      '黄金',
      '碳钢',
      '等级上限',
      'championship car',
      'body',
      'weapon',
      'wheel',
      'gadget',
      'power',
      'star',
      'tier',
      'wood',
      'metal',
      'military',
      'gold',
      'carbon',
      'classic',
      'titan',
      'surfer',
      'sneaky',
      'boulder',
      'whale',
      'pyramid',
      'diamond',
      'scorpion',
      'arrow',
      'vector',
      'orca',
      'paladin',
      'coefficient',
      'formula',
      'base value',
      'per-level bonus',
      'base per-level bonus',
      'final per-level bonus',
      'skill bonus',
      'HP/ATK multiplier',
      'wheel size',
      'category',
      'blades',
      'saw',
      'chainsaw',
      'drill',
      'laser',
      'rocket',
      'double rocket',
      'stinger',
      'gadget hp',
      'fusion',
      'prestige',
      'stage',
    ],
    blocks: <GuideBlock>[
      GuideBlock.text(
        '锦标赛战车由 **1 个车身** 与若干 **武器 / 车轮 / 配件** 组成。部件按**材质**分五个系列：'
            '**木质、金属、军用、黄金、碳钢** —— 这里的材质指部件本身的材质，例如「1 星金属车身」'
            '指的就是金属材质的 1 星车身。车身提供供电，并决定整车的基础 HP 与插槽。',
        'A Championship car consists of **one body** plus a number of **weapons / wheels / gadgets**. Parts come in '
            'five material series: **Wood, Metal, Military, Gold and Carbon** — the material of the part itself, e.g. a '
            '"1-star metal body". The body supplies power and decides the car\'s base HP and slots.',
      ),
      // ---------- 1. 电力规则 ----------
      GuideBlock.heading('电力规则', 'Power rules'),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '**车身提供供电**（正电力）；**武器、车轮、配件消耗电力**（负电力）',
          'The **body supplies power** (positive); **weapons, wheels and gadgets drain it** (negative)',
        ),
        GuideBullet(
          '整车的供电不得低于总耗电，否则该车无法使用',
          'The car\'s total supply must not be below its total drain, otherwise the car cannot be used',
        ),
      ]),
      // ---------- 2. 25 档与等级上限 ----------
      GuideBlock.heading('25 档与等级上限', 'The 25 tiers and the level cap'),
      GuideBlock.text(
        '部件的档次由**材质**与**星级**决定：每种材质各分 1-5 星，5 种材质共 25 档（木质最靠前，碳钢最靠后）。'
            '**最高等级只由星级决定：最高等级 ＝ 5 × 星级 ＋ 1**，与材质无关。',
        'A part\'s tier comes from its **material** and its **star**: each material has 1-5 stars, so the five '
            'materials give 25 tiers (wood first, carbon last). The **max level depends on the star only: '
            'max level = 5 x star + 1**, whatever the material.',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['档位', '部件材质', '星级', '最高等级'],
          headEn: <String>['Tier', 'Material', 'Star', 'Max level'],
          rowsZh: _champTierRowsZh,
          rowsEn: _champTierRowsEn,
        ),
      ),
      GuideBlock.tip(
        '例如第 6 档（1 星金属）的最高等级同样只有 6 级 —— 等级上限按**星级**计算，与**档位**无关。',
        'For example tier 6 (1-star metal) also caps at level 6 — the cap follows the **star**, not the tier.',
      ),
      // ---------- 3. 每级加成 ----------
      GuideBlock.heading('每级加成', 'Per-level bonuses'),
      GuideBlock.text(
        '**基础每级加成**是配置里的原始值，按材质取值；乘上该部位的**加成系数**就是**最终每级加成**。',
        'The **base per-level bonus** is the raw value from the config, by material; multiplied by that stat\'s '
            '**coefficient** it gives the **final per-level bonus**.',
      ),
      GuideBlock.text(
        '**基础每级加成**（原始值）：',
        '**Base per-level bonus** (raw value):',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['数值', '加成系数', '木质', '金属', '军用', '黄金', '碳钢'],
          headEn: <String>[
            'Value',
            'Coefficient',
            'Wood',
            'Metal',
            'Military',
            'Gold',
            'Carbon',
          ],
          rowsZh: <List<String>>[
            <String>['车身 HP', '× 0.6', '6', '30', '150', '750', '3000'],
            <String>['武器 ATK', '× 0.4', '4', '20', '100', '500', '2000'],
            <String>['车轮 HP', '× 1', '2', '10', '50', '250', '1000'],
            <String>['车轮碾压 ATK', '× 0.4', '2', '10', '50', '250', '1000'],
            <String>['配件 HP', '× 1', '2', '10', '50', '250', '1000'],
            <String>['治疗量', '× 2', '3', '15', '75', '375', '1500'],
            <String>['随从（无人机）', '× 1', '38', '165', '833', '3960', '16898'],
          ],
          rowsEn: <List<String>>[
            <String>['Body HP', 'x 0.6', '6', '30', '150', '750', '3000'],
            <String>['Weapon ATK', 'x 0.4', '4', '20', '100', '500', '2000'],
            <String>['Wheel HP', 'x 1', '2', '10', '50', '250', '1000'],
            <String>[
              'Wheel crushing ATK',
              'x 0.4',
              '2',
              '10',
              '50',
              '250',
              '1000',
            ],
            <String>['Gadget HP', 'x 1', '2', '10', '50', '250', '1000'],
            <String>['Heal amount', 'x 2', '3', '15', '75', '375', '1500'],
            <String>[
              'Minion (drone)',
              'x 1',
              '38',
              '165',
              '833',
              '3960',
              '16898',
            ],
          ],
        ),
      ),
      GuideBlock.text(
        '**最终每级加成 ＝ 基础每级加成 × 加成系数**：',
        '**Final per-level bonus = base per-level bonus x coefficient**:',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['数值', '木质', '金属', '军用', '黄金', '碳钢'],
          headEn: <String>[
            'Value',
            'Wood',
            'Metal',
            'Military',
            'Gold',
            'Carbon',
          ],
          rowsZh: <List<String>>[
            <String>['车身 HP', '3.6', '18', '90', '450', '1800'],
            <String>['武器 ATK', '1.6', '8', '40', '200', '800'],
            <String>['车轮 HP', '2', '10', '50', '250', '1000'],
            <String>['车轮碾压 ATK', '0.8', '4', '20', '100', '400'],
            <String>['配件 HP', '2', '10', '50', '250', '1000'],
            <String>['治疗量', '6', '30', '150', '750', '3000'],
            <String>['随从（无人机）', '38', '165', '833', '3960', '16898'],
          ],
          rowsEn: <List<String>>[
            <String>['Body HP', '3.6', '18', '90', '450', '1800'],
            <String>['Weapon ATK', '1.6', '8', '40', '200', '800'],
            <String>['Wheel HP', '2', '10', '50', '250', '1000'],
            <String>['Wheel crushing ATK', '0.8', '4', '20', '100', '400'],
            <String>['Gadget HP', '2', '10', '50', '250', '1000'],
            <String>['Heal amount', '6', '30', '150', '750', '3000'],
            <String>['Minion (drone)', '38', '165', '833', '3960', '16898'],
          ],
        ),
      ),
      GuideBlock.tip(
        '车身 ×0.6（金属 30 → 每级 **+18 HP**）、武器 ×0.4（金属 20 → 每级 **+8 ATK**）、'
            '车轮 HP ×1、车轮碾压 ATK ×0.4（军用 → 每级 **+50 HP / +20 ATK**）、'
            '治疗量 ×2（金属 15 → 每级 **+30**）、配件 HP ×1（金属 10 → 每级 **+10 HP**）。'
            '随从（无人机）也是 ×1（军用 833 → 每级 **+833 HP**），而且随从 HP **不吃任何加成**。',
        'Bodies x0.6 (metal 30 -> **+18 HP** per level), weapons x0.4 (metal 20 -> **+8 ATK**), wheel HP x1 and wheel '
            'crushing ATK x0.4 (military -> **+50 HP / +20 ATK** per level), heal x2 (metal 15 -> **+30**), gadget HP x1 '
            '(metal 10 -> **+10 HP**). Minions (drones) are x1 too (military 833 -> **+833 HP** per level), and a '
            'minion\'s HP **gets no bonus at all**.',
      ),
      // ---------- 4. 车身：基础值与 HP 计算 ----------
      GuideBlock.heading(
        '车身：基础值与 HP 计算',
        'Body: base values and the HP formula',
      ),
      GuideBlock.text(
        '车身彼此只差两点：**HP/ATK 倍数**与**车身技能**。HP/ATK 倍数**只作用在 HP 上**，不影响供电。'
            '下表已收录 **13 种**车身：前 8 种是**常见车身**（有专属技能），后 5 种是**特殊车身**（无专属技能）；'
            '另有一些特殊车身尚未收录。后三列是乘上 **HP 技能**（1 / 2 / 3 级）后的**附加技能计算值**。',
        'Bodies differ in two things only: the **HP/ATK multiplier** and the **body skill**. The multiplier **affects HP '
            'only**, never the supply. The table covers **13 bodies**: the first 8 are the **common bodies** (each with '
            'its own skills) and the last 5 are **special bodies** (no skills). The last three columns are the '
            '**effective multiplier** once the point bonus (HP skill level 1 / 2 / 3) is applied.',
      ),
      GuideBlock.table(
        GuideTable(
          groupZh: <String>['', '', '附加技能的计算值', '', '', '', ''],
          groupEn: <String>[
            '',
            '',
            'with the skill bonus applied',
            '',
            '',
            '',
            '',
          ],
          headZh: <String>[
            '车身',
            'HP/ATK 倍数',
            '+10%（技能 1 级）',
            '+20%（技能 2 级）',
            '+30%（技能 3 级）',
            '电力技能',
            'HP 技能',
          ],
          headEn: <String>[
            'Body',
            'HP/ATK multiplier',
            '+10% (skill 1)',
            '+20% (skill 2)',
            '+30% (skill 3)',
            'Power skill',
            'HP skill',
          ],
          rowsZh: <List<String>>[
            <String>[
              '经典',
              '1.0000',
              '1.1000',
              '1.2000',
              '1.3000',
              '+ 3',
              '+ 30%',
            ],
            <String>[
              '滑头',
              '1.3333',
              '1.4667',
              '1.6000',
              '1.7333',
              '+ 3',
              '+ 30%',
            ],
            <String>[
              '磐石',
              '1.6667',
              '1.8333',
              '2.0000',
              '2.1667',
              '+ 3',
              '+ 30%',
            ],
            <String>[
              '巨鲸',
              '1.6667',
              '1.8333',
              '2.0000',
              '2.1667',
              '—',
              '+ 30%',
            ],
            <String>[
              '金字塔',
              '1.6667',
              '1.8333',
              '2.0000',
              '2.1667',
              '—',
              '+ 30%',
            ],
            <String>[
              '浪板',
              '1.8333',
              '2.0167',
              '2.2000',
              '2.3833',
              '+ 3',
              '+ 30%',
            ],
            <String>[
              '泰坦',
              '2.0000',
              '2.2000',
              '2.4000',
              '2.6000',
              '+ 3',
              '+ 30%',
            ],
            <String>['钻石', '2.0000', '—', '—', '—', '—', '无'],
            <String>['蝎', '2.0000', '—', '—', '—', '—', '无'],
            <String>['箭', '2.0000', '—', '—', '—', '—', '无'],
            <String>['向量', '2.1667', '—', '—', '—', '—', '无'],
            <String>['虎鲸', '2.1667', '—', '—', '—', '—', '无'],
            <String>['圣骑士', '2.3333', '—', '—', '—', '—', '无'],
          ],
          rowsEn: <List<String>>[
            <String>[
              'Classic',
              '1.0000',
              '1.1000',
              '1.2000',
              '1.3000',
              '+ 3',
              '+ 30%',
            ],
            <String>[
              'Sneaky',
              '1.3333',
              '1.4667',
              '1.6000',
              '1.7333',
              '+ 3',
              '+ 30%',
            ],
            <String>[
              'Boulder',
              '1.6667',
              '1.8333',
              '2.0000',
              '2.1667',
              '+ 3',
              '+ 30%',
            ],
            <String>[
              'Whale',
              '1.6667',
              '1.8333',
              '2.0000',
              '2.1667',
              '—',
              '+ 30%',
            ],
            <String>[
              'Pyramid',
              '1.6667',
              '1.8333',
              '2.0000',
              '2.1667',
              '—',
              '+ 30%',
            ],
            <String>[
              'Surfer',
              '1.8333',
              '2.0167',
              '2.2000',
              '2.3833',
              '+ 3',
              '+ 30%',
            ],
            <String>[
              'Titan',
              '2.0000',
              '2.2000',
              '2.4000',
              '2.6000',
              '+ 3',
              '+ 30%',
            ],
            <String>['Diamond', '2.0000', '—', '—', '—', '—', 'none'],
            <String>['Scorpion', '2.0000', '—', '—', '—', '—', 'none'],
            <String>['Arrow', '2.0000', '—', '—', '—', '—', 'none'],
            <String>['Vector', '2.1667', '—', '—', '—', '—', 'none'],
            <String>['Orca', '2.1667', '—', '—', '—', '—', 'none'],
            <String>['Paladin', '2.3333', '—', '—', '—', '—', 'none'],
          ],
        ),
      ),
      GuideBlock.tip(
        '表中技能数值均为满级（电力技能 +3、HP 技能 +30%）；未学习时按 0 计算。解锁条件见第 9 节。'
            'HP/ATK 倍数由「基础 HP × 0.6 × 倍数 ＝ 1 级显示 HP」反推（特殊车身那个等式里不带 HP 技能）。'
            '第 8 节里的融合花费与出售价也都按技能满级算。',
        'Both skill columns are maxed values (power +3, HP +30%); treat them as 0 when not learned. See section 9 '
            'for the unlock requirements. The HP/ATK multiplier was derived from "base HP x 0.6 x multiplier = '
            'displayed HP at level 1" (for special bodies that equation has no HP skill in it). The fusion cost and '
            'sale price in section 8 also assume the skills are maxed.',
      ),
      GuideBlock.text(
        '**供电与基础 HP**：同一档位的车身有 **3 种数值组合**，游戏只会把其中**任意一种**分给具体车身'
            '（同一档位的各种车身共用这 3 种组合，每个车身拿到哪一种由游戏随机决定）。'
            '**组合 1 = HP 最高、供电最低，组合 3 = HP 最低、供电最高**。'
            '表中每格为「**基础 HP / 供电**」，基础 HP 就是车身 HP 算式里的「基础 HP」（算法见本节末尾）。',
        '**Supply and base HP**: bodies of the same tier come in **3 stat combinations**, and a body only ever gets '
            '**one of them** (the bodies of a tier share these 3 combinations, and which one a given body gets is '
            'decided at random). **Combination 1 has the most HP and the least supply; combination 3 the least HP and '
            'the most supply.** Each cell reads "**base HP / supply**"; base HP is the "base HP" of the body HP '
            'formula (computed at the end of this section).',
      ),
      GuideBlock.table(
        GuideTable(
          groupZh: <String>['', '', '基础 HP / 供电', '', ''],
          groupEn: <String>['', '', 'Base HP / supply', '', ''],
          headZh: <String>['档位', '部件材质 / 星级', '组合 1', '组合 2', '组合 3'],
          headEn: <String>[
            'Tier',
            'Material / star',
            'Combo 1',
            'Combo 2',
            'Combo 3',
          ],
          rowsZh: _champSupplyRowsZh,
          rowsEn: _champSupplyRowsEn,
        ),
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '**供电**只随**星级与组合**变化：木质低于其余四种材质，'
              '**金属 / 军用 / 黄金 / 碳钢 的供电完全相同**（同星级同组合）',
          'The **supply** varies with the **star and the combination** only: wood is lower than the other four '
              'materials, and **Metal / Military / Gold / Carbon have exactly the same supply** (same star, same combination)',
        ),
        GuideBullet(
          '**基础 HP** 随**档位（材质 × 星级）**变化：五种材质的基础 HP 各不相同，越高档越大',
          'The **base HP** varies with the **tier (material x star)**: the five materials all differ, and higher '
              'tiers are larger',
        ),
        GuideBullet(
          '两种数值都与**具体是哪种车身无关** —— 同一档位的所有车身共用同一套数值',
          'Neither value depends on **which body it is** — all bodies of a tier share the same set of numbers',
        ),
        GuideBullet(
          '**电力技能**满级再 +3：经典、泰坦、浪板、滑头、磐石有；'
              '巨鲸、金字塔、钻石与特殊车身（蝎、箭、向量、虎鲸、圣骑士）都没有',
          'The **power skill** adds a further +3 at max: Classic, Titan, Surfer, Sneaky and Boulder have it; '
              'Whale, Pyramid, Diamond and the special bodies (Scorpion, Arrow, Vector, Orca, Paladin) do not',
        ),
      ]),
      GuideBlock.text(
        '**车身 HP 的算式**（与下面三个部件同形：基础值 × 技能 × 倍数，再加等级项）：',
        '**The body HP formula** (same shape as the three parts below: base value x skill x multiplier, plus the level '
            'term):',
      ),
      GuideBlock.text(
        '**车身 HP ＝ 向上取整（基础 HP × 0.6 ×（1 ＋ HP 技能加成）× HP/ATK 倍数）'
            '＋ 最终每级加成 ×（等级 － 1）**',
        '**Body HP = round-up( base HP x 0.6 x (1 + HP skill) x HP/ATK multiplier ) '
            '+ final per-level bonus x (level - 1)**',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['公式中的项', '取值'],
          headEn: <String>['Term', 'Value'],
          rowsZh: <List<String>>[
            <String>['基础 HP', '上表「基础 HP / 供电」中「/」前面的数（例：金属 4 星、组合 2 ＝ 645）'],
            <String>[
              'HP 技能加成',
              'HP 技能 1 / 2 / 3 级＝ +10% / +20% / +30%；未学习 0（乘上去后的值已在上表后三列）',
            ],
            <String>[
              'HP/ATK 倍数',
              '上表车身表：经典 1.0000、滑头 1.3333、磐石 / 巨鲸 / 金字塔 1.6667、浪板 1.8333、'
                  '泰坦 / 钻石 / 蝎 / 箭 2.0000、向量 / 虎鲸 2.1667、圣骑士 2.3333',
            ],
            <String>[
              '最终每级加成',
              '第 3 节「最终每级加成」表「车身 HP」一行（已乘 ×0.6）＝ 木质 3.6 / 金属 18 / 军用 90 / 黄金 450 / 碳钢 1800',
            ],
            <String>['等级', '当前等级；1 级时公式第二项为 0'],
          ],
          rowsEn: <List<String>>[
            <String>[
              'Base HP',
              'The number before the "/" in the table above (e.g. metal 4-star, combo 2 = 645)',
            ],
            <String>[
              'HP skill',
              'HP skill level 1 / 2 / 3 = +10% / +20% / +30%; 0 if not learned',
            ],
            <String>[
              'HP/ATK multiplier',
              'From the body table above: Classic 1.0000, Sneaky 1.3333, Boulder / Whale / Pyramid 1.6667, '
                  'Surfer 1.8333, Titan / Diamond / Scorpion / Arrow 2.0000, Vector / Orca 2.1667, Paladin 2.3333',
            ],
            <String>[
              'Final per-level bonus',
              'The "Body HP" row of the final per-level bonus table in section 3 (0.6 already applied) = wood 3.6 / '
                  'metal 18 / military 90 / gold 450 / carbon 1800',
            ],
            <String>['Level', 'Current level; the second term is 0 at level 1'],
          ],
        ),
      ),
      GuideBlock.tip(
        '例：金属 4 星、组合 2、经典（倍数 1.0000）、HP 技能 3 级（+30%）、1 级 → '
            '向上取整(645 × 0.6 × 1.3 × 1.0000) ＝ **504 HP**；升到 4 级再加 3 × 18 ＝ 54，即 558 HP。'
            '也可以直接查上表：经典 +30% 一列就是 **1.3000**。',
        'Example: metal 4-star, combo 2, Classic (multiplier 1.0000), HP skill level 3 (+30%), level 1 → '
            'round-up(645 x 0.6 x 1.3 x 1.0000) = **504 HP**; at level 4 add 3 x 18 = 54, giving 558 HP. Or just read the '
            'table: the +30% column of Classic is **1.3000**.',
      ),
      GuideBlock.tip(
        '**升级只增加 HP，供电不变**；等级上限见第 2 节。',
        '**Leveling only adds HP — the supply never changes** (confirmed in game); see section 2 for the level cap.',
      ),
      // ---------- 5. 武器：耗电、ATK 与计算 ----------
      GuideBlock.heading(
        '武器：耗电、ATK 与计算',
        'Weapons: drain, ATK and the ATK formula',
      ),
      GuideBlock.text(
        '武器分 **7 个类别**：**圆锯 / 电锯 / 电钻 / 激光 / 火箭 / 双管火箭 / 长钉**，'
            '攻击方式分**近战 / 远程**（各有独立技能线）。同一档位有 3 种数值组合，'
            '表中每格为「**耗电 / 基础 ATK / 随从 HP**」；'
            '**一件武器的耗电决定它用哪一列**（耗电越高、基础 ATK 越高，但**随从 HP 反而越低**）。'
            '耗电只由**星级**决定（同一星级的所有材质相同）。',
        'Weapons come in **7 categories** — saws / chainsaws / drills / lasers / rockets / double rockets / '
            'stingers — and attack either **melee** or **ranged** (each has its own skill line). Every tier has 3 '
            'combinations, written "**drain / base ATK / minion HP**"; **a weapon\'s drain decides which column it '
            'uses** (the higher the drain, the higher the base ATK — but the **lower the minion HP**). The drain '
            'depends on the **star** only (all materials of the same star share it).',
      ),
      GuideBlock.text(
        '武器也有一张「**HP/ATK 倍数表**」：每件武器自带一个固定的 HP/ATK 倍数（与段位、材质、星级、列都无关）；'
            '带 +30% 的那 7 件武器还有附加技能后的计算值。',
        'Weapons also have an "**HP/ATK multiplier table**": each weapon carries a fixed HP/ATK multiplier '
            '(independent of '
            'tier, material, star and column), and the 7 weapons with a +30% bonus also show the value with the skill '
            'applied.',
      ),
      GuideBlock.table(
        GuideTable(
          groupZh: <String>['', '', '附加技能的计算值', '', '', ''],
          groupEn: <String>['', '', 'with the skill bonus applied', '', '', ''],
          headZh: <String>[
            '武器',
            'HP/ATK 倍数',
            '+10%（技能 1 级）',
            '+20%（技能 2 级）',
            '+30%（技能 3 级）',
            'ATK 技能',
          ],
          headEn: <String>[
            'Weapon',
            'HP/ATK multiplier',
            '+10% (skill 1)',
            '+20% (skill 2)',
            '+30% (skill 3)',
            'ATK skill',
          ],
          rowsZh: <List<String>>[
            <String>['圆锯', '0.3300', '0.3630', '0.3960', '0.4290', '+ 30%'],
            <String>['双头圆锯', '0.6600', '—', '—', '—', '无'],
            <String>['火箭', '0.3500', '0.3850', '0.4200', '0.4550', '+ 30%'],
            <String>['双管火箭', '0.3500', '0.3850', '0.4200', '0.4550', '+ 30%'],
            <String>['旋转火箭', '0.3500', '—', '—', '—', '无'],
            <String>['激光', '0.4000', '0.4400', '0.4800', '0.5200', '+ 30%'],
            <String>['死亡射灯', '0.4000', '—', '—', '—', '无'],
            <String>['回旋镖', '0.4000', '—', '—', '—', '无'],
            <String>['长钉', '0.6150', '0.6765', '0.7380', '0.7995', '+ 30%'],
            <String>['猎枪', '0.7000', '—', '—', '—', '无'],
            <String>['燃烧瓶', '0.7500', '—', '—', '—', '无'],
            <String>['电钻', '0.8550', '0.9405', '1.0260', '1.1115', '+ 30%'],
            <String>['旋转电钻', '0.8550', '—', '—', '—', '无'],
            <String>['电锯', '1.0000', '1.1000', '1.2000', '1.3000', '+ 30%'],
            <String>['急射小机枪', '1.0000', '—', '—', '—', '无'],
            <String>['土豆大炮', '1.0000', '—', '—', '—', '无'],
            <String>['旋转电锯', '1.2000', '—', '—', '—', '无'],
            <String>['直升无人机', '0.6400', '—', '—', '—', '无'],
            <String>['直升无人机（随从）', '1.0000', '—', '—', '—', '无'],
          ],
          rowsEn: <List<String>>[
            <String>['Saw', '0.3300', '0.3630', '0.3960', '0.4290', '+ 30%'],
            <String>['Double saw', '0.6600', '—', '—', '—', 'none'],
            <String>['Rocket', '0.3500', '0.3850', '0.4200', '0.4550', '+ 30%'],
            <String>[
              'Double rocket',
              '0.3500',
              '0.3850',
              '0.4200',
              '0.4550',
              '+ 30%',
            ],
            <String>['Tilted rocket', '0.3500', '—', '—', '—', 'none'],
            <String>['Laser', '0.4000', '0.4400', '0.4800', '0.5200', '+ 30%'],
            <String>['Death ray', '0.4000', '—', '—', '—', 'none'],
            <String>['Boomerang', '0.4000', '—', '—', '—', 'none'],
            <String>[
              'Stinger',
              '0.6150',
              '0.6765',
              '0.7380',
              '0.7995',
              '+ 30%',
            ],
            <String>['Shotgun', '0.7000', '—', '—', '—', 'none'],
            <String>['Molotov', '0.7500', '—', '—', '—', 'none'],
            <String>['Drill', '0.8550', '0.9405', '1.0260', '1.1115', '+ 30%'],
            <String>['Tilted drill', '0.8550', '—', '—', '—', 'none'],
            <String>[
              'Chainsaw',
              '1.0000',
              '1.1000',
              '1.2000',
              '1.3000',
              '+ 30%',
            ],
            <String>['Rapid gun', '1.0000', '—', '—', '—', 'none'],
            <String>['Potato cannon', '1.0000', '—', '—', '—', 'none'],
            <String>['Tilted chainsaw', '1.2000', '—', '—', '—', 'none'],
            <String>['Copter Drone', '0.6400', '—', '—', '—', 'none'],
            <String>['Copter Drone (minion)', '1.0000', '—', '—', '—', 'none'],
          ],
        ),
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '**「ATK 技能」一列标出能吃到 +30% 的武器**：只有 7 件（圆锯 / 火箭 / 双管火箭 / 激光 / 长钉 / 电钻 / '
              '电锯），也只有它们有后面三列数据；其余武器这三列留「—」',
          'The **"ATK skill" column marks the weapons that can reach +30%**: only 7 (saw / rocket / double rocket / '
              'laser / stinger / drill / chainsaw), and only they have data in the last three columns; the others show '
              '"—"',
        ),
        GuideBullet(
          '**同族武器共用同一个 HP/ATK 倍数**：火箭 / 双管火箭 / 旋转火箭 都是 0.3500，激光 / 死亡射灯 / 回旋镖 都是 0.4000，'
              '电钻 / 旋转电钻 都是 0.8550，电锯 / 急射小机枪 / 土豆大炮 都是 1.0000',
          '**Weapons of the same family share one HP/ATK multiplier**: rocket / double rocket / tilted rocket = 0.3500, '
              'laser / death ray / boomerang = 0.4000, drill / tilted drill = 0.8550, chainsaw / rapid gun / potato '
              'cannon = 1.0000',
        ),
        GuideBullet(
          '**双刃武器 = 单刃 × 2**：双头圆锯的 0.6600 正好是圆锯 0.3300 的 2 倍',
          '**A double-blade weapon = the single one x 2**: the double saw\'s 0.6600 is exactly twice the saw\'s '
              '0.3300',
        ),
        GuideBullet(
          'HP/ATK 倍数的来源未知 —— 配置里没有这张表（与车身的 HP/ATK 倍数一样，写在游戏代码里），只能逐件实测',
          'Where the HP/ATK multiplier comes from is unknown — the config has no such table (like the body\'s one, it '
              'lives in the game code), so it has to be measured per weapon',
        ),
        GuideBullet(
          '**随从武器（无人机）**：分两行 —— 武器本体（直升无人机）**0.6400**，'
              '它的**随从（无人机）是 1.0000**，也就是随从 HP 直接取表值、**不乘任何倍数、不吃任何加成**'
              '（12 段电力 7 → 表值 690，显示 690）',
          '**Minion weapons (drones)** take two rows: the weapon itself (Copter Drone) = **0.6400**, and its '
              '**minion = 1.0000**, i.e. the minion HP is taken straight from the table — **no multiplier, no bonus '
              'at all** (tier 12 / drain 7 -> table 690, shown 690)',
        ),
      ]),
      GuideBlock.table(
        GuideTable(
          groupZh: <String>['', '', '耗电 / 基础 ATK / 随从 HP', '', ''],
          groupEn: <String>['', '', 'Drain / base ATK / minion HP', '', ''],
          headZh: <String>['档位', '部件材质 / 星级', '组合 1', '组合 2', '组合 3'],
          headEn: <String>[
            'Tier',
            'Material / star',
            'Combo 1',
            'Combo 2',
            'Combo 3',
          ],
          rowsZh: _champWeaponRowsZh,
          rowsEn: _champWeaponRowsEn,
        ),
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '换成更高材质时 **ATK 的涨幅远远大于耗电**：碳钢 5 星武器的 ATK 是木质 1 星的 2000 多倍，'
              '而耗电只从 4-6 涨到 8-10',
          'Going up a material, **ATK grows far faster than drain**: a carbon 5-star weapon has 2000+ times the ATK '
              'of a wood 1-star one, while the drain only moves from 4-6 to 8-10',
        ),
        GuideBullet(
          '同一档位的 3 列还有一条撞车规律：**小档（某档）＝ 大档（上一档）** —— '
              '报数据时必须写清「材质 + 星级」，否则跨档比较一定会撞车',
          'The 3 columns of a tier also collide across tiers: **the small column of one tier equals the large column '
              'of the previous tier** — always quote "material + star" when comparing, or the values will clash',
        ),
        GuideBullet(
          '同一星级、同一耗电下，不同武器的 ATK 也不同（每件武器还有一个自己的 **HP/ATK 倍数**，见本节开头的表）',
          'Even at the same star and drain, different weapons differ in ATK — each weapon also has its own '
              '**HP/ATK multiplier** (see the table at the start of this section)',
        ),
      ]),
      GuideBlock.text(
        '**武器 ATK 的算式**（与车身同形：基础值 × 倍数 ×（1 ＋ 技能），再加等级项）：',
        '**The weapon ATK formula** (same shape as the body: base value x multiplier x (1 + skill), plus the level '
            'term):',
      ),
      GuideBlock.text(
        '**武器 ATK ＝ 向上取整（基础 ATK × HP/ATK 倍数 ×（1 ＋ 武器伤害技能加成））'
            '＋ 最终每级加成 ×（等级 － 1）**',
        '**Weapon ATK = round-up( base ATK x HP/ATK multiplier x (1 + weapon damage skill) ) '
            '+ final per-level bonus x (level - 1)**',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['公式中的项', '取值'],
          headEn: <String>['Term', 'Value'],
          rowsZh: <List<String>>[
            <String>[
              '基础 ATK',
              '上表「耗电 / 基础 ATK / 随从 HP」中第一个「/」后面的数；用哪一列由该武器的**耗电**决定'
                  '（1★ ＝ 4 / 5 / 6、2★ ＝ 5 / 6 / 7 … 5★ ＝ 8 / 9 / 10，第几个就用第几列）',
            ],
            <String>[
              '武器伤害技能加成',
              '第 9 节的类别技能（1 / 2 / 3 级 ＝ +10% / +20% / +30%）；未学习 0（位置按同构推测）',
            ],
            <String>[
              'HP/ATK 倍数',
              '每件武器自带（与段位、材质、星级、列都无关）= 0.4 × 刻度 ÷ 8，见下表；'
                  '同一族的武器共用同一个倍数',
            ],
            <String>[
              '最终每级加成',
              '第 3 节「最终每级加成」表「武器 ATK」一行（已乘 ×0.4）＝ 木质 1.6 / 金属 8 / 军用 40 / 黄金 200 / 碳钢 800',
            ],
            <String>['等级', '当前等级；1 级时公式第二项为 0'],
          ],
          rowsEn: <List<String>>[
            <String>[
              'Base ATK',
              'The number after the first "/" in the table above; the column is set by the weapon\'s **drain** '
                  '(1★ = 4 / 5 / 6, 2★ = 5 / 6 / 7 … 5★ = 8 / 9 / 10 — take the matching column)',
            ],
            <String>[
              'Weapon damage skill',
              'The category skill of section 9 (levels 1 / 2 / 3 = +10% / +20% / +30%); 0 if not learned (position '
                  'assumed by symmetry)',
            ],
            <String>[
              'HP/ATK multiplier',
              'Carried by each weapon (independent of tier, material, star and column) = 0.4 x tick / 8 — see below; '
                  'weapons of the same family share the same multiplier',
            ],
            <String>[
              'Final per-level bonus',
              'The "Weapon ATK" row of the final per-level bonus table in section 3 (0.4 already applied) = wood 1.6 / '
                  'metal 8 / military 40 / gold 200 / carbon 800',
            ],
            <String>['Level', 'Current level; the second term is 0 at level 1'],
          ],
        ),
      ),
      // ---------- 6. 车轮：HP、碾压 ATK 与计算 ----------
      GuideBlock.heading(
        '车轮：HP、碾压 ATK 与计算',
        'Wheels: HP, crushing ATK and the formulas',
      ),
      GuideBlock.text(
        '车轮提供 HP（治疗类配件的治疗量见第 7 节）。车轮的档位就是它的**尺寸档**（**小 / 中 / 大**）；'
            '**原档为「小」的轮子可以读到「小 / 中 / 大」，原档为「中」的可以读到「中 / 大」，'
            '原档为「大」的只有「大」**，所以判断时看实例的读数、不看名字。',
        'Wheels give HP (the heal amount of healing gadgets is in section 7). A wheel\'s tier is simply its **size '
            'class** (**small / medium / large**); **a wheel whose own class is "small" can read small / medium / '
            'large, one whose own class is "medium" reads medium / large, and a "large" one reads large only** — '
            'judge by the reading, not by the name.',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['车轮', '原档', '可能读到的档', 'HP 技能'],
          headEn: <String>[
            'Wheel',
            'Own class',
            'Possible classes',
            'HP skill',
          ],
          rowsZh: <List<String>>[
            <String>['旋钮轮', '小', '小 / 中 / 大', '+ 45%'],
            <String>['滚轮', '小', '小 / 中 / 大', '+ 45%'],
            <String>['黏地轮 · 滚轮', '小', '小 / 中 / 大', '+ 45%'],
            <String>['爬坡轮胎', '小', '小 / 中 / 大', '无'],
            <String>['滑板轮', '中', '中 / 大', '+ 45%'],
            <String>['轱辘轮', '中', '中 / 大', '+ 45%'],
            <String>['黏地轮 · 轱辘轮', '中', '中 / 大', '+ 45%'],
            <String>['悬浮轮胎', '中', '中 / 大', '无'],
            <String>['反重力滑板轮', '中', '中 / 大', '无'],
            <String>['大脚轮', '大', '只有大', '+ 45%'],
          ],
          rowsEn: <List<String>>[
            <String>['Knob wheel', 'small', 'small / medium / large', '+ 45%'],
            <String>['Roller', 'small', 'small / medium / large', '+ 45%'],
            <String>[
              'Sticky roller',
              'small',
              'small / medium / large',
              '+ 45%',
            ],
            <String>['Climbing big', 'small', 'small / medium / large', 'none'],
            <String>['Skateboard wheel', 'medium', 'medium / large', '+ 45%'],
            <String>['Cart wheel', 'medium', 'medium / large', '+ 45%'],
            <String>['Sticky cart wheel', 'medium', 'medium / large', '+ 45%'],
            <String>['Hover tire', 'medium', 'medium / large', 'none'],
            <String>[
              'Anti-gravity skateboard wheel',
              'medium',
              'medium / large',
              'none',
            ],
            <String>['Bigfoot', 'large', 'large only', '+ 45%'],
          ],
        ),
      ),
      GuideBlock.text(
        '**「HP 技能」一列**标明该车轮能不能点到 +45%：属于 7 个可点技能车轮族的车轮都能点满；'
            '爬坡轮胎 / 悬浮轮胎 / 反重力滑板轮不属于任何可点技能的车轮族，倍数永远只有 ×1.00（填「无」）。',
        'The **"HP skill" column** marks whether the wheel can reach +45%: the wheels of the 7 tunable families can, '
            'while the climbing big / hover tire / anti-gravity skateboard wheel belong to no such family and stay at '
            'x1.00 ("none").',
      ),
      GuideBlock.text(
        '**基础值表**（基础车轮 HP 的 3 个数值 ＝ 小 / 中 / 大）：',
        '**Base values** (the 3 base wheel HP values = small / medium / large):',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['档位', '部件材质 / 星级', '基础车轮 HP（3 种数值）'],
          headEn: <String>[
            'Tier',
            'Material / star',
            'Base wheel HP (3 values)',
          ],
          rowsZh: _champWheelRowsZh,
          rowsEn: _champWheelRowsEn,
        ),
      ),
      GuideBlock.text(
        '**车轮 HP 的算式**（与车身同形：基础值 ×（1 ＋ 技能），再加等级项）：',
        '**The wheel HP formula** (same shape as the body: base value x (1 + skill), plus the level term):',
      ),
      GuideBlock.text(
        '**车轮 HP ＝ 向上取整（基础车轮 HP ×（1 ＋ 车轮类别 HP 技能加成））'
            '＋ 最终每级加成 ×（等级 － 1）**',
        '**Wheel HP = round-up( base wheel HP x (1 + wheel family HP skill) ) '
            '+ final per-level bonus x (level - 1)**',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['公式中的项', '取值'],
          headEn: <String>['Term', 'Value'],
          rowsZh: <List<String>>[
            <String>['基础车轮 HP', '上表「基础车轮 HP」一列（3 个数值：小 / 中 / 大）'],
            <String>[
              '车轮类别 HP 技能加成',
              '第 9 节里按车轮类别点到：+15% / +30% / +45%；本节最上面的车轮表「HP 技能」一列标出哪些车轮能点到 +45%',
            ],
            <String>[
              '最终每级加成',
              '第 3 节「最终每级加成」表「车轮 HP」一行（系数 ×1）＝ 木质 2 / 金属 10 / 军用 50 / 黄金 250 / 碳钢 1000',
            ],
            <String>['等级', '当前等级；1 级时公式第二项为 0'],
          ],
          rowsEn: <List<String>>[
            <String>[
              'Base wheel HP',
              'The "base wheel HP" column above (3 values: small / medium / large)',
            ],
            <String>[
              'Wheel family HP skill',
              'Points spent on that family in section 9: +15% / +30% / +45%; the "HP skill" column of the wheel '
                  'table above marks which wheels can reach +45%',
            ],
            <String>[
              'Final per-level bonus',
              'The "Wheel HP" row of the final per-level bonus table in section 3 (x1) = wood 2 / metal 10 / military '
                  '50 / gold 250 / carbon 1000',
            ],
            <String>['Level', 'Current level; the second term is 0 at level 1'],
          ],
        ),
      ),
      GuideBlock.tip(
        '与车身不同，车轮**不乘 0.6**：1 级读数就等于基础车轮 HP ×（1 ＋ 技能）。',
        'Unlike bodies, wheels **are not multiplied by 0.6**: the level-1 reading is just base wheel HP x (1 + skill).',
      ),
      GuideBlock.text(
        '**车轮的碾压 ATK**（轮子撞人时造成的伤害）用**同一档、同一尺寸列**的基础值算，系数固定 0.4，'
            '与 HP 的算式同形：',
        '**A wheel\'s crushing ATK** (the damage it deals when ramming) uses the base value of the **same tier and the '
            'same size column**, with a fixed 0.4 factor — the same shape as the HP formula:',
      ),
      GuideBlock.text(
        '**车轮碾压 ATK ＝ 向上取整（基础车轮 HP × 0.4）＋ 最终每级加成 ×（等级 － 1）**'
            '（第一项也等于同一格的「基础武器伤害」÷ 5；列同样是小 / 中 / 大）',
        '**Wheel crushing ATK = round-up( base wheel HP x 0.4 ) + final per-level bonus x (level - 1)** '
            '(the first term also equals the "base weapon damage" of the same cell / 5; the column is small / medium / '
            'large as well)',
      ),
      GuideBlock.tip(
        '例：金 3 档（段 18，基础车轮 HP 2920 / 3408 / 3895）1 级碾压 ATK = **1169 / 1364 / 1559**（实测）；'
            '每级加成见第 3 节「车轮碾压 ATK」一行（木质 0.8 / 金属 4 / 军用 **20** / 黄金 100 / 碳钢 400）——'
            '也就是 11–15 段每升 1 级 **ATK +20**（同段车轮 HP 每级 **+50**）。'
            '碾压 ATK 与 HP 一样有「撞车规律」（段 18 小 = 段 17 大 = 1169），且**不吃车轮类别 HP 技能**；'
            '与武器一样有「恰好整数时 +1」的现象（0.4 的 float32 表示略大于 0.4）。',
        'Example: tier 18 (base wheel HP 2920 / 3408 / 3895) reads crushing ATK **1169 / 1364 / 1559** at level 1 '
            '(measured); its per-level bonus is the new "wheel crushing ATK" row of section 3 (wood 0.8 / metal 4 / '
            'military **20** / gold 100 / carbon 400) — i.e. **+20 ATK** per level in tiers 11-15 (with **+50 HP** for '
            'the wheel itself). The crushing ATK follows the same collision rule as HP (tier 18 small = tier 17 large = '
            '1169), **ignores the wheel family HP skill**, and shows the "exactly integral -> +1" effect like weapons.',
      ),
      GuideBlock.tip(
        '车轮的**中档值是每个档位唯一的**（不会与相邻档撞车），拿来对照最安全；'
            '小档与大档则容易撞车（小档 ＝ 上一档的大档）；碾压 ATK 也有同样的撞车规律。',
        'The **medium value is unique within its tier** (it never collides with a neighbouring tier), so it is the '
            'safest one to compare with; the small and large values do collide (small of one tier = large of the '
            'previous one), and the crushing ATK follows the same collision rule.',
      ),
      // ---------- 7. 配件：数值档、耗电与 HP 计算 ----------
      GuideBlock.heading(
        '配件：数值档、耗电与 HP 计算',
        'Gadgets: value classes, drain and the HP formula',
      ),
      GuideBlock.text(
        '配件共 **12 种**，但**数值只有 3 个组**（**低组 / 中组 / 高组**，即车轮表里的小 / 中 / 大）—— '
            '同一组的所有配件数值完全相同，配件种类只决定它落在哪一组。**渔网与渔叉数值完全一样**（共用同一组）。',
        'There are **12 gadgets**, but only **3 groups** (**low / mid / high**, the small / medium / large of the '
            'wheel tables): every gadget of a group has identical stats, and the gadget type only decides which group '
            'it falls into. **The fishnet and the harpoon have exactly the same values** (they share a group).',
      ),
      GuideBlock.table(
        GuideTable(
          groupZh: <String>['', '组合 1', '', '组合 2', '', '', '', ''],
          groupEn: <String>['', 'Combo 1', '', 'Combo 2', '', '', '', ''],
          headZh: <String>[
            '配件',
            '耗电组',
            '基础HP组',
            '耗电组',
            '基础HP组',
            'HP 技能',
            '技能',
            '解锁条件',
          ],
          headEn: <String>[
            'Gadget',
            'Drain group',
            'Base HP group',
            'Drain group',
            'Base HP group',
            'HP skill',
            'Skill',
            'Unlocks at',
          ],
          rowsZh: <List<String>>[
            <String>['急救套件', '高组', '低组', '低组', '高组', '无', '无', '—'],
            <String>['深度冻结', '高组', '低组', '低组', '高组', '无', '无', '—'],
            <String>['升降机', '高组', '低组', '低组', '高组', '无', '无', '—'],
            <String>['叉车', '高组', '低组', '低组', '高组', '+ 45%', '调整铲斗', '段位 6'],
            <String>['护盾', '低组', '低组', '—', '—', '无', '无', '—'],
            <String>['镇静剂之枪', '低组', '低组', '—', '—', '无', '无', '—'],
            <String>['反弹器', '低组', '中组', '—', '—', '+ 45%', '调整反弹器', '段位 18'],
            <String>['古怪手套', '低组', '中组', '—', '—', '无', '无', '—'],
            <String>['推进器', '低组', '高组', '—', '—', '+ 45%', '调整推进器', '段位 0'],
            <String>['反推器', '低组', '高组', '—', '—', '+ 45%', '调整反推器', '段位 21'],
            <String>['渔网', '低组', '高组', '—', '—', '无', '无', '—'],
            <String>['渔叉', '低组', '高组', '—', '—', '无', '无', '—'],
          ],
          rowsEn: <List<String>>[
            <String>[
              'First-aid kit',
              'High group',
              'Low group',
              'Low group',
              'High group',
              'none',
              'none',
              '—',
            ],
            <String>[
              'Deep freeze',
              'High group',
              'Low group',
              'Low group',
              'High group',
              'none',
              'none',
              '—',
            ],
            <String>[
              'Lift',
              'High group',
              'Low group',
              'Low group',
              'High group',
              'none',
              'none',
              '—',
            ],
            <String>[
              'Forklift',
              'High group',
              'Low group',
              'Low group',
              'High group',
              '+ 45%',
              'Tweaked Forklifts',
              'Stage 6',
            ],
            <String>[
              'Shield',
              'Low group',
              'Low group',
              '—',
              '—',
              'none',
              'none',
              '—',
            ],
            <String>[
              'Tranquilizer gun',
              'Low group',
              'Low group',
              '—',
              '—',
              'none',
              'none',
              '—',
            ],
            <String>[
              'Bouncer',
              'Low group',
              'Mid group',
              '—',
              '—',
              '+ 45%',
              'Tweaked Repulses',
              'Stage 18',
            ],
            <String>[
              'Odd glove',
              'Low group',
              'Mid group',
              '—',
              '—',
              'none',
              'none',
              '—',
            ],
            <String>[
              'Thruster',
              'Low group',
              'High group',
              '—',
              '—',
              '+ 45%',
              'Tweaked Boosters',
              'Stage 0',
            ],
            <String>[
              'Repulser',
              'Low group',
              'High group',
              '—',
              '—',
              '+ 45%',
              'Tweaked Backpedals',
              'Stage 21',
            ],
            <String>[
              'Fishnet',
              'Low group',
              'High group',
              '—',
              '—',
              'none',
              'none',
              '—',
            ],
            <String>[
              'Harpoon',
              'Low group',
              'High group',
              '—',
              '—',
              'none',
              'none',
              '—',
            ],
          ],
        ),
      ),
      GuideBlock.text(
        '**组合 1 是标配**；只有「**高组耗电 ＋ 低组 HP**」的那 4 种（急救套件 / 深度冻结 / 升降机 / 叉车）'
            '还有**组合 2**（低组耗电 ＋ 高组 HP），其余配件只有组合 1，组合 2 的两列填「—」。'
            '**「HP 技能」一列**标明该配件能不能点到 +45%，**「技能」与「解锁条件」两列**给出对应的类别技能与解锁段位：'
            '只有叉车（调整铲斗 · 段位 6）· 反弹器（调整反弹器 · 段位 18）· 推进器（调整推进器 · 段位 0）· '
            '反推器（调整反推器 · 段位 21）这 4 种有这条技能线，其余 8 种没有（读数就是基础配件 HP）。',
        '**Combo 1 is the standard form**; only the 4 gadgets with a **high drain plus a low base HP** (first-aid kit '
            '/ deep freeze / lift / forklift) also come as **combo 2** (low drain plus high base HP); the other 8 only '
            'exist as combo 1, with "—" in the two combo 2 columns. The **"HP skill" column** marks whether the '
            'gadget can reach +45%, and the **"Skill" / "Unlocks at" columns** give the matching category skill and '
            'stage: only the forklift (Tweaked Forklifts, stage 6), bouncer (Tweaked Repulses, stage 18), thruster '
            '(Tweaked Boosters, stage 0) and repulser (Tweaked Backpedals, stage 21) have such a skill line — the '
            'other 8 gadgets have none (their reading is just the base gadget HP).',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['星级', '低组耗电', '高组耗电'],
          headEn: <String>['Star', 'Low group drain', 'High group drain'],
          rowsZh: <List<String>>[
            <String>['1 - 2 星', '1', '2'],
            <String>['3 - 5 星', '2', '3'],
          ],
          rowsEn: <List<String>>[
            <String>['1 - 2 stars', '1', '2'],
            <String>['3 - 5 stars', '2', '3'],
          ],
        ),
      ),
      GuideBlock.text(
        '**基础值表**：配件 HP 用的就是**同段同档的基础配件 HP**（下表第一列 ＝ 第 6 节车轮表的「基础车轮 HP」那一列，配件与同档车轮同值）；'
            '治疗类配件的**治疗量**也在同一张表里（最后一列）：',
        '**Base values**: gadget HP uses the **base gadget HP of the same tier** (the first column below is the "base '
            'wheel HP" column of the section-6 wheel table — a gadget has the same value as that tier\'s wheel); the '
            '**heal amount** of healing gadgets is in the same table (last column):',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['档位', '部件材质 / 星级', '基础配件 HP（3 种数值）', '基础治疗量'],
          headEn: <String>[
            'Tier',
            'Material / star',
            'Base gadget HP (3 values)',
            'Base heal',
          ],
          rowsZh: _champWheelBaseRowsZh,
          rowsEn: _champWheelBaseRowsEn,
        ),
      ),
      GuideBlock.text(
        '**配件 HP 的算式**（与车轮同形，只是技能换成「配件 HP 加成」）：',
        '**The gadget HP formula** (same shape as the wheel, with the "gadget HP bonus" skill instead; the base value '
            'is the **base gadget HP** of the same tier):',
      ),
      GuideBlock.text(
        '**配件 HP ＝ 向上取整（基础配件 HP ×（1 ＋ 配件 HP 加成））'
            '＋ 最终每级加成 ×（等级 － 1）**',
        '**Gadget HP = round-up( base gadget HP x (1 + gadget HP bonus) ) '
            '+ final per-level bonus x (level - 1)**',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['公式中的项', '取值'],
          headEn: <String>['Term', 'Value'],
          rowsZh: <List<String>>[
            <String>[
              '基础配件 HP',
              '上表「基础配件 HP」一列（＝ 同段同档车轮的数值）；3 个数值 ＝ 低组 / 中组 / 高组',
            ],
            <String>[
              '配件 HP 加成',
              '第 9 节里按配件类别点到：+15% / +30% / +45%（与车轮同形，实测点满 +45%）；未解锁 0；'
                  '上表「HP 技能 / 技能 / 解锁条件」三列标出哪些配件能点到 +45%',
            ],
            <String>[
              '最终每级加成',
              '第 3 节「最终每级加成」表「配件 HP」一行（系数 ×1）＝ 木质 2 / 金属 10 / 军用 50 / 黄金 250 / 碳钢 1000',
            ],
            <String>['等级', '当前等级；1 级时公式第二项为 0'],
          ],
          rowsEn: <List<String>>[
            <String>[
              'Base gadget HP',
              'The "base gadget HP" column above (= the value of that tier\'s wheel); 3 values = low / mid / high group',
            ],
            <String>[
              'Gadget HP bonus',
              'Points spent on that gadget category in section 9: +15% / +30% / +45% (+45% when maxed, the same shape '
                  'as the wheels); 0 if not unlocked; the "HP skill / Skill / Unlocks at" columns above mark which '
                  'gadgets can reach +45%',
            ],
            <String>[
              'Final per-level bonus',
              'The "Gadget HP" row of the final per-level bonus table in section 3 (x1) = wood 2 / metal 10 / military '
                  '50 / gold 250 / carbon 1000',
            ],
            <String>['Level', 'Current level; the second term is 0 at level 1'],
          ],
        ),
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '**配件 HP 加成**来自配件类别的点数技能（**与车轮同形**：调整推进器 / 调整铲斗 / 调整反弹器 / 调整反推器，'
              '各 +15% / +30% / +45%，1 / 2 / 3 点解锁）：未解锁时读数就等于车轮 HP，点满 +45% 后 × 1.45'
              '（例：2085 × 1.45 ＝ 3024）',
          'The **gadget HP bonus** comes from the gadget category skills (**the same shape as the wheels**: Tweaked '
              'Boosters / Tweaked Forklifts / Tweaked Repulses / Tweaked Backpedals, each +15% / +30% / +45%, costing '
              '1 / 2 / 3 points): without it the reading equals the wheel HP, and at +45% it is x1.45 (e.g. 2085 x '
              '1.45 = 3024)',
        ),
        GuideBullet(
          '治疗类配件（急救套件 / 升降机）的**治疗量**也用同一张基础值表（最后一列），公式见下方',
          'The **heal amount** of healing gadgets (autoheal / lift) uses that same base value table (last column); see '
              'its formula below',
        ),
        GuideBullet(
          '**配件 HP 与同段同档的车轮 HP 逐值相等**，配件种类只决定它落在哪一档',
          'A **gadget\'s HP equals the wheel HP of the same tier** value by value; the gadget type only decides which '
              'class it falls into',
        ),
      ]),
      GuideBlock.text(
        '**治疗量（治疗类配件）的算式**用**该配件所在组**的基础配件 HP（不是表里那列参考值）：',
        '**The heal-amount formula** (healing gadgets) uses the **base gadget HP of that gadget\'s own group** (not the '
            'reference column of the table):',
      ),
      GuideBlock.text(
        '**治疗量 ＝ 向上取整（3 × 基础配件 HP（该组）×（1 ＋ 配件技能加成））'
            '＋ 最终每级加成 ×（等级 － 1）**',
        '**Heal amount = round-up( 3 x base gadget HP (that group) x (1 + gadget skill) ) '
            '+ final per-level bonus x (level - 1)**',
      ),
      GuideBlock.tip(
        '实测：铁 2 星急救套件（低组，基础配件 HP **95**）→ 1 级 **285**（＝ 3 × 95）、3 级 **345**（每级 **+30** ＝ 2 × 15）。'
            '表里「基础治疗量」那列是配置里的**中组**参考值（≈ 1.5 × 中组车轮 HP，逐档 ±1），直接 ×2 会偏大'
            '（段 7 会得 346，实测是 285）；「最终每级加成」见第 3 节「治疗量」一行 ＝ 木 6 / 金 30 / 军 150 / 黄 750 / 碳 3000。'
            '只有**急救套件与升降机**是治疗类配件。',
        'Measured: metal 2-star autoheal (low group, base gadget HP **95**) -> level 1 **285** (= 3 x 95), level 3 '
            '**345** (**+30** per level = 2 x 15). The "base heal" column of the table is the config\'s **medium-group** '
            'reference (≈ 1.5 x medium wheel HP, ±1 per tier) and doubling it overshoots (tier 7 would give 346, while '
            'the reading is 285). The per-level bonus is the "heal amount" row of section 3 = wood 6 / metal 30 / '
            'military 150 / gold 750 / carbon 3000. Only the **autoheal and the lift** are healing gadgets.',
      ),
      // ---------- 8. 工具箱 ----------
      GuideBlock.heading('工具箱：加成与数值', 'Toolboxes: bonuses and values'),
      GuideBlock.text(
        '**工具箱不是融合材料，而是「融进部件」的加成道具**：游戏内明确提示「工具箱不能融合任何部件」，'
            '方向刚好相反——把工具箱拖到部件上，它的加成会**永久加到那个部件上**，而且可以叠多个。'
            '工具箱同样有 **25 档**（与部件共用「材料 + 星级」那套档位）。',
        '**A toolbox is not fusion material but a booster that is fused *into* a part**: the game says "you can\'t '
            'fuse anything onto toolboxes" — it works the other way round. Drag a toolbox onto a part and its bonus '
            'is **permanently added to that part**, and several of them can stack. Toolboxes also come in the same '
            '**25 tiers** (material + star) as parts.',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['工具箱', '只能融合到', '提供的属性'],
          headEn: <String>[
            'Toolbox',
            'Can only be fused into',
            'Stat it grants',
          ],
          rowsZh: <List<String>>[
            <String>['生命值工具箱', '车身 / 车轮 / 配件', '生命值（绝对值）'],
            <String>['攻击力工具箱', '武器', '攻击力（绝对值）'],
            <String>['电力工具箱', '车身', '电力 +1'],
            <String>['魔法工具箱', '任何车身', '魔法加成 +10%（有上限）'],
            <String>['终极工具箱', '终极部件', '生命值 / 攻击 / 强酸伤害 / 干扰 / 额外武器栏位（限时，可堆叠）'],
          ],
          rowsEn: <List<String>>[
            <String>[
              'Health toolbox',
              'body / wheel / gadget',
              'health (flat)',
            ],
            <String>['Attack toolbox', 'weapon', 'attack (flat)'],
            <String>['Power toolbox', 'body', 'power +1'],
            <String>['Magic toolbox', 'any body', 'magic bonus +10% (capped)'],
            <String>[
              'Ultimate toolbox',
              'ultimate parts',
              'health / attack / acid damage / jamming / an extra weapon slot (timed, stackable)',
            ],
          ],
        ),
      ),
      GuideBlock.text(
        '**加成 ＝ 向下取整（表中数值 ×（1 ＋ 加强工具箱技能））**。技能「加强工具箱」有生命值 / 攻击力 / 电力三条：'
            '前两条各 +15% / +30% / +45%（段位 6 / 段位 9 解锁，各 1 / 2 / 3 点），电力那条是威名 4 解锁、'
            '花 4 点换 **+1 电力**。',
        '**Bonus = round-down( table value x (1 + the Better Toolboxes skill) )**. That skill comes in health / attack '
            '/ power versions: the first two give +15% / +30% / +45% (unlocked at stage 6 / stage 9, costing 1 / 2 / 3 '
            'points) and the power one is unlocked at prestige 4, costing 4 points for **+1 power**.',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>[
            '档位',
            '部件材质 / 星级',
            '融合基础花费',
            '出售价',
            '生命值工具箱 +HP',
            '攻击力工具箱 +ATK',
          ],
          headEn: <String>[
            'Tier',
            'Material / star',
            'Base fuse cost',
            'Sell price',
            'Health toolbox +HP',
            'Attack toolbox +ATK',
          ],
          rowsZh: _champToolboxRowsZh,
          rowsEn: _champToolboxRowsEn,
        ),
      ),
      GuideBlock.tip(
        '两条容易踩的规则：① 工具箱**不能用于下注**；② 魔法工具箱给 +10% 魔法加成且**有上限**，到顶后不能再融。'
            '工具箱自身的**融合花费与回收**规则在下一节「融合」里。',
        'Two rules worth remembering: (1) toolboxes **cannot be used for betting**; (2) the magic toolbox gives +10% '
            'magic bonus and is **capped**, so you cannot keep fusing once it is maxed. The toolbox\'s own **fuse cost '
            'and refund** rules are in the next section ("Fusion").',
      ),
      // ---------- 9. 升级与融合 ----------
      GuideBlock.heading('融合：经验、花费与出售', 'Fusion: XP, cost and selling'),
      GuideBlock.text(
        '升级通过**融合**完成：把其他部件融合进目标部件以换取经验。**不要求材质相同**，'
            '但不同材质之间有一个固定的兑换比例，跨材质融合的收益差别很大。',
        'Upgrading is done by **fusion**: other parts are fused into the target part for XP. '
            '**The materials do not have to match**, but different materials have a fixed exchange rate, so the '
            'result varies a lot.',
      ),
      GuideBlock.tip(
        '**融合经验不计工具箱**：工具箱既不给经验、也不出现在任何经验算式里；'
            '带工具箱的部件**照样可以当材料融合**，但工具箱**不继承**——加成随部件一起消失，不返还、不转移。'
            '（工具箱自己的花费与回收规则见本节末尾。）',
        '**Fusion XP never counts toolboxes**: a toolbox gives no XP and appears in no XP formula. A part that carries '
            'toolboxes **can still be used as material**, but the toolboxes are **not inherited** — their bonuses '
            'vanish with the part, with no refund and no transfer. (The toolbox\'s own cost and refund rules are at '
            'the end of this section.)',
      ),
      GuideBlock.text(
        '**融合的本质，就是把材料换算成一个价值加到目标身上。**部件身上可以区分出**三个价值**，'
            '它们的两个输入都是**固有价值**与 **Σ 融合获得经验**：',
        '**Fusion boils down to converting the material into a value and adding it to the target.** A part carries '
            '**three values**, and all of them are built from the same two inputs, the **intrinsic value** and the '
            '**XP already invested**:',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['价值', '定义', '用在哪里'],
          headEn: <String>['Value', 'Definition', 'Used for'],
          rowsZh: <List<String>>[
            <String>[
              '**部件综合价值**',
              '固有价值 ＋ Σ 融合获得经验',
              '部件在经验阶梯上的坐标；**融合会直接把它抬高，抬上去就固定**；等级、进度与金币价值都看它',
            ],
            <String>[
              '**部件经验价值**',
              '固有价值 ＋ 0.7 × Σ 融合获得经验',
              '它当材料被融合时贡献多少经验的基础值（历次经验只按 70% 计入）',
            ],
            <String>['**部件金币价值**', '把部件综合价值当坐标去查金币阶梯（本节后面讲）', '融合花费、出售价'],
          ],
          rowsEn: <List<String>>[
            <String>[
              '**Composite value**',
              'intrinsic value + Σ XP gained',
              'the part\'s coordinate on the XP ladder; **fusing raises it directly, and once raised it is fixed**; '
                  'it drives the level, the progress bar and the coin value',
            ],
            <String>[
              '**XP value**',
              'intrinsic value + 0.7 x Σ XP gained',
              'the base for the XP it contributes as a material (past XP only counts at 70%)',
            ],
            <String>[
              '**Coin value**',
              'the coin ladder read at the composite value (covered later in this section)',
              'fusion cost, sale price',
            ],
          ],
        ),
      ),
      GuideBlock.text(
        '**固有价值表**（绝对经验点；按部件的**材料 × 星级**取值。'
            '**1 星一行就是各材质的 k**，所以不用再单独乘 k）：',
        '**Intrinsic value table** (absolute XP, by the part\'s **material x star**. The **1-star row is itself the k '
            'of each material**, so there is no separate k to multiply):',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['星级', '木质', '金属', '军用', '黄金', '碳钢'],
          headEn: <String>[
            'Star',
            'Wood',
            'Metal',
            'Military',
            'Gold',
            'Carbon',
          ],
          rowsZh: <List<String>>[
            <String>['1 星', '1', '13', '144', '1597', '17711'],
            <String>['2 星', '2', '21', '233', '2584', '28657'],
            <String>['3 星', '3', '34', '377', '4181', '46368'],
            <String>['4 星', '5', '55', '610', '6765', '75025'],
            <String>['5 星', '8', '89', '987', '10946', '121393'],
          ],
          rowsEn: <List<String>>[
            <String>['1 star', '1', '13', '144', '1597', '17711'],
            <String>['2 stars', '2', '21', '233', '2584', '28657'],
            <String>['3 stars', '3', '34', '377', '4181', '46368'],
            <String>['4 stars', '5', '55', '610', '6765', '75025'],
            <String>['5 stars', '8', '89', '987', '10946', '121393'],
          ],
        ),
      ),
      GuideBlock.text(
        '**三个公式其实是一套。**记 **Σ 融合获得经验** 为「历次喂进这个部件的经验之和」'
            '（也就是它的**已投入经验**），那么：',
        '**The three formulas are really one set.** Write **Σ XP gained** for "the XP that every part ever fused '
            'into it contributed" (that is, its **XP already invested**); then:',
      ),
      GuideBlock.text(
        '**部件综合价值 ＝ 固有价值 ＋ Σ 融合获得经验**　　（等级、进度与金币价值看它）',
        '**Composite value = intrinsic value + Σ XP gained**　　(drives the level, the progress bar and the coin '
            'value)',
      ),
      GuideBlock.text(
        '**部件经验价值 ＝ 固有价值 ＋ 0.7 × Σ 融合获得经验**　　（它当材料时贡献多少经验看它）',
        '**XP value = intrinsic value + 0.7 x Σ XP gained**　　(drives how much XP it contributes as a material)',
      ),
      GuideBlock.text(
        '**融合获得经验 ＝ 向上取整（（1 ＋ 本次融合时的融合经验技能加成）× C（品质系数）×'
            '被融合部件的部件经验价值）**',
        '**XP gained = round-up( (1 + the fusion-XP skill bonus at the moment of fusing) x C (quality factor) x '
            'XP value of the fused part )**',
      ),
      GuideBlock.text(
        '**每融合一次，就是两个价值各加一截**（Δ ＝ 本次融合获得经验）：'
            '**综合价值 ← 综合价值 ＋ Δ**、**经验价值 ← 经验价值 ＋ 0.7 Δ**。加进去就固定，之后改技能档位也不回算。'
            '两个价值互为线性关系：**经验价值 ＝ 0.7 × 综合价值 ＋ 0.3 × 固有价值**；'
            '**已投入经验 ＝ 综合价值 － 固有价值**。',
        '**Every fusion adds one step to both values** (Δ = the XP gained this time): '
            '**composite ← composite + Δ** and **XP value ← XP value + 0.7 Δ**. Once added it is fixed — changing the '
            'skill later never re-runs it. The two are linearly related: **XP value = 0.7 x composite value + 0.3 x '
            'intrinsic value**, and **XP already invested = composite value - intrinsic value**.',
      ),
      GuideBlock.text(
        '**技能加成按「本次融合当时」的档位取**（专业机械师 1 / 2 / 3 级 ＝ ＋10% / ＋20% / ＋30%），'
            '加出来的经验**立刻并入目标的部件综合价值并固定**。之后再把技能升满，'
            '**已经吃进去的经验不会回算**；同一个部件在不同时期喂给同一个目标，拿到的经验也不一样。'
            '所以要用「先抬高、再固定」的**部件综合价值**来记录，而不是拿当前技能去重算历史。',
        '**The bonus is whatever the fusion-XP skill is at the moment of fusing** (Pro Mechanic level 1 / 2 / 3 = '
            '+10% / +20% / +30%), and the XP it produces is **folded into the target\'s composite value right away and '
            'then stays fixed**. Levelling the skill up later does **not** re-run the past, and the same material fed '
            'at different times yields different amounts. That is why the **composite value** — raised first, then '
            'read — is the thing to track, instead of recomputing history with the current skill.',
      ),
      GuideBlock.text(
        '这几个数都按**绝对经验点**计算：**Σ 融合获得经验**从被融合部件的等级与进度条反推，'
            '**固有价值**按被融合部件的**材料 × 星级**查表。算出的经验**直接加进目标的部件综合价值**'
            '（也就是目标身上那个经验计数），因而同时抬高它的等级/进度与金币价值。',
        'All these figures are in **absolute XP**: **XP already invested** is read off the fused part\'s level and '
            'progress bar, and the **intrinsic value** comes from the table indexed by the fused part\'s '
            '**material x star**. The result is **added straight into the target\'s composite value** — the XP counter '
            'it carries — which raises its level/progress and its coin value at the same time.',
      ),
      GuideBlock.text(
        '换句话说：**一次融合能拿到多少经验，只由被融合的那个部件（材质、星级、已投入经验、品质）'
            '和「本次融合当时」的技能档位决定**，与目标是哪个部件、什么材质、什么星级完全无关。',
        'In other words, **how much XP a fusion gives depends only on the part being fused** (its material, star, '
            'invested XP and quality) **and on the skill level at that moment** — never on what the target is, its '
            'material or its star.',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['公式中的项', '取值'],
          headEn: <String>['Term', 'Value'],
          rowsZh: <List<String>>[
            <String>['部件经验价值', '＝ 固有价值 ＋ 0.7 × Σ 融合获得经验（见上面的式子）'],
            <String>['固有价值', '按被融合部件的**材料 × 星级**查上表（**已含材质差异，不需要再乘 k**）'],
            <String>[
              'Σ 融合获得经验',
              '就是被融合部件的**已投入经验**＝ 它的部件综合价值 － 固有价值；'
                  '按等级与进度条反推（见下面），是**绝对经验点**',
            ],
            <String>['0.7', '固定回收比例：历次经验只按 70% 计入**部件经验价值**'],
            <String>[
              'C（品质系数）',
              '普通部件 1、魔法部件 2、传奇部件 4（同星级同材质的普通件正好差 2 倍 / 4 倍）',
            ],
            <String>[
              '融合经验技能（专业机械师）',
              '按**本次融合当时**的档位取：1 / 2 / 3 级 ＝ ＋10% / ＋20% / ＋30%（威名 5 解锁）；未学习 0',
            ],
          ],
          rowsEn: <List<String>>[
            <String>[
              'XP value',
              '= intrinsic value + 0.7 x Σ XP gained (see the expression above)',
            ],
            <String>[
              'Intrinsic value',
              'Found by the fused part\'s **material x star** in the table above (**material is already accounted '
                  'for — do not multiply by k**)',
            ],
            <String>[
              'Σ XP gained',
              'The fused part\'s **XP already invested** = its composite value - intrinsic value; read back off its '
                  'level and progress bar (below), in **absolute XP**',
            ],
            <String>[
              '0.7',
              'A fixed ratio: past XP only counts at 70% towards the **XP value**',
            ],
            <String>[
              'C (quality factor)',
              'Common 1, magic 2, legendary 4 (exactly 2x / 4x a common part of the same star and material)',
            ],
            <String>[
              'Fusion-XP skill (Pro Mechanic)',
              'Taken **at the moment of fusing**: levels 1 / 2 / 3 = +10% / +20% / +30% (unlocked at prestige 5); '
                  '0 if not learned',
            ],
          ],
        ),
      ),
      GuideBlock.text(
        '**升级所需经验**只与目标部件的**材质**有关，与星级无关：',
        '**The XP needed to upgrade** depends on the target\'s **material** only, never on its star:',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['等级', '升到下一级需要', '累计到本级'],
          headEn: <String>['Level', 'To next level', 'Cumulative'],
          rowsZh: _champExpRowsZh,
          rowsEn: _champExpRowsEn,
        ),
      ),
      GuideBlock.text(
        '表中为**基础经验**，实际数值 ＝ 表中数字 × k（**目标**部件的材质；k 见表里「1 星」一行）。'
            '木质 k ＝ 1，可直接按表使用；用绝对经验对照时，把表中的数乘上 k 即可。',
        'The table gives **base XP**; the real cost is the value x k (the **target**\'s material; k is the 1-star row '
            'of the table above). Wood has k = 1, so for wood the table can be used as is; multiply by k to compare '
            'with absolute XP.',
      ),
      GuideBlock.text(
        '**升到第 L ＋ 1 级需要（L ＋ 1）× k**（1 → 2 级要 2k，2 → 3 级要 3k，依此类推）；'
            '所以「累计到本级」＝ k ×（L(L＋1)/2 － 1）。'
            '**最高等级由星级决定**（见第 2 节）：1 星 6 级、2 星 11 级、3 星 16 级、4 星 21 级、5 星 26 级。',
        '**Going from level L to L+1 costs (L+1) x k** (1 -> 2 costs 2k, 2 -> 3 costs 3k, and so on), so the '
            '"cumulative" column is k x (L(L+1)/2 - 1). **The top level is set by the star** (see section 2): 1 star 6, '
            '2 stars 11, 3 stars 16, 4 stars 21, 5 stars 26.',
      ),
      GuideBlock.text(
        '**最高那一级没有自己的经验段**：它**就是「上一级的 100%」，进度永远显示 0%**。'
            '5 星：26 级 ＝ 25 级 100%；4 星：21 级 ＝ 20 级 100%；3 星：16 级 ＝ 15 级 100%；'
            '1 星：6 级 ＝ 5 级 100%（2 星同理：11 级 ＝ 10 级 100%）。'
            '所以**部件的经验上限 ＝ 「累计到最高等级」那个数**（例如军用 3 星 ＝ 135 × 144 ＝ 19440，'
            '即 16 级 ＝ 15 级 100%），到顶之后就不再涨经验了。'
            '注意 25 → 26 级只有 **10k**（游戏原始表在最后一级收窄了，不是规律里应有的 26k）。',
        '**The top level has no bracket of its own**: it **equals the previous level at 100%, and its progress always '
            'reads 0%**. 5 stars: level 26 = level 25 at 100%; 4 stars: 21 = 20 at 100%; 3 stars: 16 = 15 at 100%; '
            '1 star: 6 = 5 at 100% (2 stars likewise: 11 = 10 at 100%). So **a part\'s XP cap is the "cumulative" '
            'figure of the top level** (e.g. military 3 stars = 135 x 144 = 19440, i.e. level 16 = level 15 at 100%), '
            'and nothing grows past it. Note that level 25 -> 26 costs only **10k** (the game\'s own table narrows at '
            'the last level instead of the 26k the pattern would suggest).',
      ),
      GuideBlock.text(
        '**反过来，从界面上的等级与进度反推已投入经验**（上面几个式子都要用它）：'
            '**已投入经验 ＝ k ×（L(L＋1)/2 － 1）＋ 进度 ×（L ＋ 1）× k**（L ＝ 显示等级，k ＝ 该部件材质的 k）；'
            '再加上固有价值就是**部件综合价值**。',
        '**Reading XP invested back out of the level and progress bar** (every expression above uses it): '
            '**XP invested = k x (L(L+1)/2 - 1) + progress x (L + 1) x k** (L = the displayed level, k = the k of the '
            'part\'s material); add the intrinsic value and you have the **composite value**.',
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '用**已升级过的部件**作融合材料更划算：它能按 70% 把历次经验计入经验价值，另加固有价值',
          'Fusing an **already-leveled part** is more efficient: it returns 70% of its invested XP plus its intrinsic value',
        ),
        GuideBullet(
          '用低材质部件融合高材质目标收益极低：金属 1 星固有价值 13、军用 1 星 144，只剩 13 ÷ 144 ≈ 9%',
          'Fusing a low-material part into a higher-material target is very inefficient: metal 1-star has an '
              'intrinsic value of 13 against 144 for military 1-star, keeping only 13 ÷ 144 ≈ 9%',
        ),
        GuideBullet(
          '被融合部件的材质、星级、等级均不受限制；目标部件自身是否为魔法 / 传奇不影响获得经验',
          'The fused part may be of any material, star and level; whether the target itself is magic / legendary does not change the XP gained',
        ),
        GuideBullet(
          '**魔法 / 传奇部件当材料**时按 C ＝ 2 / 4 倍贡献 —— 就是同星同材质普通件的 **2 倍 / 4 倍**',
          'A **magic / legendary part used as material** contributes C = 2 / 4 times as much — exactly **2x / 4x** a '
              'common part of the same star and material',
        ),
        GuideBullet(
          '**一次只能融合一个材料**，所以不存在叠加求和的问题',
          '**Only one material can be fused at a time**, so there is no summing to worry about',
        ),
      ]),
      GuideBlock.text(
        '**融合要花金币，部件也能卖金币** —— 这两件事看的是**部件金币价值**，'
            '也就是把上面算出来的**部件综合价值**当坐标去查金币阶梯。'
            '游戏的配置里并排放着**两条 34 级阶梯**，**同一位置的条目一一对应**：',
        '**Fusing costs coins and parts can be sold for coins** — both look at the **coin value**, which is the '
            '**composite value** from above used as a coordinate on the coin ladder. The game config holds **two '
            'parallel 34-step ladders** whose entries line up one to one:',
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '**经验阶梯**（部件的经验与等级）：1、2、3、5、8、13 … 9227465',
          'The **XP ladder** (a part\'s XP and level): 1, 2, 3, 5, 8, 13 ... 9227465',
        ),
        GuideBullet(
          '**金币阶梯**（部件的价值）：469、750、1125、1688 … 102375',
          'The **coin ladder** (a part\'s value): 469, 750, 1125, 1688 ... 102375',
        ),
      ]),
      GuideBlock.text(
        '**部件综合价值 ＝ 固有价值 ＋ Σ 融合获得经验** —— 它就是部件在经验阶梯上的坐标，'
            '也是部件的「成长量」（融合就是在抬高它）。',
        '**Composite value = intrinsic value + Σ XP gained** — the part\'s coordinate on the XP ladder and its total '
            'growth (fusing is what raises it).',
      ),
      GuideBlock.text(
        '**部件金币价值 ＝ 把部件综合价值当坐标，去查金币阶梯**。坐标落在第 N 格与第 N＋1 格之间时：',
        '**Coin value = the coin ladder read at the composite value.** When the coordinate falls between rung N and '
            'rung N+1:',
      ),
      GuideBlock.text(
        '**部件金币价值 ＝ 金币阶梯第 N 格 ＋（部件综合价值 － 经验阶梯第 N 格）÷'
            '（经验阶梯第 N＋1 格 － 经验阶梯第 N 格）×（金币阶梯第 N＋1 格 － 金币阶梯第 N 格）**',
        '**Coin value = coin ladder rung N + (composite value - XP ladder rung N) / '
            '(XP ladder rung N+1 - XP ladder rung N) x (coin ladder rung N+1 - coin ladder rung N)**',
      ),
      GuideBlock.text(
        '注意**别把三个价值混用**：**部件经验价值**（固有价值 ＋ **0.7 ×** Σ 融合获得经验）只管**经验**；'
            '**部件综合价值**（固有价值 ＋ Σ 融合获得经验）是坐标；**部件金币价值**才是钱。'
            '三者只在**一件也没喂过**（Σ ＝ 0，即 1 级 0%）时全部相等。',
        'Do not mix the three values up: the **XP value** (intrinsic value + **0.7 x** Σ XP gained) only drives '
            '**XP**, the **composite value** (intrinsic value + Σ XP gained) is the coordinate, and the **coin value** '
            'is the money. All three coincide only when **nothing has been fused in** (Σ = 0, i.e. level 1 / 0%).',
      ),
      GuideBlock.text(
        '两个用钱的场合都从它出发：',
        'Both places where money changes hands start from it:',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['用途', '公式'],
          headEn: <String>['What', 'Formula'],
          rowsZh: <List<String>>[
            <String>['融合花费', '**取整（部件金币价值 ×（1 － 专业交易商））**'],
            <String>['出售部件', '**取整（融合花费 × 0.5 × 品质系数 ×（1 ＋ 商人））**'],
          ],
          rowsEn: <List<String>>[
            <String>[
              'Fusion cost',
              '**round( coin value x (1 - Pro Dealer) )**',
            ],
            <String>[
              'Selling a part',
              '**round( fusion cost x 0.5 x quality factor x (1 + Merchant) )**',
            ],
          ],
        ),
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '**品质系数**：普通 1、魔法 2、传奇 4 —— 也就是说**品质不影响融合花费**，只影响卖价',
          '**Quality factor**: common 1, magic 2, legendary 4 — so **quality never changes the fusion cost**, only '
              'the sale price',
        ),
        GuideBullet(
          '**出售价是按「打过折」的价值算的**：专业交易商把花费压到 0.7 倍，卖价也跟着只剩 0.7 倍',
          '**The sale price is computed from the discounted value**: Pro Dealer cuts the cost to 0.7x, and the sale '
              'price drops to 0.7x with it',
        ),
        GuideBullet(
          '**融合花费先乘折扣、最后才取整**；出售价用的是**取整之后**的融合花费',
          'The **fusion cost applies the discount first and rounds last**; the sale price uses the **already rounded** '
              'fusion cost',
        ),
        GuideBullet(
          '**一次只能融合一个材料**，所以花费就是「目标部件在这一刻的**部件金币价值**」，不涉及求和',
          '**Only one material per fusion**, so the cost is simply the target\'s **coin value** at that moment — '
              'nothing to sum up',
        ),
        GuideBullet(
          '部件会**随等级涨钱**：等级越高价值越大，所以「升完再卖」通常比「直接卖」划算',
          'A part is **worth more as it levels up**, so selling after leveling usually beats selling straight away',
        ),
      ]),
      GuideBlock.text(
        '**25 档 1 级部件的价值与价格**。1 级 0% 时「固有价值 ＋ Σ 融合获得经验」恰好等于该档位的固有价值，'
            '所以**下表第 N 行的「部件金币价值」就是金币阶梯第 N 格的读数**'
            '（军用 3 星 ＝ 15188 就是金币阶梯第 13 格）。'
            '下表按「专业交易商、商人都是满级」计算；没点技能时：融合花费 ＝ 金币价值，出售 ＝ 金币价值 × 0.5 × 品质系数。',
        '**Value and prices of a level-1 part in each of the 25 tiers.** At level 1 / 0% the sum "intrinsic value + '
            'Σ XP gained" equals the tier intrinsic value itself, so the **"Coin value" column of row N below is '
            'simply rung N of the coin ladder** (military 3 stars = 15188 = rung 13). The table assumes Pro Dealer and '
            'Merchant are maxed; with no skills the fusion cost equals the coin value and the sale is coin value x '
            '0.5 x quality factor.',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['档位', '部件材质 / 星级', '部件金币价值', '融合花费', '出售（普通）'],
          headEn: <String>[
            'Tier',
            'Material / star',
            'Coin value',
            'Fusion cost',
            'Sale (common)',
          ],
          rowsZh: _champValueRowsZh,
          rowsEn: _champValueRowsEn,
        ),
      ),
      GuideBlock.text(
        '**完整算一遍**。输入只有五项：目标部件 **13 段（＝ 军用 3 星）**、材料部件 **11 段（＝ 军用 1 星、1 级 0%）**；'
            '两个部件都是**普通**品质、技能全是满级（专业交易商 −30%、专业机械师 ＋30%、商人 ＋30%）。'
            '下面每一步用到的数，都来自本节上面那几张表。',
        '**A full walk-through.** There are only five inputs: the target is a **tier-13 part (= military 3 stars)** and '
            'the material is a **tier-11 part (= military 1 star, level 1 / 0%)**; both are **common** and every skill '
            'is maxed (Pro Dealer -30%, Pro Mechanic +30%, Merchant +30%). Every number used below comes from one of '
            'the tables above.',
      ),
      GuideBlock.text(
        '**第 1 轮**：把 11 段喂进 13 段。',
        '**Round 1**: fuse the tier-11 part into the tier-13 part.',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['步骤', '算式', '结果'],
          headEn: <String>['Step', 'Working', 'Result'],
          rowsZh: <List<String>>[
            <String>['1. 材料固有价值', '固有价值表：1 星 · 军用', '144'],
            <String>['2. Σ 融合获得经验（材料）', '材料是 1 级 0%，没喂过任何东西', '0'],
            <String>['3. 部件经验价值（材料）', '固有价值 144 ＋ 0.7 × 0', '144'],
            <String>[
              '4. 融合获得经验',
              '向上取整（（1 ＋ 0.30）× 1 × 144）＝ 向上取整（1.30 × 144）＝ 向上取整（187.2）',
              '188',
            ],
            <String>['5. 目标综合价值', '固有价值 377 ＋ Σ（0 ＋ 188）＝ 377 ＋ 188', '565'],
            <String>[
              '6. 目标进度',
              '已投入经验 ＝ 565 － 377 ＝ 188；1 级上界 ＝ 升级经验表 1 级行（2）× k（144）＝ 288；'
                  '188 ÷ 288 ＝ 0.6528',
              '1 级 65%',
            ],
            <String>[
              '7. 目标的经验价值',
              '0.7 × 565 ＋ 0.3 × 377 ＝ 395.5 ＋ 113.1（验证线性关系）',
              '508.6',
            ],
            <String>[
              '8. 插值比例',
              '（565 － 377）÷（610 － 377）＝ 188 ÷ 233（610 ＝ 固有价值表 4 星 · 军用）',
              '0.80687',
            ],
            <String>[
              '9. 两端价值',
              '部件金币价值表第 13 行（军用 3 星）＝ 15188、第 14 行（军用 4 星）＝ 17625；'
                  '差 ＝ 17625 － 15188 ＝ 2437',
              '15188 / 2437',
            ],
            <String>[
              '10. 部件金币价值',
              '15188 ＋（188 ÷ 233）× 2437 ＝ 15188 ＋ 458156 ÷ 233 ＝ 15188 ＋ 1966.33476',
              '17154.33476',
            ],
            <String>[
              '11. 融合花费',
              '取整（17154.33476 ×（1 － 0.30））＝ 取整（17154.33476 × 0.70）＝ 取整（12008.0343）',
              '12008',
            ],
            <String>[
              '12. 出售价（普通）',
              '取整（12008 × 0.5 × 1 ×（1 ＋ 0.30））＝ 取整（12008 × 0.65）＝ 取整（7805.2）',
              '7805',
            ],
            <String>[
              '13. 对照：目标仍是 1 级 0% 时',
              '取整（15188 × 0.70）＝ 取整（10631.6）＝ 10632；取整（10632 × 0.65）＝ 取整（6910.8）',
              '10632 / 6911',
            ],
            <String>[
              '14. 同一件的魔法 / 传奇卖价',
              '取整（10632 × 0.5 × 2 × 1.30）＝ 取整（13821.6）；'
                  '取整（10632 × 0.5 × 4 × 1.30）＝ 取整（27643.2）',
              '13822 / 27643',
            ],
          ],
          rowsEn: <List<String>>[
            <String>[
              '1. Intrinsic value of the material',
              'Intrinsic value table: 1 star / military',
              '144',
            ],
            <String>[
              '2. Σ 融合获得经验（材料）',
              'The material is level 1 / 0% — nothing was ever fused into it',
              '0',
            ],
            <String>[
              '3. XP value (material)',
              'intrinsic value 144 + 0.7 x 0',
              '144',
            ],
            <String>[
              '4. XP gained',
              'round-up( (1 + 0.30) x 1 x 144 ) = round-up( 1.30 x 144 ) = round-up( 187.2 )',
              '188',
            ],
            <String>[
              '5. Composite value of the target',
              'intrinsic value 377 + Σ (0 + 188) = 377 + 188',
              '565',
            ],
            <String>[
              '6. Progress of the target',
              'XP invested = 565 - 377 = 188; top of level 1 = row 1 of the XP table (2) x k (144) = 288; '
                  '188 / 288 = 0.6528',
              'level 1, 65%',
            ],
            <String>[
              '7. XP value of the target',
              '0.7 x 565 + 0.3 x 377 = 395.5 + 113.1 (checks the linear relation)',
              '508.6',
            ],
            <String>[
              '8. Interpolation ratio',
              '(565 - 377) / (610 - 377) = 188 / 233 (610 = intrinsic value, 4 stars / military)',
              '0.80687',
            ],
            <String>[
              '9. Values at both rungs',
              'Coin value table row 13 (military 3 stars) = 15188, row 14 (military 4 stars) = 17625; '
                  'difference = 17625 - 15188 = 2437',
              '15188 / 2437',
            ],
            <String>[
              '10. Coin value',
              '15188 + (188 / 233) x 2437 = 15188 + 458156 / 233 = 15188 + 1966.33476',
              '17154.33476',
            ],
            <String>[
              '11. Fusion cost',
              'round( 17154.33476 x (1 - 0.30) ) = round( 17154.33476 x 0.70 ) = round( 12008.0343 )',
              '12008',
            ],
            <String>[
              '12. Sale price (common)',
              'round( 12008 x 0.5 x 1 x (1 + 0.30) ) = round( 12008 x 0.65 ) = round( 7805.2 )',
              '7805',
            ],
            <String>[
              '13. Control: target still at level 1 / 0%',
              'round( 15188 x 0.70 ) = round( 10631.6 ) = 10632; round( 10632 x 0.65 ) = round( 6910.8 )',
              '10632 / 6911',
            ],
            <String>[
              '14. Same part sold as magic / legendary',
              'round( 10632 x 0.5 x 2 x 1.30 ) = round( 13821.6 ); '
                  'round( 10632 x 0.5 x 4 x 1.30 ) = round( 27643.2 )',
              '13822 / 27643',
            ],
          ],
        ),
      ),
      GuideBlock.text(
        '**第 2 轮**：把刚刚变成「1 级 65%」的那个 13 段当作材料，喂给**另一个** 13 段（1 级 0%）。'
            '这一轮才能看出「部件经验价值」里 **0.7 × Σ 融合获得经验** 那一项的作用。',
        '**Round 2**: use the tier-13 part that just became level 1 / 65% as the material and fuse it into '
            '**another** tier-13 part (level 1 / 0%). Only this round exercises the **0.7 x Σ XP gained** term inside '
            'the XP value.',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['步骤', '算式', '结果'],
          headEn: <String>['Step', 'Working', 'Result'],
          rowsZh: <List<String>>[
            <String>['1. 材料固有价值', '固有价值表：3 星 · 军用', '377'],
            <String>['2. Σ 融合获得经验（材料）', '就是第 1 轮第 4 步的结果', '188'],
            <String>[
              '3. 部件经验价值（材料）',
              '固有价值 377 ＋ 0.7 × 188 ＝ 377 ＋ 131.6',
              '508.6',
            ],
            <String>[
              '4. 融合获得经验',
              '向上取整（（1 ＋ 0.30）× 1 × 508.6）＝ 向上取整（1.30 × 508.6）＝ 向上取整（661.18）',
              '662',
            ],
            <String>['5. 目标综合价值', '固有价值 377 ＋ Σ（0 ＋ 662）＝ 377 ＋ 662', '1039'],
            <String>[
              '6. 目标等级 / 进度',
              '已投入经验 ＝ 1039 － 377 ＝ 662；累计到 2 级 ＝ 144 ×（2 × 3 ÷ 2 － 1）＝ 288、'
                  '到 3 级 ＝ 144 ×（3 × 4 ÷ 2 － 1）＝ 720；662 落在 [288, 720) ⇒ 2 级；'
                  '（662 － 288）÷（720 － 288）＝ 374 ÷ 432 ＝ 0.8657',
              '2 级 87%',
            ],
            <String>[
              '7. 目标的经验价值',
              '0.7 × 1039 ＋ 0.3 × 377 ＝ 727.3 ＋ 113.1（验证线性关系）',
              '840.4',
            ],
            <String>[
              '8. 插值比例',
              '（1039 － 987）÷（1597 － 987）＝ 52 ÷ 610（987 ＝ 固有价值表 5 星 · 军用，'
                  '1597 ＝ 1 星 · 黄金）',
              '0.08525',
            ],
            <String>[
              '9. 两端价值',
              '部件金币价值表第 15 行（军用 5 星）＝ 20250、第 16 行（黄金 1 星）＝ 23063；'
                  '差 ＝ 23063 － 20250 ＝ 2813',
              '20250 / 2813',
            ],
            <String>[
              '10. 部件金币价值',
              '20250 ＋（52 ÷ 610）× 2813 ＝ 20250 ＋ 146276 ÷ 610 ＝ 20250 ＋ 239.79672',
              '20489.79672',
            ],
            <String>[
              '11. 融合花费',
              '取整（20489.79672 × 0.70）＝ 取整（14342.85770）',
              '14343',
            ],
            <String>[
              '12. 出售价（普通）',
              '取整（14343 × 0.5 × 1 × 1.30）＝ 取整（14343 × 0.65）＝ 取整（9322.95）',
              '9323',
            ],
          ],
          rowsEn: <List<String>>[
            <String>[
              '1. Intrinsic value of the material',
              'Intrinsic value table: 3 stars / military',
              '377',
            ],
            <String>[
              '2. Σ XP gained (material)',
              'The result of step 4 in round 1',
              '188',
            ],
            <String>[
              '3. XP value (material)',
              'intrinsic value 377 + 0.7 x 188 = 377 + 131.6',
              '508.6',
            ],
            <String>[
              '4. XP gained',
              'round-up( (1 + 0.30) x 1 x 508.6 ) = round-up( 1.30 x 508.6 ) = round-up( 661.18 )',
              '662',
            ],
            <String>[
              '5. Composite value of the target',
              'intrinsic value 377 + Σ (0 + 662) = 377 + 662',
              '1039',
            ],
            <String>[
              '6. Level / progress of the target',
              'XP invested = 1039 - 377 = 662; cumulative to level 2 = 144 x (2 x 3 / 2 - 1) = 288, to level 3 = '
                  '144 x (3 x 4 / 2 - 1) = 720; 662 falls in [288, 720) so level 2; '
                  '(662 - 288) / (720 - 288) = 374 / 432 = 0.8657',
              'level 2, 87%',
            ],
            <String>[
              '7. XP value of the target',
              '0.7 x 1039 + 0.3 x 377 = 727.3 + 113.1 (checks the linear relation)',
              '840.4',
            ],
            <String>[
              '8. Interpolation ratio',
              '(1039 - 987) / (1597 - 987) = 52 / 610 (987 = intrinsic value, 5 stars / military; '
                  '1597 = 1 star / gold)',
              '0.08525',
            ],
            <String>[
              '9. Values at both rungs',
              'Coin value table row 15 (military 5 stars) = 20250, row 16 (gold 1 star) = 23063; '
                  'difference = 23063 - 20250 = 2813',
              '20250 / 2813',
            ],
            <String>[
              '10. Coin value',
              '20250 + (52 / 610) x 2813 = 20250 + 146276 / 610 = 20250 + 239.79672',
              '20489.79672',
            ],
            <String>[
              '11. Fusion cost',
              'round( 20489.79672 x 0.70 ) = round( 14342.85770 )',
              '14343',
            ],
            <String>[
              '12. Sale price (common)',
              'round( 14343 x 0.5 x 1 x 1.30 ) = round( 14343 x 0.65 ) = round( 9322.95 )',
              '9323',
            ],
          ],
        ),
      ),
      GuideBlock.text(
        '**第 3 轮**：同一个 13 段（1 级 0%），但**中途把技能升了级** —— 先按专业机械师 2 级（＋20%）'
            '融合一次，再把技能升到 3 级（＋30%）融合第二次。两次喂的是**同一个 11 段**（军用 1 星、1 级 0%）。',
        '**Round 3**: the same tier-13 part (level 1 / 0%), but with the **skill upgraded in between** — first a fusion '
            'at Pro Mechanic level 2 (+20%), then the skill is raised to level 3 (+30%) and a second fusion happens. '
            'Both times the material is the **same tier-11 part** (military 1 star, level 1 / 0%).',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['步骤', '算式', '结果'],
          headEn: <String>['Step', 'Working', 'Result'],
          rowsZh: <List<String>>[
            <String>['1. 部件经验价值（材料）', '固有价值 144 ＋ 0.7 × Σ 0（两次喂的同一个部件）', '144'],
            <String>[
              '2. 第 1 次融合：技能 ＋20%',
              '向上取整（（1 ＋ 0.20）× 1 × 144）＝ 向上取整（172.8）',
              '173',
            ],
            <String>['3. 目标综合价值', '固有价值 377 ＋ 173', '550'],
            <String>[
              '4. 目标进度',
              '已投入经验 ＝ 550 － 377 ＝ 173；173 ÷ 288 ＝ 0.6007',
              '1 级 60%',
            ],
            <String>[
              '5. 第 2 次融合：技能已升到 ＋30%',
              '向上取整（（1 ＋ 0.30）× 1 × 144）＝ 向上取整（187.2）',
              '188',
            ],
            <String>['6. 目标综合价值', '550 ＋ 188（**第 1 次的 173 已经固定，不回算**）', '738'],
            <String>[
              '7. 新等级 / 进度',
              '已投入经验 ＝ 738 － 377 ＝ 361；累计到 2 级 ＝ 144 ×（2 × 3 ÷ 2 － 1）＝ 288、'
                  '到 3 级 ＝ 144 ×（3 × 4 ÷ 2 － 1）＝ 720；361 落在 [288, 720) ⇒ 2 级；'
                  '（361 － 288）÷（720 － 288）＝ 73 ÷ 432 ＝ 0.1690',
              '2 级 17%',
            ],
            <String>[
              '8. 插值比例',
              '（738 － 610）÷（987 － 610）＝ 128 ÷ 377（610 / 987 ＝ 固有价值表 4 星 / 5 星 · 军用）',
              '0.33952',
            ],
            <String>[
              '9. 两端价值',
              '部件金币价值表第 14 行（军用 4 星）＝ 17625、第 15 行（军用 5 星）＝ 20250；'
                  '差 ＝ 20250 － 17625 ＝ 2625',
              '17625 / 2625',
            ],
            <String>[
              '10. 部件金币价值',
              '17625 ＋（128 ÷ 377）× 2625 ＝ 17625 ＋ 336000 ÷ 377 ＝ 17625 ＋ 891.24668',
              '18516.24668',
            ],
            <String>[
              '11. 融合花费',
              '取整（18516.24668 × 0.70）＝ 取整（12961.37268）',
              '12961',
            ],
            <String>[
              '12. 出售价（普通）',
              '取整（12961 × 0.5 × 1 × 1.30）＝ 取整（12961 × 0.65）＝ 取整（8424.65）',
              '8425',
            ],
          ],
          rowsEn: <List<String>>[
            <String>[
              '1. XP value (material)',
              'intrinsic value 144 + 0.7 x Σ 0 (both times the same part)',
              '144',
            ],
            <String>[
              '2. 1st fusion, skill +20%',
              'round-up( (1 + 0.20) x 1 x 144 ) = round-up( 172.8 )',
              '173',
            ],
            <String>[
              '3. Composite value of the target',
              'intrinsic value 377 + 173',
              '550',
            ],
            <String>[
              '4. Progress of the target',
              'XP invested = 550 - 377 = 173; 173 / 288 = 0.6007',
              'level 1, 60%',
            ],
            <String>[
              '5. 2nd fusion, skill now +30%',
              'round-up( (1 + 0.30) x 1 x 144 ) = round-up( 187.2 )',
              '188',
            ],
            <String>[
              '6. Composite value of the target',
              '550 + 188 (**the 173 from the first fusion stays fixed — it is never recomputed**)',
              '738',
            ],
            <String>[
              '7. New level / progress',
              'XP invested = 738 - 377 = 361; cumulative to level 2 = 144 x (2 x 3 / 2 - 1) = 288, to level 3 = '
                  '144 x (3 x 4 / 2 - 1) = 720; 361 falls in [288, 720) so level 2; '
                  '(361 - 288) / (720 - 288) = 73 / 432 = 0.1690',
              'level 2, 17%',
            ],
            <String>[
              '8. Interpolation ratio',
              '(738 - 610) / (987 - 610) = 128 / 377 (610 / 987 = intrinsic value, 4 / 5 stars military)',
              '0.33952',
            ],
            <String>[
              '9. Values at both rungs',
              'Coin value table row 14 (military 4 stars) = 17625, row 15 (military 5 stars) = 20250; '
                  'difference = 20250 - 17625 = 2625',
              '17625 / 2625',
            ],
            <String>[
              '10. Coin value',
              '17625 + (128 / 377) x 2625 = 17625 + 336000 / 377 = 17625 + 891.24668',
              '18516.24668',
            ],
            <String>[
              '11. Fusion cost',
              'round( 18516.24668 x 0.70 ) = round( 12961.37268 )',
              '12961',
            ],
            <String>[
              '12. Sale price (common)',
              'round( 12961 x 0.5 x 1 x 1.30 ) = round( 12961 x 0.65 ) = round( 8424.65 )',
              '8425',
            ],
          ],
        ),
      ),
      GuideBlock.tip(
        '前两个算例的结果可以直接对照游戏：10632 / 6911 / 13822 / 27643（目标还是 1 级 0% 时）与 '
            '12008 / 7805（喂完 11 段之后）都是实测值。'
            '两个比值自己就能验证：花费 ÷ 金币价值 ≈ 0.70（专业交易商满级），出售 ÷ 花费 ≈ '
            '普通 0.65 / 魔法 1.30 / 传奇 2.60（商人满级）。'
            '第 3 轮则是技能档位的影响：**同一个 11 段，技能 ＋20% 时只给 173，＋30% 时给 188**。',
        'The first two examples can be checked directly in game: 10632 / 6911 / 13822 / 27643 (while the target is '
            'still at level 1 / 0%) and 12008 / 7805 (after fusing the tier-11 part) are all measured values. Two '
            'ratios verify themselves: cost / coin value is about 0.70 (Pro Dealer maxed), and sale / cost is about '
            '0.65 common / 1.30 magic / 2.60 legendary (Merchant maxed). Round 3 shows what the skill level does: '
            '**the same tier-11 part is worth 173 at +20% and 188 at +30%**.',
      ),
      // ---------- 工具箱的融合花费（自成一节） ----------
      GuideBlock.text(
        '**工具箱的融合花费**与部件融合是两套算钱方式：花费 ＝ 表中的**融合基础花费 × 倍率**，'
            '倍率看「这是该部件上的第几个工具箱」（第 1 个最便宜，之后逐次翻倍，'
            '到第 7 个封顶——也就是最贵是首件的 **64 倍**）：',
        '**A toolbox\'s fuse cost** is priced differently from a part fusion: cost = the **base fuse cost x '
            'multiplier**, where the multiplier depends on *which* toolbox this is for that part (the 1st is the '
            'cheapest, then it doubles each time and caps at the 7th — i.e. at most **64x** the first one):',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['该部件上第几个', '倍率', '相对第 1 个'],
          headEn: <String>['Which toolbox', 'Multiplier', 'Vs. the 1st'],
          rowsZh: <List<String>>[
            <String>['第 1 个', '× 8', '× 1'],
            <String>['第 2 个', '× 16', '× 2'],
            <String>['第 3 个', '× 32', '× 4'],
            <String>['第 4 个', '× 64', '× 8'],
            <String>['第 5 个', '× 128', '× 16'],
            <String>['第 6 个', '× 256', '× 32'],
            <String>['第 7 个及以后', '× 512（上限）', '× 64'],
          ],
          rowsEn: <List<String>>[
            <String>['1st', 'x 8', 'x 1'],
            <String>['2nd', 'x 16', 'x 2'],
            <String>['3rd', 'x 32', 'x 4'],
            <String>['4th', 'x 64', 'x 8'],
            <String>['5th', 'x 128', 'x 16'],
            <String>['6th', 'x 256', 'x 32'],
            <String>['7th and later', 'x 512 (capped)', 'x 64'],
          ],
        ),
      ),
      GuideBlock.text(
        '**出售工具箱 ＝ 第 8 节表里的「出售价」＝ 融合基础花费 × 8**：也就是说**卖掉它的钱，正好等于往空部件上'
            '融合第 1 个它的花费**（首融零净金币成本，第 2 个起就要自己贴钱）。'
            '如果工具箱已经**融进部件**，卖掉那个部件时它只能按 **50%** 折算：',
        '**Selling a toolbox = the "sell price" column of section 8 = base fuse cost x 8**: the money you get equals '
            'exactly what fusing the **1st** one onto an empty part costs (so the first fuse is gold-neutral, later ones '
            'are not). Once a toolbox has been **fused into a part**, selling that part refunds only **50%** of it:',
      ),
      GuideBlock.text(
        '**带工具箱部件的售价 ＝ 部件自身售价 ＋ Σ（每个已融合工具箱的售价 × 0.5）**'
            '（即工具箱那部分**不计入经验**、只能回收一半金币）',
        '**Price of a part with toolboxes = the part\'s own price + Σ (each fused toolbox\'s sell price x 0.5)** '
            '(the toolbox part **adds no XP** and only half of its gold comes back)',
      ),
      GuideBlock.text(
        '⚠ 那个 Σ 里的「每个工具箱的售价」**只按它自己那个档位算**（＝ 往空部件上融第 1 个它的花费），'
            '**与它是这个部件上的第几个完全无关**：翻倍的是你**付出**的花费，不是它的身价。'
            '回收的是「箱子的半价」，不是「你花钱的一半」——所以叠得越多、回收率越低：'
            '第 1 个回收 50%、第 2 个 25%、第 3 个 12.5%…'
            '拿一个「首融 1000 金币」的箱子（它的售价也是 1000）举例：',
        '⚠ Each toolbox in that sum is priced **by its own tier only** (= what fusing it as the **1st** one onto an '
            'empty part costs) and **never by which position it occupies on the part**: what doubles is your '
            '*spending*, not its value. You get back half of the **box\'s** price, not half of what you paid — so '
            'the refund rate falls as you stack: 50% for the 1st, 25% for the 2nd, 12.5% for the 3rd ... '
            'Take a toolbox whose first-fuse price is 1000 coins (its sell price is 1000 as well):',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['第几个箱子', '你付出的花费', '卖掉部件能回收', '回收 ÷ 花费'],
          headEn: <String>[
            'Which box',
            'What you pay',
            'Refund when selling',
            'Refund / paid',
          ],
          rowsZh: <List<String>>[
            <String>['第 1 个', '1,000（基础 × 8）', '500', '50%'],
            <String>['第 2 个', '2,000（基础 × 16）', '500', '25%'],
            <String>['第 3 个', '4,000（基础 × 32）', '500', '12.5%'],
            <String>['合计（3 个）', '7,000', '1,500（＝ 500 × 3）', '约 21.4%'],
          ],
          rowsEn: <List<String>>[
            <String>['1st', '1,000 (base x 8)', '500', '50%'],
            <String>['2nd', '2,000 (base x 16)', '500', '25%'],
            <String>['3rd', '4,000 (base x 32)', '500', '12.5%'],
            <String>['Total (3)', '7,000', '1,500 (= 500 x 3)', 'about 21.4%'],
          ],
        ),
      ),
      GuideBlock.tip(
        '一句话记法：**回收的是「箱子的半价」，不是「你花钱的一半」**。'
            '所以往同一个部件上叠第 2、3 个箱子，多花的钱基本等于烧掉——只有想把一个部件吃满加成时才这么干。',
        'One-liner: **you get back half of the box\'s price, not half of what you spent.** Stacking a 2nd or 3rd '
            'toolbox therefore mostly burns the extra coins — only do it to max out a single part.',
      ),
      // ---------- 10. 技能一览 ----------
      GuideBlock.heading('技能一览与解锁条件', 'Skills and unlock conditions'),
      GuideBlock.text(
        '车身技能按**段位**（stage）或**威名**（prestige，转生次数）解锁：',
        'Body skills unlock by **stage** or by **prestige** (how many times you have restarted):',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['车身', '电力技能解锁', 'HP 技能解锁'],
          headEn: <String>[
            'Body',
            'Power skill unlocks at',
            'HP skill unlocks at',
          ],
          rowsZh: <List<String>>[
            <String>['泰坦', '段位 0', '段位 3'],
            <String>['浪板', '段位 6', '段位 0'],
            <String>['滑头', '段位 3', '段位 9'],
            <String>['磐石', '段位 9', '段位 12'],
            <String>['经典', '段位 12', '段位 15'],
            <String>['金字塔', '—', '段位 18'],
            <String>['巨鲸', '—', '威名 1'],
            <String>['钻石', '—', '—'],
          ],
          rowsEn: <List<String>>[
            <String>['Titan', 'Stage 0', 'Stage 3'],
            <String>['Surfer', 'Stage 6', 'Stage 0'],
            <String>['Sneaky', 'Stage 3', 'Stage 9'],
            <String>['Boulder', 'Stage 9', 'Stage 12'],
            <String>['Classic', 'Stage 12', 'Stage 15'],
            <String>['Pyramid', '—', 'Stage 18'],
            <String>['Whale', '—', 'Prestige 1'],
            <String>['Diamond', '—', '—'],
          ],
        ),
      ),
      GuideBlock.text(
        '各技能组的数值与技能点消耗（下表的 1 / 2 / 3 为技能等级）：',
        'Values and skill-point costs of each skill group (the 1 / 2 / 3 below are skill levels):',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['技能', '数值', '技能点', '适用'],
          headEn: <String>['Skill', 'Values', 'Skill points', 'Applies to'],
          rowsZh: <List<String>>[
            <String>[
              '车身 电力',
              '+1 / +2 / +3',
              '1 / 2 / 3',
              '经典、泰坦、浪板、滑头、磐石 共 5 种车身',
            ],
            <String>[
              '车身 HP',
              '+10% / +20% / +30%',
              '1 / 2 / 3',
              '经典、滑头、磐石、巨鲸、金字塔、浪板、泰坦 共 7 种车身',
            ],
            <String>[
              '武器伤害（按类别）',
              '+10% / +20% / +30%',
              '1 / 2 / 3',
              '7 个武器类别，各一条独立技能线（解锁段位见下表）',
            ],
            <String>[
              '车轮 HP（按类别）',
              '+15% / +30% / +45%',
              '1 / 2 / 3',
              '7 个车轮类别，各一条独立技能线（解锁段位见下表；另外 4 条属配件，见下一行）',
            ],
            <String>[
              '配件 HP（按类别）',
              '+15% / +30% / +45%',
              '1 / 2 / 3',
              '4 种配件（推进器 / 叉车 / 反弹器 / 反推器）各一条独立技能线（解锁段位见下表）；'
                  '实测点满 +45%，其余 8 种配件没有这条技能',
            ],
            <String>[
              '专业机械师（威名 5）',
              '+10% / +20% / +30%',
              '2 / 3 / 4',
              '融合获得的经验',
            ],
            <String>[
              '专业交易商（威名 5）',
              '−10% / −20% / −30%',
              '2 / 3 / 4',
              '融合的花费（同时会压低出售价，见第 8 节）',
            ],
            <String>[
              '商人（段位 0）',
              '+10% / +20% / +30%',
              '1 / 2 / 3',
              '出售部件获得的金币',
            ],
          ],
          rowsEn: <List<String>>[
            <String>[
              'Body power',
              '+1 / +2 / +3',
              '1 / 2 / 3',
              'Classic, Titan, Surfer, Sneaky, Boulder — 5 bodies',
            ],
            <String>[
              'Body HP',
              '+10% / +20% / +30%',
              '1 / 2 / 3',
              'Classic, Sneaky, Boulder, Whale, Pyramid, Surfer, Titan — 7 bodies',
            ],
            <String>[
              'Weapon damage (per category)',
              '+10% / +20% / +30%',
              '1 / 2 / 3',
              'the 7 weapon categories, each with its own skill line (stages below)',
            ],
            <String>[
              'Wheel HP (per category)',
              '+15% / +30% / +45%',
              '1 / 2 / 3',
              'the 7 wheel categories, each with its own skill line (stages below; the other 4 belong to the gadgets, '
                  'see the row below)',
            ],
            <String>[
              'Gadget HP (per category)',
              '+15% / +30% / +45%',
              '1 / 2 / 3',
              '4 gadgets (thruster / forklift / bouncer / repulser), each with its own skill line (stages below); '
                  'measured +45% when maxed, the other 8 gadgets have no such skill',
            ],
            <String>[
              'Pro Mechanic (prestige 5)',
              '+10% / +20% / +30%',
              '2 / 3 / 4',
              'XP gained from fusion',
            ],
            <String>[
              'Pro Dealer (prestige 5)',
              '−10% / −20% / −30%',
              '2 / 3 / 4',
              'the cost of fusion (it lowers the sale price too, see section 8)',
            ],
            <String>[
              'Merchant (stage 0)',
              '+10% / +20% / +30%',
              '1 / 2 / 3',
              'coins gained from selling parts',
            ],
          ],
        ),
      ),
      GuideBlock.text(
        '**类别技能的解锁段位**（武器 / 车轮 / 配件各一套，与车身技能互不相干）：',
        '**Stage at which the category skills unlock** (one set each for weapons, wheels and gadgets, unrelated to '
            'body skills):',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['段位', '武器类别', '车轮类别', '配件类别'],
          headEn: <String>[
            'Stage',
            'Weapon category',
            'Wheel category',
            'Gadget category',
          ],
          rowsZh: <List<String>>[
            <String>['0', '长钉', '—', '推进器'],
            <String>['3', '火箭', '滚轮', '—'],
            <String>['6', '电钻', '—', '叉车'],
            <String>['9', '—', '旋钮轮', '—'],
            <String>['12', '电锯', '大脚轮', '—'],
            <String>['15', '圆锯 · 激光', '黏地轮 · 滚轮', '—'],
            <String>['18', '—', '滑板轮 · 轱辘轮', '反弹器'],
            <String>['21', '双管火箭', '黏地轮 · 轱辘轮', '反推器'],
          ],
          rowsEn: <List<String>>[
            <String>['0', 'Stinger', '—', 'Thruster'],
            <String>['3', 'Rocket', 'Roller', '—'],
            <String>['6', 'Drill', '—', 'Forklift'],
            <String>['9', '—', 'Knob wheel', '—'],
            <String>['12', 'Chainsaw', 'Bigfoot', '—'],
            <String>['15', 'Saw · Laser', 'Sticky roller', '—'],
            <String>['18', '—', 'Skateboard wheel · Cart wheel', 'Bouncer'],
            <String>['21', 'Double rocket', 'Sticky cart wheel', 'Repulser'],
          ],
        ),
      ),
      GuideBlock.tip(
        '**车身技能与类别技能是两套独立的加成**：车身技能只加车身自身（供电 / HP），'
            '武器伤害、车轮 HP 与配件 HP 要另点到对应**类别**的技能线；两条都会进公式，是连乘关系。',
        '**Body skills and category skills are two independent sets**: body skills only boost the body (power / HP), '
            'while weapon damage, wheel HP and gadget HP need points in the skill line of the matching **category**; '
            'both appear in the formulas and multiply together.',
      ),
      // ---------- 10. 插槽 ----------
      GuideBlock.heading('车身决定插槽', 'The body decides the slots'),
      GuideBlock.text(
        '车身数据中包含**挂点**（位置与允许挂载的部件类型），因此「能装几件武器 / 车轮 / 配件、'
            '分别装在哪里」完全由车身决定。更换车身会同时改变插槽布局。',
        'Body data contains **mount points** (a position plus the part types allowed there), so how many weapons / '
            'wheels / gadgets you can mount — and where — is entirely up to the body. Swapping the body changes the '
            'whole slot layout as well.',
      ),
      GuideBlock.tip(
        '两套体系别混：锦标赛战车的部件按「材料 + 星级」分 25 档（最高 6-26 级），'
            '终极联赛战车的部件按 R1-R6 分稀有度（最高 20 / 18 级）。',
        'Do not mix the two systems: Championship parts are tiered by "material + star" in 25 tiers (max level 6-26), '
            'while Ultimate League parts use R1-R6 rarities (max level 20 / 18).',
      ),
    ],
  ),
  GuideChapter(
    id: 'championship',
    titleZh: '锦标赛',
    titleEn: 'Championship',
    summaryZh: '内容整理中，后续补充',
    summaryEn: 'Coming soon',
    icon: Icons.workspace_premium,
    color: Colors.indigo,
    keywords: <String>['锦标赛', 'championship'],
  ),
  GuideChapter(
    id: 'ultimate_league',
    titleZh: '终极联赛',
    titleEn: 'Ultimate League',
    summaryZh: '内容整理中，后续补充',
    summaryEn: 'Coming soon',
    icon: Icons.leaderboard,
    color: Colors.deepPurple,
    keywords: <String>['终极联赛', 'ultimate league'],
  ),
  GuideChapter(
    id: 'grand_prix',
    titleZh: 'Grand Prix',
    titleEn: 'Grand Prix',
    summaryZh: '内容整理中，后续补充',
    summaryEn: 'Coming soon',
    icon: Icons.sports_motorsports,
    color: Colors.deepOrange,
    keywords: <String>['Grand Prix', 'gp', '大奖赛'],
  ),
  GuideChapter(
    id: 'all_star',
    titleZh: '全明星',
    titleEn: 'All Star',
    summaryZh: '内容整理中，后续补充',
    summaryEn: 'Coming soon',
    icon: Icons.star,
    color: Colors.amber,
    keywords: <String>['全明星', 'all star'],
  ),
  GuideChapter(
    id: 'gear_rush',
    titleZh: '齿轮奔袭',
    titleEn: 'Gear Rush',
    summaryZh: '内容整理中，后续补充',
    summaryEn: 'Coming soon',
    icon: Icons.settings_suggest,
    color: Colors.blueGrey,
    keywords: <String>['齿轮奔袭', 'gear', 'gear rush'],
  ),
  GuideChapter(
    id: 'giant_build',
    titleZh: '巨型建造',
    titleEn: 'Giant Build',
    summaryZh: '内容整理中，后续补充',
    summaryEn: 'Coming soon',
    icon: Icons.construction,
    color: Colors.brown,
    keywords: <String>['巨型建造', 'giant build'],
  ),
];
