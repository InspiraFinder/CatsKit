import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'parts_data.dart';

/// 碎片计算结果行
class _CalcRow {
  final int targetLevel;
  final int thisLevelPieces; // 本级需要碎片
  final int pieces; // 累计需要碎片
  final int cash; // 累计需要紫票
  final int token; // 累计需要代币
  final int remaining; // 剩余碎片
  const _CalcRow({
    required this.targetLevel,
    required this.thisLevelPieces,
    required this.pieces,
    required this.cash,
    required this.token,
    required this.remaining,
  });
}

/// 碎片计算界面
/// 选择稀有度 r1-r6，输入当前等级与当前碎片，
/// 计算升到每一级需要的碎片 / 紫票 / 代币，以及剩余碎片。
class FragmentCalcScreen extends StatefulWidget {
  final String locale;
  const FragmentCalcScreen({super.key, this.locale = 'zh'});

  @override
  State<FragmentCalcScreen> createState() => _FragmentCalcScreenState();
}

class _FragmentCalcScreenState extends State<FragmentCalcScreen> {
  Rarity _rarity = Rarity.r1;
  final TextEditingController _levelController = TextEditingController(
    text: '1',
  );
  final TextEditingController _fragController = TextEditingController(
    text: '0',
  );

  bool get _isZh => widget.locale == 'zh';

  String _tr(String zh, String en) => _isZh ? zh : en;

  int get _maxLevel => maxLevelForRarity(_rarity);

  int get _currentLevel => int.tryParse(_levelController.text.trim()) ?? 1;

  int get _currentFrags => int.tryParse(_fragController.text.trim()) ?? 0;

  @override
  void dispose() {
    _levelController.dispose();
    _fragController.dispose();
    super.dispose();
  }

  /// 计算所有目标等级的累计消耗与剩余碎片
  List<_CalcRow> _computeRows() {
    final costs = upgradeCosts[_rarity] ?? [];
    final cur = _currentLevel.clamp(0, _maxLevel);
    final frags = _currentFrags < 0 ? 0 : _currentFrags;
    final rows = <_CalcRow>[];
    int totalPieces = 0;
    int totalCash = 0;
    int totalToken = 0;
    for (int lv = cur + 1; lv <= _maxLevel; lv++) {
      final thisLevelPieces = lv < costs.length ? costs[lv].pieces : 0;
      if (lv < costs.length) {
        totalPieces += costs[lv].pieces;
        totalCash += costs[lv].cash;
        totalToken += costs[lv].token;
      }
      rows.add(
        _CalcRow(
          targetLevel: lv,
          thisLevelPieces: thisLevelPieces,
          pieces: totalPieces,
          cash: totalCash,
          token: totalToken,
          remaining: frags - totalPieces,
        ),
      );
    }
    return rows;
  }

  /// 使用当前碎片最多能升到几级
  int? _maxReachableLevel(List<_CalcRow> rows) {
    for (int i = rows.length - 1; i >= 0; i--) {
      if (rows[i].remaining >= 0) return rows[i].targetLevel;
    }
    return null;
  }

  String _formatNumber(int n) {
    // 负数符号单独处理，避免负号被计入千分位位置
    final sign = n < 0 ? '-' : '';
    final abs = n.abs().toString();
    final buf = StringBuffer(sign);
    for (int i = 0; i < abs.length; i++) {
      if (i > 0 && (abs.length - i) % 3 == 0) buf.write(',');
      buf.write(abs[i]);
    }
    return buf.toString();
  }

  String _rarityLabel(Rarity r) => switch (r) {
    Rarity.r1 => 'R1',
    Rarity.r2 => 'R2',
    Rarity.r3 => 'R3',
    Rarity.r4 => 'R4',
    Rarity.r5 => 'R5',
    Rarity.r6 => 'R6',
  };

  @override
  Widget build(BuildContext context) {
    final rows = _computeRows();
    final reachable = _maxReachableLevel(rows);
    final cur = _currentLevel.clamp(0, _maxLevel);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('碎片计算', 'Fragment Calc')),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, {'locale': widget.locale}),
          tooltip: _tr('返回主菜单', 'Back'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- 稀有度选择 ----
            Text(
              _tr('稀有度', 'Rarity'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final r in Rarity.values)
                  ChoiceChip(
                    label: Text(_rarityLabel(r)),
                    selected: _rarity == r,
                    onSelected: (_) => setState(() => _rarity = r),
                    selectedColor: Colors.indigo[100],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // ---- 当前等级 ----
            Text(
              _tr('当前等级（0-$_maxLevel）', 'Current Level (0-$_maxLevel)'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _levelController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '1',
                helperText: _tr('0 表示尚未获取该部件', '0 = not obtained yet'),
                prefixIcon: const Icon(Icons.trending_up, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            // ---- 当前碎片 ----
            Text(
              _tr('当前碎片', 'Current Fragments'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _fragController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '0',
                prefixIcon: const Icon(Icons.star, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // ---- 结果摘要 ----
            if (rows.isNotEmpty)
              _buildSummary(cur, reachable)
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _tr(
                    '当前等级已满（$_maxLevel），无需升级',
                    'Already at max level ($_maxLevel)',
                  ),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),

            const SizedBox(height: 12),
            // ---- 结果表格 ----
            if (rows.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  headingRowColor: WidgetStateProperty.all(
                    isDark ? const Color(0xFF0E1026) : Colors.indigo[50],
                  ),
                  columns: [
                    DataColumn(
                      label: Text(
                        _tr('目标等级', 'Target'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        _tr('本级碎片', 'This Lv'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        _tr('累计碎片', 'Cumulative'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        _tr('紫票', 'Tickets'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        _tr('代币', 'Tokens'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        _tr('剩余碎片', 'Remaining'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: [
                    for (final row in rows)
                      DataRow(
                        color: WidgetStatePropertyAll(
                          row.remaining >= 0
                              ? (row.targetLevel == reachable
                                    ? (isDark
                                          ? Colors.green.shade900
                                          : Colors.green[100])
                                    : null)
                              : (isDark
                                    ? Colors.brown.shade900
                                    : Colors.red[50]),
                        ),
                        cells: [
                          DataCell(
                            Text(
                              '${row.targetLevel}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataCell(Text(_formatNumber(row.thisLevelPieces))),
                          DataCell(Text(_formatNumber(row.pieces))),
                          DataCell(Text(_formatNumber(row.cash))),
                          DataCell(Text(_formatNumber(row.token))),
                          DataCell(
                            Text(
                              _formatNumber(row.remaining),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: row.remaining >= 0
                                    ? Colors.green[700]
                                    : Colors.red[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 结果摘要卡片
  Widget _buildSummary(int cur, int? reachable) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1026) : Colors.indigo[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.indigo.shade400 : Colors.indigo.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr(
              cur == 0
                  ? '尚未获取部件（Lv0），稀有度 ${_rarityLabel(_rarity)}'
                  : '从 Lv$cur 开始，稀有度 ${_rarityLabel(_rarity)}',
              cur == 0
                  ? 'Not obtained (Lv0), rarity ${_rarityLabel(_rarity)}'
                  : 'From Lv$cur, rarity ${_rarityLabel(_rarity)}',
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (reachable != null)
            Text(
              _tr(
                '当前碎片最多可升到 Lv$reachable',
                'Current fragments can reach up to Lv$reachable',
              ),
              style: TextStyle(color: Colors.green[800]),
            )
          else
            Text(
              _tr('当前碎片不足，无法升级', 'Not enough fragments to upgrade'),
              style: TextStyle(color: Colors.red[800]),
            ),
        ],
      ),
    );
  }
}
