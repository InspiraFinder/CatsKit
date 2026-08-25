import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gang_stats_postprocess.dart';
import 'ocr_box_painter.dart';
import 'ocr_engine.dart';

/// 一个帮派成员的车辆数据（一个账号 3 辆车）
class GangMember {
  final String userId;
  final List<int?> hp; // 3 辆车
  final List<int?> atk; // 3 辆车

  GangMember({required this.userId, required this.hp, required this.atk});

  int get totalHp => hp.fold(0, (s, v) => s + (v ?? 0));
  int get totalAtk => atk.fold(0, (s, v) => s + (v ?? 0));

  Map<String, dynamic> toJson() => {'userId': userId, 'hp': hp, 'atk': atk};

  factory GangMember.fromJson(Map<String, dynamic> json) => GangMember(
    userId: json['userId'] as String? ?? '',
    hp: ((json['hp'] as List?) ?? const [])
        .map((e) => (e as num?)?.toInt())
        .toList(),
    atk: ((json['atk'] as List?) ?? const [])
        .map((e) => (e as num?)?.toInt())
        .toList(),
  );
}

/// 帮派统计界面：上传 3 张车辆属性图（纵向叠放），OCR 识别 HP/ATK，
/// 输入用户 ID 后存档到下方表格。右上角可切换识别框、查看/复制全部识别数据。
class GangStatsScreen extends StatefulWidget {
  final String locale;
  final String server;
  const GangStatsScreen({
    super.key,
    this.locale = 'zh',
    this.server = 'cn',
  });

  @override
  State<GangStatsScreen> createState() => _GangStatsScreenState();
}

class _GangStatsScreenState extends State<GangStatsScreen> {
  static const int _vehicleCount = 3;
  static const String _prefsKey = 'gang_stats_members';

  final ImagePicker _picker = ImagePicker();
  final List<File?> _images = List.generate(_vehicleCount, (_) => null);
  final List<int> _imgW = List.generate(_vehicleCount, (_) => 0);
  final List<int> _imgH = List.generate(_vehicleCount, (_) => 0);
  final List<bool> _processing = List.generate(_vehicleCount, (_) => false);
  final List<List<Map<String, dynamic>>> _textItems = List.generate(
    _vehicleCount,
    (_) => <Map<String, dynamic>>[],
  );
  final List<TextEditingController> _hpCtrl = List.generate(
    _vehicleCount,
    (_) => TextEditingController(),
  );
  final List<TextEditingController> _atkCtrl = List.generate(
    _vehicleCount,
    (_) => TextEditingController(),
  );
  final TextEditingController _userIdCtrl = TextEditingController();
  List<GangMember> _members = [];
  bool _showOverlay = false;

  bool get _isZh => widget.locale == 'zh';
  String _t(String zh, String en) => _isZh ? zh : en;
  bool get _hasAnyImage => _images.any((f) => f != null);
  bool get _hasAnyText => _textItems.any((l) => l.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    for (final c in _hpCtrl) {
      c.dispose();
    }
    for (final c in _atkCtrl) {
      c.dispose();
    }
    _userIdCtrl.dispose();
    super.dispose();
  }

  // ==================== 持久化 ====================
  Future<void> _loadMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      final members = <GangMember>[
        for (final m in list)
          if (m != null) GangMember.fromJson((m as Map).cast<String, dynamic>()),
      ];
      if (!mounted) return;
      setState(() => _members = members);
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode([for (final m in _members) m.toJson()]),
    );
  }

  // ==================== 选图 ====================
  void _showPickOptions(int index) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(_t('从相册选择', 'From gallery')),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(index, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(_t('拍照', 'Camera')),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(index, ImageSource.camera);
              },
            ),
            if (_images[index] != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  _t('移除该图片', 'Remove image'),
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _images[index] = null;
                    _imgW[index] = 0;
                    _imgH[index] = 0;
                    _textItems[index] = [];
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(int index, ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (picked == null) return;
    await _loadImage(index, picked);
  }

  /// 批量选择多张图片，依次填入车辆位
  Future<void> _pickMultiImages() async {
    final picked = await _picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      limit: _vehicleCount,
    );
    if (picked.isEmpty) return;
    // 目标位置：优先空位，不足则按 0/1/2 顺序覆盖
    final targets = <int>[
      for (int i = 0; i < _vehicleCount; i++)
        if (_images[i] == null) i,
    ];
    for (int i = 0; i < _vehicleCount && targets.length < picked.length; i++) {
      if (!targets.contains(i)) targets.add(i);
    }
    for (int i = 0; i < picked.length && i < targets.length; i++) {
      await _loadImage(targets[i], picked[i]);
    }
  }

  /// 处理选中的一张图片：写临时文件、记录尺寸、自动识别
  Future<void> _loadImage(int index, XFile picked) async {
    final bytes = await picked.readAsBytes();
    final tempFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}gang_ocr_${index}_${DateTime.now().millisecondsSinceEpoch}.tmp',
    );
    await tempFile.writeAsBytes(bytes, flush: true);

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    // 前处理放大：仅桌面 Python OCR 需要放大 2 倍避免小数字被合并。
    // Android ML Kit 识别超大图会内部缩放（限制约 3800px 宽），
    // 导致返回坐标被压缩（数据只有真实位置的一半左右）；
    // 且放大也无法避免 HP/ATK/电量合并（新算法可拆分），故 Android 直接识别原图。
    final image = Platform.isAndroid
        ? tempFile
        : await OcrEngine.upscaleImage(tempFile, 2);
    if (!mounted) return;
    setState(() {
      _images[index] = image;
      _imgW[index] = frame.image.width;
      _imgH[index] = frame.image.height;
      _textItems[index] = [];
    });
    await _recognize(index);
  }

  /// 右上角选图弹窗（批量 / 单张相册 / 拍照）
  void _showBulkPickOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(_t('批量选择图片（最多3张）', 'Pick multiple (max 3)')),
              subtitle: Text(
                _t('一次选择，自动填入三辆车', 'Auto-fill the 3 vehicles'),
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickMultiImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(_t('从相册选择单张', 'Pick single from gallery')),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(_firstEmptyIndex(), ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(_t('拍照', 'Camera')),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(_firstEmptyIndex(), ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 识别车辆 HP/ATK（启发式：最大数字=HP，次大=ATK）
  Future<void> _recognize(int index) async {
    final image = _images[index];
    if (image == null) return;
    setState(() => _processing[index] = true);
    try {
      final items = await OcrEngine.recognize(image);
      // 桌面端识别的是放大 2 倍的图，坐标需映射回原图（除以 2）；
      // Android 端识别原图，坐标即原图坐标，无需缩放。
      final scaleFactor = Platform.isAndroid ? 1 : 2;
      final mapped = <Map<String, dynamic>>[
        for (final it in items)
          {
            'text': it['text'],
            'x': ((it['x'] as num).toInt() / scaleFactor).round(),
            'y': ((it['y'] as num).toInt() / scaleFactor).round(),
            'w': ((it['w'] as num).toInt() / scaleFactor).round(),
            'h': ((it['h'] as num).toInt() / scaleFactor).round(),
          },
      ];
      final (hp: hp, atk: atk) = classifyHpAtk(
        mapped,
        _imgW[index],
        _imgH[index],
      );
      if (!mounted) return;
      setState(() {
        _textItems[index] = mapped;
        if (hp != null) _hpCtrl[index].text = _formatNum(hp);
        if (atk != null) _atkCtrl[index].text = _formatNum(atk);
      });
    } catch (e) {
      if (!mounted) return;
      _snack('${_t('识别失败', 'OCR failed')}: $e');
    } finally {
      if (mounted) setState(() => _processing[index] = false);
    }
  }

  // ==================== 识别数据列表 / 复制 ====================
  void _showOcrTextList() {
    if (!_hasAnyText) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _t('识别数据（三辆车）', 'OCR Data (3 vehicles)'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_all),
                    tooltip: _t('复制全部', 'Copy all'),
                    onPressed: _copyAllOcr,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: _t('关闭', 'Close'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  for (int i = 0; i < _vehicleCount; i++)
                    if (_textItems[i].isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        child: Text(
                          _t('车辆 ${i + 1}', 'Vehicle ${i + 1}'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _vehicleColor(i),
                          ),
                        ),
                      ),
                      for (int k = 0; k < _textItems[i].length; k++)
                        ListTile(
                          dense: true,
                          title: Text(
                            _textItems[i][k]['text'] as String? ?? '',
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            'x:${_textItems[i][k]['x']} y:${_textItems[i][k]['y']}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          trailing: IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.copy, size: 16),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text:
                                      _textItems[i][k]['text'] as String? ?? '',
                                ),
                              );
                              _snack(_t('已复制', 'Copied'));
                            },
                          ),
                        ),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyAllOcr() async {
    final buf = StringBuffer();
    for (int i = 0; i < _vehicleCount; i++) {
      if (_textItems[i].isEmpty) continue;
      buf.writeln(_t('【车辆 ${i + 1}】', '[Vehicle ${i + 1}]'));
      for (final it in _textItems[i]) {
        final text = it['text'] as String? ?? '';
        final x = it['x'] as int? ?? 0;
        final y = it['y'] as int? ?? 0;
        final w = it['w'] as int? ?? 0;
        final h = it['h'] as int? ?? 0;
        buf.writeln('$text (x=$x y=$y w=$w h=$h)');
      }
    }
    if (buf.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: buf.toString().trim()));
    if (mounted) _snack(_t('已复制全部识别数据', 'Copied all OCR data'));
  }

  // ==================== 存档 ====================
  void _saveMember() {
    final userId = _userIdCtrl.text.trim();
    if (userId.isEmpty) {
      _snack(_t('请输入用户 ID', 'Enter user ID'));
      return;
    }
    final hp = <int?>[];
    final atk = <int?>[];
    for (int i = 0; i < _vehicleCount; i++) {
      hp.add(int.tryParse(_hpCtrl[i].text.replaceAll(',', '').trim()));
      atk.add(int.tryParse(_atkCtrl[i].text.replaceAll(',', '').trim()));
    }
    if (hp.every((v) => v == null) && atk.every((v) => v == null)) {
      _snack(_t('请先识别或填写至少一辆车的 HP/ATK', 'Fill HP/ATK first'));
      return;
    }
    setState(() {
      _members.add(GangMember(userId: userId, hp: hp, atk: atk));
      _userIdCtrl.clear();
      for (int i = 0; i < _vehicleCount; i++) {
        _hpCtrl[i].clear();
        _atkCtrl[i].clear();
        _images[i] = null;
        _imgW[i] = 0;
        _imgH[i] = 0;
        _textItems[i] = [];
      }
      _persist();
    });
    _snack(_t('已存档并合并到表格', 'Saved to table'));
  }

  void _removeMember(int index) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('删除该成员？', 'Remove this member?')),
        content: Text(_t('将删除该成员的统计记录。', 'This member will be removed.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('取消', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('删除', 'Delete')),
          ),
        ],
      ),
    ).then((ok) {
      if (ok == true && mounted) {
        setState(() {
          _members.removeAt(index);
          _persist();
        });
      }
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  Color _vehicleColor(int i) => i == 0
      ? Colors.red
      : i == 1
      ? Colors.green
      : Colors.blue;

  // ==================== UI ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('帮派统计', 'Gang Stats')),
        centerTitle: true,
        actions: [
          if (_hasAnyImage)
            IconButton(
              icon: Icon(
                _showOverlay ? Icons.text_fields : Icons.text_fields_outlined,
                color: _showOverlay ? Colors.blue : null,
              ),
              onPressed: () => setState(() => _showOverlay = !_showOverlay),
              tooltip: _showOverlay
                  ? _t('隐藏识别框', 'Hide OCR boxes')
                  : _t('显示识别框', 'Show OCR boxes'),
            ),
          if (_hasAnyText)
            IconButton(
              icon: const Icon(Icons.list_alt),
              onPressed: _showOcrTextList,
              tooltip: _t('识别数据列表', 'OCR data list'),
            ),
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: _showBulkPickOptions,
            tooltip: _t('选择图片', 'Pick image'),
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, {'locale': widget.locale}),
          tooltip: _t('返回主菜单', 'Back'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIntro(),
            const SizedBox(height: 8),
            _buildImagesArea(),
            const SizedBox(height: 10),
            _buildEditArea(),
            const SizedBox(height: 8),
            _buildUserAndSave(),
            const Divider(height: 24),
            _buildMembersTable(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  int _firstEmptyIndex() {
    for (int i = 0; i < _vehicleCount; i++) {
      if (_images[i] == null) return i;
    }
    return 0;
  }

  Widget _buildIntro() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.brown[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.brown.shade200),
      ),
      child: Text(
        _t(
          '为每个帮派成员上传 3 张车辆属性图（右上角选图，自动依次放入），自动识别 HP/ATK，输入用户 ID 后存档合并到下方表格。',
          'Upload 3 vehicle stat screenshots per member (pick via top-right, auto-filled in order), HP/ATK auto-detected. Enter user ID and save to the table below.',
        ),
        style: TextStyle(fontSize: 12, color: Colors.brown[800]),
      ),
    );
  }

  /// 三张图紧密叠放
  Widget _buildImagesArea() {
    return Column(
      children: [
        for (int i = 0; i < _vehicleCount; i++) ...[
          _buildImageTile(i),
          if (i < _vehicleCount - 1) const SizedBox(height: 4),
        ],
      ],
    );
  }

  /// 单张车辆图（含标题行与图片，供紧密叠放）
  Widget _buildImageTile(int index) {
    final image = _images[index];
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 6),
              Icon(Icons.directions_car, size: 16, color: _vehicleColor(index)),
              const SizedBox(width: 4),
              Text(
                _t('车辆 ${index + 1}', 'Vehicle ${index + 1}'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _vehicleColor(index),
                ),
              ),
              const Spacer(),
              if (image != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh, size: 16),
                  tooltip: _t('重新识别', 'Re-detect'),
                  onPressed: _processing[index]
                      ? null
                      : () => _recognize(index),
                ),
              const SizedBox(width: 4),
            ],
          ),
          if (image == null)
            InkWell(
              onTap: () => _showPickOptions(index),
              child: Container(
                width: double.infinity,
                height: 56,
                alignment: Alignment.center,
                child: Text(
                  _t('点击选择车辆 ${index + 1} 图片', 'Pick vehicle ${index + 1} image'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            )
          else
            _buildImagePreview(index),
        ],
      ),
    );
  }

  /// 集中修改识别数据（三辆车 HP/ATK）
  Widget _buildEditArea() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('修改识别数据', 'Edit recognized data'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _vehicleCount; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      _t('车辆${i + 1}', 'V${i + 1}'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _vehicleColor(i),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _hpCtrl[i],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'HP',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _atkCtrl[i],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'ATK',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(int index) {
    final image = _images[index]!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dispW = constraints.maxWidth;
        final dispH = 140.0;
        return GestureDetector(
          onTap: () => _showPickOptions(index),
          child: Container(
            height: dispH,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(image, fit: BoxFit.contain),
                  if (_processing[index])
                    Container(
                      color: Colors.black26,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    ),
                  if (_showOverlay && _textItems[index].isNotEmpty)
                    CustomPaint(
                      painter: OcrBoxPainter(
                        items: _textItems[index],
                        imageWidth: _imgW[index],
                        imageHeight: _imgH[index],
                        displayWidth: dispW,
                        displayHeight: dispH,
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

  Widget _buildUserAndSave() {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.teal[50],
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('用户 ID（该账号的三辆车）', 'User ID (this account\'s 3 vehicles)'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _userIdCtrl,
                    decoration: InputDecoration(
                      hintText: _t('输入用户 ID', 'Enter user ID'),
                      prefixIcon: const Icon(Icons.person, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _saveMember,
                  icon: const Icon(Icons.save_alt, size: 18),
                  label: Text(_t('合并', 'Merge')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 表格 ====================
  Widget _buildMembersTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('帮派成员车辆统计表', 'Gang Member Stats'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        if (_members.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _t('暂无存档数据，录入后自动显示', 'No data yet. Save to add.'),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          )
        else
          SingleChildScrollView(
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
                for (int i = 0; i < _vehicleCount; i++) ...[
                  DataColumn(
                    label: Text(
                      _t('车${i + 1}HP', 'C${i + 1}HP'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      _t('车${i + 1}ATK', 'C${i + 1}ATK'),
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
                DataColumn(
                  label: Text(
                    _t('操作', 'Op'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: [
                for (int i = 0; i < _members.length; i++)
                  DataRow(
                    cells: [
                      DataCell(Text(_members[i].userId)),
                      for (int v = 0; v < _vehicleCount; v++) ...[
                        DataCell(Text(_fmtOrDash(_members[i].hp[v]))),
                        DataCell(Text(_fmtOrDash(_members[i].atk[v]))),
                      ],
                      DataCell(Text(_formatNum(_members[i].totalHp))),
                      DataCell(Text(_formatNum(_members[i].totalAtk))),
                      DataCell(
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: Colors.red,
                          onPressed: () => _removeMember(i),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
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
