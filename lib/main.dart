import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'parts_data.dart';

const String appVersion = '0.2.2';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CatsKit',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MainMenuScreen(locale: 'zh'),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<String> boxTexts = List<String>.filled(25, '');
  List<String> boxButtonNumbers = List<String>.filled(25, '');
  int selectedButton = 0;
  bool isClearMode = false;
  String _locale = 'zh';
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
        leading: PopupMenuButton<String>(
          icon: const Icon(Icons.menu),
          onSelected: (value) {
            if (value == 'menu') {
              Navigator.popUntil(context, (route) => route.isFirst);
            } else if (value == 'build') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BuildToolScreen(locale: _locale),
                ),
              );
            } else if (value == 'settings') {
              _openSettings();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'menu',
              child: Text(_t('返回主菜单', 'Back to Menu')),
            ),
            PopupMenuItem(
              value: 'build',
              child: Text(_t('组车工具', 'Build Tool')),
            ),
            PopupMenuItem(
              value: 'settings',
              child: Text(_t('通用设置', 'Settings')),
            ),
          ],
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
class MainMenuScreen extends StatelessWidget {
  final String locale;
  const MainMenuScreen({super.key, this.locale = 'zh'});

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
                '工具集',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 48),
              _buildMenuItem(
                context,
                icon: Icons.search,
                label: '查车工具',
                color: Colors.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MainScreen()),
                ),
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                context,
                icon: Icons.build,
                label: '组车工具（开发中）',
                color: Colors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BuildToolScreen(locale: locale),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                context,
                icon: Icons.settings,
                label: '通用设置',
                color: Colors.green,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(
                      currentLocale: 'zh',
                      currentShowSnackBar: false,
                      currentGithubUpdateUrl:
                          'https://github.com/InspiraFinder/CatsKit/releases',
                      currentMirrorUrl: '',
                    ),
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

class _BuildToolScreenState extends State<BuildToolScreen> {
  bool _isAssemblyMode = true;
  PartCategory _selectedCategory = PartCategory.body;
  PartData? _body;
  final List<PartData> _weapons = [];
  final List<PartData> _wheels = [];
  final List<PartData> _gadgets = [];
  final Map<String, int> _partLevels = {};

  // ---- Navimoe 验证数据 ----
  CarValidation _validation = CarValidation.empty();

  void _recalc() {
    _validation = CarValidation.compute(
      _body,
      _weapons,
      _wheels,
      _gadgets,
      _partLevels,
    );
  }

  int _level(PartData p) => _partLevels[p.id] ?? 1;

  @override
  Widget build(BuildContext context) {
    _recalc();
    return Scaffold(
      appBar: AppBar(
        title: const Text('组车工具'),
        centerTitle: true,
        leading: PopupMenuButton<String>(
          icon: const Icon(Icons.menu),
          onSelected: (value) {
            if (value == 'menu') {
              Navigator.popUntil(context, (route) => route.isFirst);
            } else if (value == 'vehicle') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MainScreen()),
              );
            } else if (value == 'settings') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(
                    currentLocale: 'zh',
                    currentShowSnackBar: false,
                    currentGithubUpdateUrl:
                        'https://github.com/InspiraFinder/CatsKit/releases',
                    currentMirrorUrl: '',
                  ),
                ),
              );
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'menu', child: Text('返回主菜单')),
            PopupMenuItem(value: 'vehicle', child: Text('查车工具')),
            PopupMenuItem(value: 'settings', child: Text('通用设置')),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildAssemblyArea(),
          const Divider(height: 1),
          _buildButtonRow(),
          const Divider(height: 1),
          _buildPartsSelector(),
        ],
      ),
    );
  }

  // ==================== 组车区 ====================
  Widget _buildAssemblyArea() {
    final v = _validation;
    final powerOk = v.powerSupply >= v.powerConsumption;
    return Container(
      padding: const EdgeInsets.all(6),
      color: Colors.blue[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  v.error.isNotEmpty ? v.error : '状态 OK',
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
                '电力',
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
                '插槽',
                '武${v.numWeapons}/${v.numWeaponSlots} 轮${v.numWheels}/${v.numWheelSlots} 装${v.numGadgets}/${v.numGadgetSlots}',
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
                  _statChip('身体+${v.bodyBonusPct}%', '', Colors.orange),
                if (v.weaponBonusPct > 0) const SizedBox(width: 4),
                if (v.weaponBonusPct > 0)
                  _statChip('武器+${v.weaponBonusPct}%', '', Colors.red),
                if (v.wheelBonusPct > 0) const SizedBox(width: 4),
                if (v.wheelBonusPct > 0)
                  _statChip('车轮+${v.wheelBonusPct}%', '', Colors.green),
                if (v.gadgetBonusPct > 0) const SizedBox(width: 4),
                if (v.gadgetBonusPct > 0)
                  _statChip('装置+${v.gadgetBonusPct}%', '', Colors.purple),
                if (v.sponsorBonusPct > 0) const SizedBox(width: 4),
                if (v.sponsorBonusPct > 0)
                  _statChip('赞助+${v.sponsorBonusPct}%', '', Colors.teal),
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
                  ((constraints.maxWidth - 6 * totalSlots) / totalSlots).clamp(
                    70.0,
                    120.0,
                  );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSlot(
                      '车身',
                      _body,
                      Colors.orange,
                      () => setState(() => _body = null),
                      slotWidth,
                    ),
                    const SizedBox(width: 6),
                    ...List.generate(
                      v.numWeaponSlots,
                      (i) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _buildSlot(
                          '武${i + 1}',
                          i < _weapons.length ? _weapons[i] : null,
                          Colors.red,
                          () {
                            if (i < _weapons.length)
                              setState(() => _weapons.removeAt(i));
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
                          '轮${i + 1}',
                          i < _wheels.length ? _wheels[i] : null,
                          Colors.green,
                          () {
                            if (i < _wheels.length)
                              setState(() => _wheels.removeAt(i));
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
                          '装${i + 1}',
                          i < _gadgets.length ? _gadgets[i] : null,
                          Colors.purple,
                          () {
                            if (i < _gadgets.length)
                              setState(() => _gadgets.removeAt(i));
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
    /* unchanged - same as before */
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _isAssemblyMode = true),
              icon: const Icon(Icons.handyman, size: 20),
              label: const Text('组车', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAssemblyMode ? Colors.blue : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _isAssemblyMode = false),
              icon: const Icon(Icons.bar_chart, size: 20),
              label: const Text('数据展示', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: !_isAssemblyMode ? Colors.teal : Colors.grey,
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
    final parts = PartDatabase.filterByCategory(_selectedCategory);
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: PartCategory.values.map((cat) {
                  const labels = {
                    PartCategory.body: '车身',
                    PartCategory.weapon: '武器',
                    PartCategory.wheel: '车轮',
                    PartCategory.gadget: '装置',
                  };
                  const icons = {
                    PartCategory.body: Icons.directions_car,
                    PartCategory.weapon: Icons.gps_fixed,
                    PartCategory.wheel: Icons.radio_button_checked,
                    PartCategory.gadget: Icons.build,
                  };
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icons[cat]!, size: 16),
                          const SizedBox(width: 4),
                          Text(labels[cat]!),
                        ],
                      ),
                      selected: _selectedCategory == cat,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: parts.length,
                itemBuilder: (_, i) => _buildPartCard(parts[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartCard(PartData part) {
    final isUsed = part.category == PartCategory.body
        ? _body?.id == part.id
        : part.category == PartCategory.weapon
        ? _weapons.any((p) => p.id == part.id)
        : part.category == PartCategory.wheel
        ? _wheels.any((p) => p.id == part.id)
        : _gadgets.any((p) => p.id == part.id);
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
          child: Column(
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
                  part.bonusLabel,
                  style: TextStyle(fontSize: 9, color: Colors.orange[800]),
                ),
              if (!_isAssemblyMode)
                const Icon(Icons.info_outline, size: 14, color: Colors.teal),
            ],
          ),
        ),
      ),
    );
  }

  void _tryAddPart(PartData part) {
    setState(() {
      switch (part.category) {
        case PartCategory.body:
          if (_body?.id == part.id) {
            // 点击已装备的车身 → 移除车身和所有部件
            _body = null;
            _weapons.clear();
            _wheels.clear();
            _gadgets.clear();
          } else {
            // 更换车身 → 移除所有不兼容的部件
            _body = part;
            _partLevels[part.id] ??= 1;
            _weapons.clear();
            _wheels.clear();
            _gadgets.clear();
          }
        case PartCategory.weapon:
          if (_weapons.any((p) => p.id == part.id)) {
            _weapons.removeWhere((p) => p.id == part.id);
          } else {
            _weapons.add(part);
            _partLevels[part.id] ??= 1;
          }
        case PartCategory.wheel:
          if (_wheels.any((p) => p.id == part.id)) {
            _wheels.removeWhere((p) => p.id == part.id);
          } else {
            _wheels.add(part);
            _partLevels[part.id] ??= 1;
          }
        case PartCategory.gadget:
          if (_gadgets.any((p) => p.id == part.id)) {
            _gadgets.removeWhere((p) => p.id == part.id);
          } else {
            _gadgets.add(part);
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
        error = '装置过多 ($numGadgets/$numGadgetSlots)';
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
                          '${part.categoryLabel} · ${part.rarityLabel} · ${part.sponsorLabel.isNotEmpty ? part.sponsorLabel : "无赞助"}',
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
            if (part.hp1 > 0) _chip('HP 基础', part.hp1.toString(), Colors.blue),
            if (part.atk1 > 0)
              _chip('ATK 基础', part.atk1.toString(), Colors.red),
            _chip(
              '电力',
              part.power >= 0 ? '+${part.power}' : part.power.toString(),
              Colors.amber[800]!,
            ),
            if (part.slots != null) _chip('插槽', part.slotsLabel, Colors.grey),
            if (part.bonus != null) _chip('加成', part.bonusLabel, Colors.orange),
            if (part.partClass != PartClass.none)
              _chip('类型', part.classLabel, Colors.brown),
            if (part.mHp1 > 0)
              _chip('随从HP基础', part.mHp1.toString(), Colors.teal),
            const SizedBox(height: 12),
            // ---- 等级数据 + 升级费用表 ----
            const Text(
              '各等级数据与升级费用',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 12,
                headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
                columns: const [
                  DataColumn(
                    label: Text(
                      'Lv',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Stats',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Increment',
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
                      'Inc./kCash',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Inc./Token',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: () {
                  final costs = upgradeCosts[part.rarity] ?? [];
                  final rows = <DataRow>[];
                  final showHp = part.hp1 > 0;
                  double? prevStats;

                  for (int i = 0; i < part.maxLevel; i++) {
                    final lv = i + 1;
                    final stats = showHp ? part.hp(lv) : part.atk(lv);
                    final inc = prevStats != null ? stats - prevStats : 0;
                    final cost = lv < costs.length ? costs[lv] : costs.last;

                    // costs[i] 已经是 Navimoe 的每级增量，直接用
                    final incPieces = cost.pieces;
                    final incCash = cost.cash;
                    final incToken = cost.token;

                    final incPerKCash = incCash > 0
                        ? (inc / incCash * 1000).toStringAsFixed(2)
                        : 'N/A';
                    final incPerToken = incToken > 0
                        ? (inc / incToken).toStringAsFixed(2)
                        : 'N/A';

                    rows.add(
                      DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '$lv',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${stats.floor()}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              i == 0 ? '${stats.floor()}' : '+${inc.floor()}',
                              style: TextStyle(
                                fontSize: 13,
                                color: i > 0 ? Colors.green : Colors.grey,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '$incPieces',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              '$incCash',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              '$incToken',
                              style: const TextStyle(fontSize: 13),
                            ),
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
                                color: incToken > 0
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

                    prevStats = stats;
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
  late TextEditingController _updateUrlController;
  late TextEditingController _mirrorController;
  bool _isDownloading = false;
  bool _isPaused = false;
  bool _isCheckingUpdate = false;
  double _downloadProgress = 0;
  String _downloadSpeed = '';
  String _downloadedSize = '';
  int _lastReceivedBytes = 0;
  int _lastSpeedTime = 0;
  StreamSubscription? _streamSub;
  bool _cancelRequested = false;
  HttpClientResponse? _downloadResponse;
  int _totalDownloadBytes = 0;
  final List<List<int>> _downloadChunks = [];

  static const List<String> _presetMirrors = [
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
    _updateUrlController = TextEditingController(
      text: widget.currentGithubUpdateUrl,
    );
    _mirrorController = TextEditingController(text: widget.currentMirrorUrl);
  }

  @override
  void dispose() {
    _updateUrlController.dispose();
    _mirrorController.dispose();
    super.dispose();
  }

  /// 获取镜像 URL
  String _getMirrorUrl(String originalUrl) {
    final mirror = _mirrorController.text.trim();
    if (mirror.isEmpty) return originalUrl;
    final base = mirror.endsWith('/') ? mirror : '$mirror/';
    return '$base$originalUrl';
  }

  /// 手动解析域名（先试系统默认，失败则强制 IPv4），兼容 Android DNS 问题
  Future<String> _resolveHost(String host) async {
    try {
      final list = await InternetAddress.lookup(host);
      if (list.isNotEmpty) return list.first.address;
    } catch (_) {}
    // 默认失败时尝试仅 IPv4
    try {
      final list = await InternetAddress.lookup(
        host,
        type: InternetAddressType.IPv4,
      );
      if (list.isNotEmpty) return list.first.address;
    } catch (_) {}
    throw SocketException('无法解析域名: $host');
  }

  /// 尝试多个 URL，自动 DNS 回退 + 镜像轮询
  Future<HttpClientResponse> _tryFetchUrls(
    HttpClient client,
    List<String> urls, {
    Map<String, String>? headers,
  }) async {
    String? lastError;
    int dnsFailures = 0;
    for (final url in urls) {
      try {
        final uri = Uri.parse(url);
        // 先手动解析 DNS（兼容 Android 上 HttpClient 内部 DNS 失败的情况）
        final ip = await _resolveHost(uri.host);
        final ipUri = uri.replace(host: ip);

        final request = await client
            .getUrl(ipUri)
            .timeout(const Duration(seconds: 15));
        // 保留原始 Host 头，避免 CDN / 反向代理校验失败
        request.headers.set('Host', uri.host);
        if (headers != null) {
          for (final e in headers.entries) {
            request.headers.set(e.key, e.value);
          }
        }
        return await request.close();
      } catch (e) {
        lastError = e.toString();
        if (e is SocketException) dnsFailures++;
        continue;
      }
    }
    final hint = dnsFailures > 0
        ? '（所有域名均无法解析，可能是网络环境限制，'
              '请尝试使用 VPN 或切换 Wi-Fi/移动网络）'
        : '';
    throw Exception('下载失败: $lastError$hint');
  }

  /// 生成直连 + 所有可用镜像的 URL 列表
  List<String> _urlCandidates(String originalUrl) {
    final candidates = <String>[_getMirrorUrl(originalUrl)]; // 当前配置
    for (final m in _presetMirrors) {
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

  Future<void> _checkForUpdate() async {
    const apiUrl =
        'https://api.github.com/repos/InspiraFinder/CatsKit/releases/latest';

    setState(() {
      _isDownloading = true;
      _isCheckingUpdate = true;
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

      final response = await _tryFetchUrls(
        client,
        _urlCandidates(apiUrl),
        headers: headers,
      );

      String body;
      if (response.statusCode == 404) {
        // /releases/latest 返回 404 ＝ 还没有任何 release
        // 尝试获取 releases 列表
        final listUrl =
            'https://api.github.com/repos/InspiraFinder/CatsKit/releases';
        final listResponse = await _tryFetchUrls(
          client,
          _urlCandidates(listUrl),
          headers: headers,
        );

        if (listResponse.statusCode == HttpStatus.ok) {
          body = await listResponse.transform(utf8.decoder).join();
          final list = jsonDecode(body) as List<dynamic>;
          if (list.isEmpty) {
            if (!mounted) return;
            Navigator.of(context, rootNavigator: true).pop();
            setState(() {
              _isDownloading = false;
              _isCheckingUpdate = false;
            });
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('仓库中暂无任何发布版本')));
            return;
          }
          // 取列表中的第一个（最新）
          final json = list.first as Map<String, dynamic>;
          _processReleaseJson(json);
        } else {
          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).pop();
          setState(() {
            _isDownloading = false;
            _isCheckingUpdate = false;
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
      _processReleaseJson(json);
    } catch (e) {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setState(() {
        _isDownloading = false;
        _isCheckingUpdate = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('检查更新失败: $e')));
    }
  }

  void _processReleaseJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? 'unknown';
    final assets = json['assets'] as List<dynamic>? ?? [];

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() {
      _isDownloading = false;
      _isCheckingUpdate = false;
    });

    if (assets.isEmpty) {
      _updateUrlController.text =
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
      _updateUrlController.text =
          'https://github.com/InspiraFinder/CatsKit/releases/tag/$tagName';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发现最新版 $tagName，但无法获取直链，已填入 release 页面')),
      );
      return;
    }

    _updateUrlController.text = downloadUrl;

    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本: $tagName'),
            if (assetName.isNotEmpty) Text('文件: $assetName'),
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

  Future<void> _downloadUpdatePackage() async {
    final url = _updateUrlController.text.trim();
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

    _cancelRequested = false;
    _isPaused = false;
    _downloadChunks.clear();
    _totalDownloadBytes = 0;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _downloadSpeed = '';
      _downloadedSize = '';
      _lastReceivedBytes = 0;
      _lastSpeedTime = 0;
    });

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15)
        ..badCertificateCallback = (_, _, _) => true;

      final headers = <String, String>{
        'User-Agent': 'CatsKit',
        'Accept-Language': 'zh-CN,zh;q=0.9',
      };

      final response = await _tryFetchUrls(
        client,
        _urlCandidates(url),
        headers: headers,
      );

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      _downloadResponse = response;
      final totalBytes = response.contentLength ?? -1;
      _lastReceivedBytes = 0;
      _lastSpeedTime = DateTime.now().millisecondsSinceEpoch;

      final completer = Completer<void>();
      _streamSub = response.listen(
        (chunk) {
          if (_cancelRequested) {
            _streamSub?.cancel();
            _downloadResponse = null;
            completer.complete();
            return;
          }

          _downloadChunks.add(chunk);
          _totalDownloadBytes += chunk.length;

          final now = DateTime.now().millisecondsSinceEpoch;
          final elapsed = now - _lastSpeedTime;

          if (elapsed >= 1000) {
            final deltaBytes = _totalDownloadBytes - _lastReceivedBytes;
            final speedBps = deltaBytes / (elapsed / 1000);
            _downloadSpeed = speedBps >= 1024 * 1024
                ? '${(speedBps / (1024 * 1024)).toStringAsFixed(1)} MB/s'
                : '${(speedBps / 1024).toStringAsFixed(0)} KB/s';
            _lastReceivedBytes = _totalDownloadBytes;
            _lastSpeedTime = now;
          }

          _downloadedSize = _totalDownloadBytes >= 1024 * 1024
              ? '${(_totalDownloadBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
              : '${(_totalDownloadBytes / 1024).toStringAsFixed(0)} KB';

          if (totalBytes > 0) {
            _downloadProgress = _totalDownloadBytes / totalBytes;
          }

          if (mounted) setState(() {});
        },
        onDone: () {
          if (totalBytes < 0) _downloadProgress = 1;
          completer.complete();
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        cancelOnError: false,
      );

      await completer.future;

      if (_cancelRequested) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _isPaused = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('下载已取消')));
        }
        return;
      }

      final bytes = _downloadChunks.fold<List<int>>(<int>[], (a, b) {
        a.addAll(b);
        return a;
      });

      final fileName =
          uri.pathSegments.isNotEmpty && uri.pathSegments.last.isNotEmpty
          ? uri.pathSegments.last
          : 'catskit_update_package.bin';
      final downloadDir = Directory(
        '${Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.current.path}${Platform.pathSeparator}Downloads',
      );
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final outputFile = File(
        '${downloadDir.path}${Platform.pathSeparator}$fileName',
      );
      await outputFile.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新包已下载到: ${outputFile.path}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('下载失败: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isPaused = false;
        });
      }
    }
  }

  void _onPauseResume() {
    if (_isPaused) {
      _streamSub?.resume();
    } else {
      _streamSub?.pause();
    }
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _onStopDownload() {
    _cancelRequested = true;
    _streamSub?.cancel();
    _downloadResponse = null;
    setState(() {
      _isDownloading = false;
      _isPaused = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('下载已停止')));
  }

  Widget _buildControlButton({
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(locale == 'zh' ? '设置' : 'Settings'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          // 导航卡片
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.search, color: Colors.blue),
                    title: Text('查车工具'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MainScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.build, color: Colors.orange),
                    title: Text('组车工具'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BuildToolScreen(locale: locale),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
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
              controller: _updateUrlController,
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
              onPressed: _isDownloading ? null : _checkForUpdate,
              icon: const Icon(Icons.search),
              label: Text(locale == 'zh' ? '检测最新更新' : 'Check for updates'),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: _isDownloading ? null : _downloadUpdatePackage,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update),
              label: Text(
                _isDownloading
                    ? (locale == 'zh' ? '下载中...' : 'Downloading...')
                    : (locale == 'zh' ? '下载更新包' : 'Download update package'),
              ),
            ),
          ),
          if (_isDownloading) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_downloadedSize${_downloadProgress > 0 ? ' (${(_downloadProgress * 100).toStringAsFixed(1)}%)' : ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        _downloadSpeed,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!_isCheckingUpdate)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildControlButton(
                          icon: _isPaused ? Icons.play_arrow : Icons.pause,
                          label: _isPaused ? '继续' : '暂停',
                          color: Colors.orange,
                          onPressed: _onPauseResume,
                        ),
                        const SizedBox(width: 16),
                        _buildControlButton(
                          icon: Icons.stop,
                          label: '停止',
                          color: Colors.redAccent,
                          onPressed: _onStopDownload,
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
              children: _presetMirrors.map((mirror) {
                final label = mirror.isEmpty
                    ? (locale == 'zh' ? '直连' : 'Direct')
                    : mirror.replaceAll('https://', '').replaceAll('/', '');
                final isActive = _mirrorController.text.trim() == mirror;
                return ActionChip(
                  label: Text(label, style: const TextStyle(fontSize: 11)),
                  backgroundColor: isActive ? Colors.blue[100] : null,
                  onPressed: () {
                    setState(() {
                      _mirrorController.text = mirror;
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
              controller: _mirrorController,
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
          // ---- 支持本项目 ----
          ListTile(
            leading: const Icon(Icons.favorite, color: Colors.red),
            title: Text(locale == 'zh' ? '支持本项目' : 'Support this project'),
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
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'locale': locale,
                  'showSnackBar': showSnackBar,
                  'githubUpdateUrl': _updateUrlController.text.trim(),
                  'mirrorUrl': _mirrorController.text.trim(),
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
                    onPressed: _onConfirmPressed,
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

  void _onConfirmPressed() {
    widget.onImportConfirmed(controllers.map((c) => c.text).toList());
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导入成功！'), duration: Duration(seconds: 1)),
    );
  }
}
