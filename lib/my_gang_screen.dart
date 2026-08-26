import 'package:flutter/material.dart';

import 'gang_data.dart';

/// 我的帮派：类似「我的车库」，但只有 5 个帮派槽位。
/// 每个槽位保存一个帮派（名称 + 成员车辆数据表），
/// 数据从「帮派统计」模块的「导入到我的帮派」写入。
class MyGangScreen extends StatefulWidget {
  final String locale;
  final String server;
  const MyGangScreen({
    super.key,
    this.locale = 'zh',
    this.server = 'cn',
  });

  @override
  State<MyGangScreen> createState() => _MyGangScreenState();
}

class _MyGangScreenState extends State<MyGangScreen> {
  List<GangData?> _slots = List<GangData?>.filled(GangStore.slotCount, null);
  int _selectedSlot = 0;

  bool get _isZh => widget.locale == 'zh';
  String _t(String zh, String en) => _isZh ? zh : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final slots = await GangStore.load();
    if (!mounted) return;
    setState(() => _slots = slots);
  }

  Future<void> _persist() => GangStore.save(_slots);

  @override
  Widget build(BuildContext context) {
    final gang = _slots[_selectedSlot];
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('我的帮派', 'My Gang')),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, {'locale': widget.locale}),
          tooltip: _t('返回主菜单', 'Back'),
        ),
      ),
      body: Column(
        children: [
          _buildSlotSelector(),
          const Divider(height: 1),
          Expanded(
            child: gang == null || gang.isEmpty
                ? _buildEmpty()
                : _buildGangContent(gang),
          ),
        ],
      ),
    );
  }

  // ==================== 帮派槽选择 ====================
  Widget _buildSlotSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('帮派槽选择', 'Gang Slot'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < GangStore.slotCount; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _buildSlotButton(i),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotButton(int i) {
    final g = _slots[i];
    final filled = g != null && !g.isEmpty;
    final selected = i == _selectedSlot;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _selectedSlot = i),
      child: Container(
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.brown
              : filled
              ? Colors.teal[50]
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? Colors.brown
                : filled
                ? Colors.teal
                : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              filled ? Icons.groups : Icons.groups_outlined,
              size: 22,
              color: selected
                  ? Colors.white
                  : filled
                  ? Colors.teal
                  : Colors.grey,
            ),
            const SizedBox(height: 2),
            Text(
              '${i + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 空槽位 ====================
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_outlined, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text(
            _t('该槽位暂无帮派', 'No gang in this slot'),
            style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            _t('在「帮派统计」录入并导入帮派数据', 'Import from Gang Stats'),
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ==================== 帮派详情 ====================
  Widget _buildGangContent(GangData gang) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups, color: Colors.brown, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  gang.name.isEmpty
                      ? _t('帮派 ${_selectedSlot + 1}', 'Gang ${_selectedSlot + 1}')
                      : gang.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: _t('清空该帮派', 'Clear gang'),
                onPressed: () => _clearGang(_selectedSlot),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _t(
              '成员 ${gang.memberCount} 人 · 总HP ${_formatNum(gang.totalHp)} · 总ATK ${_formatNum(gang.totalAtk)}',
              '${gang.memberCount} members · HP ${_formatNum(gang.totalHp)} · ATK ${_formatNum(gang.totalAtk)}',
            ),
            style: TextStyle(fontSize: 13, color: Colors.brown[700]),
          ),
          const SizedBox(height: 10),
          _buildMembersTable(gang),
        ],
      ),
    );
  }

  void _clearGang(int index) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('清空该帮派？', 'Clear this gang?')),
        content: Text(_t('将移除该槽位的帮派数据。', 'Remove gang data from this slot.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('取消', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('清空', 'Clear')),
          ),
        ],
      ),
    ).then((ok) {
      if (ok == true && mounted) {
        setState(() {
          _slots[index] = null;
          _persist();
        });
      }
    });
  }

  // ==================== 成员表格（只读） ====================
  Widget _buildMembersTable(GangData gang) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 14,
          headingRowColor: WidgetStateProperty.all(Colors.teal[50]),
          columns: [
            DataColumn(
              label: Text(
                _t('用户ID', 'User ID'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (int v = 0; v < 3; v++) ...[
              DataColumn(
                label: Text(
                  _t('车${v + 1}HP', 'C${v + 1}HP'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  _t('车${v + 1}ATK', 'C${v + 1}ATK'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            DataColumn(
              label: Text(
                _t('总HP', 'HP'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                _t('总ATK', 'ATK'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: [
            for (int i = 0; i < gang.members.length; i++)
              DataRow(
                cells: [
                  DataCell(Text(gang.members[i].userId)),
                  for (int v = 0; v < 3; v++) ...[
                    DataCell(Text(_fmtOrDash(gang.members[i].hp[v]))),
                    DataCell(Text(_fmtOrDash(gang.members[i].atk[v]))),
                  ],
                  DataCell(Text(_formatNum(gang.members[i].totalHp))),
                  DataCell(Text(_formatNum(gang.members[i].totalAtk))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ==================== 工具 ====================
  String _fmtOrDash(int? v) => v == null ? '-' : _formatNum(v);

  String _formatNum(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
