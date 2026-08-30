import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'garage_data.dart';
import 'main.dart';
import 'parts_data.dart';

/// 升级策略：四选一（收益/代价）
/// 收益：HP 提升 或 ATK 提升
/// 代价：代币 或 紫票
enum UpgradeStrategy {
  hpToken('HP/代币', 'HP/Token'),
  hpCash('HP/紫票', 'HP/Cash'),
  atkToken('ATK/代币', 'ATK/Token'),
  atkCash('ATK/紫票', 'ATK/Cash');

  final String zh;
  final String en;
  const UpgradeStrategy(this.zh, this.en);

  /// 是否以 HP 提升作为收益（否则用 ATK）
  bool get useHp => this == hpToken || this == hpCash;

  /// 是否以代币作为代价（否则用紫票）
  bool get useToken => this == hpToken || this == atkToken;

  String label(bool isZh) => isZh ? zh : en;
}

/// 升级步骤表格展示列（用户可自定义顺序）
enum _PlanColumn {
  step('step', '步', 'Step'),
  part('part', '部件', 'Part'),
  level('level', 'Lv', 'Lv'),
  hpGain('hpGain', 'HP+', 'HP+'),
  atkGain('atkGain', 'ATK+', 'ATK+'),
  cash('cash', '紫票', 'Cash'),
  token('token', '代币', 'Token'),
  vehicleHp('vehicleHp', '升级后HP', 'HP'),
  vehicleAtk('vehicleAtk', '升级后ATK', 'ATK'),
  cumHp('cumHp', '累计HP', 'CumHP'),
  cumAtk('cumAtk', '累计ATK', 'CumATK'),
  cumCash('cumCash', '累计紫票', 'CumCash'),
  cumToken('cumToken', '累计代币', 'CumToken'),
  hpPerToken('hpPerToken', 'HP/代币', 'HP/Token'),
  hpPerCash('hpPerCash', 'HP/紫票', 'HP/Cash'),
  atkPerToken('atkPerToken', 'ATK/代币', 'ATK/Token'),
  atkPerCash('atkPerCash', 'ATK/紫票', 'ATK/Cash');

  final String id;
  final String zh;
  final String en;
  const _PlanColumn(this.id, this.zh, this.en);

  String label(bool isZh) => isZh ? zh : en;
}

/// 单步升级结果
class UpgradeStepResult {
  final int step;
  final PartData part;
  final int fromLevel;
  final int toLevel;
  final double hpGain;
  final double atkGain;
  final int cashCost; // 紫票
  final int tokenCost; // 代币
  final double vehicleHp; // 升级后车辆 HP
  final double vehicleAtk; // 升级后车辆 ATK
  final double cumulativeHp;
  final double cumulativeAtk;
  final int cumulativeCash;
  final int cumulativeToken;
  final double hpPerToken;
  final double hpPerCash;
  final double atkPerToken;
  final double atkPerCash;

  const UpgradeStepResult({
    required this.step,
    required this.part,
    required this.fromLevel,
    required this.toLevel,
    required this.hpGain,
    required this.atkGain,
    required this.cashCost,
    required this.tokenCost,
    required this.vehicleHp,
    required this.vehicleAtk,
    required this.cumulativeHp,
    required this.cumulativeAtk,
    required this.cumulativeCash,
    required this.cumulativeToken,
    required this.hpPerToken,
    required this.hpPerCash,
    required this.atkPerToken,
    required this.atkPerCash,
  });
}

/// 车辆部件集合（按 CarValidation 参数分组）
class CarParts {
  PartData? body;
  PartData? extraWeapon;
  final List<PartData> weapons = [];
  final List<PartData> wheels = [];
  final List<PartData> gadgets = [];

  List<PartData> get all => [
    ?body,
    ?extraWeapon,
    ...weapons,
    ...wheels,
    ...gadgets,
  ];
}

/// 计算车辆当前 HP/ATK（复用组车工具的 CarValidation 公式，保证一致）
({double hp, double atk}) _computeHpAtk(
  CarParts parts,
  Map<String, int> levels,
  Map<String, int> bonuses,
) {
  final v = CarValidation.compute(
    parts.body,
    parts.weapons,
    parts.wheels,
    parts.gadgets,
    parts.extraWeapon,
    levels,
    bonuses,
  );
  return (hp: v.hp, atk: v.atk);
}

/// 安全除法：分母 <= 0 时，分子 > 0 视为无穷大，否则为 0
double _ratio(double num, int den) =>
    den <= 0 ? (num > 0 ? double.infinity : 0) : num / den;

/// 单个升级候选
class _Candidate {
  final PartData part;
  final int fromLevel;
  final int toLevel;
  final double hpGain;
  final double atkGain;
  final int cashCost;
  final int tokenCost;
  final double metric; // 收益（HP 或 ATK 提升）
  final double score; // metric / 代价（代价为 0 视为无穷大）

  const _Candidate({
    required this.part,
    required this.fromLevel,
    required this.toLevel,
    required this.hpGain,
    required this.atkGain,
    required this.cashCost,
    required this.tokenCost,
    required this.metric,
    required this.score,
  });
}

/// 贪心计算升级计划：每一步在当前状态（含前序升级）下评估所有可升级部件，
/// 按策略选出性价比最高的一项，最多计算 [maxSteps] 步。
List<UpgradeStepResult> computeUpgradePlan({
  required CarParts parts,
  required Map<String, int> initialLevels,
  required Map<String, int> bonuses,
  required UpgradeStrategy strategy,
  int maxSteps = 20,
}) {
  final levels = Map<String, int>.from(initialLevels);
  final steps = <UpgradeStepResult>[];
  double cumHp = 0, cumAtk = 0;
  int cumCash = 0, cumToken = 0;

  for (int step = 1; step <= maxSteps; step++) {
    final before = _computeHpAtk(parts, levels, bonuses);

    _Candidate? best;
    for (final p in parts.all) {
      final lv = (levels[p.id] ?? 1).clamp(1, p.maxLevel).toInt();
      if (lv >= p.maxLevel) continue; // 已满级

      // 模拟升级一级
      final test = Map<String, int>.from(levels)..[p.id] = lv + 1;
      final after = _computeHpAtk(parts, test, bonuses);
      final hpGain = after.hp - before.hp;
      final atkGain = after.atk - before.atk;

      // 从 lv 升到 lv+1 的费用（upgradeCosts[rarity][lv+1]）
      final costs = upgradeCosts[p.rarity] ?? const <UpgradeCostEntry>[];
      final idx = lv + 1;
      final cost = idx < costs.length
          ? costs[idx]
          : (costs.isEmpty ? null : costs.last);
      if (cost == null) continue;

      // 收益与代价
      final metric = strategy.useHp ? hpGain : atkGain;
      final costValue = strategy.useToken ? cost.token : cost.cash;
      if (metric <= 0) continue; // 无收益（如 HP 策略下纯武器部件）

      final score = costValue <= 0 ? double.infinity : metric / costValue;
      final cand = _Candidate(
        part: p,
        fromLevel: lv,
        toLevel: lv + 1,
        hpGain: hpGain,
        atkGain: atkGain,
        cashCost: cost.cash,
        tokenCost: cost.token,
        metric: metric,
        score: score,
      );
      // 优先选得分高；得分相同时选提升大的
      if (best == null ||
          cand.score > best.score ||
          (cand.score == best.score && cand.metric > best.metric)) {
        best = cand;
      }
    }

    if (best == null) break; // 没有可升级或有收益的部件了

    // 应用最优升级
    levels[best.part.id] = best.toLevel;
    final upgraded = _computeHpAtk(parts, levels, bonuses); // 升级后绝对 HP/ATK
    cumHp += best.hpGain;
    cumAtk += best.atkGain;
    cumCash += best.cashCost;
    cumToken += best.tokenCost;

    steps.add(
      UpgradeStepResult(
        step: step,
        part: best.part,
        fromLevel: best.fromLevel,
        toLevel: best.toLevel,
        hpGain: best.hpGain,
        atkGain: best.atkGain,
        cashCost: best.cashCost,
        tokenCost: best.tokenCost,
        vehicleHp: upgraded.hp,
        vehicleAtk: upgraded.atk,
        cumulativeHp: cumHp,
        cumulativeAtk: cumAtk,
        cumulativeCash: cumCash,
        cumulativeToken: cumToken,
        hpPerToken: _ratio(best.hpGain, best.tokenCost),
        hpPerCash: _ratio(best.hpGain, best.cashCost),
        atkPerToken: _ratio(best.atkGain, best.tokenCost),
        atkPerCash: _ratio(best.atkGain, best.cashCost),
      ),
    );
  }

  return steps;
}

/// 升级计划界面
class UpgradePlanScreen extends StatefulWidget {
  final String locale;
  final String server;
  const UpgradePlanScreen({
    super.key,
    this.locale = 'zh',
    this.server = 'cn',
  });

  @override
  State<UpgradePlanScreen> createState() => _UpgradePlanScreenState();
}

class _UpgradePlanScreenState extends State<UpgradePlanScreen> {
  List<GarageVehicle?> _slots = List<GarageVehicle?>.filled(
    GarageStore.slotCount,
    null,
  );
  int _selectedSlot = 0; // 0-based
  UpgradeStrategy _strategy = UpgradeStrategy.hpToken;
  bool _useBonuses = false; // 是否附带额外加成计算（默认不附带）
  int _maxSteps = 20; // 计算的最大步数（表格行数，可增加）
  List<UpgradeStepResult>? _steps;
  late Map<String, PartData> _partById;
  List<_PlanColumn> _columns = List.of(_PlanColumn.values);

  bool get _isZh => widget.locale == 'zh';
  String _t(String zh, String en) => _isZh ? zh : en;

  @override
  void initState() {
    super.initState();
    _partById = {
      for (final p in PartDatabase.partsForServer(widget.server)) p.id: p,
    };
    _loadColumns();
    _loadBonuses();
    _loadMaxSteps();
    _load();
  }

  static const String _colPrefsKey = 'upgrade_plan_columns';
  static const String _bonusPrefsKey = 'upgrade_plan_use_bonuses';
  static const String _stepsPrefsKey = 'upgrade_plan_max_steps';

  /// 读取持久化的列顺序
  Future<void> _loadColumns() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_colPrefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final ids = (jsonDecode(raw) as List).cast<String>();
      final ordered = <_PlanColumn>[
        for (final id in ids)
          if (_PlanColumn.values.any((c) => c.id == id))
            _PlanColumn.values.firstWhere((c) => c.id == id),
      ];
      for (final c in _PlanColumn.values) {
        if (!ordered.contains(c)) ordered.add(c);
      }
      if (!mounted) return;
      setState(() => _columns = ordered);
    } catch (_) {}
  }

  /// 保存列顺序
  Future<void> _saveColumns() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _colPrefsKey,
      jsonEncode([for (final c in _columns) c.id]),
    );
  }

  /// 读取持久化的"是否附带额外加成"
  Future<void> _loadBonuses() async {
    final prefs = await SharedPreferences.getInstance();
    final use = prefs.getBool(_bonusPrefsKey);
    if (use == null) return;
    if (!mounted) return;
    setState(() {
      _useBonuses = use;
      _recompute();
    });
  }

  /// 保存"是否附带额外加成"
  Future<void> _saveBonuses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bonusPrefsKey, _useBonuses);
  }

  /// 读取持久化的默认计算行数
  Future<void> _loadMaxSteps() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_stepsPrefsKey);
    if (v == null || v < 1) return;
    if (!mounted) return;
    setState(() {
      _maxSteps = v;
      _recompute();
    });
  }

  /// 保存计算行数（作为下次默认值）
  Future<void> _saveMaxSteps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_stepsPrefsKey, _maxSteps);
  }

  Future<void> _load() async {
    final slots = await GarageStore.load();
    if (!mounted) return;
    setState(() {
      _slots = slots.toList();
      final cur = _slots[_selectedSlot];
      if (cur == null || cur.isEmpty) {
        final idx = _slots.indexWhere((v) => v != null && !v.isEmpty);
        _selectedSlot = idx < 0 ? 0 : idx;
      }
      _recompute();
    });
  }

  GarageVehicle? get _vehicle => _slots[_selectedSlot];

  void _onSelectSlot(int i) {
    setState(() {
      _selectedSlot = i;
      _recompute();
    });
  }

  void _onSelectStrategy(UpgradeStrategy s) {
    setState(() {
      _strategy = s;
      _recompute();
    });
  }

  /// 切换是否附带额外加成计算
  void _toggleBonuses() {
    setState(() {
      _useBonuses = !_useBonuses;
      _recompute();
    });
    _saveBonuses();
  }

  /// 将车辆分解为计算所需部件集合
  CarParts _resolveParts(GarageVehicle v) {
    final parts = CarParts();
    if (v.bodyId != null) parts.body = _partById[v.bodyId!];
    if (v.extraWeaponId != null) parts.extraWeapon = _partById[v.extraWeaponId!];
    for (final id in v.weaponIds) {
      final p = _partById[id];
      if (p != null) parts.weapons.add(p);
    }
    for (final id in v.wheelIds) {
      final p = _partById[id];
      if (p != null) parts.wheels.add(p);
    }
    for (final id in v.gadgetIds) {
      final p = _partById[id];
      if (p != null) parts.gadgets.add(p);
    }
    return parts;
  }

  void _recompute() {
    final v = _vehicle;
    if (v == null || v.isEmpty) {
      _steps = null;
      return;
    }
    final parts = _resolveParts(v);
    if (parts.all.isEmpty) {
      _steps = null;
      return;
    }
    _steps = computeUpgradePlan(
      parts: parts,
      initialLevels: v.levels,
      bonuses: _useBonuses ? v.bonuses : <String, int>{},
      strategy: _strategy,
      maxSteps: _maxSteps,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _vehicle;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('升级计划', 'Upgrade Plan')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.percent,
              color: _useBonuses ? Colors.orange : Colors.grey,
            ),
            onPressed: _toggleBonuses,
            tooltip: _t(
              '额外加成计算：${_useBonuses ? '开' : '关'}',
              'Extra bonus: ${_useBonuses ? 'ON' : 'OFF'}',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.view_column),
            onPressed: _showColumnSettings,
            tooltip: _t('列设置', 'Column Settings'),
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, {'locale': widget.locale}),
          tooltip: _t('返回主菜单', 'Back'),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSlotSelector(),
            const Divider(height: 1),
            _buildStrategySelector(),
            const Divider(height: 1),
            if (vehicle == null || vehicle.isEmpty)
              _buildNoVehicle()
            else
              _buildResult(),
          ],
        ),
      ),
    );
  }

  // ==================== 车位选择（与我的车库一致） ====================
  Widget _buildSlotSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('选择要升级的车辆（车位）', 'Select vehicle to upgrade (slot)'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < GarageStore.slotCount; i++) ...[
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
    final v = _slots[i];
    final filled = v != null && !v.isEmpty;
    final selected = i == _selectedSlot;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _onSelectSlot(i),
      child: Container(
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.indigo
              : filled
              ? Colors.teal[50]
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? Colors.indigo
                : filled
                ? Colors.teal
                : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              filled ? Icons.directions_car : Icons.directions_car_outlined,
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

  // ==================== 策略选择（四选一） ====================
  Widget _buildStrategySelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('升级策略（收益/代价）', 'Upgrade Strategy (gain/cost)'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: UpgradeStrategy.values.map((s) {
              final selected = _strategy == s;
              return ChoiceChip(
                label: Text(
                  s.label(_isZh),
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: selected,
                onSelected: (_) => _onSelectStrategy(s),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          Text(
            _t(
              '额外加成计算：${_useBonuses ? '已开启' : '未开启（默认）'}',
              'Extra bonus: ${_useBonuses ? 'ON' : 'OFF (default)'}',
            ),
            style: TextStyle(
              fontSize: 11,
              color: _useBonuses ? Colors.orange[700] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoVehicle() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.upgrade, size: 72, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              _t(
                '该车位为空，请先在「我的车库」中保存车辆，\n或切换上方车位按钮选择已保存的车辆',
                'This slot is empty. Save a vehicle in "My Garage"\nor switch the slot buttons above to pick a saved vehicle.',
              ),
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 结果 ====================
  Widget _buildResult() {
    final steps = _steps;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (steps == null || steps.isEmpty)
            _buildNoStepsHint()
          else
            _buildStepsTable(steps),
        ],
      ),
    );
  }

  Widget _buildNoStepsHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Text(
        _t(
          '该车辆所有部件已满级，或当前策略下没有可提升项。',
          'All parts are max level, or no upgrade yields a gain under this strategy.',
        ),
        style: TextStyle(fontSize: 13, color: Colors.orange[800]),
      ),
    );
  }

  Widget _buildStepsTable(List<UpgradeStepResult> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t(
            '升级步骤表（共 ${steps.length} 步）',
            'Upgrade Steps (${steps.length})',
          ),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 14,
            headingRowColor: WidgetStateProperty.all(Colors.indigo[50]),
            columns: [
              for (final c in _columns) _buildColumnHeader(c),
            ],
            rows: [
              for (final s in steps)
                DataRow(
                  cells: [
                    for (final c in _columns) DataCell(_buildCell(c, s)),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _increaseMaxSteps(10),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                _t('+10 行（上限 $_maxSteps）', '+10 rows (max $_maxSteps)'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.indigo,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _customizeMaxSteps,
              icon: const Icon(Icons.edit, size: 18),
              label: Text(_t('自定义行数', 'Custom rows')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.indigo,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _saveMaxSteps,
              icon: const Icon(Icons.save_alt, size: 18),
              label: Text(_t('保存为默认', 'Save as default')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 增加计算行数（不自动保存，需点「保存为默认」持久化）
  void _increaseMaxSteps(int delta) {
    setState(() {
      _maxSteps += delta;
      _recompute();
    });
  }

  /// 玩家自定义展示多少行（弹窗输入）
  Future<void> _customizeMaxSteps() async {
    final controller = TextEditingController(text: '$_maxSteps');
    String? error;
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(_t('自定义计算行数', 'Custom rows')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _t('行数', 'Rows'),
                  hintText: _t('输入要展示的最大行数', 'Max rows to show'),
                  errorText: error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t('取消', 'Cancel')),
            ),
            TextButton(
              onPressed: () {
                final n = int.tryParse(controller.text.trim());
                if (n == null || n < 1) {
                  setDlg(
                    () => error = _t(
                      '请输入有效行数（≥1）',
                      'Enter a valid row count (≥1)',
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, n);
              },
              child: Text(_t('确定', 'OK')),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (v == null || !mounted) return;
    setState(() {
      _maxSteps = v;
      _recompute();
    });
  }

  DataColumn _buildColumnHeader(_PlanColumn c) {
    return DataColumn(
      label: Text(
        c.label(_isZh),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCell(_PlanColumn c, UpgradeStepResult s) {
    switch (c) {
      case _PlanColumn.step:
        return Text('${s.step}');
      case _PlanColumn.part:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 10, color: _catColor(s.part.category)),
            const SizedBox(width: 4),
            Text(
              pn(s.part, widget.locale),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        );
      case _PlanColumn.level:
        return Text(
          '${s.fromLevel}→${s.toLevel}',
          style: const TextStyle(fontSize: 13),
        );
      case _PlanColumn.hpGain:
        return Text(
          '+${s.hpGain.floor()}',
          style: TextStyle(
            fontSize: 13,
            color: s.hpGain > 0 ? Colors.blue : Colors.grey,
          ),
        );
      case _PlanColumn.atkGain:
        return Text(
          '+${s.atkGain.floor()}',
          style: TextStyle(
            fontSize: 13,
            color: s.atkGain > 0 ? Colors.red : Colors.grey,
          ),
        );
      case _PlanColumn.cash:
        return Text('${s.cashCost}');
      case _PlanColumn.token:
        return Text('${s.tokenCost}');
      case _PlanColumn.vehicleHp:
        return Text(
          '${s.vehicleHp.floor()}',
          style: const TextStyle(fontSize: 13),
        );
      case _PlanColumn.vehicleAtk:
        return Text(
          '${s.vehicleAtk.floor()}',
          style: const TextStyle(fontSize: 13),
        );
      case _PlanColumn.cumHp:
        return Text(
          '${s.cumulativeHp.floor()}',
          style: const TextStyle(fontSize: 13),
        );
      case _PlanColumn.cumAtk:
        return Text(
          '${s.cumulativeAtk.floor()}',
          style: const TextStyle(fontSize: 13),
        );
      case _PlanColumn.cumCash:
        return Text('${s.cumulativeCash}');
      case _PlanColumn.cumToken:
        return Text('${s.cumulativeToken}');
      case _PlanColumn.hpPerToken:
        return Text(_fmtRatio(s.hpPerToken));
      case _PlanColumn.hpPerCash:
        return Text(_fmtRatio(s.hpPerCash));
      case _PlanColumn.atkPerToken:
        return Text(_fmtRatio(s.atkPerToken));
      case _PlanColumn.atkPerCash:
        return Text(_fmtRatio(s.atkPerCash));
    }
  }

  /// 列设置弹窗：调整显示顺序、隐藏/显示、恢复默认
  void _showColumnSettings() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final hidden = _PlanColumn.values
                .where((c) => !_columns.contains(c))
                .toList();

            void apply(List<_PlanColumn> list) {
              setDialogState(() => _columns = list);
              setState(() {});
              _saveColumns();
            }

            void move(int index, int delta) {
              final target = index + delta;
              if (target < 0 || target >= _columns.length) return;
              final list = List<_PlanColumn>.from(_columns);
              final tmp = list[index];
              list[index] = list[target];
              list[target] = tmp;
              apply(list);
            }

            void hide(_PlanColumn c) {
              final list = List<_PlanColumn>.from(_columns)..remove(c);
              apply(list);
            }

            void show(_PlanColumn c) {
              final list = List<_PlanColumn>.from(_columns)..add(c);
              apply(list);
            }

            return AlertDialog(
              title: Text(_t('列设置', 'Column Settings')),
              contentPadding: const EdgeInsets.fromLTRB(24, 12, 12, 12),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(
                          '显示列（从上到下 = 从左到右）',
                          'Visible columns (top = left)',
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (int i = 0; i < _columns.length; i++)
                        _buildColRow(
                          _columns[i],
                          canUp: i > 0,
                          canDown: i < _columns.length - 1,
                          onUp: () => move(i, -1),
                          onDown: () => move(i, 1),
                          onHide: () => hide(_columns[i]),
                        ),
                      if (hidden.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          _t('隐藏列', 'Hidden columns'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final c in hidden)
                          _buildColRow(c, hidden: true, onShow: () => show(c)),
                      ],
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => apply(List.of(_PlanColumn.values)),
                        icon: const Icon(Icons.restore, size: 18),
                        label: Text(_t('恢复默认', 'Reset default')),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 列设置中的单行
  Widget _buildColRow(
    _PlanColumn c, {
    bool canUp = false,
    bool canDown = false,
    VoidCallback? onUp,
    VoidCallback? onDown,
    VoidCallback? onHide,
    bool hidden = false,
    VoidCallback? onShow,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: hidden ? Colors.grey[100] : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              c.label(_isZh),
              style: TextStyle(
                fontSize: 13,
                color: hidden ? Colors.grey : Colors.black87,
              ),
            ),
          ),
          if (!hidden) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.arrow_upward, size: 16),
              onPressed: canUp ? onUp : null,
              tooltip: _t('上移', 'Up'),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.arrow_downward, size: 16),
              onPressed: canDown ? onDown : null,
              tooltip: _t('下移', 'Down'),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.visibility_off,
                size: 16,
                color: Colors.grey,
              ),
              onPressed: onHide,
              tooltip: _t('隐藏', 'Hide'),
            ),
          ] else ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.visibility, size: 16, color: Colors.blue),
              onPressed: onShow,
              tooltip: _t('显示', 'Show'),
            ),
          ],
        ],
      ),
    );
  }

  /// 格式化性价比：无穷大显示 99999+
  String _fmtRatio(double v) {
    if (v.isInfinite || v.isNaN) return '99999+';
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  Color _catColor(PartCategory c) {
    switch (c) {
      case PartCategory.body:
        return Colors.orange;
      case PartCategory.weapon:
        return Colors.red;
      case PartCategory.wheel:
        return Colors.green;
      case PartCategory.gadget:
        return Colors.purple;
    }
  }
}
