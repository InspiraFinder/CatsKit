import 'package:flutter/material.dart';

import 'max_stats_data.dart';
import 'parts_data.dart';

/// 极限数值：展示「单车/三车 × 工具模式」各种组合的极限配车结果
///
/// 数值全部是离线程序预计算好的（见 max_stats_data.dart），
/// App 只负责展示，不在设备上做任何搜索/穷举计算。
class MaxStatsScreen extends StatefulWidget {
  final String locale;
  final String server;
  const MaxStatsScreen({
    super.key,
    this.locale = 'zh',
    this.server = 'cn',
  });

  @override
  State<MaxStatsScreen> createState() => _MaxStatsScreenState();
}

class _MaxStatsScreenState extends State<MaxStatsScreen> {
  bool get _isZh => widget.locale == 'zh';
  String _t(String zh, String en) => _isZh ? zh : en;

  /// 筛选状态（可多选）
  final Set<int> _vehSel = {1, 3};
  final Set<ItemMode> _modeSel = {...ItemMode.values};

  /// 部件 id → 部件（国际服 + 国服一起索引，用于取中/英文名）
  late final Map<String, PartData> _parts = {
    for (final p in PartDatabase.allParts) p.id: p,
    for (final p in PartDatabase.cnAllParts) p.id: p,
  };

  String _pn(String id) {
    final p = _parts[id];
    if (p == null) return id;
    return _isZh ? p.nameZh : p.name;
  }

  String _pnList(List<String> ids) =>
      ids.isEmpty ? '-' : ids.map(_pn).join(' / ');

  static String _fmt(num v) {
    final s = v.round().abs().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '${v < 0 ? '-' : ''}$b';
  }

  static String _fmtDelta(num v) => '${v > 0 ? '+' : ''}${_fmt(v)}';

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  List<StatCase> get _visible => kStatCases
      .where(
        (c) => _vehSel.contains(c.vehCount) && _modeSel.contains(c.itemMode),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final cases = _visible;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('极限数值', 'Max Stats')),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, {'locale': widget.locale}),
          tooltip: _t('返回主菜单', 'Back'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildContactNote(),
          const SizedBox(height: 8),
          _buildFilters(),
          const SizedBox(height: 8),
          if (cases.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                _t('请至少选择一个组合', 'Select at least one combination'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            )
          else ...[
            _buildOverviewTable(cases),
            const SizedBox(height: 10),
            for (final c in cases) ...[
              _buildCaseCard(c),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ───────────────────────── 顶部提示 ─────────────────────────

  Widget _buildContactNote() {
    final isDark = _isDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A1F00) : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.orange.shade800 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.campaign,
              size: 16, color: isDark ? Colors.orange[300] : Colors.orange[800]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _t(
                '如果发现数值更高的配车，请联系开发者。',
                'If you find a build with higher stats, please contact the developer.',
              ),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.orange[200] : Colors.orange[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 筛选按钮 ─────────────────────────

  Widget _buildFilters() {
    final isDark = _isDark;
    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        selectedColor: isDark ? const Color(0xFF1B4B43) : Colors.teal[100],
      );
    }

    Widget row(String title, List<Widget> chips) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Wrap(spacing: 6, runSpacing: -4, children: chips),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.teal.shade800 : Colors.teal.shade200,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(_t('车辆', 'Cars'), [
            chip(
              label: _t('单车', '1 car'),
              selected: _vehSel.contains(1),
              onTap: () => setState(() {
                _vehSel.contains(1) ? _vehSel.remove(1) : _vehSel.add(1);
              }),
            ),
            chip(
              label: _t('三车', '3 cars'),
              selected: _vehSel.contains(3),
              onTap: () => setState(() {
                _vehSel.contains(3) ? _vehSel.remove(3) : _vehSel.add(3);
              }),
            ),
          ]),
          const SizedBox(height: 4),
          row(_t('道具', 'Items'), [
            for (final m in ItemMode.values)
              chip(
                label: _isZh ? m.labelZh : m.labelEn,
                selected: _modeSel.contains(m),
                onTap: () => setState(() {
                  _modeSel.contains(m) ? _modeSel.remove(m) : _modeSel.add(m);
                }),
              ),
          ]),
        ],
      ),
    );
  }

  // ───────────────────────── 总览表 ─────────────────────────

  Widget _buildOverviewTable(List<StatCase> cases) {
    final isDark = _isDark;
    final headStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.teal[100] : Colors.teal[900],
    );
    final cellStyle = TextStyle(
      fontSize: 12,
      color: isDark ? Colors.grey[300] : Colors.grey[800],
    );
    Widget th(String s, {TextAlign align = TextAlign.center}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text(s, style: headStyle, textAlign: align),
        );
    Widget td(String s, {TextAlign align = TextAlign.center, Color? c}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text(
            s,
            style: cellStyle.copyWith(
              color: c ?? cellStyle.color,
              fontWeight: c == null ? FontWeight.normal : FontWeight.bold,
            ),
            textAlign: align,
          ),
        );

    final rows = <TableRow>[
      TableRow(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF10312B) : Colors.teal[50],
        ),
        children: [
          th(_t('组合', 'Combination'), align: TextAlign.left),
          th(_t('国际服', 'Intl')),
          th(_t('国服', 'CN')),
          th('${_t('国服', 'CN')} − ${_t('国际服', 'Intl')}'),
        ],
      ),
    ];
    for (final c in cases) {
      final intl = c.totalOf('intl');
      final cn = c.totalOf('cn');
      final d = cn - intl;
      final pct = intl == 0 ? 0.0 : d / intl * 100;
      final color = d >= 0
          ? (isDark ? Colors.green[300] : Colors.green[700])
          : (isDark ? Colors.red[300] : Colors.red[700]);
      rows.add(
        TableRow(
          children: [
            td(_isZh ? c.nameZh : c.nameEn, align: TextAlign.left),
            td(_fmt(intl)),
            td(_fmt(cn)),
            td(
              '${_fmtDelta(d)}\n(${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%)',
              c: color,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.teal.shade800 : Colors.teal.shade200,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
            child: Text(
              _t('极限值对比（目标 = HP+ATK）', 'Comparison (target = HP+ATK)'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.teal[200] : Colors.teal[800],
              ),
            ),
          ),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.6),
              1: FlexColumnWidth(1.1),
              2: FlexColumnWidth(1.1),
              3: FlexColumnWidth(1.3),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: rows,
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 单个组合卡片 ─────────────────────────

  Widget _buildCaseCard(StatCase c) {
    final isDark = _isDark;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  size: 18,
                  color: isDark ? Colors.amber[200] : Colors.amber[800],
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _isZh ? c.nameZh : c.nameEn,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _isZh ? c.descZh : c.descEn,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            _buildServerPanel(c, 'intl'),
            const SizedBox(height: 8),
            _buildServerPanel(c, 'cn'),
            const SizedBox(height: 6),
            _buildDeltaLine(c),
          ],
        ),
      ),
    );
  }

  Widget _buildDeltaLine(StatCase c) {
    final isDark = _isDark;
    final intl = c.totalOf('intl');
    final cn = c.totalOf('cn');
    final d = cn - intl;
    final pct = intl == 0 ? 0.0 : d / intl * 100;
    final color = d >= 0
        ? (isDark ? Colors.green[300] : Colors.green[700])
        : (isDark ? Colors.red[300] : Colors.red[700]);
    return Row(
      children: [
        Icon(Icons.compare_arrows, size: 16, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '${_t('国服 − 国际服', 'CN − Intl')}: '
            '${_fmtDelta(d)} (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServerPanel(StatCase c, String server) {
    final isDark = _isDark;
    final isCn = server == 'cn';
    final main = isCn ? Colors.red : Colors.blue;
    final bg = isDark
        ? (isCn ? const Color(0xFF2A1414) : const Color(0xFF0D1B2A))
        : (isCn ? Colors.red[50] : Colors.blue[50]);
    final border = isDark
        ? (isCn ? Colors.red.shade900 : Colors.blue.shade900)
        : (isCn ? Colors.red.shade200 : Colors.blue.shade200);
    final vs = c.vehiclesOf(server);
    final hp = c.hpOf(server);
    final atk = c.atkOf(server);
    final used = vs.fold<int>(0, (int s, StatVehicle v) => s + v.itemsUsed);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isDark ? main.shade900 : main.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCn ? _t('国服', 'CN') : _t('国际服', 'Intl'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? main.shade100 : main.shade900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'HP+ATK ${_fmt(hp + atk)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (server == widget.server)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _t('当前', 'current'),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'HP ${_fmt(hp)} · ATK ${_fmt(atk)}',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          if (c.itemMode != ItemMode.none)
            Text(
              _t(
                '道具 $used/${c.itemBudget}${c.sharedItems ? '（三车共用）' : ''}',
                'Items $used/${c.itemBudget}${c.sharedItems ? ' (shared)' : ''}',
              ),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.orange[200] : Colors.orange[800],
              ),
            ),
          const SizedBox(height: 2),
          for (int i = 0; i < vs.length; i++)
            _buildVehicleTile(vs[i], i, shared: c.sharedItems),
        ],
      ),
    );
  }

  Widget _buildVehicleTile(StatVehicle v, int index, {bool shared = false}) {
    final isDark = _isDark;
    final body = _parts[v.bodyId];
    final slots = body?.slots;
    final slotText =
        slots == null ? '' : '(${slots.weapon}武/${slots.wheel}轮/${slots.gadget}配)';
    final title = '${_t('车', 'Car')}${index + 1} · ${_pn(v.bodyId)}$slotText';
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'HP ${_fmt(v.hp)} · ATK ${_fmt(v.atk)} · '
            '${shared ? _t('本车道具', 'items here') : _t('道具', 'items')} '
            '${v.itemsUsed}',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          children: [
            _kv(_t('额外武器', 'Extra weapon'),
                v.extraId == null ? _t('无', 'none') : _pn(v.extraId!)),
            _kv(_t('武器', 'Weapons'), _pnList(v.weaponIds)),
            _kv(_t('车轮', 'Wheels'), _pnList(v.wheelIds)),
            _kv(_t('配件', 'Gadgets'), _pnList(v.gadgetIds)),
            _kv(
              _t('道具分配', 'Items'),
              v.items.isEmpty
                  ? _t('（无道具）', '(none)')
                  : v.items
                      .map((it) => '${_pn(it.partId)}+${it.pct}%')
                      .join('，'),
            ),
            _kv(
              _t('净电力', 'Net power'),
              '${v.netPower >= 0 ? '+' : ''}${v.netPower}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String val) {
    final isDark = _isDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 66,
            child: Text(
              k,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              val,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[200] : Colors.grey[900],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
