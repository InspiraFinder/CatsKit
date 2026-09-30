import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

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
const double _kColSeason = 116;
const double _kColEnemy = 116;
const double _kColTime = 122;
const double _kColDuration = 84;
const double _kColGap = 84;
const double _kColScore = 92;
const double _kColWins = 80;
const double _kColMultiplier = 62;
const double _kColGained = 100;
const double _kColOps = 80;

/// 表格总宽（按当前列顺序算；「操作」列固定在最右）
double _tableWidth(List<SeasonStatColumn> columns) =>
    _kTablePad * 2 +
    columns.fold<double>(0, (s, c) => s + seasonStatColumnWidth(c)) +
    _kColOps;

const double _kRowHeight = 46;
const double _kHeaderHeight = 40;

/// 表格的一列（顺序可由用户自定义）
enum SeasonStatColumn {
  season,
  order,
  enemy,
  start,
  end,
  duration,
  gap,
  battleScore,
  winsBefore,
  winsAfter,
  multiplier,
  gained,
}

/// 默认列顺序（「操作」列固定在最右，不参与排序）
const List<SeasonStatColumn> kDefaultSeasonStatColumns = <SeasonStatColumn>[
  SeasonStatColumn.order,
  SeasonStatColumn.enemy,
  SeasonStatColumn.start,
  SeasonStatColumn.end,
  SeasonStatColumn.duration,
  SeasonStatColumn.gap,
  SeasonStatColumn.battleScore,
  SeasonStatColumn.winsBefore,
  SeasonStatColumn.winsAfter,
  SeasonStatColumn.multiplier,
  SeasonStatColumn.gained,
];

/// 列名（持久化用，别改）
String seasonStatColumnName(SeasonStatColumn c) => c.name;

/// 从持久化的名字还原列（未知名字忽略）
SeasonStatColumn? seasonStatColumnFromName(String name) {
  for (final c in SeasonStatColumn.values) {
    if (c.name == name) return c;
  }
  return null;
}

/// 把存下来的顺序补齐成完整顺序（缺的按默认顺序追加到末尾）
List<SeasonStatColumn> normalizeColumnOrder(List<String> saved) {
  final out = <SeasonStatColumn>[];
  for (final n in saved) {
    final c = seasonStatColumnFromName(n);
    if (c != null && !out.contains(c)) out.add(c);
  }
  for (final c in kDefaultSeasonStatColumns) {
    if (!out.contains(c)) out.add(c);
  }
  return out;
}

/// 列的宽度
double seasonStatColumnWidth(SeasonStatColumn c) {
  switch (c) {
    case SeasonStatColumn.season:
      return _kColSeason;
    case SeasonStatColumn.order:
      return _kColIndex;
    case SeasonStatColumn.enemy:
      return _kColEnemy;
    case SeasonStatColumn.start:
    case SeasonStatColumn.end:
      return _kColTime;
    case SeasonStatColumn.duration:
      return _kColDuration;
    case SeasonStatColumn.gap:
      return _kColGap;
    case SeasonStatColumn.battleScore:
      return _kColScore;
    case SeasonStatColumn.winsBefore:
    case SeasonStatColumn.winsAfter:
      return _kColWins;
    case SeasonStatColumn.multiplier:
      return _kColMultiplier;
    case SeasonStatColumn.gained:
      return _kColGained;
  }
}

/// 列的表头文案
String seasonStatColumnLabel(SeasonStatColumn c, bool zh) {
  switch (c) {
    case SeasonStatColumn.season:
      return zh ? '赛季' : 'Season';
    case SeasonStatColumn.order:
      return zh ? '场次' : 'No.';
    case SeasonStatColumn.enemy:
      return zh ? '对战' : 'Opponent';
    case SeasonStatColumn.start:
      return zh ? '开始' : 'Start';
    case SeasonStatColumn.end:
      return zh ? '结束' : 'End';
    case SeasonStatColumn.duration:
      return zh ? '持续' : 'Duration';
    case SeasonStatColumn.gap:
      return zh ? '间隔' : 'Gap';
    case SeasonStatColumn.battleScore:
      return zh ? '战斗分' : 'Battle';
    case SeasonStatColumn.winsBefore:
      return zh ? '赛前胜场' : 'Wins before';
    case SeasonStatColumn.winsAfter:
      return zh ? '赛后胜场' : 'Wins after';
    case SeasonStatColumn.multiplier:
      return zh ? '系数' : 'x';
    case SeasonStatColumn.gained:
      return zh ? '本场得分' : 'Gained';
  }
}

/// 列对应的排序键（null = 该列不可排序）
SeasonStatSortKey? seasonStatColumnSortKey(SeasonStatColumn c) {
  switch (c) {
    case SeasonStatColumn.season:
      return SeasonStatSortKey.season;
    case SeasonStatColumn.order:
      return SeasonStatSortKey.order;
    case SeasonStatColumn.enemy:
      return SeasonStatSortKey.enemyId;
    case SeasonStatColumn.start:
      return SeasonStatSortKey.startTime;
    case SeasonStatColumn.end:
      return SeasonStatSortKey.endTime;
    case SeasonStatColumn.duration:
      return SeasonStatSortKey.duration;
    case SeasonStatColumn.gap:
      return SeasonStatSortKey.gap;
    case SeasonStatColumn.battleScore:
      return SeasonStatSortKey.finalScore;
    case SeasonStatColumn.winsBefore:
      return SeasonStatSortKey.winsBefore;
    case SeasonStatColumn.winsAfter:
      return SeasonStatSortKey.winsAfter;
    case SeasonStatColumn.multiplier:
      return SeasonStatSortKey.multiplier;
    case SeasonStatColumn.gained:
      return SeasonStatSortKey.gainedScore;
  }
}

class _SeasonStatsScreenState extends State<SeasonStatsScreen> {
  bool get _isZh => widget.locale == 'zh';
  String _t(String zh, String en) => _isZh ? zh : en;

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _hCtrl = ScrollController();

  /// 当前赛季的记录
  List<SeasonStatRecord> _records = <SeasonStatRecord>[];

  /// 已归档的赛季（归档时间新的在前）
  List<SeasonArchive> _archives = <SeasonArchive>[];

  /// 当前赛季的名称
  String _currentName = SeasonStatsStore.defaultCurrentName;

  /// 赛季筛选：`''` = 当前赛季，`*` = 全部赛季（跨赛季查询），其余 = 归档 id
  String _seasonFilter = '';

  /// 派生行（赛季 / 场次 / 间隔 / 胜场 / 系数 / 本场得分）——依赖战斗先后顺序，
  /// 每个赛季各自重算（场次从 1 开始），筛选排序不会影响它。
  List<SeasonStatRow> _rows = <SeasonStatRow>[];
  bool _loading = true;

  /// 搜索方式：按对方 / 按时间范围
  SeasonStatSearchMode _searchMode = SeasonStatSearchMode.opponent;

  /// 按对方搜索的关键词（只匹配对方 ID）
  String _query = '';

  /// 按时间范围搜索的起止时间（闭区间；为空表示不设该侧上限）
  DateTime? _fromTime;
  DateTime? _toTime;

  SeasonStatSortKey _sortKey = SeasonStatSortKey.startTime;
  bool _ascending = false;

  /// 用户自定义的列顺序（不含固定的「操作」列）
  List<SeasonStatColumn> _columns = List<SeasonStatColumn>.of(
    kDefaultSeasonStatColumns,
  );

  /// 自定义导出目录（空 = 用默认目录）
  String _exportDir = '';

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

  /// 当前筛选出来的赛季分组（因为可能跨赛季，所以是一个列表）
  List<SeasonGroup> get _groups {
    final current = SeasonGroup(
      id: '',
      name: _currentName,
      records: _records,
    );
    if (_seasonFilter == '*') {
      return <SeasonGroup>[current, ..._archives.map((a) => a.toGroup())];
    }
    if (_seasonFilter.isEmpty) return <SeasonGroup>[current];
    for (final a in _archives) {
      if (a.id == _seasonFilter) return <SeasonGroup>[a.toGroup()];
    }
    return <SeasonGroup>[current];
  }

  /// 跨赛季查询时（不止一个赛季在表里）才显示「赛季」列
  bool get _showSeasonColumn => _groups.length > 1;

  /// 实际要渲染的列（跨赛季时才插入「赛季」列，位置跟着用户顺序走）
  List<SeasonStatColumn> get _visibleColumns {
    if (!_showSeasonColumn) return _columns;
    // 「赛季」列插在用户顺序里「场次」之前；用户没排过就放最前
    final out = List<SeasonStatColumn>.of(_columns);
    final idx = out.indexOf(SeasonStatColumn.order);
    out.insert(idx < 0 ? 0 : idx, SeasonStatColumn.season);
    return out;
  }

  /// 切换赛季筛选（派生行要跟着重算，否则场次/胜场还是旧赛季的）
  void _setSeasonFilter(String v) {
    setState(() {
      _seasonFilter = v;
      _rows = buildSeasonStatRowsForGroups(_groups);
    });
  }

  /// 当前赛季的派生行（用于新增时预填「赛前胜场」等）
  List<SeasonStatRow> get _currentRows => buildSeasonStatRows(
    _records,
    seasonName: _currentName,
    seasonId: '',
  );

  /// 数据变化后统一刷新原始记录 / 归档 / 派生行
  void _setData({
    List<SeasonStatRecord>? records,
    List<SeasonArchive>? archives,
    String? currentName,
    bool loading = false,
  }) {
    setState(() {
      if (records != null) _records = records;
      if (archives != null) _archives = archives;
      if (currentName != null) _currentName = currentName;
      _rows = buildSeasonStatRowsForGroups(_groups);
      if (loading) _loading = false;
    });
  }

  Future<void> _load() async {
    final records = await SeasonStatsStore.load();
    final archives = await SeasonStatsStore.loadArchives();
    final name = await SeasonStatsStore.loadCurrentName();
    final order = await SeasonStatsStore.loadColumnOrder();
    final exportDir = await SeasonStatsStore.loadExportDir();
    if (!mounted) return;
    setState(() => _columns = normalizeColumnOrder(order));
    _exportDir = exportDir;
    _setData(
      records: records,
      archives: archives,
      currentName: name,
      loading: true,
    );
  }

  /// 当前赛季最后一场的赛后胜场（下一场的「赛前胜场」）；表里没记录时按 0 算
  int? get _lastWins {
    final rows = _currentRows;
    return rows.isEmpty ? 0 : rows.last.winsAfter;
  }

  /// 某条记录在当前赛季里的赛前胜场（编辑时用）
  int? _winsBeforeOf(String id) {
    for (final r in _currentRows) {
      if (r.id == id) return r.winsBefore;
    }
    return null;
  }

  /// 当前搜索 / 筛选条件下的行
  List<SeasonStatRow> get _visible {
    // 两种搜索方式互斥：按对方时不管时间，按时间时不管对方
    final byOpponent = _searchMode == SeasonStatSearchMode.opponent;
    return filterAndSortSeasonStatRows(
      _rows,
      query: byOpponent ? _query : '',
      from: byOpponent ? null : _fromTime,
      to: byOpponent ? null : _toTime,
      sortKey: _sortKey,
      ascending: _ascending,
    );
  }

  /// 是否有任何搜索条件生效
  bool get _hasFilter => _searchMode == SeasonStatSearchMode.opponent
      ? _query.trim().isNotEmpty
      : (_fromTime != null || _toTime != null);

  /// 清空搜索条件
  void _resetSearch() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _fromTime = null;
      _toTime = null;
    });
  }

  /// 选一个时间（[isFrom] = true 选起始，否则选结束）
  Future<void> _pickSearchTime(bool isFrom) async {
    final now = DateTime.now();
    final base = (isFrom ? _fromTime : _toTime) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: isFrom ? _t('选择起始日期', 'Start date') : _t('选择结束日期', 'End date'),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: isFrom ? _t('选择起始时间', 'Start time') : _t('选择结束时间', 'End time'),
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
      if (isFrom) {
        _fromTime = picked;
        // 起始晚于结束时把结束一起顺延，避免出现空区间
        if (_toTime != null && _toTime!.isBefore(picked)) _toTime = picked;
      } else {
        _toTime = picked;
        if (_fromTime != null && _fromTime!.isAfter(picked)) _fromTime = picked;
      }
    });
  }

  /// 快捷填充时间范围（今天 / 近 7 天 / 近 30 天）
  void _quickRange(SeasonStatRange range) {
    final now = DateTime.now();
    final start = rangeStart(range, now: now);
    setState(() {
      _searchMode = SeasonStatSearchMode.time;
      _fromTime = start;
      _toTime = now;
    });
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
      winsBefore: _lastWins,
    );
    if (record == null) return;
    final list = await SeasonStatsStore.add(record);
    if (!mounted) return;
    _setData(records: list);
  }

  Future<void> _editRecord(SeasonStatRecord record) async {
    final edited = await showSeasonStatRecordDialog(
      context,
      locale: widget.locale,
      initial: record,
      winsBefore: _winsBeforeOf(record.id),
    );
    if (edited == null) return;
    final list = await SeasonStatsStore.update(edited);
    if (!mounted) return;
    _setData(records: list);
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
    _setData(records: list);
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('清空当前赛季？', 'Clear the current season?')),
        content: Text(
          _t(
            '将删除当前赛季的 ${_records.length} 条记录（归档不受影响），无法撤销。'
                '赛季结束时建议用「归档」而不是清空。',
            'This deletes the ${_records.length} records of the current season '
                '(archives are untouched) and cannot be undone. Use "Archive" '
                'when a season ends.',
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
    _setData(records: <SeasonStatRecord>[]);
  }

  /// 复制整张表（TSV，可直接粘贴进 Excel / 表格软件）
  void _copyTable() {
    final rows = _visible;
    if (rows.isEmpty) return;
    final showSeason = _showSeasonColumn;
    final buf = StringBuffer()
      ..writeln(
        [
          if (showSeason) _t('赛季', 'Season'),
          _t('场次', 'No.'),
          _t('对战', 'Opponent'),
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
          if (showSeason) r.seasonName,
          r.order.toString(),
          r.enemyId,
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
          PopupMenuButton<String>(
            tooltip: _t('更多', 'More'),
            onSelected: (v) {
              switch (v) {
                case 'archive':
                  _archiveSeason();
                case 'archives':
                  _manageArchives();
                case 'rename':
                  _renameCurrentSeason();
                case 'columns':
                  _editColumnOrder();
                case 'exportDir':
                  _editExportSettings();
                case 'export':
                  _exportToFile();
                case 'import':
                  _importFromFile();
                case 'copy':
                  _copyTable();
                case 'clear':
                  _clearAll();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'archive',
                enabled: _records.isNotEmpty,
                child: _menuRow(
                  Icons.inventory_2_outlined,
                  _t('归档当前赛季', 'Archive season'),
                ),
              ),
              PopupMenuItem(
                value: 'archives',
                child: _menuRow(
                  Icons.folder_special_outlined,
                  _t('管理归档（${_archives.length}）', 'Archives (${_archives.length})'),
                ),
              ),
              PopupMenuItem(
                value: 'rename',
                child: _menuRow(
                  Icons.drive_file_rename_outline,
                  _t('重命名当前赛季', 'Rename season'),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'columns',
                child: _menuRow(
                  Icons.view_column_outlined,
                  _t('调整列顺序', 'Column order'),
                ),
              ),
              PopupMenuItem(
                value: 'exportDir',
                child: _menuRow(
                  Icons.folder_outlined,
                  _t('导出设置（目录）', 'Export folder'),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'export',
                enabled: _records.isNotEmpty || _archives.isNotEmpty,
                child: _menuRow(Icons.file_upload_outlined, _t('导出到文件', 'Export to file')),
              ),
              PopupMenuItem(
                value: 'import',
                child: _menuRow(Icons.file_download_outlined, _t('从文件导入', 'Import from file')),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'copy',
                enabled: rows.isNotEmpty,
                child: _menuRow(Icons.copy_all, _t('复制表格', 'Copy table')),
              ),
              PopupMenuItem(
                value: 'clear',
                enabled: _records.isNotEmpty,
                child: _menuRow(
                  Icons.delete_sweep_outlined,
                  _t('清空当前赛季', 'Clear season'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSeasonBar(),
                _buildSummary(summary),
                _buildFilters(),
                const Divider(height: 1),
                Expanded(child: _buildTable(rows)),
              ],
            ),
    );
  }

  Widget _menuRow(IconData icon, String label) => Row(
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 14)),
    ],
  );

  // ==================== 归档 / 赛季名称 ====================

  /// 归档当前赛季：填名称（+备注）→ 移入归档并清空当前表格
  Future<void> _archiveSeason() async {
    if (_records.isEmpty) return;
    final summary = summarizeSeasonGroup(_records);
    final nameCtrl = TextEditingController(
      text: suggestSeasonName(_records, index: _archives.length + 1),
    );
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(_t('归档当前赛季', 'Archive season')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(
                    '给这赛季起个名字，方便以后在跨赛季查询里认出来。',
                    'Give this season a name so you can find it later.',
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: _t('赛季名称', 'Season name'),
                    hintText: _t('第 1 赛季 / 2026-09 赛季', 'Season 1 / 2026-09'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(
                      label: Text(
                        _t('第 ${_archives.length + 1} 赛季', 'Season ${_archives.length + 1}'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setDialogState(
                        () => nameCtrl.text = '第 ${_archives.length + 1} 赛季',
                      ),
                    ),
                    if (suggestSeasonName(_records).isNotEmpty)
                      ActionChip(
                        label: Text(
                          suggestSeasonName(_records),
                          style: const TextStyle(fontSize: 12),
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setDialogState(
                          () => nameCtrl.text = suggestSeasonName(_records),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: _t('备注（可选）', 'Note (optional)'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                _archiveSummaryBox(summary),
                const SizedBox(height: 8),
                Text(
                  _t(
                    '⚠️ 归档后当前表格会清空，新赛季从第 1 场重新开始。',
                    '⚠️ The current table will be cleared and the new season restarts at battle 1.',
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t('取消', 'Cancel')),
            ),
            FilledButton(
              onPressed: nameCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: Text(_t('归档', 'Archive')),
            ),
          ],
        ),
      ),
    );

    final name = nameCtrl.text.trim();
    final note = noteCtrl.text.trim();
    nameCtrl.dispose();
    noteCtrl.dispose();
    if (ok != true || !mounted) return;

    final archives = await SeasonStatsStore.archiveCurrent(
      name: name,
      note: note,
    );
    final newName = suggestSeasonName(<SeasonStatRecord>[]);
    await SeasonStatsStore.saveCurrentName(newName);
    if (!mounted) return;
    _setData(
      records: <SeasonStatRecord>[],
      archives: archives,
      currentName: newName,
    );
    _snack(_t('已归档「$name」', 'Archived "$name"'));
  }

  /// 归档信息小卡（归档确认里用）
  Widget _archiveSummaryBox(SeasonGroupSummary s) {
    String line(String label, String value) => '$label：$value';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line(_t('场数', 'Battles'), '${s.battleCount}'),
            style: const TextStyle(fontSize: 13),
          ),
          Text(
            line(_t('胜场', 'Wins'), '${s.winCount}'),
            style: const TextStyle(fontSize: 13),
          ),
          Text(
            line(
              _t('本场得分合计', 'Gained'),
              formatSeasonStatScore(s.totalGained),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          if (s.startTime != null && s.endTime != null)
            Text(
              line(
                _t('时间范围', 'Range'),
                '${formatSeasonStatFullTime(s.startTime!)} ~ '
                    '${formatSeasonStatFullTime(s.endTime!)}',
              ),
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }

  /// 重命名当前赛季
  Future<void> _renameCurrentSeason() async {
    final ctrl = TextEditingController(text: _currentName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('重命名当前赛季', 'Rename current season')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: _t('赛季名称', 'Season name'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('保存', 'Save')),
          ),
        ],
      ),
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || !mounted) return;
    final saved = name.isEmpty ? SeasonStatsStore.defaultCurrentName : name;
    await SeasonStatsStore.saveCurrentName(saved);
    if (!mounted) return;
    _setData(currentName: saved);
  }

  /// 归档管理：重命名 / 查看 / 导出 / 删除 / 取回到当前赛季
  Future<void> _manageArchives() async {
    while (mounted) {
      final action = await showDialog<_ArchiveAction>(
        context: context,
        builder: (ctx) => _ArchiveManagerDialog(
          locale: widget.locale,
          archives: _archives,
          currentName: _currentName,
        ),
      );
      if (action == null || !mounted) return;

      if (action.type == _ArchiveActionType.open) {
        _setSeasonFilter(action.archive!.id);
        return;
      }
      if (action.type == _ArchiveActionType.rename) {
        await _renameArchive(action.archive!);
      } else if (action.type == _ArchiveActionType.delete) {
        await _deleteArchive(action.archive!);
      } else if (action.type == _ArchiveActionType.restore) {
        await _restoreArchive(action.archive!);
      } else if (action.type == _ArchiveActionType.export) {
        await _exportToFile(onlyArchive: action.archive);
      }
      if (!mounted) return;
      // 回到管理列表继续操作
    }
  }

  Future<void> _renameArchive(SeasonArchive archive) async {
    final nameCtrl = TextEditingController(text: archive.name);
    final noteCtrl = TextEditingController(text: archive.note);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('编辑归档信息', 'Edit archive')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _t('赛季名称', 'Season name'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: _t('备注', 'Note'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('保存', 'Save')),
          ),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final note = noteCtrl.text.trim();
    nameCtrl.dispose();
    noteCtrl.dispose();
    if (ok != true || !mounted || name.isEmpty) return;
    final archives = await SeasonStatsStore.upsertArchive(
      archive.copyWith(name: name, note: note),
    );
    if (!mounted) return;
    _setData(archives: archives);
  }

  Future<void> _deleteArchive(SeasonArchive archive) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('删除归档「${archive.name}」？', 'Delete "${archive.name}"?')),
        content: Text(
          _t(
            '将删除该赛季的全部 ${archive.battleCount} 条记录，无法撤销。',
            'This deletes all ${archive.battleCount} battles of this season and cannot be undone.',
          ),
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
    if (ok != true || !mounted) return;
    final archives = await SeasonStatsStore.removeArchive(archive.id);
    if (!mounted) return;
    _setData(
      archives: archives,
      // 当前正看着这个被删掉的赛季就切回当前赛季
      currentName: _seasonFilter == archive.id ? _currentName : null,
    );
    if (_seasonFilter == archive.id) {
      _setSeasonFilter('');
    }
    _snack(_t('已删除归档「${archive.name}」', 'Deleted "${archive.name}"'));
  }

  /// 把归档的记录取回当前赛季（归档本身保留）
  Future<void> _restoreArchive(SeasonArchive archive) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('取回到当前赛季？', 'Restore into current season?')),
        content: Text(
          _t(
            '把「${archive.name}」的 ${archive.battleCount} 条记录追加到当前赛季'
                '（${_records.length} 条）后面，归档本身保留。',
            'Append the ${archive.battleCount} battles of "${archive.name}" to the '
                'current season (${_records.length} battles). The archive is kept.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('取回', 'Restore')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final records = await SeasonStatsStore.restoreFromArchive(archive);
    if (!mounted) return;
    _setData(records: records);
    _snack(_t('已取回 ${archive.battleCount} 场', 'Restored ${archive.battleCount} battles'));
  }

  // ==================== 文件导入 / 导出 ====================

  /// 默认导出目录
  ///
  /// - 桌面：`~/Downloads/CatsKit`（用户能直接看到）
  /// - Android：`/storage/emulated/0/Download/CatsKit`（公共下载目录，比应用私有目录好找；
  ///   若系统不允许写入，导出时会报错并提示改用自定义目录）
  /// - iOS：应用缓存目录（iOS 没有公共可写目录，导出后走「打开文件」分享出去）
  String _defaultExportDir() {
    final sep = Platform.pathSeparator;
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download${sep}CatsKit';
    }
    if (Platform.isIOS) {
      return '${Directory.systemTemp.path}${sep}CatsKit';
    }
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return '$home${sep}Downloads${sep}CatsKit';
  }

  /// 当前生效的导出目录（自定义优先）
  String get _effectiveExportDir =>
      _exportDir.trim().isEmpty ? _defaultExportDir() : _exportDir.trim();

  /// 列顺序设置：上下移动调整，可恢复默认
  Future<void> _editColumnOrder() async {
    var order = List<SeasonStatColumn>.of(_columns);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void move(int i, int delta) {
            final j = i + delta;
            if (j < 0 || j >= order.length) return;
            setDialogState(() {
              final tmp = order[i];
              order[i] = order[j];
              order[j] = tmp;
            });
          }

          return AlertDialog(
            title: Text(_t('调整列顺序', 'Column order')),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(
                      '用箭头调整左右顺序（越靠上越靠左）。「操作」列固定在最右。',
                      'Use the arrows to reorder columns (top = leftmost). '
                          'The Actions column stays rightmost.',
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: order.length,
                      itemBuilder: (ctx, i) {
                        final c = order[i];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          title: Text(
                            seasonStatColumnLabel(c, _isZh),
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_upward, size: 18),
                                tooltip: _t('左移', 'Move left'),
                                visualDensity: VisualDensity.compact,
                                onPressed: i == 0 ? null : () => move(i, -1),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_downward,
                                  size: 18,
                                ),
                                tooltip: _t('右移', 'Move right'),
                                visualDensity: VisualDensity.compact,
                                onPressed: i == order.length - 1
                                    ? null
                                    : () => move(i, 1),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => setDialogState(
                  () => order = List<SeasonStatColumn>.of(
                    kDefaultSeasonStatColumns,
                  ),
                ),
                child: Text(_t('恢复默认', 'Reset')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(_t('取消', 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(_t('保存', 'Save')),
              ),
            ],
          );
        },
      ),
    );
    if (saved != true || !mounted) return;
    await SeasonStatsStore.saveColumnOrder(
      order.map(seasonStatColumnName).toList(),
    );
    if (!mounted) return;
    setState(() => _columns = order);
  }

  /// 导出设置：自定义导出目录
  Future<void> _editExportSettings() async {
    final dir = await showDialog<String>(
      context: context,
      builder: (ctx) => _ExportSettingsDialog(
        locale: widget.locale,
        initialDir: _effectiveExportDir,
        defaultDir: _defaultExportDir(),
      ),
    );
    if (dir == null || !mounted) return;
    await SeasonStatsStore.saveExportDir(dir);
    if (!mounted) return;
    setState(() => _exportDir = dir);
    _snack(_t('导出目录已保存', 'Export folder saved'));
  }

  /// 导出到文件：一份 JSON（可再导入）+ 一份 TSV（Excel 可直接打开）
  ///
  /// [onlyArchive] 非空时只导出该归档；否则导出当前赛季 + 全部归档。
  Future<void> _exportToFile({SeasonArchive? onlyArchive}) async {
    final now = DateTime.now();
    final groups = onlyArchive != null
        ? <SeasonGroup>[onlyArchive.toGroup()]
        : <SeasonGroup>[
            SeasonGroup(id: '', name: _currentName, records: _records),
            ..._archives.map((a) => a.toGroup()),
          ];
    final bundle = SeasonStatsBundle(
      currentSeasonName: _currentName,
      records: onlyArchive != null ? <SeasonStatRecord>[] : _records,
      archives: onlyArchive != null ? <SeasonArchive>[onlyArchive] : _archives,
    );
    if (bundle.isEmpty) {
      _snack(_t('没有可导出的记录', 'Nothing to export'));
      return;
    }

    try {
      final dir = Directory(_effectiveExportDir);
      if (!await dir.exists()) await dir.create(recursive: true);
      final stamp = formatSeasonStatFileStamp(now);
      final base = onlyArchive != null
          ? 'CatsKit-赛季-${_safeFileName(onlyArchive.name)}-$stamp'
          : 'CatsKit-赛季统计-$stamp';
      final jsonFile = File('${dir.path}${Platform.pathSeparator}$base.json');
      final tsvFile = File('${dir.path}${Platform.pathSeparator}$base.tsv');
      await jsonFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(bundle.toJson()),
        flush: true,
      );
      // BOM 让 Excel 正确识别 UTF-8 中文
      await tsvFile.writeAsString(
        '\uFEFF${seasonGroupsToTsv(groups, zh: _isZh)}',
        flush: true,
      );
      if (!mounted) return;
      await _showExportResult(
        jsonPath: jsonFile.path,
        tsvPath: tsvFile.path,
        battles: bundle.totalRecords,
      );
    } catch (e) {
      if (!mounted) return;
      _snack(_t('导出失败：$e', 'Export failed: $e'));
    }
  }

  String _safeFileName(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');

  Future<void> _showExportResult({
    required String jsonPath,
    required String tsvPath,
    required int battles,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('导出完成', 'Export done')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('共 $battles 场已导出到：', '$battles battles exported to:'),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              SelectableText(
                jsonPath,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _t('（JSON：可再导入回 App）', '(JSON: importable back into the app)'),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              SelectableText(
                tsvPath,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _t('（TSV：用 Excel / 表格软件打开）', '(TSV: open with Excel)'),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonPath));
              _snack(_t('已复制路径', 'Path copied'));
            },
            child: Text(_t('复制路径', 'Copy path')),
          ),
          TextButton(
            onPressed: () => OpenFilex.open(tsvPath),
            child: Text(_t('打开表格', 'Open TSV')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('好', 'OK')),
          ),
        ],
      ),
    );
  }

  /// 从文件导入（弹系统文件选择器）
  Future<void> _importFromFile() async {
    const group = XTypeGroup(
      label: '赛季统计存档',
      extensions: <String>['json'],
    );
    XFile? file;
    try {
      file = await openFile(acceptedTypeGroups: const <XTypeGroup>[group]);
    } catch (e) {
      if (!mounted) return;
      _snack(_t('打开文件选择器失败：$e', 'File picker failed: $e'));
      return;
    }
    if (file == null || !mounted) return;

    SeasonStatsBundle bundle;
    try {
      bundle = decodeSeasonStatsBundle(await file.readAsString());
    } catch (e) {
      if (!mounted) return;
      _snack(_t('文件格式不对：$e', 'Bad file: $e'));
      return;
    }
    if (bundle.isEmpty) {
      _snack(_t('文件里没有任何赛季记录', 'The file has no battles'));
      return;
    }
    if (!mounted) return;

    final mode = await showDialog<_ImportMode>(
      context: context,
      builder: (ctx) => _ImportModeDialog(
        locale: widget.locale,
        fileName: file!.name,
        bundle: bundle,
      ),
    );
    if (mode == null || !mounted) return;

    try {
      final archives = await SeasonStatsStore.loadArchives();
      final records = mode == _ImportMode.replaceAll
          ? <SeasonStatRecord>[]
          : await SeasonStatsStore.load();
      final usedIds = <String>{
        for (final a in mode == _ImportMode.replaceAll
            ? <SeasonArchive>[]
            : archives)
          for (final r in a.records) r.id,
        for (final r in records) r.id,
      };
      String freshId() {
        var id = newSeasonStatId();
        while (usedIds.contains(id)) {
          id = newSeasonStatId() + (usedIds.length).toString();
        }
        usedIds.add(id);
        return id;
      }

      // 归档：追加（replaceAll 时直接替换）
      final outArchives = mode == _ImportMode.replaceAll
          ? <SeasonArchive>[]
          : List<SeasonArchive>.of(archives);
      for (final a in bundle.archives) {
        outArchives.insert(
          0,
          a.copyWith(
            id: freshId(),
            records: <SeasonStatRecord>[
              for (final r in a.records) r.copyWith(id: freshId()),
            ],
          ),
        );
      }

      // 当前赛季记录
      var outRecords = List<SeasonStatRecord>.of(records);
      if (mode == _ImportMode.asCurrentSeason) {
        for (final r in bundle.records) {
          outRecords.add(r.copyWith(id: freshId()));
        }
      } else if (mode == _ImportMode.asNewArchive) {
        // 把文件里的「当前赛季」也变成一个归档
        final name = bundle.currentSeasonName.trim().isEmpty
            ? suggestSeasonName(bundle.records, index: outArchives.length + 1)
            : bundle.currentSeasonName.trim();
        if (bundle.records.isNotEmpty) {
          outArchives.insert(
            0,
            SeasonArchive(
              id: freshId(),
              name: name,
              archivedAt: DateTime.now(),
              records: <SeasonStatRecord>[
                for (final r in bundle.records) r.copyWith(id: freshId()),
              ],
            ),
          );
        }
      }

      await SeasonStatsStore.saveArchives(outArchives);
      await SeasonStatsStore.save(outRecords);
      if (!mounted) return;
      _setData(archives: outArchives, records: outRecords);
      _snack(
        _t(
          '已导入 ${bundle.totalRecords} 场',
          'Imported ${bundle.totalRecords} battles',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack(_t('导入失败：$e', 'Import failed: $e'));
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontSize: 12))),
    );
  }

  /// 赛季选择条：当前赛季 / 全部赛季（跨赛季查询） / 各归档
  Widget _buildSeasonBar() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // 注意：总数要按「当前赛季 + 全部归档」算，不能跟着当前筛选变
    final totalAll =
        _records.length + _archives.fold<int>(0, (s, a) => s + a.battleCount);
    final visibleCount = summarizeSeasonStats(_visible).count;
    return Container(
      width: double.infinity,
      color: dark ? Colors.white10 : Colors.teal.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Icon(Icons.calendar_month, size: 18, color: Colors.teal[700]),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _seasonFilter,
                isDense: true,
                isExpanded: true,
                style: TextStyle(
                  fontSize: 14,
                  color: dark ? Colors.white : Colors.black87,
                ),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                    value: '',
                    child: Text(
                      _t(
                        '当前赛季：$_currentName（${_records.length} 场）',
                        'Current: $_currentName (${_records.length})',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_archives.isNotEmpty)
                    DropdownMenuItem(
                      value: '*',
                      child: Text(
                        _t(
                          '全部赛季（共 $totalAll 场）',
                          'All seasons ($totalAll)',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  for (final a in _archives)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text(
                        '${a.name}（${a.battleCount} 场）',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => _setSeasonFilter(v ?? ''),
              ),
            ),
          ),
          if (_showSeasonColumn) ...[
            const SizedBox(width: 8),
            Text(
              _t('跨赛季显示 $visibleCount 场', '$visibleCount across seasons'),
              style: TextStyle(fontSize: 11, color: Colors.teal[700]),
            ),
          ],
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
            _t('总场次', 'Battles'),
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

  /// 搜索区：先选「搜什么」（对方 / 时间），再按对应方式输入
  Widget _buildFilters() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final byOpponent = _searchMode == SeasonStatSearchMode.opponent;

    Widget quickChip(SeasonStatRange range, String label) => ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      onPressed: () => _quickRange(range),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          // ---- 先选搜索方式 ----
          Row(
            children: [
              Text(
                _t('搜索：', 'Search:'),
                style: TextStyle(
                  fontSize: 13,
                  color: dark ? Colors.white70 : Colors.grey[700],
                ),
              ),
              const SizedBox(width: 8),
              SegmentedButton<SeasonStatSearchMode>(
                segments: <ButtonSegment<SeasonStatSearchMode>>[
                  ButtonSegment<SeasonStatSearchMode>(
                    value: SeasonStatSearchMode.opponent,
                    icon: const Icon(Icons.groups_2, size: 16),
                    label: Text(
                      _t('对方', 'Opponent'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  ButtonSegment<SeasonStatSearchMode>(
                    value: SeasonStatSearchMode.time,
                    icon: const Icon(Icons.schedule, size: 16),
                    label: Text(
                      _t('时间', 'Time'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                selected: <SeasonStatSearchMode>{_searchMode},
                onSelectionChanged: (s) =>
                    setState(() => _searchMode = s.first),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Spacer(),
              if (_hasFilter)
                TextButton.icon(
                  onPressed: _resetSearch,
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: Text(
                    _t('重置', 'Reset'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // ---- 按对方：搜索框 ----
          if (byOpponent)
            SizedBox(
              height: 36,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _t('输入对方 ID', 'Enter opponent ID'),
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
            )
          // ---- 按时间：起始 + 结束 ----
          else ...[
            Row(
              children: [
                Expanded(
                  child: _timeField(
                    label: _t('起始时间', 'From'),
                    value: _fromTime,
                    onTap: () => _pickSearchTime(true),
                    onClear: _fromTime == null
                        ? null
                        : () => setState(() => _fromTime = null),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _timeField(
                    label: _t('结束时间', 'To'),
                    value: _toTime,
                    onTap: () => _pickSearchTime(false),
                    onClear: _toTime == null
                        ? null
                        : () => setState(() => _toTime = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Text(
                    _t('快捷：', 'Quick:'),
                    style: TextStyle(
                      fontSize: 12,
                      color: dark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 6),
                  quickChip(SeasonStatRange.today, _t('今天', 'Today')),
                  const SizedBox(width: 6),
                  quickChip(SeasonStatRange.last7, _t('近 7 天', '7 days')),
                  const SizedBox(width: 6),
                  quickChip(SeasonStatRange.last30, _t('近 30 天', '30 days')),
                ],
              ),
            ),
          ],

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _t(
                '共 ${_groups.fold<int>(0, (s, g) => s + g.records.length)} 场，'
                    '当前显示 ${_visible.length} 场',
                '${_groups.fold<int>(0, (s, g) => s + g.records.length)} battles, '
                    '${_visible.length} shown',
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

  /// 时间输入框（点一下弹日期 + 时间选择）
  Widget _timeField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          suffixIcon: onClear == null
              ? const Icon(Icons.schedule, size: 16)
              : IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onClear,
                  visualDensity: VisualDensity.compact,
                ),
        ),
        child: Text(
          value == null
              ? _t('不限', 'Any')
              : formatSeasonStatFullTime(value),
          style: TextStyle(
            fontSize: 13,
            color: value == null ? Colors.grey : null,
          ),
        ),
      ),
    );
  }

  Widget _buildTable(List<SeasonStatRow> rows) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final columns = _visibleColumns;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(
          _tableWidth(columns),
          constraints.maxWidth,
        );
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
                  _buildHeader(dark, columns: columns),
                  Expanded(
                    child: rows.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            itemCount: rows.length,
                            itemExtent: _kRowHeight,
                            itemBuilder: (context, index) => _buildRow(
                              rows[index],
                              index,
                              dark,
                              columns: columns,
                            ),
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

  Widget _buildHeader(
    bool dark, {
    required List<SeasonStatColumn> columns,
  }) {
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
          for (final c in columns)
            cell(
              seasonStatColumnLabel(c, _isZh),
              width: seasonStatColumnWidth(c),
              sortKey: seasonStatColumnSortKey(c),
            ),
          cell(_t('操作', 'Actions'), width: _kColOps),
        ],
      ),
    );
  }

  Widget _buildRow(
    SeasonStatRow r,
    int index,
    bool dark, {
    required List<SeasonStatColumn> columns,
  }) {
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

    /// 按列类型渲染单元格
    Widget cellOf(SeasonStatColumn c) {
      switch (c) {
        case SeasonStatColumn.season:
          return cell(
            r.seasonName.isEmpty ? '-' : r.seasonName,
            _kColSeason,
            style: TextStyle(
              fontSize: 12,
              color: dark ? Colors.white70 : Colors.teal[800],
            ),
          );
        case SeasonStatColumn.order:
          return SizedBox(
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
          );
        case SeasonStatColumn.enemy:
          return cell(
            r.enemyId.isEmpty ? '-' : r.enemyId,
            _kColEnemy,
            style: r.enemyId.isEmpty ? dim : null,
          );
        case SeasonStatColumn.start:
          return cell(formatSeasonStatTime(r.startTime), _kColTime);
        case SeasonStatColumn.end:
          return cell(formatSeasonStatTime(r.endTime), _kColTime);
        case SeasonStatColumn.duration:
          return cell(
            formatSeasonStatDuration(r.durationMinutes, zh: _isZh),
            _kColDuration,
          );
        case SeasonStatColumn.gap:
          return cell(
            r.gapMinutes == null
                ? '-'
                : formatSeasonStatDuration(r.gapMinutes!, zh: _isZh),
            _kColGap,
            style: r.gapMinutes == null ? dim : null,
          );
        case SeasonStatColumn.battleScore:
          return cell(
            formatSeasonStatScore(r.finalScore),
            _kColScore,
            style: const TextStyle(fontSize: 13),
          );
        case SeasonStatColumn.winsBefore:
          return cell(
            r.winsBefore?.toString() ?? '-',
            _kColWins,
            style: r.winsBefore == null ? dim : null,
          );
        case SeasonStatColumn.winsAfter:
          return cell(
            r.winsAfter?.toString() ?? '-',
            _kColWins,
            style: r.winsAfter == null
                ? dim
                : const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          );
        case SeasonStatColumn.multiplier:
          return cell(
            r.multiplier == null ? '-' : '×${r.multiplier}',
            _kColMultiplier,
            style: r.multiplier == null
                ? dim
                : TextStyle(
                    fontSize: 13,
                    color: Colors.deepOrange[700],
                    fontWeight: FontWeight.bold,
                  ),
          );
        case SeasonStatColumn.gained:
          return cell(
            r.gainedScore == null
                ? '-'
                : formatSeasonStatScore(r.gainedScore!),
            _kColGained,
            style: r.gainedScore == null
                ? dim
                : const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          );
      }
    }

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
              for (final c in columns) cellOf(c),
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

// ==================== 导出设置 ====================

/// 导出目录设置对话框（自己持有控制器，避免关闭动画期间被 dispose）
class _ExportSettingsDialog extends StatefulWidget {
  final String locale;
  final String initialDir;
  final String defaultDir;

  const _ExportSettingsDialog({
    required this.locale,
    required this.initialDir,
    required this.defaultDir,
  });

  @override
  State<_ExportSettingsDialog> createState() => _ExportSettingsDialogState();
}

class _ExportSettingsDialogState extends State<_ExportSettingsDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initialDir,
  );

  bool get _isZh => widget.locale == 'zh';
  String _t(String zh, String en) => _isZh ? zh : en;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_t('导出设置', 'Export settings')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t(
                '导出的 JSON / TSV 会写到这里。手机默认是公共「下载」目录；'
                    '如果系统不允许写入，可以改成别的目录。',
                'Exported JSON / TSV files go here. On Android the default is the public '
                    'Download folder; if the system blocks writing there, pick another folder.',
              ),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                labelText: _t('导出目录', 'Export folder'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    // 先取好 messenger，避免 await 之后再碰 context
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final dir = await getDirectoryPath(
                        confirmButtonText: _t('选择', 'Select'),
                      );
                      if (dir == null || dir.isEmpty || !mounted) return;
                      setState(() => _ctrl.text = dir);
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            _t(
                              '这个平台不支持选目录，请直接填路径：$e',
                              'Folder picker unsupported here, type the path: $e',
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: Text(
                    _t('选择文件夹', 'Pick folder'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _ctrl.text = widget.defaultDir),
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: Text(
                    _t('恢复默认', 'Default'),
                    style: const TextStyle(fontSize: 12),
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
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: Text(_t('保存', 'Save')),
        ),
      ],
    );
  }
}

// ==================== 归档管理 ====================

/// 归档管理里可执行的操作
enum _ArchiveActionType { open, rename, export, restore, delete }

class _ArchiveAction {
  final _ArchiveActionType type;
  final SeasonArchive? archive;

  const _ArchiveAction(this.type, [this.archive]);
}

/// 归档列表对话框：查看 / 重命名 / 导出 / 取回 / 删除
class _ArchiveManagerDialog extends StatelessWidget {
  final String locale;
  final List<SeasonArchive> archives;
  final String currentName;

  const _ArchiveManagerDialog({
    required this.locale,
    required this.archives,
    required this.currentName,
  });

  @override
  Widget build(BuildContext context) {
    final isZh = locale == 'zh';
    String t(String zh, String en) => isZh ? zh : en;
    return AlertDialog(
      title: Text(t('赛季归档（${archives.length}）', 'Archives (${archives.length})')),
      content: SizedBox(
        width: 420,
        child: archives.isEmpty
            ? Text(
                t(
                  '还没有归档。赛季结束时用「归档当前赛季」把记录存下来，'
                      '之后就能在这里查看、导出或跨赛季查询。',
                  'No archives yet. Use "Archive season" when a season ends, then you '
                      'can browse, export or query across seasons here.',
                ),
                style: const TextStyle(fontSize: 13),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: archives.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final a = archives[i];
                  final start = a.startTime;
                  final end = a.endTime;
                  final range = (start == null || end == null)
                      ? ''
                      : '${formatSeasonStatExportTime(start)} ~ '
                            '${formatSeasonStatExportTime(end)}';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.inventory_2_outlined, size: 20),
                    title: Text(
                      a.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(
                            '${a.battleCount} 场 · 归档于 ${formatSeasonStatExportTime(a.archivedAt)}',
                            '${a.battleCount} battles · archived ${formatSeasonStatExportTime(a.archivedAt)}',
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (range.isNotEmpty)
                          Text(
                            range,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        if (a.note.isNotEmpty)
                          Text(
                            a.note,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                    trailing: PopupMenuButton<_ArchiveActionType>(
                      tooltip: t('操作', 'Actions'),
                      onSelected: (v) {
                        Navigator.pop(ctx, _ArchiveAction(v, a));
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: _ArchiveActionType.open,
                          child: Text(t('查看（切到该赛季）', 'View')),
                        ),
                        PopupMenuItem(
                          value: _ArchiveActionType.rename,
                          child: Text(t('重命名 / 备注', 'Rename')),
                        ),
                        PopupMenuItem(
                          value: _ArchiveActionType.export,
                          child: Text(t('导出到文件', 'Export')),
                        ),
                        PopupMenuItem(
                          value: _ArchiveActionType.restore,
                          child: Text(t('取回到当前赛季', 'Restore')),
                        ),
                        PopupMenuItem(
                          value: _ArchiveActionType.delete,
                          child: Text(t('删除归档', 'Delete')),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('关闭', 'Close')),
        ),
      ],
    );
  }
}

// ==================== 导入方式 ====================

enum _ImportMode { asCurrentSeason, asNewArchive, replaceAll }

/// 导入方式选择：追加到当前赛季 / 作为归档导入 / 替换全部数据
class _ImportModeDialog extends StatefulWidget {
  final String locale;
  final String fileName;
  final SeasonStatsBundle bundle;

  const _ImportModeDialog({
    required this.locale,
    required this.fileName,
    required this.bundle,
  });

  @override
  State<_ImportModeDialog> createState() => _ImportModeDialogState();
}

class _ImportModeDialogState extends State<_ImportModeDialog> {
  _ImportMode mode = _ImportMode.asCurrentSeason;

  @override
  Widget build(BuildContext context) {
    final isZh = widget.locale == 'zh';
    String t(String zh, String en) => isZh ? zh : en;
    final b = widget.bundle;

    Widget option(_ImportMode m, String title, String desc) => ListTile(
      onTap: () => setState(() => mode = m),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        mode == m
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked,
        size: 20,
        color: mode == m ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
    );

    return AlertDialog(
      title: Text(t('导入赛季记录', 'Import battles')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.fileName,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                t(
                  '文件里有：当前赛季 ${b.records.length} 场'
                      '${b.archives.isEmpty ? '' : '，归档 ${b.archives.length} 个（${b.archives.fold<int>(0, (s, a) => s + a.battleCount)} 场）'}',
                  'File contains: ${b.records.length} battles in the current season'
                      '${b.archives.isEmpty ? '' : ', ${b.archives.length} archives (${b.archives.fold<int>(0, (s, a) => s + a.battleCount)} battles)'}',
                ),
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              const Divider(),
              option(
                _ImportMode.asCurrentSeason,
                t('追加到当前赛季', 'Append to current season'),
                t('把文件里的当前赛季记录接在现有记录后面', 'Append the file\'s battles after the current ones'),
              ),
              option(
                _ImportMode.asNewArchive,
                t('作为归档导入', 'Import as archive'),
                t('文件里的当前赛季会变成一个归档，不污染正在打的赛季', 'The file\'s season becomes an archive'),
              ),
              option(
                _ImportMode.replaceAll,
                t('替换全部数据', 'Replace everything'),
                t('⚠️ 清空现有记录与归档，只用文件里的内容', '⚠️ Wipes current records and archives'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('取消', 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, mode),
          child: Text(t('导入', 'Import')),
        ),
      ],
    );
  }
}

// ==================== 新增 / 编辑对话框 ====================

/// 弹出「新增 / 编辑记录」对话框，取消返回 null。
///
/// [initial] 非空表示编辑已有记录；[defaultStart] / [defaultEnd] / [defaultScore] /
/// [winsBefore] 用于「时间计算」导入或手动新增时预填：
/// 「赛前胜场」决定结算系数（不填系数就自动按它取），「赛后胜场」默认 = 赛前 +1。
Future<SeasonStatRecord?> showSeasonStatRecordDialog(
  BuildContext context, {
  String locale = 'zh',
  SeasonStatRecord? initial,
  DateTime? defaultStart,
  DateTime? defaultEnd,
  int? defaultScore,
  int? winsBefore,
  String defaultEnemyId = '',
}) {
  return showDialog<SeasonStatRecord>(
    context: context,
    builder: (ctx) => _SeasonStatDialog(
      locale: locale,
      initial: initial,
      defaultStart: defaultStart,
      defaultEnd: defaultEnd,
      defaultScore: defaultScore,
      winsBefore: winsBefore,
      defaultEnemyId: defaultEnemyId,
    ),
  );
}

class _SeasonStatDialog extends StatefulWidget {
  final String locale;
  final SeasonStatRecord? initial;
  final DateTime? defaultStart;
  final DateTime? defaultEnd;
  final int? defaultScore;

  /// 本场之前的赛季胜场（决定结算系数）
  final int? winsBefore;

  /// 「对战」输入框的默认值
  final String defaultEnemyId;

  const _SeasonStatDialog({
    required this.locale,
    this.initial,
    this.defaultStart,
    this.defaultEnd,
    this.defaultScore,
    this.winsBefore,
    this.defaultEnemyId = '',
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
  late TextEditingController _winsBeforeCtrl;
  late TextEditingController _enemyCtrl;

  /// 本场结果：true = 获胜
  late bool _won;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = widget.initial?.startTime ?? widget.defaultStart ?? now;
    _end = widget.initial?.endTime ?? widget.defaultEnd ?? now;
    _scoreCtrl = TextEditingController(
      text: (widget.initial?.finalScore ?? widget.defaultScore ?? 0).toString(),
    );
    final wins = widget.initial?.winsBefore ?? widget.winsBefore;
    _winsBeforeCtrl = TextEditingController(text: wins?.toString() ?? '');
    _enemyCtrl = TextEditingController(
      text: widget.initial?.enemyId.isNotEmpty == true
          ? widget.initial!.enemyId
          : widget.defaultEnemyId,
    );
    _won = widget.initial?.won ?? true;
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    _winsBeforeCtrl.dispose();
    _enemyCtrl.dispose();
    super.dispose();
  }

  int get _durationMinutes {
    final d = _end.difference(_start).inMinutes;
    return d < 0 ? 0 : d;
  }

  /// 输入的赛前胜场（空 = 没填）
  int? get _winsBeforeInput {
    final text = _winsBeforeCtrl.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  /// 结算系数：完全由「赛前胜场」决定
  int? get _multiplier => seasonScoreMultiplierOf(_winsBeforeInput);

  /// 赛后胜场 = 赛前 +（本场获胜 ? 1 : 0）
  int? get _winsAfter => _winsBeforeInput == null
      ? null
      : _winsBeforeInput! + (_won ? 1 : 0);

  /// 系数所在档位的文案（`0 - 1` / `30 及以上`）
  String _multiplierBandLabel() {
    final before = _winsBeforeInput;
    if (before == null) return '-';
    for (final band in kSeasonScoreMultipliers) {
      if (before < band.minWins) continue;
      if (band.maxWins != null && before > band.maxWins!) continue;
      return band.winsLabel(_isZh);
    }
    return '-';
  }

  int get _battleScore =>
      int.tryParse(_scoreCtrl.text.replaceAll(',', '').trim()) ?? 0;

  int? get _gainedScore =>
      _multiplier == null ? null : _battleScore * _multiplier!;

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
              controller: _enemyCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _t('对战（敌方 ID）', 'Opponent (enemy ID)'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _winsBeforeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: false,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _t('赛前胜场', 'Wins before'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 132,
                  child: SegmentedButton<bool>(
                    segments: <ButtonSegment<bool>>[
                      ButtonSegment<bool>(
                        value: true,
                        label: Text(
                          _t('胜', 'Win'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(
                          _t('负', 'Lose'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                    selected: <bool>{_won},
                    onSelectionChanged: (s) => setState(() => _won = s.first),
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _t('本场结果', 'Result'),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.savings,
                  size: 16,
                  color: _multiplier == null
                      ? Colors.grey
                      : Colors.deepOrange[700],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _multiplier == null
                        ? _t(
                            '填了赛前胜场后自动算系数与本场得分',
                            'multiplier and score are auto once wins are filled',
                          )
                        : _t(
                            '系数 ×$_multiplier（赛前 ${_multiplierBandLabel()} 胜）'
                                ' · 赛后 ${_winsAfter ?? '-'} 胜 · '
                                '本场得分 ${formatSeasonStatScore(_gainedScore ?? 0)}'
                                '（${formatSeasonStatScore(_battleScore)} × $_multiplier）',
                            '×$_multiplier · after ${_winsAfter ?? '-'} wins · '
                                'gained ${formatSeasonStatScore(_gainedScore ?? 0)}',
                          ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _multiplier == null
                          ? Colors.grey
                          : Colors.deepOrange[700],
                    ),
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
            final record = SeasonStatRecord(
              id: widget.initial?.id ?? newSeasonStatId(),
              enemyId: _enemyCtrl.text.trim(),
              startTime: _start,
              endTime: _end,
              finalScore: _battleScore,
              source: widget.initial?.source ?? 'manual',
              winsBefore: _winsBeforeInput,
              won: _won,
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
///
/// [overwriteLast] 为 true 时不是新增，而是把**最近一场**（开始时间最新的那条）
/// 用本次结果覆盖掉（保留原来的 id、赛前胜场与本场结果作为默认值，可在对话框里改）。
/// 返回是否真的写入了记录。
Future<bool> importSeasonStatFromTimer(
  BuildContext context, {
  required String locale,
  required DateTime startTime,
  required DateTime endTime,
  required int finalScore,
  String enemyId = '',
  bool overwriteLast = false,
}) async {
  final isZh = locale == 'zh';
  // 「赛前胜场」= 现有最后一场的赛后胜场（表里没记录则 0）
  final existing = await SeasonStatsStore.load();
  final rows = buildSeasonStatRows(existing);
  final last = rows.isEmpty ? null : rows.last;

  if (overwriteLast && last == null) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isZh ? '赛季统计里还没有记录，先点「新增」吧' : 'No record to overwrite yet',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
    return false;
  }

  if (!context.mounted) return false;
  final record = await showSeasonStatRecordDialog(
    context,
    locale: locale,
    winsBefore: last?.winsBefore ?? 0,
    defaultEnemyId: enemyId,
    initial: SeasonStatRecord(
      id: overwriteLast ? last!.id : newSeasonStatId(),
      enemyId: enemyId.isNotEmpty ? enemyId : (last?.enemyId ?? ''),
      startTime: startTime,
      endTime: endTime,
      finalScore: finalScore,
      source: overwriteLast ? last!.record.source : 'timer',
      winsBefore: overwriteLast ? last!.winsBefore : null,
      won: overwriteLast ? last!.won : null,
    ),
  );
  if (record == null) return false;
  if (overwriteLast) {
    await SeasonStatsStore.update(record);
  } else {
    await SeasonStatsStore.add(record);
  }
  if (!context.mounted) return true;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        isZh
            ? '${overwriteLast ? '已覆盖最近一条' : '已导入赛季统计'}'
                  '（${formatSeasonStatDuration(record.durationMinutes, zh: true)} · '
                  '战斗分 ${formatSeasonStatScore(record.finalScore)}）'
            : '${overwriteLast ? 'Overwrote the last record' : 'Imported'}: '
                  '${formatSeasonStatDuration(record.durationMinutes, zh: false)} · '
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
