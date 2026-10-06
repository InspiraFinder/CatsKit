import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fusion_calc_data.dart';
import 'mini_slider.dart';

/// 熔铸计算：把锦标赛战车的部件加进来，随时看它的「金币价值 / 售价 / 融合花费」，
/// 并在模块内直接做融合（材料从已添加的部件里挑）。
///
/// 数值口径见 [fusion_calc_data]，与机制指南「融合：经验、花费与出售」完全一致。
class FusionCalcScreen extends StatefulWidget {
  final String locale;
  final String server;

  const FusionCalcScreen({super.key, this.locale = 'zh', this.server = 'cn'});

  @override
  State<FusionCalcScreen> createState() => _FusionCalcScreenState();
}

class _FusionCalcScreenState extends State<FusionCalcScreen> {
  static const String _partsKey = 'fusion_calc_parts_v1';
  static const String _skillsKey = 'fusion_calc_skills_v1';

  final List<FusionPart> _parts = <FusionPart>[];

  /// 0 = 未学习，1 / 2 / 3 = 技能等级
  int _dealerLevel = 0;
  int _mechanicLevel = 0;
  int _merchantLevel = 0;

  bool _loaded = false;

  bool get _isZh => widget.locale == 'zh';

  String _t(String zh, String en) => _isZh ? zh : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ==================== 持久化 ====================

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_partsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _parts
          ..clear()
          ..addAll(
            list.map(
              (e) => FusionPart.fromJson(Map<String, dynamic>.from(e as Map)),
            ),
          );
      }
      final skills = prefs.getStringList(_skillsKey);
      if (skills != null && skills.length >= 3) {
        _dealerLevel = int.tryParse(skills[0]) ?? 0;
        _mechanicLevel = int.tryParse(skills[1]) ?? 0;
        _merchantLevel = int.tryParse(skills[2]) ?? 0;
      }
    } catch (_) {
      // 数据损坏时保持空列表即可
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _partsKey,
        jsonEncode(_parts.map((p) => p.toJson()).toList()),
      );
      await prefs.setStringList(_skillsKey, <String>[
        '$_dealerLevel',
        '$_mechanicLevel',
        '$_merchantLevel',
      ]);
    } catch (_) {
      // 忽略写入失败
    }
  }

  // ==================== 工具 ====================

  String _num(num v) {
    final isInt = v == v.roundToDouble();
    final s = isInt ? v.toInt().toString() : v.toStringAsFixed(2);
    final neg = s.startsWith('-');
    final body = neg ? s.substring(1) : s;
    final dot = body.indexOf('.');
    final intPart = dot < 0 ? body : body.substring(0, dot);
    final frac = dot < 0 ? '' : body.substring(dot);
    final buf = StringBuffer(neg ? '-' : '');
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '$buf$frac';
  }

  String _material(int idx) => _isZh ? kMaterialZh[idx] : kMaterialEn[idx];

  String _quality(PartQuality q) =>
      _isZh ? kQualityZh[q.index] : kQualityEn[q.index];

  String _partTitle(FusionPart p) =>
      '${p.tier} ${_t('段', 'tier')} · ${_material(p.materialIdx)} ${p.star} ${_t('星', 'star')}';

  String _levelText(FusionPart p) {
    if (p.isMaxLevel) return '${p.level} ${_t('级（满级）', '(max)')}';
    return '${p.level} ${_t('级', '')} · ${(p.progress * 100).toStringAsFixed(1)}%';
  }

  // ==================== 增删改 ====================

  Future<void> _addPart() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PartEditorDialog(
        isZh: _isZh,
        dealerLevel: _dealerLevel,
        merchantLevel: _merchantLevel,
        onSave: (part) async {
          setState(() => _parts.add(part));
          await _save();
        },
      ),
    );
  }

  Future<void> _editPart(FusionPart part) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PartEditorDialog(
        isZh: _isZh,
        dealerLevel: _dealerLevel,
        merchantLevel: _merchantLevel,
        initial: part,
        onSave: (edited) async {
          setState(() {
            part.materialIdx = edited.materialIdx;
            part.star = edited.star;
            part.exp = edited.exp;
            part.quality = edited.quality;
          });
          await _save();
        },
      ),
    );
  }

  Future<void> _removePart(FusionPart part) async {
    setState(() => _parts.remove(part));
    await _save();
  }

  // ==================== 融合 ====================

  Future<void> _fuseInto(FusionPart target) async {
    if (target.isMaxLevel) {
      _toast(
        _t(
          '「${_partTitle(target)}」已经满级（${target.level} 级），不能再融合了',
          '"${_partTitle(target)}" is already at max level ${target.level}',
        ),
      );
      return;
    }
    final materials = _parts.where((p) => !identical(p, target)).toList();
    if (materials.isEmpty) {
      _toast(_t('至少要有两个部件才能融合', 'Add at least two parts first'));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _FuseSheet(screen: this, target: target),
    );
  }

  Widget _materialTile(
    BuildContext ctx, {
    required FusionPart target,
    required FusionPart material,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final gain = fusionXpGainOf(
      materialExp: material.exp,
      materialIdx: material.materialIdx,
      materialStar: material.star,
      materialQuality: material.quality,
      mechanicLevel: _mechanicLevel,
    );
    final cost = fusionCostOf(
      target.exp,
      target.materialIdx,
      target.star,
      _dealerLevel,
    );
    final tbCount = material.toolboxCount;
    final tbNote = tbCount > 0
        ? _t(
            '\n⚠ 它身上有 $tbCount 个工具箱，融合后不继承（相当于白花金币）',
            '\n⚠ It carries $tbCount toolbox(es) which are NOT inherited',
          )
        : '';
    final theme = Theme.of(ctx);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
          : null,
      child: ListTile(
        dense: true,
        selected: selected,
        title: Text(
          '${_partTitle(material)} · ${_quality(material.quality)}'
          '${tbCount > 0 ? _t('　⚠ 带工具箱', ' ⚠ toolboxes') : ''}',
        ),
        subtitle: Text(
          _t(
                '${_levelText(material)}　→ 目标 +${_num(gain)} 经验',
                '${_levelText(material)}　-> +${_num(gain)} XP',
              ) +
              tbNote,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              _num(cost),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              _t('花费金币', 'coins'),
              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  /// 融合一次（材料被吃掉）+ 存盘。
  ///
  /// 没有提示条：目标卡上会立即显示新的等级 / 经验 / 花费与出售价，
  /// 材料卡则从列表里消失。
  Future<void> _performFusion({
    required FusionPart target,
    required FusionPart material,
  }) async {
    final gain = fusionXpGainOf(
      materialExp: material.exp,
      materialIdx: material.materialIdx,
      materialStar: material.star,
      materialQuality: material.quality,
      mechanicLevel: _mechanicLevel,
    );
    setState(() {
      // 最高等级没有自己的经验段（它就是上一级的 100%），所以经验夹到满级上限
      target.addExp(gain);
      _parts.remove(material);
    });
    await _save();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ==================== 技能设置 ====================

  Future<void> _setSkill(int which, int level) async {
    setState(() {
      if (which == 0) _dealerLevel = level;
      if (which == 1) _mechanicLevel = level;
      if (which == 2) _merchantLevel = level;
    });
    await _save();
  }

  Widget _skillRow(String label, String hint, int which, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          SegmentedButton<int>(
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(value: 0, label: Text('0')),
              ButtonSegment<int>(value: 1, label: Text('1')),
              ButtonSegment<int>(value: 2, label: Text('2')),
              ButtonSegment<int>(value: 3, label: Text('3')),
            ],
            selected: <int>{value},
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onSelectionChanged: (s) => _setSkill(which, s.first),
          ),
        ],
      ),
    );
  }

  // ==================== 主界面 ====================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('熔铸计算', 'Fusion Calculator')),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: _t('返回主菜单', 'Back'),
          onPressed: () => Navigator.pop(context, <String, dynamic>{
            'locale': widget.locale,
          }),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: _t('添加部件', 'Add part'),
            onPressed: _addPart,
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _skillCard(theme),
                  const SizedBox(height: 12),
                  _partsHeader(theme),
                  const SizedBox(height: 8),
                  if (_parts.isEmpty)
                    _emptyHint(theme)
                  else
                    for (final p in _parts) _partCard(theme, p),
                  const SizedBox(height: 16),
                  _legend(theme),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPart,
        icon: const Icon(Icons.add),
        label: Text(_t('添加部件', 'Add part')),
      ),
    );
  }

  Widget _skillCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.tune, size: 18),
                const SizedBox(width: 6),
                Text(
                  _t('熔铸相关技能', 'Fusion skills'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _skillRow(
              _t('专业交易商（威名 5）', 'Pro Dealer (prestige 5)'),
              _t(
                '−10% / −20% / −30%　降低融合花费',
                '-10% / -20% / -30%  cuts fusion cost',
              ),
              0,
              _dealerLevel,
            ),
            _skillRow(
              _t('专业机械师（威名 5）', 'Pro Mechanic (prestige 5)'),
              _t(
                '+10% / +20% / +30%　提高融合获得的经验',
                '+10% / +20% / +30%  more XP per fusion',
              ),
              1,
              _mechanicLevel,
            ),
            _skillRow(
              _t('商人（段位 0）', 'Merchant (stage 0)'),
              _t(
                '+10% / +20% / +30%　提高出售价',
                '+10% / +20% / +30%  higher sale price',
              ),
              2,
              _merchantLevel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _partsHeader(ThemeData theme) {
    return Row(
      children: <Widget>[
        Text(
          _t('已添加的部件', 'Added parts'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Text(
          '${_parts.length}',
          style: TextStyle(color: theme.colorScheme.outline),
        ),
        const Spacer(),
        if (_parts.isNotEmpty)
          TextButton.icon(
            onPressed: () async {
              setState(_parts.clear);
              await _save();
            },
            icon: const Icon(Icons.delete_sweep, size: 18),
            label: Text(_t('清空', 'Clear')),
          ),
      ],
    );
  }

  Widget _emptyHint(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.add_box_outlined,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                '还没有部件。点右下角「添加部件」，设定材质、星级、等级、经验条进度与品质。',
                'No parts yet. Tap "Add part" and set material, star, level, progress and quality.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _partCard(ThemeData theme, FusionPart p) {
    final coinValue = coinValueOf(p.exp, p.materialIdx, p.star);
    final cost = fusionCostOf(p.exp, p.materialIdx, p.star, _dealerLevel);
    final sell = sellPriceOf(
      p.exp,
      p.materialIdx,
      p.star,
      quality: p.quality,
      dealerLevel: _dealerLevel,
      merchantLevel: _merchantLevel,
    );
    final refund = p.toolboxRefund;
    final accent = theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _partTitle(p),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _chip(
                  _quality(p.quality),
                  p.quality == PartQuality.common
                      ? theme.colorScheme.outline
                      : (p.quality == PartQuality.magic
                            ? Colors.blue
                            : Colors.orange),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: _t('删除', 'Delete'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _removePart(p),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              p.isMaxLevel
                  ? '${p.level} ${_t('级', '')}　${_t('已满级（＝ ${p.level - 1} 级 100%，进度恒为 0%）', 'max level (= ${p.level - 1} at 100%, progress is always 0%)')}'
                  : '${_levelText(p)}　${_t('升到下一级还需 ${_num(p.toNextLevel)} 经验', '${_num(p.toNextLevel)} XP to next level')}',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 8),
            _kv(_t('固有价值', 'Intrinsic'), _num(p.intrinsic)),
            _kv(
              _t('已投入经验', 'XP invested'),
              _num(p.exp),
              hint: _t(
                '综合价值 ${_num(p.compositeValue)}　上限 ${_num(p.maxExp)}',
                'composite ${_num(p.compositeValue)}　cap ${_num(p.maxExp)}',
              ),
            ),
            _kv(
              _t('经验价值', 'XP value'),
              _num(p.xpValue),
              hint: _t('当材料时按它算经验', 'drives XP when used as material'),
            ),
            _kv(
              _t('部件金币价值', 'Coin value'),
              _num(coinValue),
              hint: _t('未取整', 'unrounded'),
            ),
            if (p.toolboxCount > 0) ...<Widget>[
              const SizedBox(height: 6),
              _toolboxList(theme, p),
            ],
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _moneyBlock(
                      theme,
                      _t('出售可得', 'Sells for'),
                      sell + refund,
                      hint: refund > 0
                          ? _t(
                              '部件 ${_num(sell)} ＋ 工具箱回收 ${_num(refund)}',
                              'part ${_num(sell)} + toolbox refund ${_num(refund)}',
                            )
                          : null,
                    ),
                  ),
                  Container(width: 1, height: 30, color: theme.dividerColor),
                  Expanded(
                    child: _moneyBlock(theme, _t('融合需要', 'Fusion costs'), cost),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                TextButton.icon(
                  onPressed: p.isMaxLevel ? null : () => _fuseInto(p),
                  icon: const Icon(Icons.merge_type, size: 18),
                  label: Text(
                    p.isMaxLevel
                        ? _t('已满级，无法融合', 'Maxed — cannot fuse')
                        : _t('融合进这个部件', 'Fuse into this'),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _fuseToolboxInto(p),
                  icon: const Icon(Icons.widgets_outlined, size: 18),
                  label: Text(_t('融工具箱', 'Fuse toolbox')),
                ),
                TextButton.icon(
                  onPressed: () => _editPart(p),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(_t('编辑', 'Edit')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _moneyBlock(ThemeData theme, String label, int value, {String? hint}) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.paid_outlined, size: 14),
            const SizedBox(width: 4),
            Text(
              _num(value),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        if (hint != null)
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
          ),
      ],
    );
  }

  /// 已融工具箱列表（**只看数量**：每个只记材质 / 星级，用于算花费与回收）
  Widget _toolboxList(ThemeData theme, FusionPart p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.widgets_outlined, size: 15),
              const SizedBox(width: 6),
              Text(
                _t(
                  '已融工具箱 ${p.toolboxCount} 个',
                  '${p.toolboxCount} toolbox(es) fused',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _t(
                  '卖出可回收 ${_num(p.toolboxRefund)}',
                  'refund ${_num(p.toolboxRefund)}',
                ),
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          for (var i = 0; i < p.toolboxes.length; i++) _toolboxRow(theme, p, i),
        ],
      ),
    );
  }

  Widget _toolboxRow(ThemeData theme, FusionPart p, int i) {
    final t = p.toolboxes[i];
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '${_t('第', 'no.')}${i + 1}${_t(' 个', '')}　'
            '${_material(t.materialIdx)} ${t.star} ${_t('星', 'star')}'
            '　→ ${_t('回收', 'refund')} ${_num(t.refund)}',
            style: const TextStyle(fontSize: 11.5),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 15),
          tooltip: _t('移除这个工具箱', 'Remove this toolbox'),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: () async {
            setState(() => p.toolboxes.removeAt(i));
            await _save();
          },
        ),
      ],
    );
  }

  /// 往部件上融一个工具箱（弹窗里可以连续融多个）；没有提示条，卡片上的数量直接 +1
  Future<void> _fuseToolboxInto(FusionPart part) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ToolboxSheet(
        isZh: _isZh,
        part: part,
        onFuse: (materialIdx, star) async {
          setState(
            () => part.toolboxes.add(
              FusionToolbox(materialIdx: materialIdx, star: star),
            ),
          );
          await _save();
        },
      ),
    );
  }

  Widget _kv(String k, String v, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(
              k,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Text(v, style: const TextStyle(fontSize: 13)),
          if (hint != null)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  hint,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _legend(ThemeData theme) {
    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _t('口径说明', 'How the numbers work'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 6),
            for (final line in <String>[
              _t(
                '· 综合价值 ＝ 固有价值 ＋ 已投入经验；经验价值 ＝ 固有价值 ＋ 0.7 × 已投入经验',
                '· Composite = intrinsic + XP invested; XP value = intrinsic + 0.7 x XP invested',
              ),
              _t(
                '· 金币价值 ＝ 把综合价值当坐标，在 34 级金币阶梯上线性插值',
                '· Coin value = the 34-step coin ladder read at the composite value',
              ),
              _t(
                '· 融合需要 ＝ round(金币价值 × (1 − 专业交易商))',
                '· Fusion costs = round(coin value x (1 - Pro Dealer))',
              ),
              _t(
                '· 出售可得 ＝ round(融合需要 × 0.5 × 品质系数 × (1 + 商人))，品质系数 普通 1 / 魔法 2 / 传奇 4',
                '· Sells for = round(cost x 0.5 x quality x (1 + Merchant)); quality common 1 / magic 2 / legendary 4',
              ),
              _t(
                '· 融合获得经验 = ⌈(1 + 专业机械师) × 品质系数 × 材料的经验价值⌉，按融合当时的技能档位取',
                '· XP gained = ceil((1 + Pro Mechanic) x quality x material XP value), at the skill level of that moment',
              ),
              _t(
                '· 一次只能融合一个材料，材料会被消耗',
                '· One material per fusion; it is consumed',
              ),
              _t(
                '· 工具箱只统计**数量**：每个只记材质 / 星级（决定花多少钱、卖掉回收多少），不区分生命值 / 攻击力 / 电力 / 魔法',
                '· Toolboxes are counted, not classified: each keeps its material / star (cost and refund), '
                    'health / attack / power / magic are not distinguished',
              ),
              _t(
                '· 工具箱融合花费 = 基础花费 × 8 × 2^k（k = 已融个数；第 7 个起封顶 ×512）',
                '· Toolbox fuse cost = base x 8 x 2^k (k = already fused; capped at x512 from the 7th)',
              ),
              _t(
                '· 卖掉带工具箱的部件时，每个工具箱都按「它自己售价的 50%」回收，与它是第几个无关'
                    '（第 2 个起花的钱翻倍，回收不翻倍）；把该部件当材料融合时，工具箱不继承',
                '· Selling refunds 50% of each toolbox\'s own sell price, regardless of its position '
                    '(you pay double from the 2nd on, but the refund does not double); toolboxes are '
                    'not inherited when the part is fused as material',
              ),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  line,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== 通用：弹窗按钮 ====================

/// 熔铸计算里所有弹出窗口统一的按钮：
///
/// * **取消** —— 不保存，关掉窗口
/// * **确定并继续** —— 保存本次操作，**窗口留着**接着做下一件
///   （继续添加下一个部件 / 接着融下一个工具箱 / 接着喂下一个材料）
/// * **确定并关闭** —— 保存本次操作并关掉窗口
///
/// [onContinue] / [onDone] 传 `null` 表示该按钮暂时不可用（例如还没选材料）。
/// [expanded] 为 true 时改用「上排两个 + 下排一个整宽」的布局（底部弹窗更好按）。
/// [simple] 为 true 时只留「取消 + 确定」两个按钮（**编辑**已有部件时用，省高度）。
///
/// 对话框里（`expanded == false`）三个按钮排成**一行**小而扁的按钮：
/// `OverflowBar` 在竖屏手机上会把它们折成三行，太占高度。
class _PopupActions extends StatelessWidget {
  final bool isZh;
  final VoidCallback onCancel;
  final VoidCallback? onContinue;
  final VoidCallback? onDone;
  final bool expanded;
  final bool simple;

  const _PopupActions({
    required this.isZh,
    required this.onCancel,
    this.onContinue,
    this.onDone,
    this.expanded = false,
    this.simple = false,
  });

  /// 对话框里用的一行小按钮（字号 13.5、高 34，比默认 Button 矮一截）
  Widget _flat(String text, VoidCallback? onPressed) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      minimumSize: const Size(0, 34),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
    ),
    child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
  );

  @override
  Widget build(BuildContext context) {
    final cancel = _flat(isZh ? '取消' : 'Cancel', onCancel);
    if (simple) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Flexible(child: cancel),
          const SizedBox(width: 4),
          Flexible(child: _flat(isZh ? '确定' : 'OK', onDone)),
        ],
      );
    }
    if (!expanded) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Flexible(child: cancel),
          const SizedBox(width: 4),
          Flexible(child: _flat(isZh ? '确定并继续' : 'OK & continue', onContinue)),
          const SizedBox(width: 4),
          Flexible(child: _flat(isZh ? '确定并关闭' : 'OK & close', onDone)),
        ],
      );
    }
    final keepOpen = FilledButton.tonal(
      onPressed: onContinue,
      child: Text(isZh ? '确定并继续' : 'OK & continue'),
    );
    final close = FilledButton(
      onPressed: onDone,
      child: Text(isZh ? '确定并关闭' : 'OK & close'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: cancel),
            const SizedBox(width: 8),
            Expanded(child: keepOpen),
          ],
        ),
        const SizedBox(height: 8),
        close,
      ],
    );
  }
}

// ==================== 部件编辑/添加对话框 ====================

class _PartEditorDialog extends StatefulWidget {
  final bool isZh;
  final int dealerLevel;
  final int merchantLevel;
  final FusionPart? initial;

  /// 真正执行保存（由外层写进列表 + 持久化）
  final Future<void> Function(FusionPart part) onSave;

  const _PartEditorDialog({
    required this.isZh,
    required this.dealerLevel,
    required this.merchantLevel,
    this.initial,
    required this.onSave,
  });

  @override
  State<_PartEditorDialog> createState() => _PartEditorDialogState();
}

class _PartEditorDialogState extends State<_PartEditorDialog> {
  late int _materialIdx;
  late int _star;
  late int _level;
  late double _progress;
  late PartQuality _quality;

  bool get _isZh => widget.isZh;

  String _t(String zh, String en) => _isZh ? zh : en;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _materialIdx = init?.materialIdx ?? 2; // 默认军用
    _star = init?.star ?? 3; // 默认 3 星
    _quality = init?.quality ?? PartQuality.common;
    if (init != null) {
      _level = init.level;
      _progress = init.isMaxLevel ? 0 : init.progress;
    } else {
      _level = 1;
      _progress = 0;
    }
  }

  int get _maxLevel => maxDisplayLevel(_star);

  bool get _isMax => _level >= _maxLevel;

  /// 当前设定对应的「已投入经验」
  int get _exp {
    final level = _level.clamp(1, _maxLevel);
    return expFromLevelProgress(
      level: level,
      progress: _isMax ? 0 : _progress,
      materialIdx: _materialIdx,
      star: _star,
    );
  }

  String _num(num v) {
    final isInt = v == v.roundToDouble();
    final s = isInt ? v.toInt().toString() : v.toStringAsFixed(2);
    final neg = s.startsWith('-');
    final body = neg ? s.substring(1) : s;
    final dot = body.indexOf('.');
    final intPart = dot < 0 ? body : body.substring(0, dot);
    final frac = dot < 0 ? '' : body.substring(dot);
    final buf = StringBuffer(neg ? '-' : '');
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '$buf$frac';
  }

  FusionPart _build() => FusionPart(
    id: widget.initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
    materialIdx: _materialIdx,
    star: _star,
    exp: _exp,
    quality: _quality,
    toolboxes: widget.initial?.toolboxes,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _build();
    final coinValue = coinValueOf(preview.exp, _materialIdx, _star);
    final cost = fusionCostOf(
      preview.exp,
      _materialIdx,
      _star,
      widget.dealerLevel,
    );
    final sell = sellPriceOf(
      preview.exp,
      _materialIdx,
      _star,
      quality: _quality,
      dealerLevel: widget.dealerLevel,
      merchantLevel: widget.merchantLevel,
    );

    return AlertDialog(
      // 竖屏手机（360 dp 宽）上默认左右各 40 会让内容太窄、行数变多，这里收窄
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(
        widget.initial == null
            ? _t('添加部件', 'Add part')
            : _t('编辑部件', 'Edit part'),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // 一行两个下拉（比两排 chip 省一半高度）
              Row(
                children: <Widget>[
                  Expanded(
                    child: _dropdown<int>(
                      _t('材质', 'Material'),
                      value: _materialIdx,
                      items: <int>[0, 1, 2, 3, 4],
                      text: (i) => _isZh ? kMaterialZh[i] : kMaterialEn[i],
                      onChanged: (v) => setState(() => _materialIdx = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dropdown<int>(
                      _t('星级', 'Star'),
                      value: _star,
                      items: <int>[1, 2, 3, 4, 5],
                      text: (s) => '$s ★',
                      onChanged: (v) => setState(() {
                        _star = v;
                        if (_level > _maxLevel) _level = _maxLevel;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  SizedBox(
                    width: 44,
                    child: Text(
                      _t('品质', 'Quality'),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SegmentedButton<int>(
                      segments: <ButtonSegment<int>>[
                        for (var q = 0; q < 3; q++)
                          ButtonSegment<int>(
                            value: q,
                            label: Text(_isZh ? kQualityZh[q] : kQualityEn[q]),
                          ),
                      ],
                      selected: <int>{_quality.index},
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onSelectionChanged: (s) => setState(
                        () => _quality = PartQuality.values[s.first],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _sliderLine(
                label: _t('等级', 'Level'),
                value: _isMax ? '$_level ${_t('满', 'max')}' : '$_level',
                slider: MiniSlider(
                  min: 1,
                  max: _maxLevel.toDouble(),
                  value: _level.toDouble(),
                  divisions: _maxLevel - 1,
                  formatValue: (v) => '${v.round()}',
                  onChanged: (v) => setState(() {
                    _level = v.round();
                    if (_isMax) _progress = 0;
                  }),
                ),
              ),
              _sliderLine(
                label: _t('进度', 'Progress'),
                value: _isMax
                    ? '—'
                    : '${(_progress * 100).toStringAsFixed(0)}%',
                slider: MiniSlider(
                  min: 0,
                  max: 1,
                  value: _isMax ? 0 : _progress,
                  formatValue: (v) => '${(v * 100).round()}%',
                  onChanged: _isMax
                      ? null
                      : (v) => setState(() => _progress = v),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _t(
                        '${preview.tier} 段 · ${_isZh ? kMaterialZh[_materialIdx] : kMaterialEn[_materialIdx]} $_star 星 · ${_isZh ? kQualityZh[_quality.index] : kQualityEn[_quality.index]}',
                        'tier ${preview.tier} · ${kMaterialEn[_materialIdx]} $_star★ · ${kQualityEn[_quality.index]}',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t(
                        '已投入经验 ${_num(preview.exp)}（满级上限 ${_num(preview.maxExp)}）　'
                            '综合价值 ${_num(preview.compositeValue)}　经验价值 ${_num(preview.xpValue)}\n'
                            '金币价值 ${_num(coinValue)}　融合需要 ${_num(cost)}　出售可得 ${_num(sell)}',
                        'XP invested ${_num(preview.exp)} (cap ${_num(preview.maxExp)})　'
                            'composite ${_num(preview.compositeValue)}　XP value ${_num(preview.xpValue)}\n'
                            'coin value ${_num(coinValue)}　fusion ${_num(cost)}　sells ${_num(sell)}',
                      ),
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                    if (_isMax) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        _t(
                          '满级：$_maxLevel 级没有自己的经验段，它就是第 ${_maxLevel - 1} 级的 100%，进度永远显示 0%',
                          'Max level: level $_maxLevel has no bracket of its own — it is level ${_maxLevel - 1} '
                              'at 100%, so the progress always reads 0%',
                        ),
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        _PopupActions(
          isZh: _isZh,
          // 编辑已有部件：只留「取消 + 确定」（没有「继续编辑下一个」这种需求）
          simple: widget.initial != null,
          onCancel: () => Navigator.pop(context),
          onContinue: () => _confirm(keepOpen: true),
          onDone: () => _confirm(keepOpen: false),
        ),
      ],
    );
  }

  /// 保存并选择是否关掉窗口（确定并继续 = 不关，接着改/接着添加）
  Future<void> _confirm({required bool keepOpen}) async {
    await widget.onSave(_build());
    if (!mounted) return;
    if (!keepOpen) {
      Navigator.pop(context);
      return;
    }
    setState(() {});
  }

  /// 紧凑下拉（一行能放两个）
  Widget _dropdown<T>(
    String label, {
    required T value,
    required List<T> items,
    required String Function(T) text,
    required ValueChanged<T> onChanged,
  }) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<T>(
      initialValue: value,
      isDense: true,
      isExpanded: true,
      style: TextStyle(fontSize: 13.5, color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: const OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<T>>[
        for (final i in items)
          DropdownMenuItem<T>(value: i, child: Text(text(i))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  /// 紧凑滑块行：左边标签 + 滑块 + 右边数值（比「标签一行 + 滑块一行」省一半）
  Widget _sliderLine({
    required String label,
    required String value,
    required Widget slider,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, color: theme.colorScheme.outline),
          ),
        ),
        Expanded(child: slider),
        SizedBox(
          width: 52,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ==================== 工具箱选择弹窗 ====================

/// 往部件上融一个工具箱：选工具箱的**材质 / 星级**（决定花费与回收），
/// 再按「第几个」算倍率。**不区分类型**（生命值 / 攻击力 / 电力 / 魔法）。
///
/// 「确定并继续」= 融合后窗口留着（可以接着融下一个）；「确定并关闭」= 融合后关掉。
class _ToolboxSheet extends StatefulWidget {
  final bool isZh;
  final FusionPart part;

  /// 真正执行融合（由外层 [FusionCalcScreen] 做：加进部件、保存、弹提示）
  final Future<void> Function(int materialIdx, int star) onFuse;

  const _ToolboxSheet({
    required this.isZh,
    required this.part,
    required this.onFuse,
  });

  @override
  State<_ToolboxSheet> createState() => _ToolboxSheetState();
}

class _ToolboxSheetState extends State<_ToolboxSheet> {
  late int _materialIdx;
  late int _star;

  bool get _isZh => widget.isZh;

  String _t(String zh, String en) => _isZh ? zh : en;

  String _num(num v) {
    final isInt = v == v.roundToDouble();
    final s = isInt ? v.toInt().toString() : v.toStringAsFixed(2);
    final neg = s.startsWith('-');
    final body = neg ? s.substring(1) : s;
    final dot = body.indexOf('.');
    final intPart = dot < 0 ? body : body.substring(0, dot);
    final frac = dot < 0 ? '' : body.substring(dot);
    final buf = StringBuffer(neg ? '-' : '');
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '$buf$frac';
  }

  @override
  void initState() {
    super.initState();
    _materialIdx = widget.part.materialIdx;
    _star = widget.part.star;
  }

  int get _cost => toolboxFuseCostOf(
    materialIdx: _materialIdx,
    star: _star,
    alreadyFused: widget.part.toolboxCount,
  );

  /// 融合这个箱子；[keepOpen] 为 true 时窗口留着继续融下一个
  Future<void> _confirm({required bool keepOpen}) async {
    await widget.onFuse(_materialIdx, _star);
    if (!mounted) return;
    if (!keepOpen) {
      Navigator.pop(context);
      return;
    }
    // 已融个数变了 → 刷新「这是第几个」、倍率、花费与回收预览
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final part = widget.part;
    final k = part.toolboxCount;
    final mult = toolboxFuseMultiplier(k);
    final base = kToolboxBaseCost[tierIndex(_materialIdx, _star)];
    final sell = toolboxSellPriceOf(_materialIdx, _star);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.widgets_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _t('融工具箱', 'Fuse a toolbox'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t(
                        '目标：${_partTitle(part)}（已融 ${part.toolboxCount} 个）',
                        'Target: ${_partTitleEn(part)} (${part.toolboxCount} fused)',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _materialStarPicker(theme),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _row(
                            theme,
                            _t('箱子档位', 'Toolbox tier'),
                            '${tierNumber(_materialIdx, _star)} ${_t('段', 'tier')}',
                          ),
                          _row(
                            theme,
                            _t('融合花费', 'Fuse cost'),
                            '${_num(_cost)} ${_t('金币', 'coins')}'
                            '　(${_t('基础', 'base')} ${_num(base)} × $mult)',
                          ),
                          _row(
                            theme,
                            _t('这是第几个', 'Which toolbox'),
                            '${_t('第', 'no. ')}${k + 1}${_t(' 个', '')}',
                          ),
                          _row(
                            theme,
                            _t('箱子自己售价', 'Its own sell price'),
                            _num(sell),
                          ),
                          _row(
                            theme,
                            _t('融进后回收', 'Refund once fused'),
                            '${_num(sell * kFusedToolboxSellPercent ~/ 100)}'
                            '（$kFusedToolboxSellPercent%）',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        '· 这里只记工具箱的数量与它的材质 / 星级（决定花多少钱、卖掉回收多少），不区分生命值 / 攻击力 / 电力 / 魔法。\n'
                            '· 工具箱加的是属性、不占经验：满级部件也能融，且不影响部件自身的融合经验与售价。\n'
                            '· 卖掉这个部件时，每个工具箱都只按「它自己售价的 50%」回收——'
                            '**与它是第几个无关**，第 2 个起花的钱翻倍、回收并不翻倍。\n'
                            '· 把部件当材料融合时，工具箱不继承（加成随之消失）。',
                        '· Only the count and each box\'s material / star are tracked here (they set the cost and the '
                            'refund); health / attack / power / magic are not distinguished.\n'
                            '· A toolbox adds a stat, not XP: even a maxed part can take one, and the part\'s own XP '
                            'and price formulas stay unchanged.\n'
                            '· Selling refunds 50% of each toolbox\'s own sell price — **not** a share of what '
                            'you paid, so the doubled cost of the 2nd/3rd one is not refunded.\n'
                            '· Toolboxes are not inherited when the part is used as material.',
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _PopupActions(
              isZh: _isZh,
              expanded: true,
              onCancel: () => Navigator.pop(context),
              onContinue: () => _confirm(keepOpen: true),
              onDone: () => _confirm(keepOpen: false),
            ),
          ],
        ),
      ),
    );
  }

  /// 材质 + 星级（跟添加部件里同一套控件，省位置）
  Widget _materialStarPicker(ThemeData theme) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _dropdown<int>(
            theme,
            label: _t('工具箱材质', 'Material'),
            value: _materialIdx,
            items: <int>[0, 1, 2, 3, 4],
            text: (i) => _isZh ? kMaterialZh[i] : kMaterialEn[i],
            onChanged: (v) => setState(() => _materialIdx = v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _dropdown<int>(
            theme,
            label: _t('工具箱星级', 'Star'),
            value: _star,
            items: <int>[1, 2, 3, 4, 5],
            text: (s) => '$s ★',
            onChanged: (v) => setState(() => _star = v),
          ),
        ),
      ],
    );
  }

  Widget _dropdown<T>(
    ThemeData theme, {
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) text,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isDense: true,
      isExpanded: true,
      style: TextStyle(fontSize: 13.5, color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: const OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<T>>[
        for (final i in items)
          DropdownMenuItem<T>(value: i, child: Text(text(i))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  String _partTitle(FusionPart p) =>
      '${p.tier} ${_t('段', 'tier')} · ${_isZh ? kMaterialZh[p.materialIdx] : kMaterialEn[p.materialIdx]} ${p.star} ${_t('星', 'star')}';

  String _partTitleEn(FusionPart p) =>
      'tier ${p.tier} · ${kMaterialEn[p.materialIdx]} ${p.star}★';

  Widget _row(ThemeData theme, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      children: <Widget>[
        SizedBox(
          width: 96,
          child: Text(
            k,
            style: TextStyle(fontSize: 11.5, color: theme.colorScheme.outline),
          ),
        ),
        Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5))),
      ],
    ),
  );
}

// ==================== 选材料融合的弹窗 ====================

/// 选一个部件当材料喂给目标部件。
///
/// 先点材料（会高亮），再按底部按钮：
/// **确定并继续** = 融合完窗口留着，可以接着喂下一个材料；
/// **确定并关闭** = 融合完关掉窗口。
class _FuseSheet extends StatefulWidget {
  final _FusionCalcScreenState screen;
  final FusionPart target;

  const _FuseSheet({required this.screen, required this.target});

  @override
  State<_FuseSheet> createState() => _FuseSheetState();
}

class _FuseSheetState extends State<_FuseSheet> {
  FusionPart? _picked;

  _FusionCalcScreenState get _s => widget.screen;

  /// 当前还能当材料的部件（融合后材料会被吃掉，所以要每次现取）
  List<FusionPart> get _materials =>
      _s._parts.where((p) => !identical(p, widget.target)).toList();

  Future<void> _confirm({required bool keepOpen}) async {
    final material = _picked;
    if (material == null) return;
    await _s._performFusion(target: widget.target, material: material);
    if (!mounted) return;
    // 目标满级、或没有别的部件了 → 继续也没意义，直接关掉
    if (!keepOpen || widget.target.isMaxLevel || _materials.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _picked = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final materials = _materials;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                _s._t(
                  '选择要喂给「${_s._partTitle(widget.target)}」的材料',
                  'Pick a material for "${_s._partTitle(widget.target)}"',
                ),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (materials.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Text(
                  _s._t('已经没有别的部件可以喂了', 'No other part is left to fuse'),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.outline,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    for (final m in materials)
                      _s._materialTile(
                        context,
                        target: widget.target,
                        material: m,
                        selected: identical(m, _picked),
                        onTap: () => setState(() => _picked = m),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _s._t(
                '· 一次只能融合一个材料，材料会被消耗。\n'
                    '· 先点上面选一个材料，再按下面的按钮：「确定并继续」会保留窗口，'
                    '方便接着喂下一个。',
                '· One material per fusion, and it is consumed.\n'
                    '· Tap a material above, then use the buttons below: "OK & continue" keeps this '
                    'sheet open so you can feed another one.',
              ),
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            _PopupActions(
              isZh: _s._isZh,
              expanded: true,
              onCancel: () => Navigator.pop(context),
              onContinue: _picked == null
                  ? null
                  : () => _confirm(keepOpen: true),
              onDone: _picked == null ? null : () => _confirm(keepOpen: false),
            ),
          ],
        ),
      ),
    );
  }
}
