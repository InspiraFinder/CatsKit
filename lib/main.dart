import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import 'parts_data.dart';
import 'time_calc_screen.dart';

const String appVersion = '0.6.3';

/// 获取部件在当前语言下的显示名称
String pn(PartData part, String? locale) {
  if (locale == 'zh' && part.nameZh.isNotEmpty) return part.nameZh;
  if (locale == 'ja' && part.nameJa.isNotEmpty) return part.nameJa;
  return part.name;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _appLocale = 'zh';

  void _onLocaleChanged(String newLocale) {
    setState(() => _appLocale = newLocale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CatsKit',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: MainMenuScreen(
        locale: _appLocale,
        onLocaleChanged: _onLocaleChanged,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final String locale;
  const MainScreen({super.key, this.locale = 'zh'});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<String> boxTexts = List<String>.filled(25, '');
  List<String> boxButtonNumbers = List<String>.filled(25, '');
  int selectedButton = 0;
  bool isClearMode = false;
  late String _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.locale;
  }

  bool _showSnackBar = false; // 默认不显示提示
  String githubUpdateUrl = 'https://github.com/InspiraFinder/CatsKit/releases';
  String _mirrorUrl = '';

  String _t(String zh, String en) => _locale == 'zh' ? zh : en;

  // 条件显示 SnackBar
  void _showMessage(String zhMsg, String enMsg) {
    if (_showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(zhMsg, enMsg)),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  // 统计出现次数
  Map<String, dynamic> _getStatistics() {
    Map<int, int> counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
    for (String numbers in boxButtonNumbers) {
      for (int i = 0; i < numbers.length; i++) {
        int digit = int.tryParse(numbers[i]) ?? 0;
        if (digit >= 1 && digit <= 6) {
          counts[digit] = counts[digit]! + 1;
        }
      }
    }
    int total = counts.values.fold(0, (sum, value) => sum + value);
    return {'counts': counts, 'total': total};
  }

  @override
  Widget build(BuildContext context) {
    var stats = _getStatistics();
    Map<int, int> counts = stats['counts'];
    int total = stats['total'];

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('查车工具', 'Vehicle Check')),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, {'locale': _locale}),
          tooltip: _t('返回主菜单', 'Back to Menu'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _buildGridBoxes(),
              const SizedBox(height: 15),
              _buildButtonRow(),
              const SizedBox(height: 15),
              _buildActionRow(),
              const SizedBox(height: 12),
              _buildStatistics(counts, total),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridBoxes() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          childAspectRatio: 1.0,
          crossAxisSpacing: 4.0,
          mainAxisSpacing: 4.0,
        ),
        itemCount: 25,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _onGridBoxPressed(index),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1),
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[200],
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        boxTexts[index].isNotEmpty
                            ? boxTexts[index]
                            : '${index + 1}',
                        style: TextStyle(
                          fontSize: boxTexts[index].isNotEmpty ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: boxTexts[index].isNotEmpty
                              ? Colors.black
                              : Colors.grey,
                        ),
                        maxLines: 3,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        boxButtonNumbers[index],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildButtonRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        int buttonNumber = index + 1;
        bool isSelected = selectedButton == buttonNumber;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: ElevatedButton(
              onPressed: () => _onButtonPressed(buttonNumber),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 24),
                backgroundColor: isSelected ? Colors.blue[900] : Colors.blue,
                foregroundColor: Colors.white,
                elevation: isSelected ? 8 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                'P$buttonNumber',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.yellow : Colors.white,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionRow() {
    return IntrinsicHeight(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: ElevatedButton(
                onPressed: _onImportPressed,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 8,
                  ),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _t('导入', 'Import'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: ElevatedButton(
                onPressed: _toggleClearMode,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 8,
                  ),
                  backgroundColor: isClearMode
                      ? Colors.orange[800]
                      : Colors.grey,
                  foregroundColor: Colors.white,
                  elevation: isClearMode ? 8 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isClearMode ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  isClearMode
                      ? (_locale == 'zh' ? '清除模式\n(开)' : 'Clear\nMode ON')
                      : (_locale == 'zh' ? '清除模式\n(关)' : 'Clear\nMode OFF'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: ElevatedButton(
                onPressed: _clearAllNumbers,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 8,
                  ),
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _t('清除全部', 'Clear All'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(Map<int, int> counts, int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_t('总数量', 'Total')}: $total',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: List.generate(6, (index) {
              int num = index + 1;
              return Text(
                'P$num: ${counts[num]}',
                style: const TextStyle(fontSize: 15),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _onButtonPressed(int buttonNumber) {
    if (isClearMode) {
      _clearMatchingNumbers(buttonNumber);
    } else {
      _toggleButton(buttonNumber);
    }
  }

  void _clearMatchingNumbers(int buttonNumber) {
    String digit = buttonNumber.toString();
    bool anyCleared = false;
    setState(() {
      for (int i = 0; i < boxButtonNumbers.length; i++) {
        String old = boxButtonNumbers[i];
        if (old.contains(digit)) {
          boxButtonNumbers[i] = old.replaceAll(digit, '');
          anyCleared = true;
        }
      }
    });
    if (anyCleared) {
      _showMessage(
        '已清除所有方框中的数字 $buttonNumber',
        'Cleared all boxes containing number $buttonNumber',
      );
    } else {
      _showMessage(
        '没有找到包含数字 $buttonNumber 的方框',
        'No boxes found containing number $buttonNumber',
      );
    }
  }

  void _toggleButton(int buttonNumber) {
    setState(() {
      selectedButton = (selectedButton == buttonNumber) ? 0 : buttonNumber;
    });
    if (selectedButton == 0) {
      _showMessage('已取消选择', 'Deselected');
    } else {
      _showMessage(
        '已选择按钮 P$selectedButton，现在可以点击方框',
        'Selected P$selectedButton, tap a box to add',
      );
    }
  }

  void _toggleClearMode() {
    setState(() {
      isClearMode = !isClearMode;
      if (isClearMode) selectedButton = 0;
    });
    if (isClearMode) {
      _showMessage(
        '清除模式已开启，点击方框清除数字，点击 P1-P6 清除所有对应的数字',
        'Clear mode ON: tap box to clear, tap P1-P6 to clear matching numbers',
      );
    } else {
      _showMessage('清除模式已关闭', 'Clear mode OFF');
    }
  }

  void _clearAllNumbers() {
    setState(() {
      for (int i = 0; i < boxButtonNumbers.length; i++)
        boxButtonNumbers[i] = '';
    });
    _showMessage('已清除所有方框下方的数字', 'Cleared all numbers below boxes');
  }

  void _onGridBoxPressed(int boxIndex) {
    if (isClearMode) {
      setState(() {
        if (boxButtonNumbers[boxIndex].isNotEmpty) {
          boxButtonNumbers[boxIndex] = '';
          _showMessage(
            '已清除方框 ${boxIndex + 1} 下方的数字',
            'Cleared number of box ${boxIndex + 1}',
          );
        } else {
          _showMessage(
            '方框 ${boxIndex + 1} 下方本来就没有数字',
            'Box ${boxIndex + 1} already has no number',
          );
        }
      });
      return;
    }

    if (selectedButton == 0) {
      _showMessage('请先选择一个按钮（P1-P6）', 'Please select a button first (P1-P6)');
      return;
    }

    setState(() {
      String current = boxButtonNumbers[boxIndex];
      boxButtonNumbers[boxIndex] = (current.length < 3)
          ? current + selectedButton.toString()
          : selectedButton.toString();
    });
    _showMessage(
      '已向方框 ${boxIndex + 1} 添加按钮 $selectedButton，当前: ${boxButtonNumbers[boxIndex]}',
      'Added button $selectedButton to box ${boxIndex + 1}, now: ${boxButtonNumbers[boxIndex]}',
    );
  }

  void _onImportPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImportScreen(
          initialBoxTexts: boxTexts,
          onImportConfirmed: (updatedTexts) =>
              setState(() => boxTexts = updatedTexts),
        ),
      ),
    );
  }

  void _openSettings() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          currentLocale: _locale,
          currentShowSnackBar: _showSnackBar,
          currentGithubUpdateUrl: githubUpdateUrl,
          currentMirrorUrl: _mirrorUrl,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _locale = result['locale'];
        _showSnackBar = result['showSnackBar'];
        githubUpdateUrl = result['githubUpdateUrl'] ?? githubUpdateUrl;
        _mirrorUrl = result['mirrorUrl'] ?? _mirrorUrl;
      });
      _showMessage('语言已切换', 'Language changed');
    }
  }
}

// ==================== 主菜单 ====================
class MainMenuScreen extends StatefulWidget {
  final String locale;
  final ValueChanged<String>? onLocaleChanged;
  const MainMenuScreen({super.key, this.locale = 'zh', this.onLocaleChanged});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  late String _locale;

  String _t(String zh, String en) => _locale == 'zh' ? zh : en;

  @override
  void initState() {
    super.initState();
    _locale = widget.locale;
  }

  @override
  void didUpdateWidget(MainMenuScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locale != oldWidget.locale) {
      _locale = widget.locale;
    }
  }

  /// 导航到子页面，返回时检查语言是否变更
  Future<void> _navigateAndAwaitLocale(Widget screen) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (result != null && result['locale'] != null && mounted) {
      final newLocale = result['locale'] as String;
      if (newLocale != _locale) {
        setState(() => _locale = newLocale);
        widget.onLocaleChanged?.call(newLocale);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CatsKit'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_car, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'CatsKit',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _t('工具集', 'Toolkit'),
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 48),
              _buildMenuItem(
                context,
                icon: Icons.search,
                label: _t('查车工具', 'Vehicle Check'),
                color: Colors.blue,
                onTap: () =>
                    _navigateAndAwaitLocale(MainScreen(locale: _locale)),
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                context,
                icon: Icons.build,
                label: _t('组车工具', 'Build Tool'),
                color: Colors.orange,
                onTap: () =>
                    _navigateAndAwaitLocale(BuildToolScreen(locale: _locale)),
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                context,
                icon: Icons.timer,
                label: _t('时间计算', 'Timer'),
                color: Colors.purple,
                onTap: () =>
                    _navigateAndAwaitLocale(TimeCalcScreen(locale: _locale)),
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                context,
                icon: Icons.settings,
                label: _t('通用设置', 'Settings'),
                color: Colors.green,
                onTap: () => _navigateAndAwaitLocale(
                  SettingsScreen(
                    currentLocale: _locale,
                    currentShowSnackBar: false,
                    currentGithubUpdateUrl:
                        'https://github.com/InspiraFinder/CatsKit/releases',
                    currentMirrorUrl: '',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 组车工具 ====================
class BuildToolScreen extends StatefulWidget {
  final String locale;
  const BuildToolScreen({super.key, this.locale = 'zh'});

  @override
  State<BuildToolScreen> createState() => _BuildToolScreenState();
}

/// 单个组车区的数据
class _VehicleBuild {
  PartData? body;
  final weapons = <PartData>[];
  final wheels = <PartData>[];
  final gadgets = <PartData>[];

  /// 该车辆中是否使用了指定部件
  bool usesPart(PartData p) =>
      body?.id == p.id ||
      weapons.any((x) => x.id == p.id) ||
      wheels.any((x) => x.id == p.id) ||
      gadgets.any((x) => x.id == p.id);

  void clear() {
    body = null;
    weapons.clear();
    wheels.clear();
    gadgets.clear();
  }
}

class _BuildToolScreenState extends State<BuildToolScreen> {
  bool _isAssemblyMode = true;
  bool _showImages = false;
  bool _isFilterMode = true;
  int _gridColumns = 3;
  final PartCategory _selectedCategory = PartCategory.body;
  final Set<PartCategory> _selectedCategories = {};
  final Set<Rarity> _selectedRarities = {};
  final TextEditingController _searchController = TextEditingController();
  final List<_VehicleBuild> _vehicles = [_VehicleBuild()];
  int _activeIndex = 0;
  final Map<String, int> _partLevels = {};

  _VehicleBuild get _activeVehicle => _vehicles[_activeIndex];
  CarValidation _validation = CarValidation.empty();

  void _recalc() {
    _validation = CarValidation.compute(
      _activeVehicle.body,
      _activeVehicle.weapons,
      _activeVehicle.wheels,
      _activeVehicle.gadgets,
      _partLevels,
    );
  }

  int _level(PartData p) => _partLevels[p.id] ?? 1;

  String _t(String zh, String en) => widget.locale == 'zh' ? zh : en;

  /// 检查部件是否已被任意车辆使用
  bool _isPartUsedAnywhere(PartData part) =>
      _vehicles.any((v) => v.usesPart(part));

  /// 新增车辆
  void _addVehicle() {
    setState(() {
      _vehicles.add(_VehicleBuild());
      _activeIndex = _vehicles.length - 1;
    });
  }

  /// 删除车辆（至少保留一辆）
  void _removeVehicle(int index) {
    if (_vehicles.length <= 1) return;
    setState(() {
      // 清理被删车辆中部件记录的等级
      final v = _vehicles[index];
      for (final p in [v.body, ...v.weapons, ...v.wheels, ...v.gadgets]) {
        if (p != null) _partLevels.remove(p.id);
      }
      _vehicles.removeAt(index);
      if (_activeIndex >= _vehicles.length) {
        _activeIndex = _vehicles.length - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _recalc();
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('组车工具', 'Build Tool')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _showImages ? Icons.image : Icons.text_fields,
              color: _showImages ? Colors.orange : null,
            ),
            onPressed: () => setState(() => _showImages = !_showImages),
            tooltip: _showImages ? _t('文字模式', 'Text') : _t('图片模式', 'Image'),
          ),
          PopupMenuButton<int>(
            icon: Icon(Icons.grid_view, size: 20),
            tooltip: _t('每行数量', 'Columns'),
            onSelected: (v) => setState(() => _gridColumns = v),
            itemBuilder: (_) => [2, 3, 4, 5]
                .map(
                  (n) => PopupMenuItem(
                    value: n,
                    child: Text(
                      n == _gridColumns ? '$_gridColumns ✓' : '$n',
                      style: TextStyle(
                        fontWeight: n == _gridColumns
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                )
                .toList(),
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
          children: [
            _buildAssemblyArea(),
            _buildButtonRow(),
            const Divider(height: 1),
            _buildPartsSelector(),
          ],
        ),
      ),
    );
  }

  // ==================== 组车区 ====================
  Widget _buildAssemblyArea() {
    return Column(
      children: [
        for (int i = 0; i < _vehicles.length; i++) ...[
          _buildSingleVehicleArea(_vehicles[i], i),
          if (_isAssemblyMode && i < _vehicles.length - 1)
            const Divider(height: 8),
        ],
      ],
    );
  }

  Widget _buildSingleVehicleArea(_VehicleBuild vh, int vi) {
    final v = vi == _activeIndex
        ? _validation
        : CarValidation.compute(
            vh.body,
            vh.weapons,
            vh.wheels,
            vh.gadgets,
            _partLevels,
          );
    final powerOk = v.powerSupply >= v.powerConsumption;
    final isActive = vi == _activeIndex;
    return GestureDetector(
      onTap: () => setState(() => _activeIndex = vi),
      child: Container(
        padding: const EdgeInsets.all(6),
        color: isActive
            ? Colors.blue[50]
            : _isAssemblyMode
            ? Colors.grey[100]
            : Colors.teal[50],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // —— 删除按钮（数据查询模式隐藏） ——
            if (_isAssemblyMode && _vehicles.length > 1)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.red,
                  ),
                  label: Text(
                    _t('删除组车区', 'Delete'),
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                  onPressed: () => _removeVehicle(vi),
                ),
              ),
            // ---- 状态行 ----
            Row(
              children: [
                Icon(
                  v.ok ? Icons.check_circle : Icons.error,
                  size: 16,
                  color: v.ok ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    v.error.isNotEmpty ? v.error : _t('状态 OK', 'OK'),
                    style: TextStyle(
                      fontSize: 12,
                      color: v.ok ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // ---- 属性行 ----
            Row(
              children: [
                _statChip('HP', '${v.hp.floor()}', Colors.blue),
                const SizedBox(width: 4),
                _statChip('ATK', '${v.atk.floor()}', Colors.red),
                const SizedBox(width: 4),
                _statChip(
                  _t('电力', 'PWR'),
                  '${v.powerConsumption}/${v.powerSupply}',
                  powerOk ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // ---- 插槽与加成行 ----
            Row(
              children: [
                _statChip(
                  _t('插槽', 'Slots'),
                  '${_t('武器', 'Wpn')}${v.numWeapons}/${v.numWeaponSlots} ${_t('车轮', 'Whl')}${v.numWheels}/${v.numWheelSlots} ${_t('配件', 'Gad')}${v.numGadgets}/${v.numGadgetSlots}',
                  Colors.grey,
                ),
              ],
            ),
            if (v.bodyBonusPct > 0 ||
                v.weaponBonusPct > 0 ||
                v.wheelBonusPct > 0 ||
                v.gadgetBonusPct > 0 ||
                v.sponsorBonusPct > 0) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  if (v.bodyBonusPct > 0)
                    _statChip(
                      '${_t('车身', 'Body')}+${v.bodyBonusPct}%',
                      '',
                      Colors.orange,
                    ),
                  if (v.weaponBonusPct > 0) ...[
                    const SizedBox(width: 4),
                    _statChip(
                      '${_t('武器', 'Weapon')}+${v.weaponBonusPct}%',
                      '',
                      Colors.red,
                    ),
                  ],
                  if (v.wheelBonusPct > 0) ...[
                    const SizedBox(width: 4),
                    _statChip(
                      '${_t('车轮', 'Wheel')}+${v.wheelBonusPct}%',
                      '',
                      Colors.green,
                    ),
                  ],
                  if (v.gadgetBonusPct > 0) ...[
                    const SizedBox(width: 4),
                    _statChip(
                      '${_t('配件', 'Gadget')}+${v.gadgetBonusPct}%',
                      '',
                      Colors.purple,
                    ),
                  ],
                  if (v.sponsorBonusPct > 0) ...[
                    const SizedBox(width: 4),
                    _statChip(
                      '${_t('赞助', 'Sponsor')}+${v.sponsorBonusPct}%',
                      '',
                      Colors.teal,
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 6),
            // ---- 插槽行 ----
            LayoutBuilder(
              builder: (context, constraints) {
                final totalSlots =
                    1 + v.numWeaponSlots + v.numWheelSlots + v.numGadgetSlots;
                final slotWidth =
                    ((constraints.maxWidth - 6 * totalSlots) / totalSlots)
                        .clamp(70.0, 120.0);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSlot(
                        _t('车身', 'Body'),
                        vh.body,
                        Colors.orange,
                        () => setState(() => vh.body = null),
                        slotWidth,
                      ),
                      const SizedBox(width: 6),
                      ...List.generate(
                        v.numWeaponSlots,
                        (i) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _buildSlot(
                            '${_t('武', 'Wpn')}${i + 1}',
                            i < vh.weapons.length ? vh.weapons[i] : null,
                            Colors.red,
                            () {
                              if (i < vh.weapons.length)
                                setState(() => vh.weapons.removeAt(i));
                            },
                            slotWidth,
                          ),
                        ),
                      ),
                      ...List.generate(
                        v.numWheelSlots,
                        (i) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _buildSlot(
                            '${_t('轮', 'Whl')}${i + 1}',
                            i < vh.wheels.length ? vh.wheels[i] : null,
                            Colors.green,
                            () {
                              if (i < vh.wheels.length)
                                setState(() => vh.wheels.removeAt(i));
                            },
                            slotWidth,
                          ),
                        ),
                      ),
                      ...List.generate(
                        v.numGadgetSlots,
                        (i) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _buildSlot(
                            '${_t('配', 'Gad')}${i + 1}',
                            i < vh.gadgets.length ? vh.gadgets[i] : null,
                            Colors.purple,
                            () {
                              if (i < vh.gadgets.length)
                                setState(() => vh.gadgets.removeAt(i));
                            },
                            slotWidth,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label${value.isNotEmpty ? ' $value' : ''}',
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSlot(
    String label,
    PartData? part,
    Color color,
    VoidCallback onRemove,
    double w,
  ) {
    return GestureDetector(
      onTap: part != null ? onRemove : null,
      child: Container(
        width: w,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: part != null ? 2 : 1),
          borderRadius: BorderRadius.circular(6),
          color: part != null ? color.withValues(alpha: 0.15) : Colors.white,
        ),
        child: part != null
            ? _buildSlotContent(part, color)
            : Center(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ),
      ),
    );
  }

  Widget _buildSlotContent(PartData part, Color color) {
    final lv = _level(part);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          pn(part, widget.locale),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'Lv$lv HP${part.hp(lv).floor()} ATK${part.atk(lv).floor()}',
          style: TextStyle(fontSize: 8, color: Colors.grey[700]),
        ),
        SizedBox(
          width: 60,
          height: 18,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: lv.clamp(1, part.maxLevel),
              isDense: true,
              isExpanded: true,
              style: const TextStyle(fontSize: 10, color: Colors.black),
              items: List.generate(
                part.maxLevel,
                (i) =>
                    DropdownMenuItem(value: i + 1, child: Text('Lv${i + 1}')),
              ),
              onChanged: (v) => setState(() => _partLevels[part.id] = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButtonRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () =>
                  setState(() => _isAssemblyMode = !_isAssemblyMode),
              icon: Icon(
                _isAssemblyMode ? Icons.handyman : Icons.bar_chart,
                size: 20,
              ),
              label: Text(
                _isAssemblyMode ? _t('组车', 'Build') : _t('数据查询', 'Browse'),
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _isFilterMode = !_isFilterMode),
              icon: Icon(
                _isFilterMode ? Icons.filter_list : Icons.search,
                size: 20,
              ),
              label: Text(
                _isFilterMode ? _t('筛选', 'Filter') : _t('搜索', 'Search'),
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFilterMode ? Colors.orange : Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isAssemblyMode ? _addVehicle : null,
              icon: const Icon(Icons.add, size: 20),
              label: Text(
                _t('新增车辆', 'Add Car'),
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAssemblyMode ? Colors.green : Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 部件备选区 ====================
  Widget _buildPartsSelector() {
    // 根据当前模式筛选部件
    List<PartData> parts;
    if (_isFilterMode) {
      // 筛选模式：按分类 + 稀有度筛选
      parts = PartDatabase.allParts.where((p) {
        if (_selectedCategories.isNotEmpty &&
            !_selectedCategories.contains(p.category))
          return false;
        if (_selectedRarities.isNotEmpty &&
            !_selectedRarities.contains(p.rarity))
          return false;
        return true;
      }).toList();
    } else {
      // 搜索模式：按文字搜索（部件名/ID）
      final q = _searchController.text.trim().toLowerCase();
      if (q.isEmpty) {
        parts = PartDatabase.allParts;
      } else {
        parts = PartDatabase.allParts.where((p) {
          return p.id.toLowerCase().contains(q) ||
              p.name.toLowerCase().contains(q) ||
              p.nameZh.contains(q) ||
              p.nameJa.contains(q);
        }).toList();
      }
    }

    return Column(
      children: [
        // ---- 筛选/搜索控件 ----
        if (_isFilterMode) _buildFilterChips() else _buildSearchBar(),
        // ---- 网格 ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _gridColumns,
              childAspectRatio: 1.0,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: parts.length,
            itemBuilder: (_, i) => _buildPartCard(parts[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Column(
      children: [
        // 分类筛选
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: PartCategory.values.map((cat) {
                final labels = {
                  PartCategory.body: _t('车身', 'Body'),
                  PartCategory.weapon: _t('武器', 'Weapon'),
                  PartCategory.wheel: _t('车轮', 'Wheel'),
                  PartCategory.gadget: _t('配件', 'Gadget'),
                };
                const icons = {
                  PartCategory.body: Icons.directions_car,
                  PartCategory.weapon: Icons.gps_fixed,
                  PartCategory.wheel: Icons.radio_button_checked,
                  PartCategory.gadget: Icons.build,
                };
                final selected = _selectedCategories.contains(cat);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icons[cat]!, size: 16),
                        const SizedBox(width: 4),
                        Text(labels[cat]!),
                      ],
                    ),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedCategories.add(cat);
                      } else {
                        _selectedCategories.remove(cat);
                      }
                    }),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // 稀有度筛选
        Container(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: Rarity.values.map((r) {
                final label = r.name.toUpperCase();
                final selected = _selectedRarities.contains(r);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedRarities.add(r);
                      } else {
                        _selectedRarities.remove(r);
                      }
                    }),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: _t('搜索部件名称或ID...', 'Search part name or ID...'),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 12,
          ),
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  /// 赞助商对应的图片资源路径
  String sponsorImage(Sponsor sponsor) {
    switch (sponsor) {
      case Sponsor.mecha:
        return 'assets/images/sp_mecha.png';
      case Sponsor.naturalis:
        return 'assets/images/sp_naturalis.png';
      case Sponsor.gluttony:
        return 'assets/images/sp_gluttony.png';
      case Sponsor.sporty:
      case Sponsor.none:
        return '';
    }
  }

  Widget _buildPartCard(PartData part) {
    final isUsed = _isPartUsedAnywhere(part);
    return GestureDetector(
      onTap: () => _isAssemblyMode ? _tryAddPart(part) : _showPartData(part),
      child: Card(
        color: _isAssemblyMode && isUsed
            ? Colors.green[100]
            : !_isAssemblyMode
            ? Colors.teal[50]
            : null,
        elevation: isUsed ? 4 : 1,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: _showImages
              ? Stack(
                  children: [
                    // 部件图片
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(1),
                        child: Image.asset(
                          'assets/images/${part.id}.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.broken_image,
                                  size: 24,
                                  color: Colors.grey,
                                ),
                                Text(
                                  pn(part, widget.locale),
                                  style: const TextStyle(fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 赞助商标识（左下角）
                    if (part.sponsor != Sponsor.none)
                      Positioned(
                        left: 2,
                        bottom: 2,
                        child: Image.asset(
                          sponsorImage(part.sponsor),
                          width: 20,
                          height: 20,
                        ),
                      ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      pn(part, widget.locale),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (part.hp1 > 0)
                      Text(
                        'HP ${part.hp1}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                      ),
                    if (part.atk1 > 0)
                      Text(
                        'ATK ${part.atk1}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                      ),
                    if (part.bonus != null)
                      Text(
                        part.bonusLabelEn(widget.locale),
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.orange[800],
                        ),
                      ),
                    if (!_isAssemblyMode)
                      const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.teal,
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  void _tryAddPart(PartData part) {
    setState(() {
      final v = _activeVehicle;

      // 如果已被其他车辆使用 → 先移除
      for (final other in _vehicles) {
        if (other == v) continue;
        if (other.body?.id == part.id) other.body = null;
        other.weapons.removeWhere((p) => p.id == part.id);
        other.wheels.removeWhere((p) => p.id == part.id);
        other.gadgets.removeWhere((p) => p.id == part.id);
      }

      switch (part.category) {
        case PartCategory.body:
          if (v.body?.id == part.id) {
            v.clear();
            _partLevels.remove(part.id);
          } else {
            v.clear();
            v.body = part;
            _partLevels[part.id] ??= 1;
          }
        case PartCategory.weapon:
          if (v.weapons.any((p) => p.id == part.id)) {
            v.weapons.removeWhere((p) => p.id == part.id);
            _partLevels.remove(part.id);
          } else {
            v.weapons.add(part);
            _partLevels[part.id] ??= 1;
          }
        case PartCategory.wheel:
          if (v.wheels.any((p) => p.id == part.id)) {
            v.wheels.removeWhere((p) => p.id == part.id);
            _partLevels.remove(part.id);
          } else {
            v.wheels.add(part);
            _partLevels[part.id] ??= 1;
          }
        case PartCategory.gadget:
          if (v.gadgets.any((p) => p.id == part.id)) {
            v.gadgets.removeWhere((p) => p.id == part.id);
            _partLevels.remove(part.id);
          } else {
            v.gadgets.add(part);
            _partLevels[part.id] ??= 1;
          }
      }
    });
  }

  void _showPartData(PartData part) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PartDataScreen(part: part, locale: widget.locale),
      ),
    );
  }
}

// ==================== Navimoe 验证逻辑 ====================
class CarValidation {
  final bool ok;
  final String error;
  final double hp;
  final double atk;
  final int powerSupply;
  final int powerConsumption;
  final int numBodies;
  final int numWeapons;
  final int numWheels;
  final int numGadgets;
  final int numBodySlots;
  final int numWeaponSlots;
  final int numWheelSlots;
  final int numGadgetSlots;
  final int bodyBonusPct;
  final int weaponBonusPct;
  final int wheelBonusPct;
  final int gadgetBonusPct;
  final int sponsorBonusPct;

  const CarValidation({
    required this.ok,
    required this.error,
    required this.hp,
    required this.atk,
    required this.powerSupply,
    required this.powerConsumption,
    required this.numBodies,
    required this.numWeapons,
    required this.numWheels,
    required this.numGadgets,
    required this.numBodySlots,
    required this.numWeaponSlots,
    required this.numWheelSlots,
    required this.numGadgetSlots,
    required this.bodyBonusPct,
    required this.weaponBonusPct,
    required this.wheelBonusPct,
    required this.gadgetBonusPct,
    required this.sponsorBonusPct,
  });

  factory CarValidation.empty() => CarValidation(
    ok: true,
    error: '',
    hp: 0,
    atk: 0,
    powerSupply: 0,
    powerConsumption: 0,
    numBodies: 0,
    numWeapons: 0,
    numWheels: 0,
    numGadgets: 0,
    numBodySlots: 0,
    numWeaponSlots: 0,
    numWheelSlots: 0,
    numGadgetSlots: 0,
    bodyBonusPct: 0,
    weaponBonusPct: 0,
    wheelBonusPct: 0,
    gadgetBonusPct: 0,
    sponsorBonusPct: 0,
  );

  factory CarValidation.compute(
    PartData? body,
    List<PartData> weapons,
    List<PartData> wheels,
    List<PartData> gadgets,
    Map<String, int> levels,
  ) {
    final allParts = <PartData>[];
    if (body != null) allParts.add(body);
    allParts.addAll(weapons);
    allParts.addAll(wheels);
    allParts.addAll(gadgets);

    int lv(PartData p) => (levels[p.id] ?? 1).clamp(1, p.maxLevel);

    // Slot limits from body
    final numBodies = body != null ? 1 : 0;
    final numWeapons = weapons.length;
    final numWheels = wheels.length;
    final numGadgets = gadgets.length;
    final numBodySlots = 1;
    final numWeaponSlots = body?.slots?.weapon ?? 0;
    final numWheelSlots = body?.slots?.wheel ?? 0;
    final numGadgetSlots = body?.slots?.gadget ?? 0;

    // Power
    final powerSupply = allParts.fold(
      0,
      (s, p) => s + (p.power > 0 ? p.power : 0),
    );
    final powerConsumption = allParts.fold(
      0,
      (s, p) => s + (p.power < 0 ? -p.power : 0),
    );

    // Bonuses
    final bodyBonusPct = allParts.fold(
      0,
      (s, p) =>
          s + (p.bonus?.category == PartCategory.body ? p.bonus!.percent : 0),
    );
    final weaponBonusPct = allParts.fold(
      0,
      (s, p) =>
          s + (p.bonus?.category == PartCategory.weapon ? p.bonus!.percent : 0),
    );
    final wheelBonusPct = allParts.fold(
      0,
      (s, p) =>
          s + (p.bonus?.category == PartCategory.wheel ? p.bonus!.percent : 0),
    );
    final gadgetBonusPct = allParts.fold(
      0,
      (s, p) =>
          s + (p.bonus?.category == PartCategory.gadget ? p.bonus!.percent : 0),
    );

    // Sponsor bonus: 3+ same sponsor → 10% + (count-3)*5%
    final sponsorCounts = <Sponsor, int>{};
    for (final p in allParts)
      if (p.sponsor != Sponsor.none)
        sponsorCounts[p.sponsor] = (sponsorCounts[p.sponsor] ?? 0) + 1;
    int sponsorBonusPct = 0;
    for (final cnt in sponsorCounts.values) {
      if (cnt >= 3) sponsorBonusPct += 10 + (cnt - 3) * 5;
    }

    // HP: bodyHp*(1+bodyBonus/100) + wheelHp*(1+wheelBonus/100) + gadgetHp*(1+gadgetBonus/100)
    double bodyHp = 0, wheelHp = 0, gadgetHp = 0, weaponAtk = 0, wheelAtk = 0;
    for (final p in allParts) {
      final hp = p.hp(lv(p));
      final atk = p.atk(lv(p));
      if (p.category == PartCategory.body) bodyHp += hp;
      if (p.category == PartCategory.wheel) {
        wheelHp += hp;
        wheelAtk += atk;
      }
      if (p.category == PartCategory.gadget) gadgetHp += hp;
      if (p.category == PartCategory.weapon) weaponAtk += atk;
    }
    double hp =
        bodyHp * (1 + bodyBonusPct / 100.0) +
        wheelHp * (1 + wheelBonusPct / 100.0) +
        gadgetHp * (1 + gadgetBonusPct / 100.0);
    double atk =
        weaponAtk * (1 + weaponBonusPct / 100.0) +
        wheelAtk * (1 + wheelBonusPct / 100.0);
    hp *= 1 + sponsorBonusPct / 100.0;
    atk *= 1 + sponsorBonusPct / 100.0;

    // Validation
    String error = '';
    if (numBodies == 0)
      error = '缺少车身';
    else if (numBodies > 1)
      error = '车身过多';
    else {
      if (numWeapons > numWeaponSlots)
        error = '武器过多 ($numWeapons/$numWeaponSlots)';
      else if (numWheels > numWheelSlots)
        error = '车轮过多 ($numWheels/$numWheelSlots)';
      else if (numGadgets > numGadgetSlots)
        error = '配件过多 ($numGadgets/$numGadgetSlots)';
      else if (powerConsumption > powerSupply)
        error = '电力不足 ($powerConsumption/$powerSupply)';
    }
    final ok = error.isEmpty;

    return CarValidation(
      ok: ok,
      error: error,
      hp: hp,
      atk: atk,
      powerSupply: powerSupply,
      powerConsumption: powerConsumption,
      numBodies: numBodies,
      numWeapons: numWeapons,
      numWheels: numWheels,
      numGadgets: numGadgets,
      numBodySlots: numBodySlots,
      numWeaponSlots: numWeaponSlots,
      numWheelSlots: numWheelSlots,
      numGadgetSlots: numGadgetSlots,
      bodyBonusPct: bodyBonusPct,
      weaponBonusPct: weaponBonusPct,
      wheelBonusPct: wheelBonusPct,
      gadgetBonusPct: gadgetBonusPct,
      sponsorBonusPct: sponsorBonusPct,
    );
  }
}

// ==================== 部件数据展示界面 ====================
class _PartDataScreen extends StatelessWidget {
  final PartData part;
  final String locale;
  const _PartDataScreen({required this.part, this.locale = 'zh'});

  @override
  Widget build(BuildContext context) {
    String t(String zh, String en) => locale == 'zh' ? zh : en;
    return Scaffold(
      appBar: AppBar(title: Text(pn(part, locale)), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ---- 概览卡片 ----
            Card(
              color: _categoryColor(part.category).withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      _categoryIcon(part.category),
                      size: 40,
                      color: _categoryColor(part.category),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pn(part, locale),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${part.categoryLabelEn(locale)} · ${part.rarityLabel} · ${part.sponsorLabel.isNotEmpty ? part.sponsorLabel : t('无赞助', 'None')}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'EN: ${part.name}${part.nameZh.isNotEmpty ? '  ·  ZH: ${part.nameZh}' : ''}${part.nameJa.isNotEmpty ? '  ·  JA: ${part.nameJa}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ---- 基础属性 ----
            if (part.hp1 > 0)
              _chip(t('HP基础', 'Base HP'), part.hp1.toString(), Colors.blue),
            if (part.atk1 > 0)
              _chip(t('ATK基础', 'Base ATK'), part.atk1.toString(), Colors.red),
            _chip(
              t('电力', 'PWR'),
              part.power >= 0 ? '+${part.power}' : part.power.toString(),
              Colors.amber[800]!,
            ),
            if (part.slots != null)
              _chip(t('插槽', 'Slots'), part.slotsLabelEn(locale), Colors.grey),
            if (part.bonus != null)
              _chip(t('加成', 'Bonus'), part.bonusLabelEn(locale), Colors.orange),
            if (part.partClass != PartClass.none)
              _chip(t('类型', 'Class'), part.classLabelEn(locale), Colors.brown),
            if (part.mHp1 > 0)
              _chip(t('随从HP', 'Minion HP'), part.mHp1.toString(), Colors.teal),
            const SizedBox(height: 12),
            // ---- 等级数据 + 升级费用表 ----
            Text(
              t('各等级数据与升级费用', 'Stats & Upgrade Cost by Lv'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 12,
                headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
                columns: [
                  DataColumn(
                    label: Text(
                      'Lv',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (part.hp1 > 0)
                    DataColumn(
                      label: Text(
                        'HP',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (part.atk1 > 0)
                    DataColumn(
                      label: Text(
                        'ATK',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (part.mHp1 > 0)
                    DataColumn(
                      label: Text(
                        locale == 'zh' ? '随从HP' : 'Minion HP',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  DataColumn(
                    label: Text(
                      '碎片',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      '紫票',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      '代币',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale == 'zh' ? '提升/千紫票' : 'Inc./kCash',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale == 'zh' ? '提升/代币' : 'Inc./Token',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: () {
                  final costs = upgradeCosts[part.rarity] ?? [];
                  final rows = <DataRow>[];
                  final hasHp = part.hp1 > 0;
                  final hasAtk = part.atk1 > 0;
                  final hasMhp = part.mHp1 > 0;
                  // 主属性用于计算效率：有HP用HP，否则用ATK
                  double? prevMain;

                  for (int i = 0; i < part.maxLevel; i++) {
                    final lv = i + 1;
                    final hp = hasHp ? part.hp(lv) : 0.0;
                    final atk = hasAtk ? part.atk(lv) : 0.0;
                    final mhp = hasMhp ? part.mHp(lv) : 0.0;
                    final prevHp = hasHp && i > 0 ? part.hp(lv - 1) : 0.0;
                    final prevAtk = hasAtk && i > 0 ? part.atk(lv - 1) : 0.0;
                    final mainStat = hasHp ? hp : atk;
                    final mainInc = prevMain != null ? mainStat - prevMain : 0;
                    final cost = lv < costs.length ? costs[lv] : costs.last;

                    final incPieces = cost.pieces;
                    final incCash = cost.cash;
                    final incToken = cost.token;

                    final incPerKCash = incCash > 0
                        ? (mainInc / incCash * 1000).toStringAsFixed(2)
                        : 'N/A';
                    final incPerToken = incToken > 0
                        ? (mainInc / incToken).toStringAsFixed(2)
                        : 'N/A';

                    final cells = <DataCell>[
                      DataCell(
                        Text(
                          '$lv',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ];

                    // HP 列
                    if (hasHp) {
                      cells.add(
                        DataCell(
                          Text(
                            '${hp.floor()}${i > 0 ? ' (+${(hp - prevHp).floor()})' : ''}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      );
                    }
                    // ATK 列
                    if (hasAtk) {
                      cells.add(
                        DataCell(
                          Text(
                            '${atk.floor()}${i > 0 ? ' (+${(atk - prevAtk).floor()})' : ''}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      );
                    }
                    // 随从HP列
                    if (hasMhp) {
                      cells.add(
                        DataCell(
                          Text(
                            '${mhp.floor()}',
                            style: TextStyle(fontSize: 13, color: Colors.teal),
                          ),
                        ),
                      );
                    }

                    cells.addAll([
                      DataCell(
                        Text(
                          '$incPieces',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      DataCell(
                        Text('$incCash', style: const TextStyle(fontSize: 13)),
                      ),
                      DataCell(
                        Text('$incToken', style: const TextStyle(fontSize: 13)),
                      ),
                      DataCell(
                        Text(
                          incPerKCash,
                          style: TextStyle(
                            fontSize: 12,
                            color: incCash > 0 ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          incPerToken,
                          style: TextStyle(
                            fontSize: 12,
                            color: incToken > 0 ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ]);

                    rows.add(DataRow(cells: cells));
                    prevMain = mainStat;
                  }
                  return rows;
                }(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
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

// ==================== 设置界面 ====================
class SettingsScreen extends StatefulWidget {
  final String currentLocale;
  final bool currentShowSnackBar;
  final String currentGithubUpdateUrl;
  final String currentMirrorUrl;

  const SettingsScreen({
    super.key,
    required this.currentLocale,
    required this.currentShowSnackBar,
    required this.currentGithubUpdateUrl,
    required this.currentMirrorUrl,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String locale;
  late bool showSnackBar;
  late TextEditingController updateUrlController;
  late TextEditingController mirrorController;
  late TextEditingController downloadPathController;
  bool isDownloading = false;
  bool isPaused = false;
  bool isCheckingUpdate = false;
  double downloadProgress = 0;
  String downloadSpeed = '';
  String downloadedSize = '';
  int lastReceivedBytes = 0;
  int lastSpeedTime = 0;
  StreamSubscription? streamSub;
  bool cancelRequested = false;
  HttpClientResponse? downloadResponse;
  int totalDownloadBytes = 0;
  final List<List<int>> downloadChunks = [];
  String downloadedFilePath = '';

  static const List<String> presetMirrors = [
    '',
    'https://ghproxy.com/',
    'https://ghproxy.net/',
    'https://gh-proxy.com/',
    'https://gh.xiu2.xyz/',
    'https://mirror.ghproxy.com/',
  ];

  // 网页工具（非API代理，仅做参考）
  // https://github.ur1.fun/
  // https://github.akams.cn/

  @override
  void initState() {
    super.initState();
    locale = widget.currentLocale;
    showSnackBar = widget.currentShowSnackBar;
    updateUrlController = TextEditingController(
      text: widget.currentGithubUpdateUrl,
    );
    mirrorController = TextEditingController(text: widget.currentMirrorUrl);
    // 初始化下载路径
    final defaultPath = Platform.isAndroid
        ? '${Directory.systemTemp.path}${Platform.pathSeparator}CatsKit'
        : '${Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.current.path}${Platform.pathSeparator}Downloads${Platform.pathSeparator}CatsKit';
    downloadPathController = TextEditingController(text: defaultPath);
  }

  @override
  void dispose() {
    updateUrlController.dispose();
    mirrorController.dispose();
    downloadPathController.dispose();
    super.dispose();
  }

  /// 获取镜像 URL
  String getMirrorUrl(String originalUrl) {
    final mirror = mirrorController.text.trim();
    if (mirror.isEmpty) return originalUrl;
    final base = mirror.endsWith('/') ? mirror : '$mirror/';
    return '$base$originalUrl';
  }

  /// 解析域名 -> IP，含 DNS-over-HTTPS 回退（绕过 Android 系统 DNS 缺陷）
  Future<String> resolveHost(String host) async {
    // 1) 系统 DNS
    try {
      final list = await InternetAddress.lookup(host);
      if (list.isNotEmpty) return list.first.address;
    } catch (_) {}
    try {
      final list = await InternetAddress.lookup(
        host,
        type: InternetAddressType.IPv4,
      );
      if (list.isNotEmpty) return list.first.address;
    } catch (_) {}
    // 2) DNS-over-HTTPS 回退（硬编码 IP，绕过系统 DNS 缺陷）
    // 国内可用：Alibaba(223.5.5.5), 114DNS(114.114.114.114), Tencent(119.29.29.29)
    // 海外可用：Google(8.8.8.8), Cloudflare(1.1.1.1)
    for (final dohIp in [
      '223.5.5.5',
      '114.114.114.114',
      '119.29.29.29',
      '8.8.8.8',
      '1.1.1.1',
    ]) {
      try {
        final dohClient = HttpClient()
          ..connectionTimeout = const Duration(seconds: 10)
          ..badCertificateCallback = (_, _, _) => true;
        final dohUri = Uri.parse('https://$dohIp/resolve?name=$host&type=A');
        final req = await dohClient.getUrl(dohUri);
        req.headers.set('Accept', 'application/dns-json');
        final res = await req.close().timeout(const Duration(seconds: 10));
        final body = await res.transform(utf8.decoder).join();
        dohClient.close(force: true);
        final json = jsonDecode(body) as Map<String, dynamic>;
        if (json['Answer'] != null) {
          for (final a in json['Answer'] as List<dynamic>) {
            final m = a as Map<String, dynamic>;
            if (m['type'] == 1) return m['data'] as String;
          }
        }
      } catch (_) {}
    }
    throw SocketException('无法解析域名: $host');
  }

  /// 尝试多个 URL，自动 DNS 回退 + 镜像轮询
  Future<HttpClientResponse> tryFetchUrls(
    HttpClient client,
    List<String> urls, {
    Map<String, String>? headers,
  }) async {
    String? lastError;
    for (final url in urls) {
      try {
        final uri = Uri.parse(url);
        final ip = await resolveHost(uri.host);
        final ipUri = uri.replace(host: ip);

        final request = await client
            .getUrl(ipUri)
            .timeout(const Duration(seconds: 15));
        request.headers.set('Host', uri.host);
        if (headers != null) {
          for (final e in headers.entries) {
            request.headers.set(e.key, e.value);
          }
        }
        return await request.close();
      } catch (e) {
        lastError = e.toString();
        continue;
      }
    }
    throw Exception('下载失败: $lastError');
  }

  /// 生成直连 + 所有可用镜像的 URL 列表
  List<String> urlCandidates(String originalUrl) {
    final candidates = <String>[getMirrorUrl(originalUrl)]; // 当前配置
    for (final m in presetMirrors) {
      if (m.isEmpty) continue; // 空 = 直连，已包含
      final base = m.endsWith('/') ? m : '$m/';
      final mirrored = '$base$originalUrl';
      if (!candidates.contains(mirrored)) {
        candidates.add(mirrored);
      }
    }
    // 确保直连也在列表里
    if (!candidates.contains(originalUrl)) {
      candidates.add(originalUrl);
    }
    return candidates;
  }

  Future<void> checkForUpdate() async {
    const apiUrl =
        'https://api.github.com/repos/InspiraFinder/CatsKit/releases/latest';

    setState(() {
      isDownloading = true;
      isCheckingUpdate = true;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15)
        ..badCertificateCallback = (_, _, _) => true;

      final headers = <String, String>{
        'User-Agent': 'CatsKit',
        'Accept': 'application/vnd.github+json',
        'Accept-Language': 'zh-CN,zh;q=0.9',
      };

      final response = await tryFetchUrls(
        client,
        urlCandidates(apiUrl),
        headers: headers,
      );

      String body;
      if (response.statusCode == 404) {
        // /releases/latest 返回 404 ＝ 还没有任何 release
        // 尝试获取 releases 列表
        final listUrl =
            'https://api.github.com/repos/InspiraFinder/CatsKit/releases';
        final listResponse = await tryFetchUrls(
          client,
          urlCandidates(listUrl),
          headers: headers,
        );

        if (listResponse.statusCode == HttpStatus.ok) {
          body = await listResponse.transform(utf8.decoder).join();
          final list = jsonDecode(body) as List<dynamic>;
          if (list.isEmpty) {
            if (!mounted) return;
            Navigator.of(context, rootNavigator: true).pop();
            setState(() {
              isDownloading = false;
              isCheckingUpdate = false;
            });
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('仓库中暂无任何发布版本')));
            return;
          }
          // 取列表中的第一个（最新）
          final json = list.first as Map<String, dynamic>;
          processReleaseJson(json);
        } else {
          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).pop();
          setState(() {
            isDownloading = false;
            isCheckingUpdate = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('仓库中暂无发布版本')));
        }
        return;
      }

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      processReleaseJson(json);
    } catch (e) {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setState(() {
        isDownloading = false;
        isCheckingUpdate = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('检查更新失败: $e')));
    }
  }

  /// 比较版本号字符串，返回 1 (a>b), -1 (a<b), 0 (a==b)
  int compareVersion(String a, String b) {
    final pa = a.replaceFirst(RegExp(r'^v'), '').split('.');
    final pb = b.replaceFirst(RegExp(r'^v'), '').split('.');
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (int i = 0; i < len; i++) {
      final va = int.tryParse(i < pa.length ? pa[i] : '0') ?? 0;
      final vb = int.tryParse(i < pb.length ? pb[i] : '0') ?? 0;
      if (va > vb) return 1;
      if (va < vb) return -1;
    }
    return 0;
  }

  void processReleaseJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? 'unknown';
    final assets = json['assets'] as List<dynamic>? ?? [];

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() {
      isDownloading = false;
      isCheckingUpdate = false;
    });

    // 对比版本号
    final cmp = compareVersion(tagName, appVersion);
    if (cmp <= 0) {
      // tag 版本 <= 当前版本 → 已是最新
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            locale == 'zh'
                ? '已是最新版本 (v$appVersion)'
                : 'Already up to date (v$appVersion)',
          ),
        ),
      );
      return;
    }

    if (assets.isEmpty) {
      updateUrlController.text =
          'https://github.com/InspiraFinder/CatsKit/releases/tag/$tagName';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发现最新版 $tagName，已填入 release 页面地址')),
        );
      }
      return;
    }

    final firstAsset = assets.first as Map<String, dynamic>;
    final downloadUrl = firstAsset['browser_download_url'] as String? ?? '';
    final assetName = firstAsset['name'] as String? ?? '';

    if (downloadUrl.isEmpty) {
      updateUrlController.text =
          'https://github.com/InspiraFinder/CatsKit/releases/tag/$tagName';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发现最新版 $tagName，但无法获取直链，已填入 release 页面')),
      );
      return;
    }

    updateUrlController.text = downloadUrl;

    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本: v$appVersion'),
            Text('最新版本: $tagName'),
            const SizedBox(height: 4),
            Text('文件: ${assetName.isNotEmpty ? assetName : "（无附件）"}'),
            const SizedBox(height: 8),
            const Text('下载地址已自动填入，点击"下载更新包"开始下载。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> downloadUpdatePackage() async {
    final url = updateUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先填写 GitHub 更新包地址')));
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('更新包地址格式不正确')));
      return;
    }

    cancelRequested = false;
    isPaused = false;
    downloadChunks.clear();
    totalDownloadBytes = 0;

    setState(() {
      isDownloading = true;
      downloadProgress = 0;
      downloadSpeed = '';
      downloadedSize = '';
      lastReceivedBytes = 0;
      lastSpeedTime = 0;
    });

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15)
        ..badCertificateCallback = (_, _, _) => true;

      final headers = <String, String>{
        'User-Agent': 'CatsKit',
        'Accept-Language': 'zh-CN,zh;q=0.9',
      };

      final response = await tryFetchUrls(
        client,
        urlCandidates(url),
        headers: headers,
      );

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      downloadResponse = response;
      final totalBytes = response.contentLength ?? -1;
      lastReceivedBytes = 0;
      lastSpeedTime = DateTime.now().millisecondsSinceEpoch;

      final completer = Completer<void>();
      streamSub = response.listen(
        (chunk) {
          if (cancelRequested) {
            streamSub?.cancel();
            downloadResponse = null;
            completer.complete();
            return;
          }

          downloadChunks.add(chunk);
          totalDownloadBytes += chunk.length;

          final now = DateTime.now().millisecondsSinceEpoch;
          final elapsed = now - lastSpeedTime;

          if (elapsed >= 1000) {
            final deltaBytes = totalDownloadBytes - lastReceivedBytes;
            final speedBps = deltaBytes / (elapsed / 1000);
            downloadSpeed = speedBps >= 1024 * 1024
                ? '${(speedBps / (1024 * 1024)).toStringAsFixed(1)} MB/s'
                : '${(speedBps / 1024).toStringAsFixed(0)} KB/s';
            lastReceivedBytes = totalDownloadBytes;
            lastSpeedTime = now;
          }

          downloadedSize = totalDownloadBytes >= 1024 * 1024
              ? '${(totalDownloadBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
              : '${(totalDownloadBytes / 1024).toStringAsFixed(0)} KB';

          if (totalBytes > 0) {
            downloadProgress = totalDownloadBytes / totalBytes;
          }

          if (mounted) setState(() {});
        },
        onDone: () {
          if (totalBytes < 0) downloadProgress = 1;
          completer.complete();
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        cancelOnError: false,
      );

      await completer.future;

      if (cancelRequested) {
        if (mounted) {
          setState(() {
            isDownloading = false;
            isPaused = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('下载已取消')));
        }
        return;
      }

      final bytes = downloadChunks.fold<List<int>>(<int>[], (a, b) {
        a.addAll(b);
        return a;
      });

      final fileName =
          uri.pathSegments.isNotEmpty && uri.pathSegments.last.isNotEmpty
          ? uri.pathSegments.last
          : 'catskit_update_package.bin';
      // 获取可写下载目录（使用用户自定义路径）
      final customPath = downloadPathController.text.trim();
      final downloadDir = Directory(
        customPath.isNotEmpty
            ? customPath
            : (Platform.isAndroid
                  ? '${Directory.systemTemp.path}${Platform.pathSeparator}CatsKit'
                  : '${Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.current.path}${Platform.pathSeparator}Downloads'),
      );
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final outputFile = File(
        '${downloadDir.path}${Platform.pathSeparator}$fileName',
      );
      await outputFile.writeAsBytes(bytes, flush: true);

      downloadedFilePath = outputFile.path;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '更新包已下载到: ${locale == 'zh' ? '${outputFile.path}，可点击安装按钮进行安装' : '${outputFile.path}, click install to proceed'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('下载失败: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isDownloading = false;
          isPaused = false;
        });
      }
    }
  }

  /// 安装下载的更新包
  Future<void> installPackage() async {
    final path = downloadedFilePath;
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            locale == 'zh'
                ? '没有可安装的文件，请先下载'
                : 'No file to install, download first',
          ),
        ),
      );
      return;
    }

    try {
      await OpenFilex.open(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${locale == 'zh' ? '安装失败' : 'Install failed'}: $e'),
        ),
      );
    }
  }

  void onPauseResume() {
    if (isPaused) {
      streamSub?.resume();
    } else {
      streamSub?.pause();
    }
    setState(() {
      isPaused = !isPaused;
    });
  }

  void onStopDownload() {
    cancelRequested = true;
    streamSub?.cancel();
    downloadResponse = null;
    setState(() {
      isDownloading = false;
      isPaused = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('下载已停止')));
  }

  Widget buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 14)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(100, 40),
      ),
    );
  }

  Future<void> showNetworkDiagnosis(BuildContext context, String locale) async {
    // 先显示加载对话框
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final results = <String>[];
    void log(String msg) => results.add(msg);

    try {
      log('===== 网络诊断 =====');
      log('设备: Android');
      log('');

      final hosts = [
        'api.github.com',
        'github.com',
        'google.com',
        'ghproxy.com',
        '223.5.5.5',
        '114.114.114.114',
      ];

      log('--- 1) InternetAddress.lookup ---');
      for (final host in hosts) {
        try {
          final list = await InternetAddress.lookup(host);
          log('$host -> ${list.map((a) => a.address).join(', ')}');
        } catch (e) {
          log('$host -> ❌ $e');
        }
      }

      log('');
      log('--- 2) DNS-over-HTTPS ---');
      const dohList = [
        '223.5.5.5',
        '114.114.114.114',
        '119.29.29.29',
        '8.8.8.8',
        '1.1.1.1',
      ];
      for (final dohIp in dohList) {
        try {
          final client = HttpClient()
            ..connectionTimeout = const Duration(seconds: 8)
            ..badCertificateCallback = (_, _, _) => true;
          final uri = Uri.parse(
            'https://$dohIp/resolve?name=api.github.com&type=A',
          );
          final req = await client.getUrl(uri);
          req.headers.set('Accept', 'application/dns-json');
          final res = await req.close().timeout(const Duration(seconds: 8));
          final body = await res.transform(utf8.decoder).join();
          client.close(force: true);
          final json = jsonDecode(body) as Map<String, dynamic>;
          if (json['Answer'] != null) {
            final ips = (json['Answer'] as List)
                .map((a) => (a as Map)['data'])
                .join(', ');
            log('DoH $dohIp -> $ips');
          } else {
            log('DoH $dohIp -> ❌ 无 Answer');
          }
        } catch (e) {
          log('DoH $dohIp -> ❌ $e');
        }
      }

      log('');
      log('--- 3) HTTPS 连通性 (api.github.com) ---');
      for (final dohIp in dohList) {
        try {
          final client = HttpClient()
            ..connectionTimeout = const Duration(seconds: 8)
            ..badCertificateCallback = (_, _, _) => true;
          final dohUri = Uri.parse(
            'https://$dohIp/resolve?name=api.github.com&type=A',
          );
          final req = await client.getUrl(dohUri);
          req.headers.set('Accept', 'application/dns-json');
          final res = await req.close().timeout(const Duration(seconds: 8));
          final body = await res.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          String? ip;
          if (json['Answer'] != null) {
            for (final a in json['Answer'] as List) {
              final m = a as Map<String, dynamic>;
              if (m['type'] == 1) {
                ip = m['data'] as String;
                break;
              }
            }
          }
          if (ip == null) {
            log('Via $dohIp -> ❌ 解析失败');
            continue;
          }
          final testUri = Uri.parse('https://$ip');
          final testReq = await client
              .getUrl(testUri)
              .timeout(const Duration(seconds: 10));
          testReq.headers.set('Host', 'api.github.com');
          testReq.headers.set('User-Agent', 'CatsKit');
          testReq.headers.set('Accept', 'application/vnd.github+json');
          final testRes = await testReq.close();
          log('Via $dohIp (IP=$ip) -> HTTP ${testRes.statusCode}');
          client.close(force: true);
        } catch (e) {
          log('Via $dohIp -> ❌ $e');
        }
      }
    } catch (e) {
      log('');
      log('‼️ 诊断程序异常: $e');
    }

    // 关闭加载，显示结果
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // 关加载
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('网络诊断结果'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              results.join('\n'),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(locale == 'zh' ? '设置' : 'Settings'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          const Divider(),
          ListTile(
            title: Text(locale == 'zh' ? '中文' : 'Chinese'),
            leading: Radio<String>(
              value: 'zh',
              groupValue: locale,
              onChanged: (value) {
                setState(() {
                  locale = value!;
                });
              },
            ),
          ),
          ListTile(
            title: Text(locale == 'zh' ? 'English' : 'English'),
            leading: Radio<String>(
              value: 'en',
              groupValue: locale,
              onChanged: (value) {
                setState(() {
                  locale = value!;
                });
              },
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: Text(locale == 'zh' ? '显示操作提示' : 'Show operation hints'),
            subtitle: Text(
              locale == 'zh'
                  ? '每次点击按钮时显示灰色提示条'
                  : 'Show snackbar when clicking buttons',
            ),
            value: showSnackBar,
            onChanged: (value) {
              setState(() {
                showSnackBar = value;
              });
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              locale == 'zh' ? 'GitHub 更新包地址' : 'GitHub update package URL',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: updateUrlController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: locale == 'zh'
                    ? '请输入 GitHub release 直链'
                    : 'Enter GitHub release direct URL',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: isDownloading ? null : checkForUpdate,
              icon: const Icon(Icons.search),
              label: Text(locale == 'zh' ? '检测最新更新' : 'Check for updates'),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isDownloading ? null : downloadUpdatePackage,
                    icon: isDownloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update),
                    label: Text(
                      isDownloading
                          ? (locale == 'zh' ? '下载中...' : 'Downloading...')
                          : (locale == 'zh' ? '下载更新包' : 'Download'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: downloadedFilePath.isEmpty
                        ? null
                        : installPackage,
                    icon: const Icon(Icons.install_mobile),
                    label: Text(locale == 'zh' ? '安装' : 'Install'),
                  ),
                ),
              ],
            ),
          ),
          if (isDownloading) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  // 显示下载路径
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${locale == 'zh' ? '下载到' : 'Save to'}: ${downloadPathController.text}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: downloadProgress > 0 ? downloadProgress : null,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$downloadedSize${downloadProgress > 0 ? ' (${(downloadProgress * 100).toStringAsFixed(1)}%)' : ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        downloadSpeed,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!isCheckingUpdate)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        buildControlButton(
                          icon: isPaused ? Icons.play_arrow : Icons.pause,
                          label: isPaused ? '继续' : '暂停',
                          color: Colors.orange,
                          onPressed: onPauseResume,
                        ),
                        const SizedBox(width: 16),
                        buildControlButton(
                          icon: Icons.stop,
                          label: '停止',
                          color: Colors.redAccent,
                          onPressed: onStopDownload,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              locale == 'zh' ? '镜像加速地址（可选）' : 'Mirror URL (optional)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              locale == 'zh'
                  ? '如果无法连接 GitHub，可使用镜像加速。留空则直连。'
                  : 'If GitHub is unreachable, use a mirror. Leave empty for direct.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 8),
          // 预设镜像快速选择
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: presetMirrors.map((mirror) {
                final label = mirror.isEmpty
                    ? (locale == 'zh' ? '直连' : 'Direct')
                    : mirror.replaceAll('https://', '').replaceAll('/', '');
                final isActive = mirrorController.text.trim() == mirror;
                return ActionChip(
                  label: Text(label, style: const TextStyle(fontSize: 11)),
                  backgroundColor: isActive ? Colors.blue[100] : null,
                  onPressed: () {
                    setState(() {
                      mirrorController.text = mirror;
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: mirrorController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: locale == 'zh'
                    ? 'https://ghproxy.net/'
                    : 'https://ghproxy.net/',
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          // ---- 下载保存路径 ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              locale == 'zh' ? '下载保存路径' : 'Download save path',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: downloadPathController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: locale == 'zh'
                    ? '输入下载保存路径'
                    : 'Enter download save path',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.restore),
                  onPressed: () {
                    final defaultPath = Platform.isAndroid
                        ? '${Directory.systemTemp.path}${Platform.pathSeparator}CatsKit'
                        : '${Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.current.path}${Platform.pathSeparator}Downloads${Platform.pathSeparator}CatsKit';
                    downloadPathController.text = defaultPath;
                  },
                  tooltip: locale == 'zh' ? '恢复默认' : 'Reset default',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ActionChip(
                  label: Text(
                    locale == 'zh' ? '默认路径' : 'Default',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    final defaultPath = Platform.isAndroid
                        ? '${Directory.systemTemp.path}${Platform.pathSeparator}CatsKit'
                        : '${Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.current.path}${Platform.pathSeparator}Downloads${Platform.pathSeparator}CatsKit';
                    downloadPathController.text = defaultPath;
                  },
                ),
                if (Platform.isAndroid) ...[
                  ActionChip(
                    label: const Text(
                      'Downloads',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () => downloadPathController.text =
                        '/storage/emulated/0/Download/CatsKit',
                  ),
                  ActionChip(
                    label: const Text(
                      'Documents',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () => downloadPathController.text =
                        '/storage/emulated/0/Documents/CatsKit',
                  ),
                  ActionChip(
                    label: const Text('DCIM', style: TextStyle(fontSize: 12)),
                    onPressed: () => downloadPathController.text =
                        '/storage/emulated/0/DCIM/CatsKit',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          // ---- 版本信息 ----
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.grey),
            title: Text(locale == 'zh' ? '当前版本' : 'Version'),
            trailing: Text(
              'v$appVersion',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          // ---- 项目主页 ----
          ListTile(
            leading: const Icon(Icons.favorite, color: Colors.red),
            title: Text(locale == 'zh' ? '项目主页' : 'Project Homepage'),
            subtitle: Text(
              locale == 'zh'
                  ? 'CatsKit — 猫猫车工具\n请在 GitHub 上 Star (点赞) 以支持本项目'
                  : 'CatsKit — Cat Car Builder\nPlease ⭐ on GitHub to support',
            ),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () async {
              final uri = Uri.parse('https://github.com/InspiraFinder/CatsKit');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${locale == 'zh' ? '无法打开链接' : 'Cannot open link'}: $uri',
                    ),
                  ),
                );
              }
            },
          ),
          const Divider(),
          // ---- 鸣谢 ----
          ListTile(
            leading: const Icon(Icons.emoji_events, color: Colors.amber),
            title: Text(locale == 'zh' ? '鸣谢' : 'Acknowledgments'),
            subtitle: Text('Navimoe C.A.T.S. Engine'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () async {
              final uri = Uri.parse('https://github.com/SAK-20744/Navimoe');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${locale == 'zh' ? '无法打开链接' : 'Cannot open link'}: $uri',
                    ),
                  ),
                );
              }
            },
          ),
          const Divider(),
          // ---- 网络诊断 ----
          ListTile(
            leading: const Icon(Icons.bug_report, color: Colors.deepOrange),
            title: Text(locale == 'zh' ? '网络诊断' : 'Network Diagnosis'),
            subtitle: Text(
              locale == 'zh' ? '检测 DNS 解析和网络连通性' : 'Test DNS & connectivity',
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => showNetworkDiagnosis(context, locale),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'locale': locale,
                  'showSnackBar': showSnackBar,
                  'githubUpdateUrl': updateUrlController.text.trim(),
                  'mirrorUrl': mirrorController.text.trim(),
                });
              },
              child: Text(locale == 'zh' ? '保存' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }
}

// 导入界面（未改动，但国际化未完善，保持原样）
class ImportScreen extends StatefulWidget {
  final List<String> initialBoxTexts;
  final Function(List<String>) onImportConfirmed;
  const ImportScreen({
    super.key,
    required this.initialBoxTexts,
    required this.onImportConfirmed,
  });

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  late List<TextEditingController> controllers;

  @override
  void initState() {
    super.initState();
    controllers = List.generate(
      25,
      (i) => TextEditingController(text: widget.initialBoxTexts[i]),
    );
  }

  @override
  void dispose() {
    for (var c in controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入文本'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: List.generate(25, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${index + 1}:',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: controllers[index],
                            decoration: InputDecoration(
                              hintText: '输入文本...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    child: const Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirmPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text(
                      '确定',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void onConfirmPressed() {
    widget.onImportConfirmed(controllers.map((c) => c.text).toList());
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导入成功！'), duration: Duration(seconds: 1)),
    );
  }
}
