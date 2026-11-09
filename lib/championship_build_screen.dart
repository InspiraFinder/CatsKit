import 'package:flutter/material.dart';

import 'championship_data.dart';

/// 锦标赛战车 · 组车工具
///
/// 规则参考「机制指南 → 锦标赛战车」：
/// - 25 档（5 材质 × 5 星级），每档 3 个参数组合（数值不同）
/// - 等级上限按星级：6 / 11 / 16 / 21 / 26
/// - 车身提供供电；武器、配件消耗电力，供电不足则无法出车
/// - 车身插槽**暂不限制**（可任意添加武器 / 车轮 / 配件）
/// - 每件可选装 1 个工具箱（+HP 或 +ATK，按该件档位取加成）
/// - 可选**具体部件**并应用它的 HP/ATK 倍数与类别技能（+10/20/30%）
/// - 组合选项数量随部件变化：车轮按可读尺寸档（1-3 个）、
///   配件按是否有组合 2（1-2 个）
class ChampionshipBuildScreen extends StatefulWidget {
  final String locale;
  const ChampionshipBuildScreen({super.key, this.locale = 'zh'});

  @override
  State<ChampionshipBuildScreen> createState() =>
      _ChampionshipBuildScreenState();
}

class _ChampPart {
  int tier = 24;
  int partIndex = 0;
  int combo = 0;
  int level = 26;
  int toolbox = 0; // 0 = 无, 1 = +HP, 2 = +ATK
  int skillPct = 30; // 0 / 10 / 20 / 30

  void clampLevel() {
    final max = champMaxLevel(tier);
    if (level > max) level = max;
    if (level < 1) level = 1;
  }
}

class _ChampionshipBuildScreenState extends State<ChampionshipBuildScreen> {
  bool get _zh => widget.locale == 'zh';
  String _t(String zh, String en) => _zh ? zh : en;

  int _bodyTier = 24;
  int _bodyIndex = 6; // 默认「泰坦」
  int _bodyCombo = 0;
  int _bodyLevel = 26;
  int _bodyToolbox = 0;
  int _bodySkillPct = 30;

  final List<_ChampPart> _weapons = <_ChampPart>[];
  final List<_ChampPart> _wheels = <_ChampPart>[];
  final List<_ChampPart> _gadgets = <_ChampPart>[];

  // ---------- 计算 ----------

  double get _bodyHp =>
      champBodyHpValue(
        tier: _bodyTier,
        combo: _bodyCombo,
        level: _bodyLevel,
        body: kChampBodies[_bodyIndex],
        skillPct: kChampBodies[_bodyIndex].hasHpSkill ? _bodySkillPct : 0,
      ) +
      (_bodyToolbox == 1 ? kChampToolboxHp[_bodyTier] : 0);

  double get _bodyBaseHp => kChampBodyHp[_bodyTier][_bodyCombo].toDouble();

  int get _bodySupply => kChampBodySupply[_bodyTier][_bodyCombo];

  double _weaponAtk(_ChampPart p) {
    final w = kChampWeapons[p.partIndex];
    return champWeaponAtkValue(
          tier: p.tier,
          combo: p.combo,
          level: p.level,
          weapon: w,
          skillPct: w.hasAtkSkill ? p.skillPct : 0,
        ) +
        (p.toolbox == 2 ? kChampToolboxAtk[p.tier] : 0);
  }

  int _weaponDrain(_ChampPart p) => kChampWeaponDrain[p.tier][p.combo];

  int _wheelSize(_ChampPart p) {
    final w = kChampWheels[p.partIndex];
    return w.classes[p.combo.clamp(0, w.classes.length - 1)];
  }

  double _wheelHp(_ChampPart p) {
    return champWheelHpValue(
          tier: p.tier,
          sizeClass: _wheelSize(p),
          level: p.level,
          skillPct: kChampWheels[p.partIndex].hasHpSkill ? p.skillPct : 0,
        ) +
        (p.toolbox == 1 ? kChampToolboxHp[p.tier] : 0);
  }

  double _wheelAtk(_ChampPart p) {
    return champWheelAtkValue(
          tier: p.tier,
          sizeClass: _wheelSize(p),
          level: p.level,
        ) +
        (p.toolbox == 2 ? kChampToolboxAtk[p.tier] : 0);
  }

  double _gadgetHp(_ChampPart p) {
    final g = kChampGadgets[p.partIndex];
    return champGadgetHpValue(
          tier: p.tier,
          hpGroup: champGadgetHpGroup(g, p.combo),
          level: p.level,
          skillPct: g.hasHpSkill ? p.skillPct : 0,
        ) +
        (p.toolbox == 1 ? kChampToolboxHp[p.tier] : 0);
  }

  int _gadgetDrain(_ChampPart p) {
    final g = kChampGadgets[p.partIndex];
    return champGadgetDrain(
      p.tier,
      highGroup: champGadgetHighDrain(g, p.combo),
    );
  }

  double get _totalHp =>
      _bodyHp +
      _weapons.fold(
        0.0,
        (s, p) =>
            s + (p.toolbox == 1 ? (kChampToolboxHp[p.tier]).toDouble() : 0),
      ) +
      _wheels.fold(0.0, (s, p) => s + _wheelHp(p)) +
      _gadgets.fold(0.0, (s, p) => s + _gadgetHp(p));

  double get _totalAtk =>
      _weapons.fold(0.0, (s, p) => s + _weaponAtk(p)) +
      _wheels.fold(0.0, (s, p) => s + _wheelAtk(p)) +
      _gadgets.fold(
        0.0,
        (s, p) => s + (p.toolbox == 2 ? kChampToolboxAtk[p.tier] : 0),
      ) +
      (_bodyToolbox == 2 ? kChampToolboxAtk[_bodyTier] : 0);

  int get _totalDrain =>
      _weapons.fold(0, (s, p) => s + _weaponDrain(p)) +
      _gadgets.fold(0, (s, p) => s + _gadgetDrain(p));

  int get _netPower => _bodySupply - _totalDrain;

  // ---------- 文案 ----------

  String _num(double v) {
    final n = v.round().toString();
    final sign = n.startsWith('-') ? '-' : '';
    final abs = sign.isEmpty ? n : n.substring(1);
    final buf = StringBuffer(sign);
    for (var i = 0; i < abs.length; i++) {
      if (i > 0 && (abs.length - i) % 3 == 0) buf.write(',');
      buf.write(abs[i]);
    }
    return buf.toString();
  }

  String _comboLabel(int c) => _zh ? '组合 ${c + 1}' : 'Combo ${c + 1}';

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = _netPower >= 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('锦标赛组车工具', 'Championship Builder')),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          _summaryCard(isDark, ok),
          const SizedBox(height: 12),
          _sectionTitle(_t('车身', 'Body')),
          _bodyCard(isDark),
          const SizedBox(height: 12),
          _sectionTitle(_t('武器', 'Weapons')),
          for (var i = 0; i < _weapons.length; i++)
            _partCard(
              key: ValueKey('w$i'),
              title: _t('武器 ${i + 1}', 'Weapon ${i + 1}'),
              part: _weapons[i],
              kind: _PartKind.weapon,
              onChanged: () => setState(() {}),
              onDelete: () => setState(() => _weapons.removeAt(i)),
            ),
          _addButton(
            _t('添加武器', 'Add weapon'),
            () => setState(() => _weapons.add(_ChampPart())),
          ),
          const SizedBox(height: 12),
          _sectionTitle(_t('车轮', 'Wheels')),
          for (var i = 0; i < _wheels.length; i++)
            _partCard(
              key: ValueKey('h$i'),
              title: _t('车轮 ${i + 1}', 'Wheel ${i + 1}'),
              part: _wheels[i],
              kind: _PartKind.wheel,
              onChanged: () => setState(() {}),
              onDelete: () => setState(() => _wheels.removeAt(i)),
            ),
          _addButton(
            _t('添加车轮', 'Add wheel'),
            () => setState(() => _wheels.add(_ChampPart()..partIndex = 9)),
          ),
          const SizedBox(height: 12),
          _sectionTitle(_t('配件', 'Gadgets')),
          for (var i = 0; i < _gadgets.length; i++)
            _partCard(
              key: ValueKey('g$i'),
              title: _t('配件 ${i + 1}', 'Gadget ${i + 1}'),
              part: _gadgets[i],
              kind: _PartKind.gadget,
              onChanged: () => setState(() {}),
              onDelete: () => setState(() => _gadgets.removeAt(i)),
            ),
          _addButton(
            _t('添加配件', 'Add gadget'),
            () => setState(() => _gadgets.add(_ChampPart()..partIndex = 4)),
          ),
          const SizedBox(height: 16),
          Text(
            _t(
              '说明：插槽暂不限制；已按所选具体部件应用 HP/ATK 倍数与类别技能；'
                  '车轮按可读尺寸档、配件按是否有组合 2 提供不同数量的组合选项。',
              'Slots are unlimited for now; the selected part\'s HP/ATK multiplier '
                  'and class skill are applied. Wheels offer the readable size '
                  'classes and gadgets offer combo 1/2 depending on the part.',
            ),
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(bool isDark, bool ok) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ok
              ? (isDark ? Colors.green[800]! : Colors.green[300]!)
              : Colors.red,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _statBox(_t('总 HP', 'Total HP'), _num(_totalHp))),
              Expanded(
                child: _statBox(_t('总 ATK', 'Total ATK'), _num(_totalAtk)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statBox(
                  _t('供电', 'Supply'),
                  '$_bodySupply',
                  color: Colors.amber,
                ),
              ),
              Expanded(
                child: _statBox(
                  _t('耗电', 'Drain'),
                  '$_totalDrain',
                  color: Colors.orange,
                ),
              ),
              Expanded(
                child: _statBox(
                  _t('净电力', 'Net power'),
                  '$_netPower',
                  color: ok ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          if (!ok) ...[
            const SizedBox(height: 6),
            Text(
              _t('电力不足，无法出车', 'Not enough power — this car cannot run'),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _addButton(String label, VoidCallback onTap) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _bodyCard(bool isDark) {
    final hp = _bodyHp;
    final supply = _bodySupply;
    final body = kChampBodies[_bodyIndex];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_car, size: 18, color: Colors.orange[700]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${body.nameZh} · ${champTierNameZh(_bodyTier)} · ${_comboLabel(_bodyCombo)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _nameDropdown(
              <String>[
                for (final b in kChampBodies)
                  '${b.nameZh}（×${b.multiplier.toStringAsFixed(4)}）',
              ],
              _bodyIndex,
              (v) => setState(() => _bodyIndex = v),
            ),
            const SizedBox(height: 6),
            _tierDropdown(_bodyTier, (v) {
              setState(() {
                _bodyTier = v;
                final max = champMaxLevel(v);
                if (_bodyLevel > max) _bodyLevel = max;
              });
            }),
            const SizedBox(height: 6),
            _comboChips(_bodyCombo, const <String>['组合 1', '组合 2', '组合 3'], (
              c,
            ) {
              setState(() => _bodyCombo = c);
            }),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _levelDropdown(
                    _bodyLevel,
                    champMaxLevel(_bodyTier),
                    (v) => setState(() => _bodyLevel = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _toolboxDropdown(
                    _bodyToolbox,
                    (v) => setState(() => _bodyToolbox = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _skillDropdown(
              _bodySkillPct,
              body.hasHpSkill,
              (v) => setState(() => _bodySkillPct = v),
            ),
            const SizedBox(height: 8),
            Text(
              '${_t('HP', 'HP')} ${_num(hp)}   ·   '
              '${_t('供电', 'Supply')} $supply   ·   '
              '${_t('基础 HP', 'Base HP')} ${_num(_bodyBaseHp)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _partNames(_PartKind kind) => switch (kind) {
    _PartKind.weapon => <String>[
      for (final w in kChampWeapons)
        '${w.nameZh}（×${w.multiplier.toStringAsFixed(4)}）',
    ],
    _PartKind.wheel => <String>[for (final w in kChampWheels) w.nameZh],
    _PartKind.gadget => <String>[for (final g in kChampGadgets) g.nameZh],
  };

  bool _hasSkill(_PartKind kind, int index) => switch (kind) {
    _PartKind.weapon => kChampWeapons[index].hasAtkSkill,
    _PartKind.wheel => kChampWheels[index].hasHpSkill,
    _PartKind.gadget => kChampGadgets[index].hasHpSkill,
  };

  String _sizeLabel(int size) => switch (size) {
    0 => _t('小', 'Small'),
    1 => _t('中', 'Medium'),
    _ => _t('大', 'Large'),
  };

  List<String> _comboLabels(_PartKind kind, int index) => switch (kind) {
    _PartKind.weapon => const <String>['组合 1', '组合 2', '组合 3'],
    _PartKind.wheel => <String>[
      for (final c in kChampWheels[index].classes) _sizeLabel(c),
    ],
    _PartKind.gadget =>
      kChampGadgets[index].hasCombo2
          ? const <String>['组合 1', '组合 2']
          : const <String>['组合 1'],
  };

  Widget _partCard({
    required Key key,
    required String title,
    required _ChampPart part,
    required _PartKind kind,
    required VoidCallback onChanged,
    required VoidCallback onDelete,
  }) {
    final names = _partNames(kind);
    final combos = _comboLabels(kind, part.partIndex);
    final hasSkill = _hasSkill(kind, part.partIndex);
    final partName = names[part.partIndex];

    final detail = switch (kind) {
      _PartKind.weapon =>
        'ATK ${_num(_weaponAtk(part))}   ·   ${_t('耗电', 'Drain')} ${_weaponDrain(part)}',
      _PartKind.wheel =>
        'HP ${_num(_wheelHp(part))}   ·   ${_t('碾压 ATK', 'Crush ATK')} ${_num(_wheelAtk(part))}',
      _PartKind.gadget =>
        'HP ${_num(_gadgetHp(part))}   ·   ${_t('治疗', 'Heal')} ${_num(champGadgetHealValue(tier: part.tier, level: part.level))}'
            '   ·   ${_t('耗电', 'Drain')} ${_gadgetDrain(part)}',
    };

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  switch (kind) {
                    _PartKind.weapon => Icons.gps_fixed,
                    _PartKind.wheel => Icons.circle_outlined,
                    _PartKind.gadget => Icons.widgets_outlined,
                  },
                  size: 16,
                  color: Colors.purple[400],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$title · $partName · ${champTierNameZh(part.tier)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: _t('删除', 'Delete'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _nameDropdown(names, part.partIndex, (v) {
              part.partIndex = v;
              final n = _comboLabels(kind, v).length;
              if (part.combo >= n) part.combo = n - 1;
              if (!_hasSkill(kind, v)) part.skillPct = 0;
              onChanged();
            }),
            const SizedBox(height: 6),
            _tierDropdown(part.tier, (v) {
              part.tier = v;
              part.clampLevel();
              onChanged();
            }),
            const SizedBox(height: 6),
            _comboChips(part.combo, combos, (c) {
              part.combo = c;
              onChanged();
            }),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _levelDropdown(part.level, champMaxLevel(part.tier), (
                    v,
                  ) {
                    part.level = v;
                    onChanged();
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _toolboxDropdown(part.toolbox, (v) {
                    part.toolbox = v;
                    onChanged();
                  }),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _skillDropdown(part.skillPct, hasSkill, (v) {
              part.skillPct = v;
              onChanged();
            }),
            const SizedBox(height: 8),
            Text(detail, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _tierDropdown(int tier, ValueChanged<int> onChanged) {
    return DropdownButton<int>(
      value: tier,
      isExpanded: true,
      style: const TextStyle(fontSize: 12),
      items: [
        for (var i = 0; i < 25; i++)
          DropdownMenuItem(
            value: i,
            child: Text(
              '${i + 1}. ${champTierNameZh(i)}（${_t('上限', 'max')} ${champMaxLevel(i)}）',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _comboChips(
    int combo,
    List<String> labels,
    ValueChanged<int> onChanged,
  ) {
    return Wrap(
      spacing: 6,
      children: [
        for (var c = 0; c < labels.length; c++)
          ChoiceChip(
            label: Text(labels[c], style: const TextStyle(fontSize: 11)),
            selected: combo == c,
            onSelected: (_) => onChanged(c),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _nameDropdown(
    List<String> names,
    int index,
    ValueChanged<int> onChanged,
  ) {
    return DropdownButton<int>(
      value: index,
      isExpanded: true,
      style: const TextStyle(fontSize: 12),
      items: [
        for (var i = 0; i < names.length; i++)
          DropdownMenuItem(
            value: i,
            child: Text(names[i], style: const TextStyle(fontSize: 12)),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _skillDropdown(int pct, bool enabled, ValueChanged<int> onChanged) {
    if (!enabled) {
      return Text(
        _t('无类别技能', 'No class skill'),
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      );
    }
    return DropdownButton<int>(
      value: pct,
      isExpanded: true,
      style: const TextStyle(fontSize: 12),
      items: [
        for (final p in kChampSkillPcts)
          DropdownMenuItem(
            value: p,
            child: Text(
              p == 0 ? _t('技能：无', 'Skill: none') : _t('技能 +$p%', 'Skill +$p%'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _levelDropdown(int level, int max, ValueChanged<int> onChanged) {
    return DropdownButton<int>(
      value: level,
      isExpanded: true,
      style: const TextStyle(fontSize: 12),
      items: [
        for (var lv = 1; lv <= max; lv++)
          DropdownMenuItem(
            value: lv,
            child: Text(
              '${_t('等级', 'Lv')} $lv',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _toolboxDropdown(int value, ValueChanged<int> onChanged) {
    return DropdownButton<int>(
      value: value,
      isExpanded: true,
      style: const TextStyle(fontSize: 12),
      items: [
        DropdownMenuItem(
          value: 0,
          child: Text(
            _t('无工具箱', 'No toolbox'),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        DropdownMenuItem(
          value: 1,
          child: Text(
            _t('+HP 工具箱', '+HP toolbox'),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        DropdownMenuItem(
          value: 2,
          child: Text(
            _t('+ATK 工具箱', '+ATK toolbox'),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

enum _PartKind { weapon, wheel, gadget }
