import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'garage_data.dart';
import 'main.dart';
import 'part_shape_view.dart' show hexagonPath;
import 'parts_data.dart';
import 'parts_shape_data.dart';

/// 本地部件名（避免循环依赖 main.dart 的 pn）
String _pn(PartData part, String? locale) {
  if (locale == 'zh' && part.nameZh.isNotEmpty) return part.nameZh;
  if (locale == 'ja' && part.nameJa.isNotEmpty) return part.nameJa;
  return part.name;
}

/// 可重排部件条目（同类型部件可互换插槽位置）
typedef _ReorderEntry = ({PartCategory category, int index, PartData part});

/// 可交互插槽条目
typedef _SlotEntry = ({PartCategory category, int index, String? partId});

/// 车辆质量信息（重心 + 总重）
typedef _VehicleMass = ({Offset centerOfGravity, double totalWeight});

/// 我的车库界面
/// - 顶部 1~10 共 10 个车位按钮，选择已保存的车
/// - 国际服：展示车身与部件形状（部件安装到对应插槽，处理重叠），
///   可切换显示/隐藏插槽编号，可调整同类型部件在插槽上的顺序
/// - 国服/国际服：展示每个部件的裸数值与算上每一项加成后的数值
class MyGarageScreen extends StatefulWidget {
  final String locale;
  final String server;
  const MyGarageScreen({super.key, this.locale = 'zh', this.server = 'cn'});

  @override
  State<MyGarageScreen> createState() => _MyGarageScreenState();
}

class _MyGarageScreenState extends State<MyGarageScreen> {
  List<GarageVehicle?> _slots = List<GarageVehicle?>.filled(
    GarageStore.slotCount,
    null,
  );
  int _selectedSlot = 0; // 0-based
  bool _showSlotNumbers = true;
  bool _swapMode = false;
  _ReorderEntry? _selectedPart; // 调整模式下选中的部件
  double _shapeZoom = 1.0; // 形状缩放倍数
  late Map<String, PartData> _partById;
  final TextEditingController _codeController = TextEditingController();

  bool get _isZh => widget.locale == 'zh';
  bool get _isIntl => widget.server == 'intl';

  String _t(String zh, String en) => _isZh ? zh : en;

  @override
  void initState() {
    super.initState();
    _partById = {
      for (final p in PartDatabase.partsForServer(widget.server)) p.id: p,
    };
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final slots = await GarageStore.load();
    if (!mounted) return;
    setState(() {
      _slots = slots.map((v) => v == null ? null : _normalize(v)).toList();
      final cur = _slots[_selectedSlot];
      if (cur == null || cur.isEmpty) {
        final idx = _slots.indexWhere((v) => v != null && !v.isEmpty);
        _selectedSlot = idx < 0 ? 0 : idx;
      }
    });
  }

  /// 将槽位数组对齐到车身实际插槽数（兼容旧版紧凑列表数据）
  GarageVehicle _normalize(GarageVehicle v) {
    final body = v.bodyId == null ? null : _partById[v.bodyId!];
    if (body == null || body.slots == null) return v;
    List<String?> align(List<String?> slots, int count) {
      if (slots.length == count) return slots;
      final result = List<String?>.filled(count, null);
      for (int i = 0; i < slots.length && i < count; i++) {
        result[i] = slots[i];
      }
      return result;
    }

    return GarageVehicle(
      bodyId: v.bodyId,
      extraWeaponId: v.extraWeaponId,
      weaponSlots: align(v.weaponSlots, body.slots!.weapon),
      wheelSlots: align(v.wheelSlots, body.slots!.wheel),
      gadgetSlots: align(v.gadgetSlots, body.slots!.gadget),
      levels: v.levels,
      bonuses: v.bonuses,
    );
  }

  Future<void> _persist() => GarageStore.save(_slots);

  GarageVehicle? get _vehicle => _slots[_selectedSlot];

  @override
  Widget build(BuildContext context) {
    final vehicle = _vehicle;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('我的车库', 'My Garage')),
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
            child: vehicle == null || vehicle.isEmpty
                ? _buildEmpty()
                : _buildVehicleContent(vehicle),
          ),
        ],
      ),
    );
  }

  // ==================== 车位选择 ====================
  Widget _buildSlotSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('车位选择', 'Slot Select'),
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
    final name = (v?.name ?? '').trim();
    final hasName = filled && name.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() {
        _selectedSlot = i;
        _swapMode = false;
        _selectedPart = null;
        _shapeZoom = 1.0;
      }),
      child: Container(
        constraints: const BoxConstraints(minWidth: 62, maxWidth: 110),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
            if (hasName)
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : Colors.black87,
                ),
              )
            else
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

  Widget _buildEmpty() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.garage_outlined, size: 72, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              _t('该车位为空', 'This slot is empty'),
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              _t(
                '请先在「组车工具」中组好车并保存到车位，\n或粘贴车辆码导入到该车位',
                'Build a car in the Build Tool and save it to a slot,\nor paste a vehicle code to import into this slot',
              ),
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildCodeImportField(),
          ],
        ),
      ),
    );
  }

  // ==================== 车辆内容 ====================
  Widget _buildVehicleContent(GarageVehicle v) {
    final bodyPart = v.bodyId == null ? null : _partById[v.bodyId!];
    final bodyShape = _isIntl && bodyPart != null
        ? kPartShapeData[bodyPart.id]
        : null;
    final mass = bodyShape != null ? _computeVehicleMass(v, bodyShape) : null;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (v.name != null && v.name!.isNotEmpty) ...[
          Row(
            children: [
              const Icon(
                Icons.drive_file_rename_outline,
                size: 18,
                color: Colors.indigo,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  v.name!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (_isIntl) _buildShapeToolbar(v) else _buildRebuildButton(v),
        const SizedBox(height: 12),
        if (_isIntl) ...[
          if (bodyShape != null) ...[
            _GarageShapeView(
              bodyData: bodyShape,
              slotParts: _buildSlotParts(v, bodyShape),
              showNumbers: _showSlotNumbers,
              locale: widget.locale,
              centerOfGravity: mass?.centerOfGravity,
              zoom: _shapeZoom,
            ),
            if (mass != null) ...[
              const SizedBox(height: 6),
              Text(
                _t(
                  '总重 ${mass.totalWeight.toStringAsFixed(1)}',
                  'Total weight ${mass.totalWeight.toStringAsFixed(1)}',
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 4),
            _buildZoomSlider(),
          ] else
            Text(
              _t('该车身暂无形状数据', 'No shape data for this body'),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          const SizedBox(height: 8),
          _buildReorderSection(v),
          const Divider(height: 24),
        ],
        _buildStatsSection(v),
        _buildVehicleCodeSection(v),
        const SizedBox(height: 16),
      ],
    );
  }

  /// “重新组车”按钮：带着当前车位的车跳转到组车工具
  Widget _buildRebuildButton(GarageVehicle v) {
    return SizedBox(width: double.infinity, child: _rebuildButton(v));
  }

  /// “重新组车”按钮本体（可单独整行，也可与形状工具栏同排）
  Widget _rebuildButton(GarageVehicle v) {
    return ElevatedButton.icon(
      onPressed: () => _rebuildVehicle(v),
      icon: const Icon(Icons.build, size: 18),
      label: Text(
        _t('重新组车', 'Rebuild'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  /// 跳转到组车工具，返回后刷新车库数据
  Future<void> _rebuildVehicle(GarageVehicle v) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuildToolScreen(
          locale: widget.locale,
          server: widget.server,
          initialVehicle: v,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  /// 构建与车身插槽一一对应的部件形状列表
  List<PartShapeData?> _buildSlotParts(
    GarageVehicle v,
    PartShapeData bodyShape,
  ) {
    final slots = bodyShape.slots;
    final result = List<PartShapeData?>.filled(slots.length, null);
    int wi = 0, whi = 0, gi = 0;
    for (int i = 0; i < slots.length; i++) {
      String? partId;
      switch (slots[i].type) {
        case 'weapon':
          if (wi < v.weaponSlots.length) partId = v.weaponSlots[wi];
          wi++;
          break;
        case 'special_weapon':
          partId = v.extraWeaponId;
          break;
        case 'wheel':
          if (whi < v.wheelSlots.length) partId = v.wheelSlots[whi];
          whi++;
          break;
        case 'gadget':
          if (gi < v.gadgetSlots.length) partId = v.gadgetSlots[gi];
          gi++;
          break;
      }
      final part = partId == null ? null : _partById[partId];
      result[i] = part == null ? null : kPartShapeData[part.id];
    }
    return result;
  }

  /// 形状质心（多边形用鞋带公式质心，圆形取圆心）
  Offset _shapeCentroid(PartShapeData data) {
    if (data.shapeType == 'circle') return const Offset(200, 200);
    final pts = data.points!;
    double a2 = 0;
    double cx = 0, cy = 0;
    for (int i = 0; i < pts.length; i++) {
      final p = pts[i];
      final q = pts[(i + 1) % pts.length];
      final cross = p.dx * q.dy - q.dx * p.dy;
      a2 += cross;
      cx += (p.dx + q.dx) * cross;
      cy += (p.dy + q.dy) * cross;
    }
    final area = a2 / 2;
    if (area.abs() < 1e-9) {
      var minX = pts.first.dx, maxX = pts.first.dx;
      var minY = pts.first.dy, maxY = pts.first.dy;
      for (final p in pts) {
        minX = math.min(minX, p.dx);
        maxX = math.max(maxX, p.dx);
        minY = math.min(minY, p.dy);
        maxY = math.max(maxY, p.dy);
      }
      return Offset((minX + maxX) / 2, (minY + maxY) / 2);
    }
    return Offset(cx / (6 * area), cy / (6 * area));
  }

  /// 车辆重心：按重量加权平均车身与各部件（部件重心取插槽位置）
  _VehicleMass? _computeVehicleMass(GarageVehicle v, PartShapeData bodyShape) {
    double totalWeight = 0;
    double sumX = 0, sumY = 0;
    void add(double w, double x, double y) {
      if (w <= 0) return;
      totalWeight += w;
      sumX += w * x;
      sumY += w * y;
    }

    final bodyCg = _shapeCentroid(bodyShape);
    add(bodyShape.weight, bodyCg.dx, bodyCg.dy);

    int wi = 0, whi = 0, gi = 0;
    for (final slot in bodyShape.slots) {
      String? partId;
      switch (slot.type) {
        case 'weapon':
          if (wi < v.weaponSlots.length) partId = v.weaponSlots[wi];
          wi++;
          break;
        case 'special_weapon':
          partId = v.extraWeaponId;
          break;
        case 'wheel':
          if (whi < v.wheelSlots.length) partId = v.wheelSlots[whi];
          whi++;
          break;
        case 'gadget':
          if (gi < v.gadgetSlots.length) partId = v.gadgetSlots[gi];
          gi++;
          break;
      }
      if (partId == null) continue;
      final part = _partById[partId];
      final ps = part == null ? null : kPartShapeData[part.id];
      if (ps == null) continue;
      add(ps.weight, slot.x, slot.y);
    }

    if (totalWeight <= 0) return null;
    return (
      centerOfGravity: Offset(sumX / totalWeight, sumY / totalWeight),
      totalWeight: totalWeight,
    );
  }

  Widget _buildShapeToolbar(GarageVehicle v) {
    return Row(
      children: [
        Expanded(child: _rebuildButton(v)),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () =>
                setState(() => _showSlotNumbers = !_showSlotNumbers),
            icon: Icon(
              _showSlotNumbers ? Icons.numbers : Icons.numbers_outlined,
              size: 18,
            ),
            label: Text(
              _showSlotNumbers
                  ? _t('隐藏编号', 'Hide numbers')
                  : _t('显示编号', 'Show numbers'),
              style: const TextStyle(fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _renameVehicle(v),
            icon: const Icon(Icons.edit, size: 18),
            label: Text(
              _t('修改名称', 'Rename'),
              style: const TextStyle(fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  /// 修改当前车位的名称
  Future<void> _renameVehicle(GarageVehicle v) async {
    final controller = TextEditingController(text: v.name ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('修改车位名称', 'Rename slot')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: InputDecoration(
            labelText: _t('车位名称', 'Slot name'),
            hintText: _t('例如：主战车', 'e.g. Main build'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('取消', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(_t('保存', 'Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || !mounted) return;
    setState(() {
      v.name = newName.isEmpty ? null : newName;
      _persist();
    });
  }

  /// 形状缩放滑条（横向滑动缩放，附百分比显示）
  Widget _buildZoomSlider() {
    return Row(
      children: [
        const Icon(Icons.zoom_out, size: 18, color: Colors.grey),
        Expanded(
          child: Slider(
            value: _shapeZoom,
            min: 0.5,
            max: 3.0,
            divisions: 25,
            label: '${(_shapeZoom * 100).round()}%',
            onChanged: (v) => setState(() => _shapeZoom = v),
          ),
        ),
        const Icon(Icons.zoom_in, size: 18, color: Colors.grey),
        const SizedBox(width: 4),
        SizedBox(
          width: 40,
          child: Text(
            '${(_shapeZoom * 100).round()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  // ==================== 同类型部件顺序调整 ====================
  /// 可交互插槽条目（武器/车轮/配件三类，不含特殊武器槽）
  List<_SlotEntry> _slotEntries(GarageVehicle v) {
    final list = <_SlotEntry>[];
    void add(List<String?> slots, PartCategory cat) {
      for (int i = 0; i < slots.length; i++) {
        list.add((category: cat, index: i, partId: slots[i]));
      }
    }

    add(v.weaponSlots, PartCategory.weapon);
    add(v.wheelSlots, PartCategory.wheel);
    add(v.gadgetSlots, PartCategory.gadget);
    return list;
  }

  Widget _buildReorderSection(GarageVehicle v) {
    final slots = _slotEntries(v);
    if (slots.isEmpty) return const SizedBox.shrink();
    final sel = _selectedPart;
    // 按分类分组
    final groups = <PartCategory, List<_SlotEntry>>{};
    for (final s in slots) {
      groups.putIfAbsent(s.category, () => []).add(s);
    }
    const cats = [
      PartCategory.weapon,
      PartCategory.wheel,
      PartCategory.gadget,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _t('部件与插槽', 'Parts & Slots'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() {
                _swapMode = !_swapMode;
                _selectedPart = null;
              }),
              icon: Icon(_swapMode ? Icons.check : Icons.swap_horiz, size: 16),
              label: Text(_swapMode ? _t('完成', 'Done') : _t('调整顺序', 'Reorder')),
            ),
          ],
        ),
        if (_swapMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _t(
                '点击一个部件再点击另一个部件可交换位置；点击空插槽可将选中部件移入',
                'Tap a part then another to swap; tap an empty slot to move the selected part in',
              ),
              style: TextStyle(fontSize: 12, color: Colors.orange[800]),
            ),
          ),
        for (final cat in cats)
          if (groups[cat]?.isNotEmpty ?? false) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    _categoryIcon(cat),
                    size: 15,
                    color: _categoryColor(cat),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _catLabel(cat),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in groups[cat]!) _buildSlotChip(slot, sel),
              ],
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  String _catShortLabel(PartCategory cat) {
    switch (cat) {
      case PartCategory.weapon:
        return _t('武', 'W');
      case PartCategory.wheel:
        return _t('轮', 'Wh');
      case PartCategory.gadget:
        return _t('配', 'G');
      default:
        return _t('身', 'B');
    }
  }

  String _catLabel(PartCategory cat) {
    switch (cat) {
      case PartCategory.weapon:
        return _t('武器', 'Weapons');
      case PartCategory.wheel:
        return _t('车轮', 'Wheels');
      case PartCategory.gadget:
        return _t('配件', 'Gadgets');
      default:
        return _t('其他', 'Other');
    }
  }

  /// 插槽 chip：部件或空槽统一展示；调整模式下可交互
  Widget _buildSlotChip(_SlotEntry slot, _ReorderEntry? sel) {
    final color = _categoryColor(slot.category);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color fg = isDark ? Colors.white : Colors.black87;
    final slotTag = '[${_catShortLabel(slot.category)}${slot.index + 1}]';

    IconData leading;
    Color? bg;
    Color border;
    String label;
    if (slot.partId == null) {
      // 空插槽
      label = '$slotTag ${_t('空', 'Empty')}';
      leading = Icons.add_circle_outline;
      bg = color.withValues(alpha: 0.08);
      border = color.withValues(alpha: 0.4);
      if (_swapMode && sel != null && sel.category == slot.category) {
        // 选中部件的可放置目标
        bg = Colors.green[50];
        border = Colors.green;
        leading = Icons.add_circle_outline;
      }
    } else {
      final part = _partById[slot.partId!];
      final partName = part == null ? slot.partId! : _pn(part, widget.locale);
      label = '$slotTag $partName';
      final selected =
          sel != null &&
          sel.category == slot.category &&
          sel.index == slot.index;
      if (_swapMode && sel != null) {
        if (selected) {
          // 当前选中的部件
          bg = Colors.green[100];
          border = Colors.green;
          leading = Icons.check_circle;
        } else if (sel.category == slot.category) {
          // 同类型已占用：点击交换
          bg = Colors.orange[50];
          border = Colors.orange;
          leading = Icons.swap_horiz;
        } else {
          // 不同类型：不可用
          bg = Colors.grey[100];
          border = Colors.grey[300]!;
          fg = Colors.grey;
          leading = Icons.block;
        }
      } else {
        leading = _categoryIcon(slot.category);
        bg = color.withValues(alpha: 0.08);
        border = color.withValues(alpha: 0.5);
      }
    }

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _onSlotTap(slot),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(leading, size: 14, color: fg),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12, color: fg)),
            ],
          ),
        ),
      ),
    );
  }

  void _onSlotTap(_SlotEntry slot) {
    if (!_swapMode) return;
    final sel = _selectedPart;
    if (sel == null) {
      // 未选中部件：仅已占用插槽可选中（作为部件）
      if (slot.partId != null) {
        final part = _partById[slot.partId!];
        if (part != null) {
          setState(() {
            _selectedPart = (
              category: slot.category,
              index: slot.index,
              part: part,
            );
          });
        }
      }
      return;
    }
    if (slot.category != sel.category) {
      _showHint(
        _t('不能安装到不同类型的插槽', 'Cannot place into a slot of a different type'),
      );
      return;
    }
    setState(() {
      if (slot.index == sel.index) {
        _selectedPart = null; // 点击原槽位：取消选中
      } else if (slot.partId == null) {
        _movePartToSlot(sel.category, sel.index, slot.index); // 移入空槽
        _selectedPart = null;
      } else {
        _swapInVehicle(sel.category, sel.index, slot.index); // 交换
        _selectedPart = null;
      }
    });
  }

  void _showHint(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  /// 对应分类的槽位数组
  List<String?> _slotList(GarageVehicle v, PartCategory cat) {
    switch (cat) {
      case PartCategory.weapon:
        return v.weaponSlots;
      case PartCategory.wheel:
        return v.wheelSlots;
      case PartCategory.gadget:
        return v.gadgetSlots;
      default:
        return const <String?>[];
    }
  }

  /// 将部件从 from 槽移动到 to 槽（to 必须为空，from 清空）
  void _movePartToSlot(PartCategory cat, int from, int to) {
    final v = _vehicle!;
    final list = _slotList(v, cat);
    if (from < 0 || to < 0 || from >= list.length || to >= list.length) return;
    if (list[to] != null || list[from] == null) return;
    list[to] = list[from];
    list[from] = null;
    _persist();
  }

  /// 交换同一分类内两个插槽上的部件
  void _swapInVehicle(PartCategory cat, int a, int b) {
    final v = _vehicle!;
    final list = _slotList(v, cat);
    if (a < 0 || b < 0 || a >= list.length || b >= list.length) return;
    final tmp = list[a];
    list[a] = list[b];
    list[b] = tmp;
    _persist();
  }

  // ==================== 车辆码 ====================
  Widget _buildVehicleCodeSection(GarageVehicle v) {
    final code = GarageVehicle.encode(v);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Text(
          _t('车辆码', 'Vehicle Code'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _t(
            '复制此车辆码可分享车辆配置；粘贴他人车辆码可导入到当前车位',
            'Copy this code to share the vehicle; paste a code to import into the current slot',
          ),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
          ),
          child: SelectableText(
            code,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(height: 8),
        _buildCodeImportField(),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => _copyVehicleCode(v),
          icon: const Icon(Icons.copy, size: 16),
          label: Text(_t('复制车辆码', 'Copy code')),
        ),
      ],
    );
  }

  /// 粘贴车辆码并导入的输入框 + 按钮（空车位与非空车位共用）
  Widget _buildCodeImportField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _codeController,
            decoration: InputDecoration(
              hintText: _t('粘贴车辆码…', 'Paste vehicle code…'),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _importFromCode,
          icon: const Icon(Icons.download, size: 18),
          label: Text(_t('导入', 'Import')),
        ),
      ],
    );
  }

  Future<void> _copyVehicleCode(GarageVehicle v) async {
    await Clipboard.setData(ClipboardData(text: GarageVehicle.encode(v)));
    if (!mounted) return;
    _showHint(_t('车辆码已复制', 'Vehicle code copied'));
  }

  Future<void> _importFromCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showHint(_t('请先粘贴车辆码', 'Paste a vehicle code first'));
      return;
    }
    final vehicle = GarageVehicle.decode(code);
    if (vehicle == null || vehicle.isEmpty) {
      _showHint(_t('无效的车辆码', 'Invalid vehicle code'));
      return;
    }
    setState(() {
      _slots[_selectedSlot] = _normalize(vehicle);
    });
    await _persist();
    if (!mounted) return;
    _codeController.clear();
    _showHint(
      _t(
        '已导入到车位 ${_selectedSlot + 1}',
        'Imported to slot ${_selectedSlot + 1}',
      ),
    );
  }

  // ==================== 数值与加成 ====================
  Widget _buildStatsSection(GarageVehicle v) {
    final allParts = <PartData>[];
    PartData? bodyPart = v.bodyId == null ? null : _partById[v.bodyId!];
    if (bodyPart != null) allParts.add(bodyPart);
    PartData? extraWeapon = v.extraWeaponId == null
        ? null
        : _partById[v.extraWeaponId!];
    if (extraWeapon != null) allParts.add(extraWeapon);
    for (final id in v.weaponIds) {
      final p = _partById[id];
      if (p != null) allParts.add(p);
    }
    for (final id in v.wheelIds) {
      final p = _partById[id];
      if (p != null) allParts.add(p);
    }
    for (final id in v.gadgetIds) {
      final p = _partById[id];
      if (p != null) allParts.add(p);
    }

    int catBonus(PartCategory cat) => allParts.fold(
      0,
      (s, p) => s + (p.bonus?.category == cat ? p.bonus!.percent : 0),
    );
    final bodyBonusPct = catBonus(PartCategory.body);
    final weaponBonusPct = catBonus(PartCategory.weapon);
    final wheelBonusPct = catBonus(PartCategory.wheel);
    final gadgetBonusPct = catBonus(PartCategory.gadget);

    // 赞助加成：同赞助 3+ 个 → 10% + (n-3)*5%
    final sponsorCounts = <Sponsor, int>{};
    for (final p in allParts) {
      if (p.sponsor != Sponsor.none) {
        sponsorCounts[p.sponsor] = (sponsorCounts[p.sponsor] ?? 0) + 1;
      }
    }
    int sponsorBonusPct = 0;
    for (final cnt in sponsorCounts.values) {
      if (cnt >= 3) sponsorBonusPct += 10 + (cnt - 3) * 5;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('数值与加成', 'Stats & Bonuses'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (bodyBonusPct > 0)
              _bonusChip('${_t('车身', 'Body')}+$bodyBonusPct%', Colors.orange),
            if (weaponBonusPct > 0)
              _bonusChip('${_t('攻击', 'ATK')}+$weaponBonusPct%', Colors.red),
            if (wheelBonusPct > 0)
              _bonusChip('${_t('车轮', 'Wheel')}+$wheelBonusPct%', Colors.green),
            if (gadgetBonusPct > 0)
              _bonusChip(
                '${_t('配件', 'Gadget')}+$gadgetBonusPct%',
                Colors.purple,
              ),
            if (sponsorBonusPct > 0)
              _bonusChip(
                '${_t('赞助', 'Sponsor')}+$sponsorBonusPct%',
                Colors.teal,
              ),
            if (bodyBonusPct == 0 &&
                weaponBonusPct == 0 &&
                wheelBonusPct == 0 &&
                gadgetBonusPct == 0 &&
                sponsorBonusPct == 0)
              Text(
                _t('无加成', 'No bonus'),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildWholeVehicleCard(
          v,
          allParts,
          bodyBonusPct,
          weaponBonusPct,
          wheelBonusPct,
          gadgetBonusPct,
          sponsorBonusPct,
        ),
        const SizedBox(height: 6),
        for (final p in allParts)
          _buildPartStatCard(
            v,
            p,
            bodyBonusPct,
            weaponBonusPct,
            wheelBonusPct,
            gadgetBonusPct,
            sponsorBonusPct,
            bodyPart,
            extraWeapon,
          ),
      ],
    );
  }

  /// 整车数值汇总（额外加成放在最后算：裸 → 分类 → 赞助 → 额外 → 最终）
  Widget _buildWholeVehicleCard(
    GarageVehicle v,
    List<PartData> allParts,
    int bodyB,
    int weaponB,
    int wheelB,
    int gadgetB,
    int sponsorB,
  ) {
    double bareHp = 0, afterCatHp = 0, afterSponsorHp = 0, finalHp = 0;
    double bareAtk = 0, afterCatAtk = 0, afterSponsorAtk = 0, finalAtk = 0;
    bool hasHp = false, hasAtk = false, hasExtra = false;
    for (final p in allParts) {
      final lv = (v.levels[p.id] ?? 1).clamp(1, p.maxLevel).toInt();
      int catB;
      switch (p.category) {
        case PartCategory.body:
          catB = bodyB;
          break;
        case PartCategory.weapon:
          catB = weaponB;
          break;
        case PartCategory.wheel:
          catB = wheelB;
          break;
        case PartCategory.gadget:
          catB = gadgetB;
          break;
      }
      final extra = (v.bonuses[p.id] ?? 0).clamp(0, 150);
      if (extra > 0) hasExtra = true;
      final cm = 1 + catB / 100.0;
      final sm = 1 + sponsorB / 100.0;
      final em = 1 + extra / 100.0;
      final hpV = p.hp(lv);
      final atkV = p.atk(lv);
      if (hpV > 0) hasHp = true;
      if (atkV > 0) hasAtk = true;
      bareHp += hpV;
      bareAtk += atkV;
      afterCatHp += hpV * cm;
      afterCatAtk += atkV * cm;
      afterSponsorHp += hpV * cm * sm;
      afterSponsorAtk += atkV * cm * sm;
      finalHp += hpV * cm * em * sm;
      finalAtk += atkV * cm * em * sm;
    }
    final hasCat = bodyB + weaponB + wheelB + gadgetB > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? Colors.white70 : Colors.grey[800];

    Widget line(
      String label,
      double bare,
      double afterCat,
      double afterSponsor,
      double finalV,
    ) {
      final chain = <String>['${_t('裸', 'Base')} ${_fmt(bare)}'];
      if (hasCat) {
        chain.add('${_t('分类+', 'Cat+')} ${_fmt(afterCat)}');
      }
      if (sponsorB > 0) {
        chain.add(
          '${_t('赞助+', 'Sponsor+')}$sponsorB%: ${_fmt(afterSponsor)}',
        );
      }
      if (hasExtra) {
        chain.add('${_t('额外+', 'Extra+')} ${_fmt(finalV)}');
      }
      chain.add('${_t('最终', 'Final')} ${_fmt(finalV)}');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text.rich(
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            children: [
              TextSpan(
                text: chain.join(' → '),
                style: TextStyle(fontSize: 12, color: subColor),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? Colors.indigo.shade900 : Colors.indigo[50],
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.directions_car,
                  size: 18,
                  color: Colors.indigo,
                ),
                const SizedBox(width: 6),
                Text(
                  _t('整车数据', 'Whole Vehicle'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (hasHp)
              line(_t('HP', 'HP'), bareHp, afterCatHp, afterSponsorHp, finalHp),
            if (hasAtk)
              line(
                _t('ATK', 'ATK'),
                bareAtk,
                afterCatAtk,
                afterSponsorAtk,
                finalAtk,
              ),
          ],
        ),
      ),
    );
  }

  Widget _bonusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPartStatCard(
    GarageVehicle v,
    PartData p,
    int bodyB,
    int weaponB,
    int wheelB,
    int gadgetB,
    int sponsorB,
    PartData? bodyPart,
    PartData? extraWeapon,
  ) {
    final lv = (v.levels[p.id] ?? 1).clamp(1, p.maxLevel);
    final extra = (v.bonuses[p.id] ?? 0).clamp(0, 150);
    int catB;
    switch (p.category) {
      case PartCategory.body:
        catB = bodyB;
        break;
      case PartCategory.weapon:
        catB = weaponB;
        break;
      case PartCategory.wheel:
        catB = wheelB;
        break;
      case PartCategory.gadget:
        catB = gadgetB;
        break;
    }
    final slotDesc = _slotDescription(v, p, bodyPart, extraWeapon);
    final shape = kPartShapeData[p.id];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _categoryIcon(p.category),
                  size: 18,
                  color: _categoryColor(p.category),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_pn(p, widget.locale)} (${p.rarityLabel} · ${_t('Lv', 'Lv')}$lv${slotDesc.isNotEmpty ? ' · $slotDesc' : ''})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (p.hp1 > 0)
              _statLine(_t('HP', 'HP'), p.hp(lv), catB, extra, sponsorB),
            if (p.atk1 > 0)
              _statLine(_t('ATK', 'ATK'), p.atk(lv), catB, extra, sponsorB),
            if (p.mHp1 > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text.rich(
                  TextSpan(
                    text: '${_t('随从HP', 'Minion HP')}: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    children: [
                      TextSpan(
                        text: _fmt(p.mHp(lv)),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (p.power != 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${_t('电力', 'Power')}: ${p.power > 0 ? '+' : ''}${p.power}',
                  style: TextStyle(fontSize: 12, color: Colors.amber[800]),
                ),
              ),
            if (p.bonus != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${_t('自身加成', 'Own bonus')}: ${p.bonusLabelEn(widget.locale)}',
                  style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                ),
              ),
            if (shape != null && shape.weight > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${_t('重量', 'Weight')}: ${shape.weight.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 12, color: Colors.deepOrange),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 数值链条：裸值 → 分类加成 → 赞助加成 → 额外加成 → 最终（额外加成放最后）
  Widget _statLine(
    String label,
    double bare,
    int catB,
    int extra,
    int sponsorB,
  ) {
    final afterCat = bare * (1 + catB / 100);
    final afterSponsor = afterCat * (1 + sponsorB / 100);
    final finalV = afterSponsor * (1 + extra / 100);
    final chain = <String>['${_t('裸', 'Base')} ${_fmt(bare)}'];
    if (catB > 0) chain.add('${_t('分类+', 'Cat+')}$catB%: ${_fmt(afterCat)}');
    if (sponsorB > 0) {
      chain.add('${_t('赞助+', 'Sponsor+')}$sponsorB%: ${_fmt(afterSponsor)}');
    }
    if (extra > 0) {
      chain.add('${_t('额外+', 'Extra+')}$extra%: ${_fmt(finalV)}');
    }
    chain.add('${_t('最终', 'Final')} ${_fmt(finalV)}');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(
          text: '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          children: [
            TextSpan(
              text: chain.join(' → '),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _slotDescription(
    GarageVehicle v,
    PartData p,
    PartData? bodyPart,
    PartData? extraWeapon,
  ) {
    if (p.id == bodyPart?.id) return _t('车身', 'Body');
    if (p.id == extraWeapon?.id) return _t('额外武器', 'X-Weapon');
    final w = v.weaponSlots.indexOf(p.id);
    if (w >= 0) return '${_t('武', 'W')}${w + 1}';
    final wh = v.wheelSlots.indexOf(p.id);
    if (wh >= 0) return '${_t('轮', 'Wh')}${wh + 1}';
    final g = v.gadgetSlots.indexOf(p.id);
    if (g >= 0) return '${_t('配', 'G')}${g + 1}';
    return '';
  }

  String _fmt(num n) {
    final sign = n < 0 ? '-' : '';
    final s = n.abs().round().toString();
    final buf = StringBuffer(sign);
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  IconData _categoryIcon(PartCategory c) {
    switch (c) {
      case PartCategory.body:
        return Icons.directions_car;
      case PartCategory.weapon:
        return Icons.gps_fixed;
      case PartCategory.wheel:
        return Icons.radio_button_checked;
      case PartCategory.gadget:
        return Icons.build;
    }
  }

  Color _categoryColor(PartCategory c) {
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

// ==================== 形状展示（车身 + 已安装部件） ====================
class _GarageShapeView extends StatelessWidget {
  final PartShapeData bodyData;
  final List<PartShapeData?> slotParts;
  final bool showNumbers;
  final String locale;
  final Offset? centerOfGravity;
  final double zoom;
  const _GarageShapeView({
    required this.bodyData,
    required this.slotParts,
    required this.showNumbers,
    required this.locale,
    this.centerOfGravity,
    this.zoom = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 320,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: _GaragePainter(
            bodyData,
            slotParts,
            showNumbers,
            locale,
            centerOfGravity,
            isDark,
            zoom,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _GaragePainter extends CustomPainter {
  final PartShapeData bodyData;
  final List<PartShapeData?> slotParts;
  final bool showNumbers;
  final String locale;
  final Offset? centerOfGravity;
  final bool isDark;
  final double zoom;

  _GaragePainter(
    this.bodyData,
    this.slotParts,
    this.showNumbers,
    this.locale,
    this.centerOfGravity,
    this.isDark,
    this.zoom,
  );

  static const double _pad = 18.0;
  static const double _gridSize = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    // 背景 + 方格纸
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = isDark ? const Color(0xFF212121) : const Color(0xFFFAFAFA),
    );
    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF424242) : const Color(0xFFE3E3E3)
      ..strokeWidth = 0.6;
    for (double x = 0; x <= size.width; x += _gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += _gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 坐标变换（以车身包围盒为基准）
    final bbox = _bbox();
    final contentW = size.width - 2 * _pad;
    final contentH = size.height - 2 * _pad;
    final bw = math.max(bbox.width, 0.001);
    final bh = math.max(bbox.height, 0.001);
    final scale = math.min(contentW / bw, contentH / bh);
    final effScale = scale * zoom;
    Offset tr(Offset p) => Offset(
      (size.width - bbox.width * effScale) / 2 -
          bbox.left * effScale +
          p.dx * effScale,
      (size.height - bbox.height * effScale) / 2 -
          bbox.top * effScale +
          p.dy * effScale,
    );

    // 层1：车轮（底层，叠在车身下）
    for (int i = 0; i < bodyData.slots.length; i++) {
      if (bodyData.slots[i].type == 'wheel' && slotParts[i] != null) {
        _drawPart(
          canvas,
          slotParts[i]!,
          bodyData.slots[i],
          tr,
          effScale,
          'wheel',
        );
      }
    }
    // 层2：车身
    _drawBody(canvas, tr, effScale);
    // 层3：武器 / 特殊武器 / 配件（顶层，叠在车身上）
    for (int i = 0; i < bodyData.slots.length; i++) {
      final t = bodyData.slots[i].type;
      if (t == 'wheel') continue;
      if (slotParts[i] != null) {
        _drawPart(canvas, slotParts[i]!, bodyData.slots[i], tr, effScale, t);
      }
    }
    // 层4：插槽定位图形 + 编号（字符在图形外）
    for (int i = 0; i < bodyData.slots.length; i++) {
      final slot = bodyData.slots[i];
      final c = tr(Offset(slot.x, slot.y));
      _drawSlotIndicator(
        canvas,
        c,
        slot.type,
        showNumbers ? _slotLabel(i) : null,
      );
    }
    // 层5：车辆重心标记
    if (centerOfGravity != null) {
      _drawCenterOfGravity(canvas, tr(centerOfGravity!));
    }
    // 层6：比例尺（左下角，与背景方格同步，标注实际意义长度）
    _drawScaleBar(canvas, size, effScale);
  }

  Color _partFillColor(String type) {
    switch (type) {
      case 'weapon':
        return Colors.red;
      case 'special_weapon':
        return Colors.brown;
      case 'wheel':
        return Colors.green;
      case 'gadget':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  /// 插槽编号：同类型按出现顺序编号；中文用 武/轮/配，英文用 W/Wh/G
  String _slotLabel(int i) {
    final type = bodyData.slots[i].type;
    int n = 1;
    for (int j = 0; j < i; j++) {
      if (bodyData.slots[j].type == type) n++;
    }
    final zh = locale == 'zh';
    switch (type) {
      case 'weapon':
        return zh ? '武$n' : 'W$n';
      case 'special_weapon':
        return zh ? '特' : 'X';
      case 'wheel':
        return zh ? '轮$n' : 'Wh$n';
      case 'gadget':
        return zh ? '配$n' : 'G$n';
      case 'body':
        return zh ? '身' : 'B';
      default:
        return '?';
    }
  }

  /// 在指定插槽位置绘制部件形状（部件中心对齐插槽位置）
  void _drawPart(
    Canvas canvas,
    PartShapeData part,
    PartSlotPos slot,
    Offset Function(Offset) tr,
    double scale,
    String type,
  ) {
    final color = _partFillColor(type);
    final fill = Paint()..color = color.withValues(alpha: 0.45);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final (cx, cy) = _partCenter(part);
    Offset map(Offset p) =>
        tr(Offset(slot.x + (p.dx - cx), slot.y + (p.dy - cy)));
    if (part.shapeType == 'polygon') {
      final pts = part.points!;
      final path = Path();
      for (int i = 0; i < pts.length; i++) {
        final q = map(pts[i]);
        if (i == 0) {
          path.moveTo(q.dx, q.dy);
        } else {
          path.lineTo(q.dx, q.dy);
        }
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    } else {
      final c = tr(Offset(slot.x, slot.y));
      final r = (part.radius ?? 10.0) * scale;
      canvas.drawCircle(c, r, fill);
      canvas.drawCircle(c, r, stroke);
    }
  }

  (double, double) _partCenter(PartShapeData part) {
    if (part.shapeType == 'circle') return (200.0, 200.0);
    final pts = part.points!;
    var minX = pts.first.dx, maxX = pts.first.dx;
    var minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    return ((minX + maxX) / 2, (minY + maxY) / 2);
  }

  void _drawBody(Canvas canvas, Offset Function(Offset) tr, double scale) {
    final fill = Paint()..color = const Color(0x3364B5F6);
    final stroke = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (bodyData.shapeType == 'polygon') {
      final pts = bodyData.points!;
      final path = Path();
      for (int i = 0; i < pts.length; i++) {
        final q = tr(pts[i]);
        if (i == 0) {
          path.moveTo(q.dx, q.dy);
        } else {
          path.lineTo(q.dx, q.dy);
        }
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    } else {
      final c = tr(const Offset(200, 200));
      final r = (bodyData.radius ?? 10.0) * scale;
      canvas.drawCircle(c, r, fill);
      canvas.drawCircle(c, r, stroke);
    }
  }

  Rect _bbox() {
    if (bodyData.shapeType == 'circle') {
      final r = bodyData.radius ?? 10.0;
      return Rect.fromCenter(
        center: const Offset(200, 200),
        width: 2 * r,
        height: 2 * r,
      );
    }
    final pts = bodyData.points!;
    var minX = pts.first.dx, maxX = pts.first.dx;
    var minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// 插槽定位图形（缩小版，按类型形状 + 对应颜色）；编号字符画在图形外
  void _drawSlotIndicator(Canvas canvas, Offset c, String type, String? label) {
    final color = _partFillColor(type);
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    switch (type) {
      case 'weapon':
        final path = hexagonPath(c, 4);
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        break;
      case 'special_weapon':
        final diamond = Path()
          ..moveTo(c.dx, c.dy - 5)
          ..lineTo(c.dx + 5, c.dy)
          ..lineTo(c.dx, c.dy + 5)
          ..lineTo(c.dx - 5, c.dy)
          ..close();
        canvas.drawPath(diamond, fill);
        canvas.drawPath(diamond, stroke);
        break;
      case 'gadget':
        final rect = Rect.fromCenter(center: c, width: 8, height: 8);
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
        break;
      default: // wheel / body
        canvas.drawCircle(c, 4, fill);
        canvas.drawCircle(c, 4, stroke);
    }
    if (label != null && label.isNotEmpty) {
      _drawSlotLabel(canvas, c, label, color);
    }
  }

  /// 编号字符：画在定位图形右上角（图形外），带白色半透明底提升可读性
  void _drawSlotLabel(Canvas canvas, Offset c, String label, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pos = Offset(c.dx + 7, c.dy - tp.height - 5);
    canvas.drawRect(
      Rect.fromLTWH(pos.dx - 1.5, pos.dy - 1, tp.width + 3, tp.height + 2),
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
    tp.paint(canvas, pos);
  }

  /// 车辆重心标记：红色倒三角形（顶点朝下）
  void _drawCenterOfGravity(Canvas canvas, Offset c) {
    final r = 12.0;
    final path = Path()
      ..moveTo(c.dx - r, c.dy - r * 0.7) // 左上
      ..lineTo(c.dx + r, c.dy - r * 0.7) // 右上
      ..lineTo(c.dx, c.dy + r) // 底部尖端（朝下）
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.red.withValues(alpha: 0.85));
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// 比例尺：与背景方格同步，展示 1 格与 5 格代表的实际长度（数据单位，非屏幕像素）
  void _drawScaleBar(Canvas canvas, Size size, double effScale) {
    const cells = 5;
    final x0 = _gridSize * 2; // 从格线处起画，保证刻度与背景方格线对齐
    final x1 = x0 + cells * _gridSize;
    final y = size.height - 14.0;
    final paint = Paint()
      ..color = isDark ? Colors.white70 : Colors.black54
      ..strokeWidth = 1.4;
    // 主横线（总长 5 格）
    canvas.drawLine(Offset(x0, y), Offset(x1, y), paint);
    // 每个格线处画刻度（与背景方格对齐），端部刻度加高
    for (int i = 0; i <= cells; i++) {
      final x = x0 + i * _gridSize;
      final isEnd = i == 0 || i == cells;
      canvas.drawLine(
        Offset(x, y - (isEnd ? 5 : 3)),
        Offset(x, y + (isEnd ? 5 : 3)),
        paint,
      );
    }
    // 每格代表的数据长度 = 屏幕格子像素 ÷ 数据到画布的缩放比
    final perCell = _gridSize / effScale;
    final zh = locale == 'zh';
    final oneLen = perCell.round();
    final fiveLen = (perCell * cells).round();
    // “1格”标签：第一个方格上方（标注实际意义长度）
    _paintScaleText(
      canvas,
      zh ? '1格≈$oneLen' : '1 cell≈$oneLen',
      x0 + _gridSize / 2,
      y - 6,
    );
    // “5格”标签：整条比例尺末端（标注实际意义长度）
    _paintScaleText(canvas, zh ? '5格≈$fiveLen' : '5 cells≈$fiveLen', x1, y - 6);
  }

  /// 在指定中心 x、基准线 bottomY 上方绘制比例尺标签
  void _paintScaleText(
    Canvas canvas,
    String text,
    double centerX,
    double bottomY,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 10,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(centerX - tp.width / 2, bottomY - tp.height));
  }

  @override
  bool shouldRepaint(covariant _GaragePainter oldDelegate) =>
      oldDelegate.bodyData != bodyData ||
      oldDelegate.slotParts != slotParts ||
      oldDelegate.showNumbers != showNumbers ||
      oldDelegate.locale != locale ||
      oldDelegate.centerOfGravity != centerOfGravity ||
      oldDelegate.isDark != isDark ||
      oldDelegate.zoom != zoom;
}
