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
  <String>['6', '铁制', '1 星', '6 级'],
  <String>['7', '铁制', '2 星', '11 级'],
  <String>['8', '铁制', '3 星', '16 级'],
  <String>['9', '铁制', '4 星', '21 级'],
  <String>['10', '铁制', '5 星', '26 级'],
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
  <String>['6', 'Iron', '1 star', 'Level 6'],
  <String>['7', 'Iron', '2 stars', 'Level 11'],
  <String>['8', 'Iron', '3 stars', 'Level 16'],
  <String>['9', 'Iron', '4 stars', 'Level 21'],
  <String>['10', 'Iron', '5 stars', 'Level 26'],
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
  <String>['6', '铁制 1 星', '285 / 8', '233 / 9', '180 / 10'],
  <String>['7', '铁制 2 星', '405 / 10', '345 / 11', '285 / 12'],
  <String>['8', '铁制 3 星', '555 / 12', '480 / 13', '405 / 14'],
  <String>['9', '铁制 4 星', '720 / 14', '645 / 15', '555 / 16'],
  <String>['10', '铁制 5 星', '915 / 16', '818 / 17', '720 / 18'],
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
  <String>['6', 'Iron 1 star', '285 / 8', '233 / 9', '180 / 10'],
  <String>['7', 'Iron 2 stars', '405 / 10', '345 / 11', '285 / 12'],
  <String>['8', 'Iron 3 stars', '555 / 12', '480 / 13', '405 / 14'],
  <String>['9', 'Iron 4 stars', '720 / 14', '645 / 15', '555 / 16'],
  <String>['10', 'Iron 5 stars', '915 / 16', '818 / 17', '720 / 18'],
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

/// 锦标赛战车：25 档武器的三种数值组合（每格 = 耗电 / ATK）
/// 组合 1 = 耗电与 ATK 最低，组合 3 = 耗电与 ATK 最高
const List<List<String>> _champWeaponRowsZh = <List<String>>[
  <String>['1', '木质 1 星', '4 / 20', '5 / 25', '6 / 30'],
  <String>['2', '木质 2 星', '5 / 30', '6 / 40', '7 / 50'],
  <String>['3', '木质 3 星', '6 / 50', '7 / 60', '8 / 70'],
  <String>['4', '木质 4 星', '7 / 70', '8 / 80', '9 / 90'],
  <String>['5', '木质 5 星', '8 / 90', '9 / 105', '10 / 120'],
  <String>['6', '铁制 1 星', '4 / 120', '5 / 155', '6 / 190'],
  <String>['7', '铁制 2 星', '5 / 190', '6 / 230', '7 / 270'],
  <String>['8', '铁制 3 星', '6 / 270', '7 / 320', '8 / 370'],
  <String>['9', '铁制 4 星', '7 / 370', '8 / 430', '9 / 480'],
  <String>['10', '铁制 5 星', '8 / 480', '9 / 545', '10 / 610'],
  <String>['11', '军用 1 星', '4 / 610', '5 / 765', '6 / 920'],
  <String>['12', '军用 2 星', '5 / 920', '6 / 1105', '7 / 1290'],
  <String>['13', '军用 3 星', '6 / 1290', '7 / 1505', '8 / 1720'],
  <String>['14', '军用 4 星', '7 / 1720', '8 / 1970', '9 / 2220'],
  <String>['15', '军用 5 星', '8 / 2220', '9 / 2500', '10 / 2780'],
  <String>['16', '黄金 1 星', '4 / 2780', '5 / 3475', '6 / 4170'],
  <String>['17', '黄金 2 星', '5 / 4170', '6 / 5005', '7 / 5840'],
  <String>['18', '黄金 3 星', '6 / 5840', '7 / 6815', '8 / 7790'],
  <String>['19', '黄金 4 星', '7 / 7790', '8 / 8905', '9 / 10020'],
  <String>['20', '黄金 5 星', '8 / 10020', '9 / 11280', '10 / 12530'],
  <String>['21', '碳钢 1 星', '4 / 12530', '5 / 15670', '6 / 18810'],
  <String>['22', '碳钢 2 星', '5 / 18810', '6 / 22580', '7 / 26350'],
  <String>['23', '碳钢 3 星', '6 / 26350', '7 / 30750', '8 / 35150'],
  <String>['24', '碳钢 4 星', '7 / 35150', '8 / 40170', '9 / 45200'],
  <String>['25', '碳钢 5 星', '8 / 45200', '9 / 50860', '10 / 56520'],
];

const List<List<String>> _champWeaponRowsEn = <List<String>>[
  <String>['1', 'Wood 1 star', '4 / 20', '5 / 25', '6 / 30'],
  <String>['2', 'Wood 2 stars', '5 / 30', '6 / 40', '7 / 50'],
  <String>['3', 'Wood 3 stars', '6 / 50', '7 / 60', '8 / 70'],
  <String>['4', 'Wood 4 stars', '7 / 70', '8 / 80', '9 / 90'],
  <String>['5', 'Wood 5 stars', '8 / 90', '9 / 105', '10 / 120'],
  <String>['6', 'Iron 1 star', '4 / 120', '5 / 155', '6 / 190'],
  <String>['7', 'Iron 2 stars', '5 / 190', '6 / 230', '7 / 270'],
  <String>['8', 'Iron 3 stars', '6 / 270', '7 / 320', '8 / 370'],
  <String>['9', 'Iron 4 stars', '7 / 370', '8 / 430', '9 / 480'],
  <String>['10', 'Iron 5 stars', '8 / 480', '9 / 545', '10 / 610'],
  <String>['11', 'Military 1 star', '4 / 610', '5 / 765', '6 / 920'],
  <String>['12', 'Military 2 stars', '5 / 920', '6 / 1105', '7 / 1290'],
  <String>['13', 'Military 3 stars', '6 / 1290', '7 / 1505', '8 / 1720'],
  <String>['14', 'Military 4 stars', '7 / 1720', '8 / 1970', '9 / 2220'],
  <String>['15', 'Military 5 stars', '8 / 2220', '9 / 2500', '10 / 2780'],
  <String>['16', 'Gold 1 star', '4 / 2780', '5 / 3475', '6 / 4170'],
  <String>['17', 'Gold 2 stars', '5 / 4170', '6 / 5005', '7 / 5840'],
  <String>['18', 'Gold 3 stars', '6 / 5840', '7 / 6815', '8 / 7790'],
  <String>['19', 'Gold 4 stars', '7 / 7790', '8 / 8905', '9 / 10020'],
  <String>['20', 'Gold 5 stars', '8 / 10020', '9 / 11280', '10 / 12530'],
  <String>['21', 'Carbon 1 star', '4 / 12530', '5 / 15670', '6 / 18810'],
  <String>['22', 'Carbon 2 stars', '5 / 18810', '6 / 22580', '7 / 26350'],
  <String>['23', 'Carbon 3 stars', '6 / 26350', '7 / 30750', '8 / 35150'],
  <String>['24', 'Carbon 4 stars', '7 / 35150', '8 / 40170', '9 / 45200'],
  <String>['25', 'Carbon 5 stars', '8 / 45200', '9 / 50860', '10 / 56520'],
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
  <String>['25', '26', '324'],
  <String>['26', '—', '350'],
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
  <String>['25', '26', '324'],
  <String>['26', '—', '350'],
];

/// 锦标赛战车：25 档车轮 HP / 随从 HP（各 3 种数值）与治疗量
const List<List<String>> _champWheelRowsZh = <List<String>>[
  <String>['1', '木质 1 星', '10 / 13 / 15', '23 / 23 / 23', '19'],
  <String>['2', '木质 2 星', '15 / 20 / 25', '38 / 30 / 23', '30'],
  <String>['3', '木质 3 星', '25 / 30 / 35', '53 / 45 / 38', '45'],
  <String>['4', '木质 4 星', '35 / 40 / 45', '68 / 60 / 53', '60'],
  <String>['5', '木质 5 星', '45 / 53 / 60', '90 / 79 / 68', '79'],
  <String>['6', '铁制 1 星', '60 / 78 / 95', '143 / 117 / 90', '116'],
  <String>['7', '铁制 2 星', '95 / 115 / 135', '203 / 173 / 143', '173'],
  <String>['8', '铁制 3 星', '135 / 160 / 185', '278 / 240 / 203', '240'],
  <String>['9', '铁制 4 星', '185 / 215 / 240', '360 / 323 / 278', '323'],
  <String>['10', '铁制 5 星', '240 / 273 / 305', '458 / 409 / 360', '409'],
  <String>['11', '军用 1 星', '305 / 383 / 460', '690 / 574 / 458', '574'],
  <String>['12', '军用 2 星', '460 / 553 / 645', '968 / 829 / 690', '829'],
  <String>['13', '军用 3 星', '645 / 753 / 860', '1290 / 1129 / 968', '1129'],
  <String>['14', '军用 4 星', '860 / 985 / 1110', '1665 / 1478 / 1290', '1478'],
  <String>['15', '军用 5 星', '1110 / 1250 / 1390', '2085 / 1875 / 1665', '1875'],
  <String>['16', '黄金 1 星', '1390 / 1738 / 2085', '3128 / 2607 / 2085', '2606'],
  <String>['17', '黄金 2 星', '2085 / 2503 / 2920', '4380 / 3754 / 3128', '3754'],
  <String>['18', '黄金 3 星', '2920 / 3408 / 3895', '5843 / 5112 / 4380', '5111'],
  <String>['19', '黄金 4 星', '3895 / 4453 / 5010', '7515 / 6679 / 5843', '6679'],
  <String>['20', '黄金 5 星', '5010 / 5640 / 6265', '9398 / 8460 / 7515', '8460'],
  <String>[
    '21',
    '碳钢 1 星',
    '6265 / 7835 / 9405',
    '14108 / 11753 / 9398',
    '11753',
  ],
  <String>[
    '22',
    '碳钢 2 星',
    '9405 / 11290 / 13175',
    '19763 / 16935 / 14108',
    '16935',
  ],
  <String>[
    '23',
    '碳钢 3 星',
    '13175 / 15375 / 17575',
    '26363 / 23063 / 19763',
    '23063',
  ],
  <String>[
    '24',
    '碳钢 4 星',
    '17575 / 20085 / 22600',
    '33900 / 30128 / 26363',
    '30128',
  ],
  <String>[
    '25',
    '碳钢 5 星',
    '22600 / 25430 / 28260',
    '42390 / 38145 / 33900',
    '38145',
  ],
];

const List<List<String>> _champWheelRowsEn = <List<String>>[
  <String>['1', 'Wood 1 star', '10 / 13 / 15', '23 / 23 / 23', '19'],
  <String>['2', 'Wood 2 stars', '15 / 20 / 25', '38 / 30 / 23', '30'],
  <String>['3', 'Wood 3 stars', '25 / 30 / 35', '53 / 45 / 38', '45'],
  <String>['4', 'Wood 4 stars', '35 / 40 / 45', '68 / 60 / 53', '60'],
  <String>['5', 'Wood 5 stars', '45 / 53 / 60', '90 / 79 / 68', '79'],
  <String>['6', 'Iron 1 star', '60 / 78 / 95', '143 / 117 / 90', '116'],
  <String>['7', 'Iron 2 stars', '95 / 115 / 135', '203 / 173 / 143', '173'],
  <String>['8', 'Iron 3 stars', '135 / 160 / 185', '278 / 240 / 203', '240'],
  <String>['9', 'Iron 4 stars', '185 / 215 / 240', '360 / 323 / 278', '323'],
  <String>['10', 'Iron 5 stars', '240 / 273 / 305', '458 / 409 / 360', '409'],
  <String>[
    '11',
    'Military 1 star',
    '305 / 383 / 460',
    '690 / 574 / 458',
    '574',
  ],
  <String>[
    '12',
    'Military 2 stars',
    '460 / 553 / 645',
    '968 / 829 / 690',
    '829',
  ],
  <String>[
    '13',
    'Military 3 stars',
    '645 / 753 / 860',
    '1290 / 1129 / 968',
    '1129',
  ],
  <String>[
    '14',
    'Military 4 stars',
    '860 / 985 / 1110',
    '1665 / 1478 / 1290',
    '1478',
  ],
  <String>[
    '15',
    'Military 5 stars',
    '1110 / 1250 / 1390',
    '2085 / 1875 / 1665',
    '1875',
  ],
  <String>[
    '16',
    'Gold 1 star',
    '1390 / 1738 / 2085',
    '3128 / 2607 / 2085',
    '2606',
  ],
  <String>[
    '17',
    'Gold 2 stars',
    '2085 / 2503 / 2920',
    '4380 / 3754 / 3128',
    '3754',
  ],
  <String>[
    '18',
    'Gold 3 stars',
    '2920 / 3408 / 3895',
    '5843 / 5112 / 4380',
    '5111',
  ],
  <String>[
    '19',
    'Gold 4 stars',
    '3895 / 4453 / 5010',
    '7515 / 6679 / 5843',
    '6679',
  ],
  <String>[
    '20',
    'Gold 5 stars',
    '5010 / 5640 / 6265',
    '9398 / 8460 / 7515',
    '8460',
  ],
  <String>[
    '21',
    'Carbon 1 star',
    '6265 / 7835 / 9405',
    '14108 / 11753 / 9398',
    '11753',
  ],
  <String>[
    '22',
    'Carbon 2 stars',
    '9405 / 11290 / 13175',
    '19763 / 16935 / 14108',
    '16935',
  ],
  <String>[
    '23',
    'Carbon 3 stars',
    '13175 / 15375 / 17575',
    '26363 / 23063 / 19763',
    '23063',
  ],
  <String>[
    '24',
    'Carbon 4 stars',
    '17575 / 20085 / 22600',
    '33900 / 30128 / 26363',
    '30128',
  ],
  <String>[
    '25',
    'Carbon 5 stars',
    '22600 / 25430 / 28260',
    '42390 / 38145 / 33900',
    '38145',
  ],
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
        '锦标赛战车：25 档与等级上限、8 种常见车身、车身 / 武器 / 车轮 / 配件 / 随从的数值表，以及 HP 与融合的计算式',
    summaryEn:
        'The Championship car: the 25 tiers and level caps, the 8 common bodies, the value tables for body / weapon / wheel / gadget / minion, and the formulas for HP and fusion',
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
      'HP 倍数',
      '数值组合',
      '挂点',
      '插槽',
      '融合',
      '回收',
      '经验',
      '魔法部件',
      '传奇部件',
      '技能',
      '段位',
      '威望',
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
      '铁制',
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
      'iron',
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
      'fusion',
      'prestige',
      'stage',
    ],
    blocks: <GuideBlock>[
      GuideBlock.text(
        '锦标赛战车由 **1 个车身** 与若干 **武器 / 车轮 / 配件** 组成。部件按**材质**分五个系列：'
            '**木质、铁制、军用、黄金、碳钢** —— 这里的材质指部件本身的材质，例如「1 星铁制车身」'
            '指的就是铁制材质的 1 星车身。车身提供供电，并决定整车的基础 HP 与插槽。',
        'A Championship car consists of **one body** plus a number of **weapons / wheels / gadgets**. Parts come in '
            'five material series: **Wood, Iron, Military, Gold and Carbon** — the material of the part itself, e.g. a '
            '"1-star iron body". The body supplies power and decides the car\'s base HP and slots.',
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
        '例如第 6 档（1 星铁制）的最高等级同样只有 6 级 —— 等级上限按**星级**计算，与**档位**无关。',
        'For example tier 6 (1-star iron) also caps at level 6 — the cap follows the **star**, not the tier.',
      ),
      // ---------- 3. 车身与 HP 倍数 ----------
      GuideBlock.heading('车身与 HP 倍数', 'Bodies and the HP multiplier'),
      GuideBlock.text(
        '车身彼此只差两点：**HP 倍数**与**车身技能**。HP 倍数**只作用在 HP 上**，不影响供电。'
            '下表已收录 **13 种**车身：前 8 种是**常见车身**（有专属技能），后 5 种是**特殊车身**（无专属技能）；'
            '另有一些特殊车身尚未收录。',
        'Bodies differ in two things only: the **HP multiplier** and the **body skill**. The multiplier **affects HP '
            'only**, never the supply. The table covers **13 bodies**: the first 8 are the **common bodies** (each with '
            'its own skills) and the last 5 are **special bodies** (no skills). A few more special bodies are not '
            'covered yet.',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['车身', 'HP 倍数', '电力技能', 'HP 技能'],
          headEn: <String>['Body', 'HP multiplier', 'Power skill', 'HP skill'],
          rowsZh: <List<String>>[
            <String>['经典', '× 1.00', '+ 3', '+ 30%'],
            <String>['滑头', '× 1.33', '+ 3', '+ 30%'],
            <String>['磐石', '× 1.67', '+ 3', '+ 30%'],
            <String>['巨鲸', '× 1.67', '—', '+ 30%'],
            <String>['金字塔', '× 1.67', '—', '+ 30%'],
            <String>['浪板', '× 1.83', '+ 3', '+ 30%'],
            <String>['泰坦', '× 2.00', '+ 3', '+ 30%'],
            <String>['钻石', '× 2.00', '—', '无'],
            <String>['蝎', '× 2.00', '—', '无'],
            <String>['箭', '× 2.00', '—', '无'],
            <String>['向量', '× 2.17', '—', '无'],
            <String>['虎鲸', '× 2.17', '—', '无'],
            <String>['圣骑士', '× 2.33', '—', '无'],
          ],
          rowsEn: <List<String>>[
            <String>['Classic', 'x 1.00', '+ 3', '+ 30%'],
            <String>['Sneaky', 'x 1.33', '+ 3', '+ 30%'],
            <String>['Boulder', 'x 1.67', '+ 3', '+ 30%'],
            <String>['Whale', 'x 1.67', '—', '+ 30%'],
            <String>['Pyramid', 'x 1.67', '—', '+ 30%'],
            <String>['Surfer', 'x 1.83', '+ 3', '+ 30%'],
            <String>['Titan', 'x 2.00', '+ 3', '+ 30%'],
            <String>['Diamond', 'x 2.00', '—', 'none'],
            <String>['Scorpion', 'x 2.00', '—', 'none'],
            <String>['Arrow', 'x 2.00', '—', 'none'],
            <String>['Vector', 'x 2.17', '—', 'none'],
            <String>['Orca', 'x 2.17', '—', 'none'],
            <String>['Paladin', 'x 2.33', '—', 'none'],
          ],
        ),
      ),
      GuideBlock.tip(
        '表中技能数值均为满级（电力技能 +3、HP 技能 +30%）；未学习时按 0 计算。解锁条件见第 9 节。'
            'HP 倍数由「基础 HP × 0.6 × 倍数 ＝ 1 级显示 HP」反推（特殊车身那个等式里不带 HP 技能）。',
        'Both skill columns are maxed values (power +3, HP +30%); treat them as 0 when not learned. See section 9 '
            'for the unlock requirements. The HP multiplier was derived from "base HP x 0.6 x multiplier = displayed HP '
            'at level 1" (for special bodies that equation has no HP skill in it).',
      ),
      // ---------- 4. 车身供电 ----------
      GuideBlock.heading('车身供电与基础 HP', 'Body supply and base HP'),
      GuideBlock.text(
        '同一档位的车身有 **3 种数值组合**，游戏只会把其中**任意一种**分给具体车身（同一档位的各种车身'
            '共用这 3 种组合，每个车身拿到哪一种由游戏随机决定）。'
            '**组合 1 = HP 最高、供电最低，组合 3 = HP 最低、供电最高**。'
            '表中每格为「**基础 HP / 供电**」，基础 HP 是计算车身 HP 的原始数值（算法见第 7 节）。',
        'Bodies of the same tier come in **3 stat combinations**, and a body only ever gets **one of them** (the 8 '
            'bodies of a tier share these 3 combinations, and which one a given body gets is decided at random). '
            '**Combination 1 has the most HP and the least supply; combination 3 the least HP and the most supply.** '
            'Each cell reads "**base HP / supply**"; base HP is the raw value used to compute body HP (see section 7).',
      ),
      GuideBlock.table(
        GuideTable(
          groupZh: <String>['', '', 'HP / 供电', '', ''],
          groupEn: <String>['', '', 'HP / supply', '', ''],
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
              '**铁制 / 军用 / 黄金 / 碳钢 的供电完全相同**（同星级同组合）',
          'The **supply** varies with the **star and the combination** only: wood is lower than the other four '
              'materials, and **Iron / Military / Gold / Carbon have exactly the same supply** (same star, same combination)',
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
      // ---------- 5. 武器 ----------
      GuideBlock.heading('武器：耗电与 ATK', 'Weapons: drain and ATK'),
      GuideBlock.text(
        '武器的耗电只由**星级**决定（同一星级的所有材质相同）；ATK 则同时取决于材质与星级。'
            '同一档位有 3 种数值组合，**耗电越高、ATK 越高**，一一对应；'
            '表中每格为「**耗电 / ATK**」，组合 1 到 3 依次是耗电与 ATK 由低到高的三组。',
        'A weapon\'s drain depends on its **star** only (all materials share it), while its ATK depends on both the '
            'material and the star. Each tier has 3 combinations, and **the higher the drain, the higher the ATK** — '
            'the two line up one to one. Each cell reads "**drain / ATK**", with combinations 1 to 3 running from the '
            'lowest drain and ATK to the highest.',
      ),
      GuideBlock.table(
        GuideTable(
          groupZh: <String>['', '', '耗电 / ATK', '', ''],
          groupEn: <String>['', '', 'Drain / ATK', '', ''],
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
          '同一星级、同一耗电下，不同武器的 ATK 也可能不同；需要精确数值时查部件图鉴',
          'At the same star and drain, different weapons can still differ in ATK — check the part list for exact values',
        ),
      ]),
      // ---------- 6. 车轮、随从与配件 ----------
      GuideBlock.heading('车轮、随从与配件', 'Wheels, minions and gadgets'),
      GuideBlock.text(
        '车轮与随从提供 HP，治疗类配件提供治疗量，同样按档位变化；'
            '配件（13 种）的耗电只看星级，HP 与车轮是同一套数值。',
        'Wheels and minions give HP, and healing gadgets give a heal amount, all varying by tier. '
            'The 13 gadgets only vary in drain by star, and their HP uses the same values as wheels.',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>[
            '档位',
            '部件材质 / 星级',
            '车轮 HP（3 种数值）',
            '随从 HP（3 种数值）',
            '治疗量',
          ],
          headEn: <String>[
            'Tier',
            'Material / star',
            'Wheel HP (3 values)',
            'Minion HP (3 values)',
            'Heal amount',
          ],
          rowsZh: _champWheelRowsZh,
          rowsEn: _champWheelRowsEn,
        ),
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['星级', '13 种配件的耗电'],
          headEn: <String>['Star', 'Drain of the 13 gadgets'],
          rowsZh: <List<String>>[
            <String>[
              '1 - 2 星',
              '2 / 1 / 1 / 2 / 2 / 2 / 1 / 1 / 1 / 1 / 1 / 0 / 0',
            ],
            <String>[
              '3 - 5 星',
              '3 / 2 / 2 / 3 / 3 / 3 / 2 / 2 / 2 / 2 / 2 / 0 / 0',
            ],
          ],
          rowsEn: <List<String>>[
            <String>[
              '1 - 2 stars',
              '2 / 1 / 1 / 2 / 2 / 2 / 1 / 1 / 1 / 1 / 1 / 0 / 0',
            ],
            <String>[
              '3 - 5 stars',
              '3 / 2 / 2 / 3 / 3 / 3 / 2 / 2 / 2 / 2 / 2 / 0 / 0',
            ],
          ],
        ),
      ),
      GuideBlock.tip(
        '配件耗电一栏里的 **0 表示该配件不耗电**；配件的 HP 直接查上表的「车轮 HP」列。',
        'A **0** in the gadget drain row means that gadget consumes no power; for a gadget\'s HP use the "wheel HP" '
            'column of the table above.',
      ),
      GuideBlock.text(
        '**每级加成**（升级时每一级固定提升的量，按材质取值）：',
        '**Per-level bonus** (the fixed gain for each level, by material):',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['数值', '木质', '铁制', '军用', '黄金', '碳钢'],
          headEn: <String>[
            'Value',
            'Wood',
            'Iron',
            'Military',
            'Gold',
            'Carbon',
          ],
          rowsZh: <List<String>>[
            <String>['车身 HP', '6', '30', '150', '750', '3000'],
            <String>['武器 ATK', '4', '20', '100', '500', '2000'],
            <String>['车轮 HP', '2', '10', '50', '250', '1000'],
            <String>['配件 HP', '2', '10', '50', '250', '1000'],
            <String>['治疗量', '3', '15', '75', '375', '1500'],
            <String>['随从 HP', '38', '165', '833', '3960', '16898'],
          ],
          rowsEn: <List<String>>[
            <String>['Body HP', '6', '30', '150', '750', '3000'],
            <String>['Weapon ATK', '4', '20', '100', '500', '2000'],
            <String>['Wheel HP', '2', '10', '50', '250', '1000'],
            <String>['Gadget HP', '2', '10', '50', '250', '1000'],
            <String>['Heal amount', '3', '15', '75', '375', '1500'],
            <String>['Minion HP', '38', '165', '833', '3960', '16898'],
          ],
        ),
      ),
      GuideBlock.tip(
        '车身已验证：实际每级提升 ＝ 表中数值 × 0.6（例：铁制 30 × 0.6 ＝ **每级 +18 HP**）。'
            '其余部件推测同样 × 0.6，尚未验证。',
        'Verified for bodies: the real per-level gain is the table value x 0.6 (e.g. iron 30 x 0.6 = **+18 HP per '
            'level**). The other part types are assumed to follow the same x 0.6 rule, but that is unverified.',
      ),
      // ---------- 7. 车身 HP ----------
      GuideBlock.heading('车身 HP 的计算', 'How body HP is computed'),
      GuideBlock.text(
        '完整公式（适用于任意档位、任意车身、任意等级）：',
        'The full formula (valid for any tier, any body and any level):',
      ),
      GuideBlock.text(
        '**车身 HP ＝ 向上取整（基础 HP × 0.6 ×（1 ＋ HP 技能加成）× HP 倍数）'
            '＋ 0.6 × 每级 HP 加成 ×（等级 － 1）**',
        '**Body HP = round-up( base HP x 0.6 x (1 + HP skill) x HP multiplier ) '
            '+ 0.6 x HP per level x (level - 1)**',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['公式中的项', '取值'],
          headEn: <String>['Term', 'Value'],
          rowsZh: <List<String>>[
            <String>['基础 HP', '该档位、该数值组合的原始数值，查第 4 节的表（例：铁制 4 星、HP 居中 ＝ 645）'],
            <String>['0.6', '固定系数'],
            <String>['HP 技能加成', '满级 0.3；未学习 0'],
            <String>[
              'HP 倍数',
              '见第 3 节：经典 1.00、滑头 1.33、磐石 / 巨鲸 / 金字塔 1.67、浪板 1.83、泰坦 / 钻石 2.00',
            ],
            <String>['每级 HP 加成', '见第 6 节的「每级加成」表（车身 HP 一行）；实际值再 × 0.6'],
            <String>['等级', '当前等级；1 级时公式第二项为 0'],
          ],
          rowsEn: <List<String>>[
            <String>[
              'Base HP',
              'The raw value of that tier and stat combination — see the table in section 4 (e.g. iron 4-star, middle HP = 645)',
            ],
            <String>['0.6', 'A fixed factor'],
            <String>['HP skill', '0.3 at max; 0 if not learned'],
            <String>[
              'HP multiplier',
              'See section 3: Classic 1.00, Sneaky 1.33, Boulder / Whale / Pyramid 1.67, Surfer 1.83, Titan / Diamond 2.00',
            ],
            <String>[
              'HP per level',
              'See the per-level bonus table in section 6 (the Body HP row); multiply by 0.6 for the real value',
            ],
            <String>['Level', 'Current level; the second term is 0 at level 1'],
          ],
        ),
      ),
      GuideBlock.tip(
        '例：铁制 4 星、HP 居中、经典（倍数 1.00）、HP 技能满级、1 级 → '
            '向上取整(645 × 0.6 × 1.3 × 1.00) ＝ **504 HP**；升到 4 级再加 3 × 18 ＝ 54，即 558 HP。',
        'Example: iron 4-star, middle HP, Classic (multiplier 1.00), maxed HP skill, level 1 → '
            'round-up(645 x 0.6 x 1.3 x 1.00) = **504 HP**; at level 4 add 3 x 18 = 54, giving 558 HP.',
      ),
      GuideBlock.tip(
        '**升级只增加 HP，供电不变**（已实测确认）；等级上限见第 2 节。',
        '**Leveling only adds HP — the supply never changes** (confirmed in game); see section 2 for the level cap.',
      ),
      // ---------- 8. 升级与融合 ----------
      GuideBlock.heading('升级与融合', 'Upgrading and fusion'),
      GuideBlock.text(
        '升级通过**融合**完成：把其他部件融合进目标部件以换取经验。**不要求材质相同**，'
            '但不同材质之间有一个固定的兑换比例，跨材质融合的收益差别很大。',
        'Upgrading is done by **fusion**: other parts are fused into the target part for XP. '
            '**The materials do not have to match**, but different materials have a fixed exchange rate, so the '
            'result varies a lot.',
      ),
      GuideBlock.text(
        '完整公式（适用于任意材质、任意星级、任意等级）：',
        'The full formula (valid for any material, star and level):',
      ),
      GuideBlock.text(
        '**融合获得经验 ＝（1 ＋ 融合技能加成）×（0.7 × 被融合部件已投入经验 ＋ 固有价值）'
            '× k（被融合部件材质）÷ k（目标部件材质）**',
        '**XP gained = (1 + fusion skill) x (0.7 x XP already invested in the fused part + intrinsic value) '
            'x k(fused part material) ÷ k(target material)**',
      ),
      GuideBlock.table(
        GuideTable(
          headZh: <String>['公式中的项', '取值'],
          headEn: <String>['Term', 'Value'],
          rowsZh: <List<String>>[
            <String>['被融合部件已投入经验', '该部件升级时已消耗的经验（按等级与当前进度换算）'],
            <String>['0.7', '固定回收比例'],
            <String>['固有价值', '只看星级：1 星 1、2 星 1.6、3 星 2.6、4 星 4.2、5 星 6.8'],
            <String>['融合技能加成', '满级 0.3（威望 5 解锁）；未学习 0'],
            <String>['k（材质）', '木质 1、铁制 13、军用 144、黄金 1597、碳钢 17711'],
            <String>['魔法 / 传奇部件', '分别为普通部件的 2 倍 / 4 倍，且不受目标部件材质影响'],
          ],
          rowsEn: <List<String>>[
            <String>[
              'XP already invested',
              'The XP already spent leveling the fused part (from its level and progress)',
            ],
            <String>['0.7', 'A fixed recovery ratio'],
            <String>[
              'Intrinsic value',
              'By star only: 1★ 1, 2★ 1.6, 3★ 2.6, 4★ 4.2, 5★ 6.8',
            ],
            <String>[
              'Fusion skill',
              '0.3 at max (unlocked at prestige 5); 0 if not learned',
            ],
            <String>[
              'k(material)',
              'Wood 1, Iron 13, Military 144, Gold 1597, Carbon 17711',
            ],
            <String>[
              'Magic / legendary',
              '2x / 4x the common value, and unaffected by the target\'s material',
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
        '表中为**基础经验**，实际数值 ＝ 表中数字 × k（目标部件材质）。木质 k ＝ 1，木质部件可直接按表使用。',
        'The table gives **base XP**; the real cost is the value x k (the target\'s material). Wood has k = 1, so for '
            'wood the table can be used as is.',
      ),
      GuideBlock.bullets(<GuideBullet>[
        GuideBullet(
          '用**已升级过的部件**作融合材料更划算：它能回收 70% 的已投入经验，另加固有价值',
          'Fusing an **already-leveled part** is more efficient: it returns 70% of its invested XP plus its intrinsic value',
        ),
        GuideBullet(
          '用低材质部件融合高材质目标收益极低：铁制 → 军用只剩 13 ÷ 144 ≈ 9%',
          'Fusing a low-material part into a higher-material target is very inefficient: iron → military keeps only 13 ÷ 144 ≈ 9%',
        ),
        GuideBullet(
          '被融合部件的材质、星级、等级均不受限制；目标部件自身是否为魔法 / 传奇不影响获得经验',
          'The fused part may be of any material, star and level; whether the target itself is magic / legendary does not change the XP gained',
        ),
      ]),
      // ---------- 9. 技能解锁 ----------
      GuideBlock.heading('车身技能解锁条件', 'When body skills unlock'),
      GuideBlock.text(
        '车身技能按**段位**（stage）或**威望**（prestige，转生次数）解锁：',
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
            <String>['巨鲸', '—', '威望 1'],
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
          headZh: <String>['技能', '数值', '技能点', '适用范围'],
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
              '武器伤害',
              '+10% / +20% / +30%',
              '1 / 2 / 3',
              '7 种武器类型：BLADES / CHAINSAWS / DOUBLE_ROCKETS / DRILLS / LASERS / ROCKETS / STINGERS',
            ],
            <String>[
              '车轮 / 配件 HP',
              '+15% / +30% / +45%',
              '1 / 2 / 3',
              '11 种车轮 / 配件类：BOOSTERS / KNOBS / TIRES / STICKY_TIRES / STICKY_ROLLERS / ROLLERS / BIGFOOTS / SCOOTERS / SCOOPS / REPULSES / BACKPEDALS',
            ],
            <String>['融合经验（威望 5）', '+10% / +20% / +30%', '—', '融合获得的经验'],
            <String>[
              '融合折扣（威望 5）',
              '−10% / −20% / −30%',
              '—',
              '融合的花费（计算方式尚未确认）',
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
              'Weapon damage',
              '+10% / +20% / +30%',
              '1 / 2 / 3',
              '7 weapon types: BLADES / CHAINSAWS / DOUBLE_ROCKETS / DRILLS / LASERS / ROCKETS / STINGERS',
            ],
            <String>[
              'Wheel / gadget HP',
              '+15% / +30% / +45%',
              '1 / 2 / 3',
              '11 wheel / gadget families: BOOSTERS / KNOBS / TIRES / STICKY_TIRES / STICKY_ROLLERS / ROLLERS / BIGFOOTS / SCOOTERS / SCOOPS / REPULSES / BACKPEDALS',
            ],
            <String>[
              'Fusion XP (prestige 5)',
              '+10% / +20% / +30%',
              '—',
              'XP gained from fusion',
            ],
            <String>[
              'Fusion discount (prestige 5)',
              '−10% / −20% / −30%',
              '—',
              'the cost of fusion (its formula is not confirmed)',
            ],
          ],
        ),
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
