import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'activity_calendar_screen.dart'; // kActivities：活动图标（示意图用）
import 'life_sim/life_sim_data.dart'; // 帮派/城市之王常量：示意图跟着数值一起变
import 'mechanism_guide_data.dart';
import 'parts_data.dart';

/// 机制指南：游戏玩法的**文字版 wiki + 配图**（主菜单 → 数据查询 → 机制指南）
///
/// 内容全部来自 [kGuideChapters]（`mechanism_guide_data.dart`），
/// 本文件只负责：目录页（搜索 + 章节卡片）、章节页（内容块渲染）、配图（示意图）。
/// 以后加新玩法机制，只需要往数据文件里加 [GuideChapter]，不用动界面代码。
class MechanismGuideScreen extends StatefulWidget {
  final String locale;
  final String server;
  const MechanismGuideScreen({
    super.key,
    this.locale = 'zh',
    this.server = 'cn',
  });

  @override
  State<MechanismGuideScreen> createState() => _MechanismGuideScreenState();
}

class _MechanismGuideScreenState extends State<MechanismGuideScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  bool get _isZh => widget.locale == 'zh';
  String _t(String zh, String en) => _isZh ? zh : en;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chapters = kGuideChapters.where((c) => c.matches(_query)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('机制指南', 'Mechanic Guide')),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, {'locale': widget.locale}),
          tooltip: _t('返回主菜单', 'Back'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          _buildIntro(isDark),
          const SizedBox(height: 10),
          _buildSearch(isDark),
          const SizedBox(height: 10),
          if (chapters.isEmpty)
            _buildEmpty(isDark)
          else
            for (final c in chapters) ...<Widget>[
              _buildChapterCard(c, isDark),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildIntro(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF241B3A) : Colors.deepPurple[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.menu_book,
              size: 18,
              color: isDark ? Colors.deepPurple[200] : Colors.deepPurple[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _t(
                '游戏玩法的文字版说明，一个玩法一章，配示意图。\n'
                '内容会持续补充（帮派联赛、城市之王、活动周期、道具与工具箱…）。',
                'Text wiki of game mechanics: one chapter per mechanic, with diagrams.\n'
                'More chapters are being added (gang league, city king, activities, items...).',
              ),
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isDark ? Colors.deepPurple[100] : Colors.deepPurple[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(bool isDark) {
    return TextField(
      controller: _search,
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _search.clear();
                  setState(() => _query = '');
                },
              ),
        hintText: _t('搜索机制 / 关键词', 'Search mechanics'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.auto_stories,
              size: 40, color: isDark ? Colors.white38 : Colors.black26),
          const SizedBox(height: 12),
          Text(
            _query.isEmpty
                ? _t('内容整理中', 'Content in progress')
                : _t('没有找到相关章节', 'No matching chapter'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _query.isEmpty
                ? _t('这一版先把模块搭起来：每个玩法一章，配文字说明与示意图，'
                    '后续填充。', 'Module scaffolded first; chapters will be filled in later.')
                : _t('换个关键词试试，或清空搜索框看全部章节。',
                    'Try another keyword, or clear the search.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterCard(GuideChapter c, bool isDark) {
    final count = c.blocks.length;
    final sectionCount = c.sections.length;
    return Material(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuideChapterScreen(
              chapter: c,
              locale: widget.locale,
              server: widget.server,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.black12,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.color.withValues(alpha: isDark ? 0.28 : 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(c.icon, size: 20, color: c.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      c.title(widget.locale),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.summary(widget.locale),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sectionCount > 0
                          ? (_isZh ? '$sectionCount 个小节' : '$sectionCount sections')
                          : (_isZh ? '$count 个段落' : '$count blocks'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: isDark ? Colors.white38 : Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 章节页 ====================
/// 单章内容（wiki 式）：顶部是「章内目录」，下面按小节渲染
/// 段落 / 要点 / 提示 / 配图 / 表格；点目录可以跳到对应小节。
class GuideChapterScreen extends StatefulWidget {
  final GuideChapter chapter;
  final String locale;
  final String server;
  const GuideChapterScreen({
    super.key,
    required this.chapter,
    this.locale = 'zh',
    this.server = 'cn',
  });

  @override
  State<GuideChapterScreen> createState() => _GuideChapterScreenState();
}

class _GuideChapterScreenState extends State<GuideChapterScreen> {
  GuideChapter get chapter => widget.chapter;
  String get locale => widget.locale;
  String get server => widget.server;

  /// 每个块的 key（目录跳转用）
  final Map<int, GlobalKey> _blockKeys = <int, GlobalKey>{};

  String _t(String zh, String en) => locale == 'zh' ? zh : en;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sections = chapter.sections;
    return Scaffold(
      appBar: AppBar(
        title: Text(chapter.title(locale)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, {'locale': locale}),
          tooltip: _t('返回目录', 'Back'),
        ),
      ),
      // 用 Column（而不是 ListView）一次建好整章，目录跳转才能立刻定位
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (sections.length > 1) ...<Widget>[
              _buildToc(sections, isDark),
              const SizedBox(height: 14),
            ],
            for (var i = 0; i < chapter.blocks.length; i++) ...<Widget>[
              KeyedSubtree(
                key: _blockKeys.putIfAbsent(i, () => GlobalKey()),
                child: _buildBlock(chapter.blocks[i], isDark),
              ),
              SizedBox(height: i == chapter.blocks.length - 1 ? 8 : 12),
            ],
          ],
        ),
      ),
    );
  }

  /// 章内目录，点击跳到对应小节
  Widget _buildToc(List<(int, String, String)> sections, bool isDark) {
    final zh = locale == 'zh';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.list_alt, size: 15, color: chapter.color),
              const SizedBox(width: 6),
              Text(
                zh ? '目录' : 'Contents',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: chapter.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < sections.length; i++)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => _jumpTo(sections[i].$1),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 20,
                      child: Text(
                        '${i + 1}.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        zh ? sections[i].$2 : sections[i].$3,
                        style: const TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _jumpTo(int blockIndex) async {
    final ctx = _blockKeys[blockIndex]?.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: 0.02,
    );
  }

  Widget _buildBlock(GuideBlock b, bool isDark) {
    final parts = <Widget>[];

    if (b.headingZh != null) {
      parts.add(Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 15,
            decoration: BoxDecoration(
              color: chapter.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _t(b.headingZh!, b.headingEn ?? b.headingZh!),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ));
    }

    if (b.textZh != null) {
      parts.add(Text(
        _t(b.textZh!, b.textEn ?? b.textZh!),
        style: const TextStyle(fontSize: 13, height: 1.6),
      ));
    }

    if (b.bullets.isNotEmpty) {
      if (parts.isNotEmpty) parts.add(const SizedBox(height: 8));
      parts.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final item in b.bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: chapter.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _t(item.zh, item.en),
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ));
    }

    if (b.table != null) {
      if (parts.isNotEmpty) parts.add(const SizedBox(height: 8));
      parts.add(_buildTable(b.table!, isDark));
    }

    if (b.tipZh != null) {
      if (parts.isNotEmpty) parts.add(const SizedBox(height: 8));
      parts.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2418) : Colors.amber[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.amber.shade700 : Colors.amber.shade200,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.lightbulb_outline,
                size: 16,
                color: isDark ? Colors.amber[200] : Colors.amber[800]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _t(b.tipZh!, b.tipEn ?? b.tipZh!),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: isDark ? Colors.amber[100] : Colors.amber[900],
                ),
              ),
            ),
          ],
        ),
      ));
    }

    if (b.figures.isNotEmpty) {
      if (parts.isNotEmpty) parts.add(const SizedBox(height: 10));
      for (final f in b.figures) {
        parts.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _FigureFrame(
            figure: f,
            locale: locale,
            server: server,
            isDark: isDark,
          ),
        ));
      }
    }

    if (parts.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: parts);
  }

  /// 表格：列宽自适应内容，太宽时可以左右滑
  Widget _buildTable(GuideTable t, bool isDark) {
    final zh = locale == 'zh';
    final head = zh ? t.headZh : t.headEn;
    final rows = zh ? t.rowsZh : t.rowsEn;
    final borderColor = isDark ? Colors.white24 : Colors.black12;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: borderColor, width: 0.7),
        children: <TableRow>[
          TableRow(
            decoration: BoxDecoration(
              color: chapter.color.withValues(alpha: isDark ? 0.24 : 0.10),
            ),
            children: <Widget>[
              for (final h in head) _cell(h, isDark, header: true),
            ],
          ),
          for (final r in rows)
            TableRow(
              children: <Widget>[
                for (final c in r) _cell(c, isDark),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(String s, bool isDark, {bool header = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Text(
        s,
        style: TextStyle(
          fontSize: 11,
          height: 1.3,
          fontWeight: header ? FontWeight.bold : FontWeight.normal,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }
}

// ==================== 配图 ====================
/// 配图外框：浅底 + 边框 + 图 + 图注
class _FigureFrame extends StatelessWidget {
  final GuideFigure figure;
  final String locale;
  final String server;
  final bool isDark;
  const _FigureFrame({
    required this.figure,
    required this.locale,
    required this.server,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191919) : const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
      ),
      child: Column(
        children: <Widget>[
          buildGuideFigure(figure,
              locale: locale, server: server, isDark: isDark),
          const SizedBox(height: 8),
          Text(
            locale == 'zh' ? figure.captionZh : figure.captionEn,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

/// 渲染一张配图（数据层只存 asset 路径或示意图 id，具体画法都在这里）
Widget buildGuideFigure(
  GuideFigure figure, {
  required String locale,
  required String server,
  required bool isDark,
}) {
  if (figure.asset != null) {
    return Image.asset(
      figure.asset!,
      height: 110,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _MissingFigure(text: figure.asset!),
    );
  }
  switch (figure.diagram) {
    case 'carLayout':
      return _CarLayoutFigure(locale: locale, isDark: isDark);
    case 'partSample':
      return _PartSampleFigure(locale: locale, server: server);
    case 'sponsors':
      return const _SponsorFigure();
    case 'activityIcons':
      return _ActivityIconsFigure(locale: locale);
    case 'jokerTiers':
      return const _JokerTiersFigure();
    case 'chestTypes':
      return _ChestTypesFigure(locale: locale);
    case 'battleBuildings':
      return _BattleBuildingsFigure(locale: locale, isDark: isDark);
    case 'gangTiers':
      return _GangTiersFigure(locale: locale, isDark: isDark);
    case 'seasonFlow':
      return _SeasonFlowFigure(locale: locale, isDark: isDark);
    default:
      return _MissingFigure(text: '${figure.diagram}');
  }
}

/// 示意图 id 写错 / 图片缺失时的占位
class _MissingFigure extends StatelessWidget {
  final String text;
  const _MissingFigure({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black26,
          style: BorderStyle.solid,
        ),
      ),
      child: Text(
        '缺失配图：$text',
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      ),
    );
  }
}

/// 车辆结构示意图：车身 / 特殊武器 / 武器 / 车轮 / 配件（颜色与「部件图鉴」一致）
class _CarLayoutFigure extends StatelessWidget {
  final String locale;
  final bool isDark;
  const _CarLayoutFigure({required this.locale, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 340 / 176,
      child: CustomPaint(
        painter: _CarLayoutPainter(zh: locale == 'zh', isDark: isDark),
      ),
    );
  }
}

class _CarLayoutPainter extends CustomPainter {
  final bool zh;
  final bool isDark;
  _CarLayoutPainter({required this.zh, required this.isDark});

  static const double _w = 340;
  static const double _h = 176;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _w, size.height / _h);

    final labelColor = isDark ? Colors.white70 : Colors.black87;

    // 车身
    final body = Rect.fromCenter(
        center: const Offset(170, 88), width: 132, height: 48);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(12)),
      Paint()..color = Colors.orange.withValues(alpha: 0.85),
    );
    _text(canvas, zh ? '车身' : 'Body', const Offset(170, 82), Colors.white,
        center: true);

    // 特殊武器（棕菱形）
    _diamond(canvas, const Offset(170, 26), 14, Colors.brown.withValues(alpha: 0.9));
    _text(canvas, zh ? '特殊武器' : 'Special', const Offset(170, 48), labelColor,
        center: true);

    // 武器（红六边形）
    for (final dx in <double>[-84, 84]) {
      _hexagon(canvas, Offset(170 + dx, 34), 15,
          Colors.red.withValues(alpha: 0.9));
      _text(canvas, zh ? '武器' : 'Weapon', Offset(170 + dx, 56), labelColor,
          center: true);
    }

    // 配件（紫方块）
    for (final dx in <double>[-118, 118]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(170 + dx, 110), width: 26, height: 26),
          const Radius.circular(4),
        ),
        Paint()..color = Colors.purple.withValues(alpha: 0.9),
      );
      _text(canvas, zh ? '配件' : 'Gadget', Offset(170 + dx, 130), labelColor,
          center: true);
    }

    // 车轮（绿圆形）
    for (final dx in <double>[-46, 46]) {
      canvas.drawCircle(Offset(170 + dx, 142), 17,
          Paint()..color = Colors.green.withValues(alpha: 0.9));
      _text(canvas, zh ? '车轮' : 'Wheel', Offset(170 + dx, 146), Colors.white,
          center: true);
    }

    // 电力说明
    _text(canvas, zh ? '电力 ∑ ≤ 上限' : 'Power ∑ ≤ limit',
        const Offset(170, 166), labelColor, center: true, fontSize: 9);

    canvas.restore();
  }

  void _hexagon(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 3 * i - math.pi / 6;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _diamond(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r, c.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _text(Canvas canvas, String s, Offset at, Color color,
      {bool center = false, double fontSize = 10}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: fontSize, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center ? Offset(at.dx - tp.width / 2, at.dy) : at);
  }

  @override
  bool shouldRepaint(covariant _CarLayoutPainter old) =>
      old.zh != zh || old.isDark != isDark;
}

/// 四类部件示例图（图片来自 `assets/images/<id>.png`，国服自动用国服图）
class _PartSampleFigure extends StatelessWidget {
  final String locale;
  final String server;
  const _PartSampleFigure({required this.locale, required this.server});

  static const List<(PartCategory, String)> _samples = <(PartCategory, String)>[
    (PartCategory.body, 'apocatlypse_bus'),
    (PartCategory.weapon, 'basketball_cannon'),
    (PartCategory.wheel, 'anti_gravity_roller'),
    (PartCategory.gadget, 'deflecting_shield'),
  ];

  @override
  Widget build(BuildContext context) {
    final list = PartDatabase.partsForServer(server);
    final parts = <PartData>[];
    for (final (cat, id) in _samples) {
      PartData? found;
      for (final p in list) {
        if (p.id == id) {
          found = p;
          break;
        }
      }
      found ??= list.firstWhere((p) => p.category == cat,
          orElse: () => list.first);
      parts.add(found);
    }
    return Row(
      children: <Widget>[
        for (final p in parts)
          Expanded(
            child: Column(
              children: <Widget>[
                Image.asset(
                  p.imagePath(server),
                  height: 54,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(height: 54),
                ),
                const SizedBox(height: 4),
                Text(
                  pn(p, locale),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
                Text(
                  _catLabel(p.category, locale),
                  style: TextStyle(
                    fontSize: 10,
                    color: _catColor(p.category),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _catLabel(PartCategory c, String locale) {
    final zh = locale == 'zh';
    return switch (c) {
      PartCategory.body => zh ? '车身' : 'Body',
      PartCategory.weapon => zh ? '武器' : 'Weapon',
      PartCategory.wheel => zh ? '车轮' : 'Wheel',
      PartCategory.gadget => zh ? '配件' : 'Gadget',
    };
  }

  static Color _catColor(PartCategory c) {
    return switch (c) {
      PartCategory.body => Colors.orange,
      PartCategory.weapon => Colors.red,
      PartCategory.wheel => Colors.green,
      PartCategory.gadget => Colors.purple,
    };
  }
}

/// 赞助商图标（3 个有图标的赞助商 + 无图标的 sporty 用文字代替）
class _SponsorFigure extends StatelessWidget {
  const _SponsorFigure();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: const <Widget>[
        _SponsorCell(asset: 'assets/images/sp_mecha.png', label: 'Mecha'),
        _SponsorCell(asset: 'assets/images/sp_naturalis.png', label: 'Naturalis'),
        _SponsorCell(asset: 'assets/images/sp_gluttony.png', label: 'Gluttony'),
      ],
    );
  }
}

class _SponsorCell extends StatelessWidget {
  final String asset;
  final String label;
  const _SponsorCell({required this.asset, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Image.asset(asset, height: 46, fit: BoxFit.contain),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

/// 王牌（Joker）R1-R5：图片见 `assets/guide/joker_r*.png`
class _JokerTiersFigure extends StatelessWidget {
  const _JokerTiersFigure();

  static const List<String> _assets = <String>[
    'assets/guide/joker_r1.png',
    'assets/guide/joker_r2.png',
    'assets/guide/joker_r3.png',
    'assets/guide/joker_r4.png',
    'assets/guide/joker_r5.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (var i = 0; i < _assets.length; i++)
          Expanded(
            child: Column(
              children: <Widget>[
                Image.asset(_assets[i], height: 44, fit: BoxFit.contain),
                const SizedBox(height: 3),
                Text('R${i + 1}', style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
      ],
    );
  }
}

/// 两种赛季结算箱子：自选箱（可二选一）/ 固定箱
class _ChestTypesFigure extends StatelessWidget {
  final String locale;
  const _ChestTypesFigure({required this.locale});

  @override
  Widget build(BuildContext context) {
    final zh = locale == 'zh';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _cell('assets/guide/chest_choice.png',
            zh ? '自选箱（可二选一）' : 'Choice chest'),
        _cell('assets/guide/chest_fixed.png',
            zh ? '固定箱（内容固定）' : 'Fixed chest'),
      ],
    );
  }

  Widget _cell(String asset, String label) {
    return Column(
      children: <Widget>[
        Image.asset(asset, height: 56, fit: BoxFit.contain),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

/// 战斗建筑与车位示意：6 个建筑（车位为奇数），蓝＝我方、红＝对方、灰＝空车位
class _BattleBuildingsFigure extends StatelessWidget {
  final String locale;
  final bool isDark;
  const _BattleBuildingsFigure({required this.locale, required this.isDark});

  /// (车位总数, 我方占几个, 对方占几个, 人机占几个, 是否链接建筑, 是否高回报建筑)
  /// 三类加起来就是车位总数；人机不属于任何一方
  static const List<(int, int, int, int, bool, bool)> _buildings =
      <(int, int, int, int, bool, bool)>[
    (5, 4, 0, 1, true, false),
    (3, 0, 2, 1, false, true),
    (5, 3, 0, 2, false, false),
    (7, 1, 4, 2, true, false),
    (3, 2, 1, 0, false, false),
    (5, 1, 1, 3, false, false),
  ];

  @override
  Widget build(BuildContext context) {
    final zh = locale == 'zh';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final (total, mine, theirs, bots, linked, high) in _buildings)
              _building(total, mine, theirs, bots, linked, high, zh),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          zh
              ? '蓝＝我方车、红＝对方帮派的车、灰＝人机车（不属于任何一方，只是开局把车位占住、可以被选中攻击）。\n'
                  '车位过半即占领；计时器归零时每个已占领建筑按车位数给分；'
                  '链接建筑分数 ×n（n = 同时占领的链接建筑数）；高回报建筑 ×5（持续 2 小时）。'
              : 'Blue = ours, red = the opposing gang, grey = bots (they belong to neither side and only keep the slot occupied and attackable at the start).\n'
                  'Hold over half the slots to occupy; at the timer each occupied building scores its slot count; '
                  'linked buildings score ×n (n = linked buildings you hold); high-reward building ×5 (lasts 2 hours).',
          style: TextStyle(
            fontSize: 10,
            height: 1.4,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _building(int total, int mine, int theirs, int bots, bool linked,
      bool high, bool zh) {
    final ours = mine > total / 2;
    final theirsWin = theirs > total / 2;
    final color = ours
        ? Colors.blue
        : (theirsWin ? Colors.red : Colors.blueGrey);
    final label = ours
        ? (zh ? '我方占领' : 'Ours')
        : (theirsWin ? (zh ? '对方占领' : 'Theirs') : (zh ? '未占领' : 'None'));
    return Container(
      width: 94,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            zh ? '$total 车位' : '$total slots',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              for (var i = 0; i < total; i++)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < mine
                        ? Colors.blue
                        : (i < mine + theirs
                            ? Colors.red
                            : (isDark ? Colors.white30 : Colors.black26)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 9, color: color)),
          if (linked || high) ...<Widget>[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: <Widget>[
                if (linked) _badge(zh ? '链接' : 'link', Colors.teal),
                if (high) _badge('×5', Colors.pink),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

/// 活动图标一览（图标来自 assets/cats_icons，名字来自 kActivities）
class _ActivityIconsFigure extends StatelessWidget {
  final String locale;
  const _ActivityIconsFigure({required this.locale});

  @override
  Widget build(BuildContext context) {
    final zh = locale == 'zh';
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: <Widget>[
        for (final a in kActivities.values)
          SizedBox(
            width: 62,
            child: Column(
              children: <Widget>[
                Image.asset(a.iconAsset, height: 34, fit: BoxFit.contain),
                const SizedBox(height: 3),
                Text(
                  zh ? a.nameZh : a.nameEn,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9.5),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 帮派四个组别（每组家数 / 升降级 / 结算系数，全部取自 life_sim_data 常量）
class _GangTiersFigure extends StatelessWidget {
  final String locale;
  final bool isDark;
  const _GangTiersFigure({required this.locale, required this.isDark});

  static const List<GangDivision> _order = <GangDivision>[
    GangDivision.gold,
    GangDivision.silver,
    GangDivision.bronze,
    GangDivision.wood,
  ];

  @override
  Widget build(BuildContext context) {
    final zh = locale == 'zh';
    return Column(
      children: <Widget>[
        for (final d in _order)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: <Widget>[
                Container(
                  width: 26,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _color(d).withValues(alpha: isDark ? 0.3 : 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _color(d), width: 1),
                  ),
                  child: Text(
                    zh ? d.nameZh : d.nameEn.substring(0, 1),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _color(d),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _desc(d, zh),
                    style: const TextStyle(fontSize: 11.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _desc(GangDivision d, bool zh) {
    final count = kGangDivisionGangCount[d]!;
    final mult = kGangLeagueRewardMul[d] ?? 1;
    final up = d.promoted == null ? null : kGangPromoteRank;
    final down = d.demoted == null ? null : kGangDemoteRank;
    if (zh) {
      final rule = up == null
          ? '不晋级'
          : (down == null ? '前 $up 名晋级' : '前 $up 名晋级 / 第 $down 名及以后退级');
      return '$count 家（每赛季浮动） · $rule · 结算系数 ×$mult';
    }
    final rule = up == null
        ? 'no promotion'
        : (down == null ? 'top $up promote' : 'top $up promote / rank $down+ demote');
    return '$count gangs · $rule · payout x$mult';
  }

  static Color _color(GangDivision d) => switch (d) {
        GangDivision.gold => Colors.amber.shade700,
        GangDivision.silver => Colors.blueGrey,
        GangDivision.bronze => Colors.brown,
        GangDivision.wood => Colors.green.shade700,
      };
}

/// 赛季收尾流程图：10 个帮派到达 30 胜 → +7 天关战斗入口 → +1 天战斗完成 → 发奖 → 缓冲 1 天 → 新赛季
class _SeasonFlowFigure extends StatelessWidget {
  final String locale;
  final bool isDark;
  const _SeasonFlowFigure({required this.locale, required this.isDark});

  /// (阶段标签, 中文说明, 英文说明, 标签颜色)
  static const List<(String, String, String, Color)> _steps =
      <(String, String, String, Color)>[
    (
      'T+0',
      '所有组别中累计有 10 个帮派达到 30 胜场 → 赛季准备结束',
      '10 gangs (across all divisions) reach 30 wins → the season starts to end',
      Colors.amber,
    ),
    (
      'T+7 天',
      '战斗入口关闭，之后不能加入新的战斗',
      'Battle entry closes — no new battles can be started',
      Colors.orange,
    ),
    (
      'T+8 天',
      '所有帮派战斗完成（单场战斗最长 1 天）',
      'All battles finish (a battle lasts up to 1 day)',
      Colors.deepOrange,
    ),
    (
      '结算',
      '发放赛季结算奖励（自选箱 / 固定箱 / 代币 / 紫票）',
      'Season rewards are granted (choice chests / fixed chests / tokens / tickets)',
      Colors.pink,
    ),
    (
      '缓冲 1 天',
      '用来领奖励、换帮派',
      'One buffer day: claim rewards and switch gangs',
      Colors.purple,
    ),
    (
      '新赛季',
      '开启新的赛季',
      'A new season begins',
      Colors.green,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final zh = locale == 'zh';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final (day, zhText, enText, color) in _steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.28 : 0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color, width: 1),
                  ),
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    zh ? zhText : enText,
                    style: const TextStyle(fontSize: 11.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 部件在当前语言下的名字（与 `main.dart` 的 `pn` 同规则，避免循环依赖）
String pn(PartData part, String? locale) {
  if (locale == 'zh' && part.nameZh.isNotEmpty) return part.nameZh;
  if (locale == 'ja' && part.nameJa.isNotEmpty) return part.nameJa;
  return part.name;
}
