import 'package:flutter/material.dart';

import 'balance_history_data.dart';

/// 历史平衡：展示历次平衡性调整内容（数据源见 balance_history_data.dart）
class BalanceHistoryScreen extends StatefulWidget {
  final String locale;
  final String server;
  const BalanceHistoryScreen({
    super.key,
    this.locale = 'zh',
    this.server = 'cn',
  });

  @override
  State<BalanceHistoryScreen> createState() => _BalanceHistoryScreenState();
}

class _BalanceHistoryScreenState extends State<BalanceHistoryScreen> {
  bool get _isZh => widget.locale == 'zh';
  String _t(String zh, String en) => _isZh ? zh : en;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('历史平衡', 'Balance History')),
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
          _buildIntro(),
          const SizedBox(height: 10),
          for (final p in kBalanceHistory) ...[
            _buildPatchCard(p),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1030) : Colors.purple[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.purple.shade300 : Colors.purple.shade200,
        ),
      ),
      child: Text(
        _t(
          '历次平衡性调整记录（国际服/国服分别标注），最终以官方公告为准。'
          '表格内容可左右滑动查看完整数值。',
          'Recorded balance changes (Intl/CN marked); official announcements prevail. '
          'Swipe the table horizontally to see full values.',
        ),
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.purple[200] : Colors.purple[800],
        ),
      ),
    );
  }

  Widget _buildPatchCard(BalancePatch p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final note = _isZh
        ? (p.noteZh ?? '')
        : ((p.noteEn ?? '').isEmpty ? (p.noteZh ?? '') : p.noteEn!);
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
                  Icons.balance,
                  size: 18,
                  color: isDark ? Colors.purple[200] : Colors.purple[700],
                ),
                const SizedBox(width: 6),
                Text(
                  p.date,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                _buildServerChip(p.server),
                if (note.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final c in p.changes) _buildChangeRow(c),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerChip(String server) {
    final isIntl = server == 'intl';
    final color = isIntl ? Colors.teal : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        isIntl ? _t('国际服', 'Intl') : _t('国服', 'CN'),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildChangeRow(BalanceChange c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final grey = isDark ? Colors.grey[400] : Colors.grey[600];
    // 变化幅度展示（电力用绝对差值，其余用百分比文本）
    final delta = _deltaInfo(c);

    // 备注类条目
    if (c.field == 'note') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: grey),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${c.partName}：${c.newValue}',
                style: TextStyle(fontSize: 12, color: grey),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      // 固定总宽：保证各行左侧列对齐；数值列（插槽等）预留足够空间避免截断
      width: 424,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 部件名
            SizedBox(
              width: 84,
              child: Text(
                c.partName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 字段
            SizedBox(
              width: 42,
              child: Text(
                _fieldLabel(c.field),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.purple[200] : Colors.purple[700],
                ),
              ),
            ),
            // 变化幅度（放在数值前，避免窄屏被省略）
            SizedBox(
              width: 50,
              child: Text(
                delta.text,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: delta.up ? Colors.green : Colors.red,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 旧值 → 新值（最后一列，可横向滑动查看）
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      c.oldValue,
                      style: TextStyle(
                        fontSize: 12,
                        color: grey,
                        decoration: TextDecoration.lineThrough,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 12, color: grey),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      c.newValue,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 变化幅度展示信息：
  /// - `power`（电力）：用新旧值的绝对差值，如 `+5` / `-3`（比百分比更直观）
  /// - 其余字段：沿用数据中提供的展示文本（如 `+10.7%`、`配件 +1`）
  ({String text, bool up}) _deltaInfo(BalanceChange c) {
    if (c.field == 'power') {
      final oldV = int.tryParse(c.oldValue.replaceAll(RegExp(r'\D'), ''));
      final newV = int.tryParse(c.newValue.replaceAll(RegExp(r'\D'), ''));
      if (oldV != null && newV != null) {
        final diff = newV - oldV;
        return (text: diff >= 0 ? '+$diff' : '$diff', up: diff >= 0);
      }
    }
    return (text: c.percent ?? '', up: c.percentUp);
  }

  String _fieldLabel(String field) {
    switch (field) {
      case 'hp':
        return 'HP';
      case 'power':
        return _t('电力', 'Power');
      case 'slots':
        return _t('插槽', 'Slots');
      default:
        return _t('其它', 'Other');
    }
  }
}
