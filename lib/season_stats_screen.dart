import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'season_stats_data.dart';

/// 赛季统计：可查询的表格
///
/// 列：场次 / 开始 / 结束 / 持续 / 间隔 / 战斗分 / 赛前胜场 / 赛后胜场 / 系数 / 本场得分
/// - 「场次、间隔、赛前胜场、系数、本场得分」由相邻记录推导，见 [buildSeasonStatRows]
/// - 支持关键词搜索、时间范围筛选、点击表头排序
/// - 支持手动新增、编辑、删除、清空，以及一键复制整张表
/// - 「时间计算」模块可以直接把一条计算结果导入到这里
class SeasonStatsScreen extends StatefulWidget {
  final String locale;
  const SeasonStatsScreen({super.key, this.locale = 'zh'});

  @override
  State<SeasonStatsScreen> createState() => _SeasonStatsScreenState();
}

/// 表格左右内边距（表头与数据行都用它，算总宽时要带上）
const double _kTablePad = 8;

/// 表格列宽（屏幕不够宽时整表横向滚动）
const double _kColIndex = 48;
const double _kColTime = 122;
const double _kColDuration = 84;
const double _kColGap = 84;
const double _kColScore = 92;
const double _kColWins = 80;
const double _kColMultiplier = 62;
const double _kColGained = 100;
const double _kColOps = 80;
const double _kTableWidth =
    _kTablePad * 2 +
    _kColIndex +
    _kColTime * 2 +
    _kColDuration +
    _kColGap +
    _kColScore +
    _kColWins * 2 +
    _kColMultiplier +
    _kColGained +
    _kColOps;

const double _kRowHeight = 46;
const double _kHeaderHeight = 40;

class _SeasonStatsScreenState extends State<SeasonStatsScreen> {
  bool get _isZh => widget.locale == 'zh';
  String _t(String zh, String en) => _isZh ? zh : en;

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _hCtrl = ScrollController();

  List<SeasonStatRecord> _records = <SeasonStatRecord>[];
  /// 派生行（场次 / 间隔 / 胜场 / 系数 / 本场得分）——依赖战斗先后顺序，
  /// 所以每次数据变化都用**全部记录**重算一次，筛选排序不会影响它。
  List<SeasonStatRow> _rows = <SeasonStatRow>[];
  bool _loading = true;
  String _query = '';
  SeasonStatRange _range = SeasonStatRange.all;
  DateTimeRange? _customRange;
  SeasonStatSortKey _sortKey = SeasonStatSortKey.startTime;
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _hCtrl.dispose();
    super.dispose();
  }

  /// 数据变化后统一刷新原始记录与派生行
  void _setRecords(List<SeasonStatRecord> records, {bool loading = false}) {
    setState(() {
      _records = records;
      _rows = buildSeasonStatRows(records);
      if (loading) _loading = false;
    });
  }

  Future<void> _load() async {
    final records = await SeasonStatsStore.load();
    if (!mounted) return;
    _setRecords(records, loading: true);
  }

  /// 上一条的赛后胜场（用于「本场默认又是胜场」）
  int get _lastWins => _rows.isEmpty ? 0 : (_rows.last.winsAfter ?? 0);

  /// 当前筛选条件（含自定义范围）下的行
  List<SeasonStatRow> get _visible {
    DateTime? from;
    DateTime? to;
    if (_range == SeasonStatRange.custom) {
      from = _customRange?.start;
      // 结束日当天也要算进去
      final end = _customRange?.end;
      to = end == null
          ? null
          : DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    } else {
      from = rangeStart(_range);
    }
    return filterAndSortSeasonStatRows(
      _rows,
      query: _query,
      from: from,
      to: to,
      sortKey: _sortKey,
      ascending: _ascending,
    );
  }

  void _toggleSort(SeasonStatSortKey key) {
    setState(() {
      if (_sortKey == key) {
        _ascending = !_ascending;
      } else {
        _sortKey = key;
        _ascending = false;
      }
    });
  }

  // ==================== 增删改 ====================

  Future<void> _addRecord() async {
    final record = await showSeasonStatRecordDialog(
      context,
      locale: widget.locale,
      defaultWinsAfter: _lastWins + 1,
    );
    if (record == null) return;
    final list = await SeasonStatsStore.add(record);
    if (!mounted) return;
    _setRecords(list);
  }

  Future<void> _editRecord(SeasonStatRecord record) async {
    final edited = await showSeasonStatRecordDialog(
      context,
      locale: widget.locale,
      initial: record,
    );
    if (edited == null) return;
    final list = await SeasonStatsStore.update(edited);
    if (!mounted) return;
    _setRecords(list);
  }

  Future<void> _deleteRecord(SeasonStatRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('删除这条记录？', 'Delete this record?')),
        content: Text(
          '${formatSeasonStatFullTime(record.startTime)}  ·  '
          '${formatSeasonStatScore(record.finalScore)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('删除', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final list = await SeasonStatsStore.remove(record.id);
    if (!mounted) return;
    _setRecords(list);
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('清空全部记录？', 'Clear all records?')),
        content: Text(
          _t(
            '将删除 ${_records.length} 条记录，无法撤销。',
            'This deletes ${_records.length} records and cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('清空', 'Clear')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await SeasonStatsStore.clear();
    if (!mounted) return;
    _setRecords(<SeasonStatRecord>[]);
  }

  /// 复制整张表（TSV，可直接粘贴进 Excel / 表格软件）
  void _copyTable() {
    final rows = _visible;
    if (rows.isEmpty) return;
    final buf = StringBuffer()
      ..writeln(
        [
          _t('场次', 'No.'),
          _t('开始', 'Start'),
          _t('结束', 'End'),
          _t('持续', 'Duration'),
          _t('间隔', 'Gap'),
          _t('战斗分', 'Battle'),
          _t('赛前胜场', 'Wins before'),
          _t('赛后胜场', 'Wins after'),
          _t('系数', 'Multiplier'),
          _t('本场得分', 'Gained'),
        ].join('\t'),
      );
    for (final r in rows) {
      buf.writeln(
        [
          r.order.toString(),
          formatSeasonStatFullTime(r.startTime),
          formatSeasonStatFullTime(r.endTime),
          formatSeasonStatDuration(r.durationMinutes, zh: _isZh),
          r.gapMinutes == null
              ? ''
              : formatSeasonStatDuration(r.gapMinutes!, zh: _isZh),
          r.finalScore.toString(),
          r.winsBefore?.toString() ?? '',
          r.winsAfter?.toString() ?? '',
          r.multiplier?.toString() ?? '',
          r.gainedScore?.toString() ?? '',
        ].join('\t'),
      );
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _t('已复制 ${rows.length} 行（可直接粘贴到表格）', 'Copied ${rows.length} rows'),
          style: const TextStyle(fontSize: 12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _customRange,
      helpText: _t('选择统计范围', 'Select range'),
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _range = SeasonStatRange.custom;
    });
  }

  // ==================== 界面 ====================

  @override
  Widget build(BuildContext context) {
    final rows = _visible;
    final summary = summarizeSeasonStats(rows);
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('赛季统计', 'Season Stats')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: _t('新增记录', 'Add record'),
            onPressed: _addRecord,
          ),
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: _t('复制表格', 'Copy table'),
            onPressed: rows.isEmpty ? null : _copyTable,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: _t('清空全部', 'Clear all'),
            onPressed: _records.isEmpty ? null : _clearAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummary(summary),
                _buildFilters(),
                const Divider(height: 1),
                Expanded(child: _buildTable(rows)),
              ],
            ),
    );
  }

  /// 摘要：横向可滚动的指标条，占一行高度
  Widget _buildSummary(SeasonStatsSummary s) {
    Widget tile(IconData icon, String label, String value, Color color) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          tile(
            Icons.list_alt,
            _t('场次', 'Battles'),
            '${s.count}',
            Colors.blue,
          ),
          if (s.lastWins != null)
            tile(
              Icons.emoji_events,
              _t('当前胜场', 'Wins'),
              '${s.lastWins}',
              Colors.amber[800]!,
            ),
          tile(
            Icons.timer_outlined,
            _t('总时长', 'Total'),
            formatSeasonStatDuration(s.totalMinutes, zh: _isZh),
            Colors.teal,
          ),
          tile(
            Icons.functions,
            _t('平均时长', 'Avg time'),
            formatSeasonStatDuration(s.averageMinutes.round(), zh: _isZh),
            Colors.indigo,
          ),
          tile(
            Icons.star,
            _t('最高战斗分', 'Best'),
            formatSeasonStatScore(s.bestScore),
            Colors.orange,
          ),
          tile(
            Icons.summarize,
            _t('战斗分合计', 'Sum'),
            formatSeasonStatScore(s.totalScore),
            Colors.deepPurple,
          ),
          tile(
            Icons.trending_up,
            _t('平均战斗分', 'Avg'),
            formatSeasonStatScore(s.averageScore.round()),
            Colors.green,
          ),
          if (s.gainedCount > 0)
            tile(
              Icons.savings,
              _t('本场得分合计', 'Gained'),
              formatSeasonStatScore(s.totalGained),
              Colors.pink,
            ),
          if (s.count > 0)
            tile(
              Icons.trending_down,
              _t('最低分', 'Worst'),
              formatSeasonStatScore(s.worstScore),
              Colors.brown,
            ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget chip(SeasonStatRange range, String label) {
      return ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: _range == range,
        visualDensity: VisualDensity.compact,
        onSelected: (_) async {
          if (range == SeasonStatRange.custom) {
            await _pickCustomRange();
          } else {
            setState(() => _range = range);
          }
        },
      );
    }

    String customLabel = _t('自定义', 'Custom');
    if (_range == SeasonStatRange.custom && _customRange != null) {
      final s = _customRange!.start;
      final e = _customRange!.end;
      customLabel =
          '${s.month}/${s.day} - ${e.month}/${e.day}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: _t('搜索时间 / 分数', 'Search time / score'),
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                chip(SeasonStatRange.all, _t('全部', 'All')),
                const SizedBox(width: 6),
                chip(SeasonStatRange.today, _t('今天', 'Today')),
                const SizedBox(width: 6),
                chip(SeasonStatRange.last7, _t('近 7 天', '7 days')),
                const SizedBox(width: 6),
                chip(SeasonStatRange.last30, _t('近 30 天', '30 days')),
                const SizedBox(width: 6),
                chip(SeasonStatRange.custom, customLabel),
                const SizedBox(width: 6),
                if (_range != SeasonStatRange.all || _query.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {
                        _query = '';
                        _range = SeasonStatRange.all;
                        _customRange = null;
                      });
                    },
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: Text(
                      _t('重置', 'Reset'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _t(
                '共 ${_records.length} 场，当前显示 ${_visible.length} 场',
                '${_records.length} battles, ${_visible.length} shown',
              ),
              style: TextStyle(
                fontSize: 11,
                color: dark ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<SeasonStatRow> rows) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(_kTableWidth, constraints.maxWidth);
        return Scrollbar(
          controller: _hCtrl,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _hCtrl,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  _buildHeader(dark),
                  Expanded(
                    child: rows.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            itemCount: rows.length,
                            itemExtent: _kRowHeight,
                            itemBuilder: (context, index) =>
                                _buildRow(rows[index], index, dark),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool dark) {
    Widget cell(
      String label, {
      double width = 0,
      SeasonStatSortKey? sortKey,
    }) {
      final active = sortKey != null && _sortKey == sortKey;
      final text = Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: active
              ? Colors.blue
              : (dark ? Colors.white70 : Colors.grey[800]),
        ),
      );
      final content = Row(
        children: [
          text,
          if (active) ...[
            const SizedBox(width: 2),
            Icon(
              _ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 13,
              color: Colors.blue,
            ),
          ],
        ],
      );
      return SizedBox(
        width: width,
        child: sortKey == null
            ? content
            : InkWell(
                onTap: () => _toggleSort(sortKey),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: content,
                ),
              ),
      );
    }

    return Container(
      height: _kHeaderHeight,
      width: double.infinity,
      color: dark ? Colors.white10 : Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: _kTablePad),
      child: Row(
        children: [
          cell(_t('场次', 'No.'), width: _kColIndex, sortKey: SeasonStatSortKey.order),
          cell(
            _t('开始', 'Start'),
            width: _kColTime,
            sortKey: SeasonStatSortKey.startTime,
          ),
          cell(
            _t('结束', 'End'),
            width: _kColTime,
            sortKey: SeasonStatSortKey.endTime,
          ),
          cell(
            _t('持续', 'Duration'),
            width: _kColDuration,
            sortKey: SeasonStatSortKey.duration,
          ),
          cell(
            _t('间隔', 'Gap'),
            width: _kColGap,
            sortKey: SeasonStatSortKey.gap,
          ),
          cell(
            _t('战斗分', 'Battle'),
            width: _kColScore,
            sortKey: SeasonStatSortKey.finalScore,
          ),
          cell(
            _t('赛前胜场', 'Wins before'),
            width: _kColWins,
            sortKey: SeasonStatSortKey.winsBefore,
          ),
          cell(
            _t('赛后胜场', 'Wins after'),
            width: _kColWins,
            sortKey: SeasonStatSortKey.winsAfter,
          ),
          cell(
            _t('系数', 'x'),
            width: _kColMultiplier,
            sortKey: SeasonStatSortKey.multiplier,
          ),
          cell(
            _t('本场得分', 'Gained'),
            width: _kColGained,
            sortKey: SeasonStatSortKey.gainedScore,
          ),
          cell(_t('操作', 'Actions'), width: _kColOps),
        ],
      ),
    );
  }

  Widget _buildRow(SeasonStatRow r, int index, bool dark) {
    Widget cell(String text, double width, {TextStyle? style}) => SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style ?? const TextStyle(fontSize: 13),
      ),
    );

    final dim = TextStyle(
      fontSize: 12,
      color: dark ? Colors.white38 : Colors.grey[500],
    );

    return Material(
      color: index.isEven
          ? Colors.transparent
          : (dark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50]),
      child: InkWell(
        onTap: () => _editRecord(r.record),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: _kTablePad),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: dark ? Colors.white12 : Colors.grey[300]!,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: _kColIndex,
                child: Row(
                  children: [
                    Text('${r.order}', style: dim),
                    const SizedBox(width: 3),
                    Icon(
                      r.fromTimer ? Icons.timer : Icons.edit_note,
                      size: 12,
                      color: r.fromTimer ? Colors.teal : Colors.blueGrey,
                    ),
                  ],
                ),
              ),
              cell(formatSeasonStatTime(r.startTime), _kColTime),
              cell(formatSeasonStatTime(r.endTime), _kColTime),
              cell(
                formatSeasonStatDuration(r.durationMinutes, zh: _isZh),
                _kColDuration,
              ),
              cell(
                r.gapMinutes == null
                    ? '-'
                    : formatSeasonStatDuration(r.gapMinutes!, zh: _isZh),
                _kColGap,
                style: r.gapMinutes == null ? dim : null,
              ),
              cell(
                formatSeasonStatScore(r.finalScore),
                _kColScore,
                style: const TextStyle(fontSize: 13),
              ),
              cell(
                r.winsBefore?.toString() ?? '-',
                _kColWins,
                style: r.winsBefore == null ? dim : null,
              ),
              cell(
                r.winsAfter?.toString() ?? '-',
                _kColWins,
                style: r.winsAfter == null
                    ? dim
                    : const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
              ),
              cell(
                r.multiplier == null ? '-' : '×${r.multiplier}',
                _kColMultiplier,
                style: r.multiplier == null
                    ? dim
                    : TextStyle(
                        fontSize: 13,
                        color: Colors.deepOrange[700],
                        fontWeight: FontWeight.bold,
                      ),
              ),
              cell(
                r.gainedScore == null
                    ? '-'
                    : formatSeasonStatScore(r.gainedScore!),
                _kColGained,
                style: r.gainedScore == null
                    ? dim
                    : const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
              ),
              SizedBox(
                width: _kColOps,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16),
                      tooltip: _t('编辑', 'Edit'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _editRecord(r.record),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      tooltip: _t('删除', 'Delete'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _deleteRecord(r.record),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _records.isEmpty ? Icons.table_chart : Icons.search_off,
            size: 56,
            color: Colors.grey[350],
          ),
          const SizedBox(height: 12),
          Text(
            _records.isEmpty
                ? _t('还没有记录', 'No records yet')
                : _t('没有符合条件的记录', 'No matching records'),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _t(
                '可以点右上角「+」手动新增，或在「时间计算」里算完直接导入',
                'Add one with “+”, or import from the Timer module',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _addRecord,
            icon: const Icon(Icons.add, size: 18),
            label: Text(_t('新增记录', 'Add record')),
          ),
        ],
      ),
    );
  }
}

// ==================== 新增 / 编辑对话框 ====================

/// 弹出「新增 / 编辑记录」对话框，取消返回 null。
///
/// [initial] 非空表示编辑已有记录；[defaultStart] / [defaultEnd] / [defaultScore] /
/// [defaultWinsAfter] 用于「时间计算」导入时预填。
Future<SeasonStatRecord?> showSeasonStatRecordDialog(
  BuildContext context, {
  String locale = 'zh',
  SeasonStatRecord? initial,
  DateTime? defaultStart,
  DateTime? defaultEnd,
  int? defaultScore,
  int? defaultWinsAfter,
}) {
  return showDialog<SeasonStatRecord>(
    context: context,
    builder: (ctx) => _SeasonStatDialog(
      locale: locale,
      initial: initial,
      defaultStart: defaultStart,
      defaultEnd: defaultEnd,
      defaultScore: defaultScore,
      defaultWinsAfter: defaultWinsAfter,
    ),
  );
}

class _SeasonStatDialog extends StatefulWidget {
  final String locale;
  final SeasonStatRecord? initial;
  final DateTime? defaultStart;
  final DateTime? defaultEnd;
  final int? defaultScore;
  final int? defaultWinsAfter;

  const _SeasonStatDialog({
    required this.locale,
    this.initial,
    this.defaultStart,
    this.defaultEnd,
    this.defaultScore,
    this.defaultWinsAfter,
  });

  @override
  State<_SeasonStatDialog> createState() => _SeasonStatDialogState();
}

class _SeasonStatDialogState extends State<_SeasonStatDialog> {
  bool get _isZh => widget.locale == 'zh';
  String _t(String zh, String en) => _isZh ? zh : en;

  late DateTime _start;
  late DateTime _end;
  late TextEditingController _scoreCtrl;
  late TextEditingController _winsCtrl;
  late TextEditingController _multiplierCtrl;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = widget.initial?.startTime ?? widget.defaultStart ?? now;
    _end = widget.initial?.endTime ?? widget.defaultEnd ?? now;
    _scoreCtrl = TextEditingController(
      text: (widget.initial?.finalScore ?? widget.defaultScore ?? 0).toString(),
    );
    final wins = widget.initial?.winsAfter ?? widget.defaultWinsAfter;
    _winsCtrl = TextEditingController(text: wins?.toString() ?? '');
    _multiplierCtrl = TextEditingController(
      text: widget.initial?.settleMultiplier?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    _winsCtrl.dispose();
    _multiplierCtrl.dispose();
    super.dispose();
  }

  int get _durationMinutes {
    final d = _end.difference(_start).inMinutes;
    return d < 0 ? 0 : d;
  }

  int get _winsAfter => int.tryParse(_winsCtrl.text.trim()) ?? 0;

  bool get _hasWins => _winsCtrl.text.trim().isNotEmpty;

  /// 自动取到的系数（系数输入框留空时用它）
  int? get _autoMultiplier =>
      _hasWins ? seasonStatMultiplierOf(_winsAfter) : null;

  /// 最终生效的系数（手填优先）
  int? get _effectiveMultiplier =>
      int.tryParse(_multiplierCtrl.text.trim()) ?? _autoMultiplier;

  int get _gainedScore =>
      (int.tryParse(_scoreCtrl.text.replaceAll(',', '').trim()) ?? 0) *
      (_effectiveMultiplier ?? 0);

  Future<void> _pick(bool isStart) async {
    final base = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(base.year - 5),
      lastDate: DateTime(base.year + 5),
      helpText: isStart ? _t('选择开始日期', 'Start date') : _t('选择结束日期', 'End date'),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: isStart ? _t('选择开始时间', 'Start time') : _t('选择结束时间', 'End time'),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        // 开始时间晚于结束时间时，把结束时间一起顺延，避免出现负时长
        final delta = _end.difference(_start);
        _start = picked;
        if (_end.isBefore(_start)) {
          _end = _start.add(delta.isNegative ? Duration.zero : delta);
        }
      } else {
        _end = picked.isBefore(_start) ? _start : picked;
      }
    });
  }

  Widget _timeRow(String label, DateTime value, bool isStart) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(isStart),
              icon: const Icon(Icons.schedule, size: 16),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  formatSeasonStatFullTime(value),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? _t('新增赛季记录', 'New season record')
            : _t('编辑赛季记录', 'Edit season record'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _timeRow(_t('开始时间', 'Start'), _start, true),
            _timeRow(_t('结束时间', 'End'), _end, false),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 78,
                    child: Text(
                      _t('持续时间', 'Duration'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    formatSeasonStatDuration(_durationMinutes, zh: _isZh),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _t('（自动计算）', '(auto)'),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _scoreCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                signed: false,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _t('战斗分', 'Battle score'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _winsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: false,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _t('赛后胜场', 'Wins after'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _multiplierCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: false,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _t('系数', 'Multiplier'),
                      hintText: _autoMultiplier == null
                          ? _t('自动', 'auto')
                          : '${_t('自动', 'auto')} ×$_autoMultiplier',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.savings,
                  size: 16,
                  color: _effectiveMultiplier == null
                      ? Colors.grey
                      : Colors.deepOrange[700],
                ),
                const SizedBox(width: 6),
                Text(
                  _t('本场得分', 'Gained'),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 8),
                Text(
                  _effectiveMultiplier == null
                      ? _t('待填赛后胜场 / 系数', 'needs wins or multiplier')
                      : '${formatSeasonStatScore(_gainedScore)}'
                            '   （${formatSeasonStatScore(int.tryParse(_scoreCtrl.text.replaceAll(',', '').trim()) ?? 0)} × $_effectiveMultiplier）',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _effectiveMultiplier == null
                        ? Colors.grey
                        : Colors.deepOrange[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_t('取消', 'Cancel')),
        ),
        FilledButton(
          onPressed: () {
            final score =
                int.tryParse(_scoreCtrl.text.replaceAll(',', '').trim()) ?? 0;
            final record = SeasonStatRecord(
              id: widget.initial?.id ?? newSeasonStatId(),
              startTime: _start,
              endTime: _end,
              finalScore: score,
              source: widget.initial?.source ?? 'manual',
              winsAfter: _hasWins ? _winsAfter : null,
              settleMultiplier:
                  int.tryParse(_multiplierCtrl.text.trim()),
            );
            Navigator.pop(context, record);
          },
          child: Text(_t('保存', 'Save')),
        ),
      ],
    );
  }
}

// ==================== 供「时间计算」调用 ====================

/// 「时间计算」→ 导入赛季统计：弹确认框并保存，成功后提示可直接跳转查看。
/// 返回是否真的写入了记录。
Future<bool> importSeasonStatFromTimer(
  BuildContext context, {
  required String locale,
  required DateTime startTime,
  required DateTime endTime,
  required int finalScore,
}) async {
  final isZh = locale == 'zh';
  // 「赛后胜场」默认接上一条 +1（先假定本场是胜场，用户可在对话框里改）
  final existing = await SeasonStatsStore.load();
  final rows = buildSeasonStatRows(existing);
  final defaultWins = rows.isEmpty ? 1 : (rows.last.winsAfter ?? 0) + 1;

  if (!context.mounted) return false;
  final record = await showSeasonStatRecordDialog(
    context,
    locale: locale,
    initial: SeasonStatRecord(
      id: newSeasonStatId(),
      startTime: startTime,
      endTime: endTime,
      finalScore: finalScore,
      source: 'timer',
      winsAfter: defaultWins,
    ),
  );
  if (record == null) return false;
  await SeasonStatsStore.add(record);
  if (!context.mounted) return true;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        isZh
            ? '已导入赛季统计（${formatSeasonStatDuration(record.durationMinutes, zh: true)} · '
                  '战斗分 ${formatSeasonStatScore(record.finalScore)}'
                  '${record.settleMultiplier != null ? ' · ×${record.settleMultiplier}' : ''}）'
            : 'Imported: ${formatSeasonStatDuration(record.durationMinutes, zh: false)} · '
                  '${formatSeasonStatScore(record.finalScore)}',
        style: const TextStyle(fontSize: 12),
      ),
      action: SnackBarAction(
        label: isZh ? '查看' : 'View',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SeasonStatsScreen(locale: locale),
            ),
          );
        },
      ),
    ),
  );
  return true;
}
