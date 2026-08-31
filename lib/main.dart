import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'fragment_calc_screen.dart';
import 'garage_data.dart';
import 'my_garage_screen.dart';
import 'part_shape_view.dart';
import 'parts_data.dart';
import 'parts_shape_data.dart';
import 'time_calc_screen.dart';
import 'activity_calendar_screen.dart';
import 'upgrade_plan_screen.dart';
import 'gang_data.dart';
import 'gang_stats_screen.dart';
import 'my_gang_screen.dart';

const String appVersion = '1.7.3';

/// 获取部件在当前语言下的显示名称
String pn(PartData part, String? locale) {
  if (locale == 'zh' && part.nameZh.isNotEmpty) return part.nameZh;
  if (locale == 'ja' && part.nameJa.isNotEmpty) return part.nameJa;
  return part.name;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // 读取持久化的语言/服务器设置
  final prefs = await SharedPreferences.getInstance();
  var savedLocale = prefs.getString('appLocale') ?? 'zh';
  final savedServer = prefs.getString('appServer') ?? 'cn';
  final savedDarkMode = prefs.getBool('appDarkMode') ?? false;
  // 国服只能使用中文
  if (savedServer == 'cn') {
    savedLocale = 'zh';
  }
  runApp(
    MyApp(
      initialLocale: savedLocale,
      initialServer: savedServer,
      initialDarkMode: savedDarkMode,
    ),
  );
}

class MyApp extends StatefulWidget {
  final String initialLocale;
  final String initialServer;
  final bool initialDarkMode;
  const MyApp({
    super.key,
    this.initialLocale = 'zh',
    this.initialServer = 'cn',
    this.initialDarkMode = false,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late String _appLocale;
  late String _appServer; // 'cn' 国服, 'intl' 国际服
  late bool _appDarkMode;

  @override
  void initState() {
    super.initState();
    _appLocale = widget.initialLocale;
    _appServer = widget.initialServer;
    _appDarkMode = widget.initialDarkMode;
  }

  void _onLocaleChanged(String newLocale) {
    setState(() => _appLocale = newLocale);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('appLocale', newLocale),
    );
  }

  void _onServerChanged(String newServer) {
    setState(() => _appServer = newServer);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('appServer', newServer),
    );
  }

  void _onDarkModeChanged(bool newValue) {
    setState(() => _appDarkMode = newValue);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('appDarkMode', newValue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CatsKit',
      // 统一处理底部安全区：避免系统导航栏/手势条遮挡页面底部内容
      builder: (context, child) =>
          SafeArea(top: false, left: false, right: false, child: child!),
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      themeMode: _appDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: MainMenuScreen(
        locale: _appLocale,
        onLocaleChanged: _onLocaleChanged,
        server: _appServer,
        onServerChanged: _onServerChanged,
        darkMode: _appDarkMode,
        onDarkModeChanged: _onDarkModeChanged,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final String locale;
  final String server;
  final bool darkMode;
  final ValueChanged<bool>? onDarkModeChanged;
  const MainScreen({
    super.key,
    this.locale = 'zh',
    this.server = 'cn',
    this.darkMode = false,
    this.onDarkModeChanged,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<String> boxTexts = List<String>.filled(25, '');
  List<String> boxButtonNumbers = List<String>.filled(25, '');
  int selectedButton = 0;
  bool isClearMode = false;
  late String _locale;
  late String _server;

  @override
  void initState() {
    super.initState();
    _locale = widget.locale;
    _server = widget.server;
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
          onPressed: () =>
              Navigator.pop(context, {'locale': _locale, 'server': _server}),
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
          currentServer: _server,
          currentShowSnackBar: _showSnackBar,
          currentDarkMode: widget.darkMode,
          currentGithubUpdateUrl: githubUpdateUrl,
          currentMirrorUrl: _mirrorUrl,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _locale = result['locale'];
        _server = result['server'] ?? _server;
        _showSnackBar = result['showSnackBar'];
        githubUpdateUrl = result['githubUpdateUrl'] ?? githubUpdateUrl;
        _mirrorUrl = result['mirrorUrl'] ?? _mirrorUrl;
      });
      if (result['darkMode'] != null) {
        widget.onDarkModeChanged?.call(result['darkMode'] as bool);
      }
      _showMessage('语言已切换', 'Language changed');
    }
  }
}

// ==================== 主菜单 ====================
class MainMenuScreen extends StatefulWidget {
  final String locale;
  final ValueChanged<String>? onLocaleChanged;
  final String server;
  final ValueChanged<String>? onServerChanged;
  final bool darkMode;
  final ValueChanged<bool>? onDarkModeChanged;
  const MainMenuScreen({
    super.key,
    this.locale = 'zh',
    this.onLocaleChanged,
    this.server = 'cn',
    this.onServerChanged,
    this.darkMode = false,
    this.onDarkModeChanged,
  });

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  late String _locale;
  late String _server;
  late bool _darkMode;

  String _t(String zh, String en) => _locale == 'zh' ? zh : en;

  @override
  void initState() {
    super.initState();
    _locale = widget.locale;
    _server = widget.server;
    _darkMode = widget.darkMode;
  }

  @override
  void didUpdateWidget(MainMenuScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locale != oldWidget.locale) {
      _locale = widget.locale;
    }
    if (widget.server != oldWidget.server) {
      _server = widget.server;
    }
    if (widget.darkMode != oldWidget.darkMode) {
      _darkMode = widget.darkMode;
    }
  }

  /// 导航到子页面，返回时检查语言/服务器是否变更
  Future<void> _navigateAndAwaitLocale(Widget screen) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (result != null && mounted) {
      if (result['locale'] != null) {
        final newLocale = result['locale'] as String;
        if (newLocale != _locale) {
          setState(() => _locale = newLocale);
          widget.onLocaleChanged?.call(newLocale);
        }
      }
      if (result['server'] != null) {
        final newServer = result['server'] as String;
        if (newServer != _server) {
          setState(() => _server = newServer);
          widget.onServerChanged?.call(newServer);
        }
      }
      if (result['darkMode'] != null) {
        final newDarkMode = result['darkMode'] as bool;
        if (newDarkMode != _darkMode) {
          setState(() => _darkMode = newDarkMode);
          widget.onDarkModeChanged?.call(newDarkMode);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CatsKit'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                onTap: () => _navigateAndAwaitLocale(
                  MainScreen(
                    locale: _locale,
                    server: _server,
                    darkMode: _darkMode,
                    onDarkModeChanged: widget.onDarkModeChanged,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                context,
                icon: Icons.build,
                label: _t('组车工具', 'Build Tool'),
                color: Colors.orange,
                onTap: () => _navigateAndAwaitLocale(
                  BuildToolScreen(locale: _locale, server: _server),
                ),
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
                icon: Icons.auto_awesome,
                label: _t('碎片计算', 'Fragment Calc'),
                color: Colors.teal,
                onTap: () => _navigateAndAwaitLocale(
                  FragmentCalcScreen(locale: _locale),
                ),
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                context,
                icon: Icons.calendar_month,
                label: _t('活动日历', 'Activity Calendar'),
                color: Colors.cyan,
                onTap: () => _navigateAndAwaitLocale(
                  ActivityCalendarScreen(locale: _locale, server: _server),
                ),
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                context,
                icon: Icons.garage,
                label: _t('我的车库', 'My Garage'),
                color: Colors.indigo,
                onTap: () => _navigateAndAwaitLocale(
                  MyGarageScreen(locale: _locale, server: _server),
                ),
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                context,
                icon: Icons.upgrade,
                label: _t('升级计划', 'Upgrade Plan'),
                color: Colors.deepOrange,
                onTap: () => _navigateAndAwaitLocale(
                  UpgradePlanScreen(locale: _locale, server: _server),
                ),
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                context,
                icon: Icons.groups_2,
                label: _t('我的帮派', 'My Gang'),
                color: Colors.teal,
                onTap: () => _navigateAndAwaitLocale(
                  MyGangScreen(locale: _locale, server: _server),
                ),
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                context,
                icon: Icons.groups,
                label: _t('帮派统计', 'Gang Stats'),
                color: Colors.brown,
                onTap: () => _navigateAndAwaitLocale(
                  GangStatsScreen(locale: _locale, server: _server),
                ),
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
                    currentServer: _server,
                    currentShowSnackBar: false,
                    currentDarkMode: _darkMode,
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
  final String server;

  /// 初始车辆（从车库“重新组车”跳转时传入，null 表示空车）
  final GarageVehicle? initialVehicle;
  const BuildToolScreen({
    super.key,
    this.locale = 'zh',
    this.server = 'cn',
    this.initialVehicle,
  });

  @override
  State<BuildToolScreen> createState() => _BuildToolScreenState();
}

/// 单个组车区的数据
class _VehicleBuild {
  PartData? body;
  PartData? extraWeapon; // 额外武器槽（不占普通武器槽位、不计算电力）
  final weapons = <PartData>[];
  final wheels = <PartData>[];
  final gadgets = <PartData>[];

  /// 该车辆中是否使用了指定部件
  bool usesPart(PartData p) =>
      body?.id == p.id ||
      extraWeapon?.id == p.id ||
      weapons.any((x) => x.id == p.id) ||
      wheels.any((x) => x.id == p.id) ||
      gadgets.any((x) => x.id == p.id);

  void clear() {
    body = null;
    extraWeapon = null;
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
  bool _horizontalLayout = false; // 宽屏下左右布局（组车区左、部件右）
  int _leftRatio = 50; // 左右布局左栏宽度百分比
  final PartCategory _selectedCategory = PartCategory.body;
  final Set<PartCategory> _selectedCategories = {};
  final Set<Rarity> _selectedRarities = {};
  final TextEditingController _searchController = TextEditingController();

  // 精确检索模式：筛选与排序
  final Set<PartCategory> _searchCategories = {};
  final Set<Rarity> _searchRarities = {};
  final TextEditingController _searchAtkController = TextEditingController();
  final TextEditingController _searchHpController = TextEditingController();
  int _searchMinAtk = 0; // ATK 筛选下限（0=不限，由输入框解析）
  int _searchMinHp = 0; // HP 筛选下限（0=不限，由输入框解析）
  int _searchSort = 0; // 0=不排序 1=ATK升 2=ATK降 3=HP升 4=HP降
  final List<_VehicleBuild> _vehicles = [_VehicleBuild()];
  int _activeIndex = 0;
  final Map<String, int> _partLevels = {};

  /// 每个部件的额外加成百分比（独立乘区，0~150%，10%一档）
  final Map<String, int> _partExtraBonus = {};

  /// 批量赋值模式：待赋值的等级（非 null 表示处于等级赋值模式）
  int? _pendingAssignLevel;

  /// 批量赋值模式：待赋值的额外加成（非 null 表示处于额外加成赋值模式）
  int? _pendingAssignBonus;

  _VehicleBuild get _activeVehicle => _vehicles[_activeIndex];
  CarValidation _validation = CarValidation.empty();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    final iv = widget.initialVehicle;
    if (iv != null) {
      _applyInitialVehicle(iv);
    }
  }

  /// 读取持久化的显示设置
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showImages = prefs.getBool('buildShowImages') ?? false;
      _gridColumns = prefs.getInt('buildGridColumns') ?? 3;
      _horizontalLayout = prefs.getBool('buildHorizontalLayout') ?? false;
      _leftRatio = prefs.getInt('buildHorizontalSplit') ?? 50;
    });
  }

  /// 保存显示设置（bool/int）
  Future<void> _savePref(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
  }

  void _recalc() {
    _validation = CarValidation.compute(
      _activeVehicle.body,
      _activeVehicle.weapons,
      _activeVehicle.wheels,
      _activeVehicle.gadgets,
      _activeVehicle.extraWeapon,
      _partLevels,
      _partExtraBonus,
    );
  }

  /// 从车库车辆数据恢复组车区（用于“重新组车”）
  void _applyInitialVehicle(GarageVehicle v) {
    if (v.isEmpty) return;
    final byId = {
      for (final p in PartDatabase.partsForServer(widget.server)) p.id: p,
    };
    PartData? find(String? id) => (id == null || id.isEmpty) ? null : byId[id];

    List<PartData> resolve(List<String?> slots) => [
      for (final id in slots)
        if (id != null && byId.containsKey(id)) byId[id]!,
    ];

    final build = _vehicles.first;
    build.body = find(v.bodyId);
    build.extraWeapon = find(v.extraWeaponId);
    build.weapons
      ..clear()
      ..addAll(resolve(v.weaponSlots));
    build.wheels
      ..clear()
      ..addAll(resolve(v.wheelSlots));
    build.gadgets
      ..clear()
      ..addAll(resolve(v.gadgetSlots));

    for (final e in v.levels.entries) {
      _partLevels[e.key] = e.value;
    }
    for (final e in v.bonuses.entries) {
      _partExtraBonus[e.key] = e.value;
    }
    _recalc();
  }

  int _level(PartData p) => _partLevels[p.id] ?? 1;

  /// 部件的额外加成百分比（归一到 10% 档，0~150%）
  int _extraBonus(PartData p) =>
      ((_partExtraBonus[p.id] ?? 0).clamp(0, 150) / 10).floor() * 10;

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
      // 清理被删车辆中部件记录的等级与额外加成
      final v = _vehicles[index];
      for (final p in [
        v.body,
        v.extraWeapon,
        ...v.weapons,
        ...v.wheels,
        ...v.gadgets,
      ]) {
        if (p != null) {
          _partLevels.remove(p.id);
          _partExtraBonus.remove(p.id);
        }
      }
      _vehicles.removeAt(index);
      if (_activeIndex >= _vehicles.length) {
        _activeIndex = _vehicles.length - 1;
      }
    });
  }

  /// 通用数值选择弹窗
  Future<int?> _pickValue({
    required String title,
    required List<int> values,
    required String Function(int) label,
  }) {
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        scrollable: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final v in values)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, v),
                child: Text(label(v)),
              ),
          ],
        ),
      ),
    );
  }

  /// 批量等级赋值：点击后进入赋值模式，再点击组车区部件对其赋等级
  Future<void> _startBatchLevel() async {
    if (_pendingAssignLevel != null) {
      setState(() => _pendingAssignLevel = null);
      return;
    }
    final choice = await _pickValue(
      title: _t('批量等级赋值', 'Set Levels'),
      values: [for (int lv = 1; lv <= 20; lv++) lv],
      label: (lv) => 'Lv$lv',
    );
    if (choice == null) return;
    setState(() {
      _pendingAssignLevel = choice;
      _pendingAssignBonus = null;
    });
  }

  /// 批量额外加成赋值：点击后进入赋值模式，再点击组车区部件对其赋额外加成（0~150%，10%一档）
  Future<void> _startBatchBonus() async {
    if (_pendingAssignBonus != null) {
      setState(() => _pendingAssignBonus = null);
      return;
    }
    final choice = await _pickValue(
      title: _t('批量额外加成赋值', 'Set Extra Bonus'),
      values: [for (int pct = 0; pct <= 150; pct += 10) pct],
      label: (pct) => pct == 0 ? '+0%' : '+$pct%',
    );
    if (choice == null) return;
    setState(() {
      _pendingAssignBonus = choice;
      _pendingAssignLevel = null;
    });
  }

  /// 处理组车区部件点击：赋值模式下对部件赋值，否则移除部件
  void _handleSlotTap(PartData part, VoidCallback onRemove) {
    final lv = _pendingAssignLevel;
    final bns = _pendingAssignBonus;
    if (lv != null) {
      setState(() => _partLevels[part.id] = lv.clamp(1, part.maxLevel));
    } else if (bns != null) {
      setState(() => _partExtraBonus[part.id] = bns);
    } else {
      onRemove();
    }
  }

  /// 将当前组车区保存到车库的某个车位（1~10）
  Future<void> _saveVehicleToGarage(_VehicleBuild vh) async {
    if (vh.body == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('请先组好一辆车（需要有车身）', 'Build a car first (body required)'),
          ),
        ),
      );
      return;
    }
    final slots = await GarageStore.load();
    if (!mounted) return;

    final partIds = <String>{
      if (vh.body != null) vh.body!.id,
      if (vh.extraWeapon != null) vh.extraWeapon!.id,
      ...vh.weapons.map((p) => p.id),
      ...vh.wheels.map((p) => p.id),
      ...vh.gadgets.map((p) => p.id),
    };
    final bodySlots = vh.body!.slots;
    List<String?> makeSlots(List<PartData> parts, int count) {
      final result = List<String?>.filled(count, null);
      for (int i = 0; i < parts.length && i < count; i++) {
        result[i] = parts[i].id;
      }
      return result;
    }

    final vehicle = GarageVehicle(
      bodyId: vh.body!.id,
      extraWeaponId: vh.extraWeapon?.id,
      weaponSlots: makeSlots(vh.weapons, bodySlots?.weapon ?? 0),
      wheelSlots: makeSlots(vh.wheels, bodySlots?.wheel ?? 0),
      gadgetSlots: makeSlots(vh.gadgets, bodySlots?.gadget ?? 0),
      levels: Map.fromEntries(
        _partLevels.entries.where((e) => partIds.contains(e.key)),
      ),
      bonuses: Map.fromEntries(
        _partExtraBonus.entries.where((e) => partIds.contains(e.key)),
      ),
    );

    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('选择保存车位', 'Select slot')),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (int i = 0; i < GarageStore.slotCount; i++)
                  buildSlotPickerButton(ctx, i + 1, slots[i]),
              ],
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;

    slots[selected - 1] = vehicle;
    await GarageStore.save(slots);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t('已保存到车位 $selected', 'Saved to slot $selected')),
      ),
    );
  }

  /// 保存弹窗中的单个车位按钮
  Widget buildSlotPickerButton(BuildContext ctx, int slot, GarageVehicle? v) {
    final filled = v != null && !v.isEmpty;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: filled ? Colors.teal[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            if (filled) {
              final ok = await showDialog<bool>(
                context: ctx,
                builder: (c2) => AlertDialog(
                  title: Text(_t('覆盖车位$slot？', 'Overwrite slot $slot?')),
                  content: Text(
                    _t('该车位已有一辆车，确定覆盖？', 'Slot already has a car. Overwrite?'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c2, false),
                      child: Text(_t('取消', 'Cancel')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c2, true),
                      child: Text(_t('覆盖', 'Overwrite')),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
            }
            Navigator.pop(ctx, slot);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (filled && (v?.name ?? '').isNotEmpty)
                      ? v!.name!
                      : _t('车位$slot', 'Slot $slot'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Icon(
                  filled ? Icons.directions_car : Icons.add_circle_outline,
                  size: 14,
                  color: filled ? Colors.teal : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _recalc();
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width > size.height;
    final useHorizontal = _horizontalLayout && isWide;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('组车工具', 'Build Tool')),
        centerTitle: true,
        actions: [
          // 左右布局切换 + 左栏比例（仅横屏/宽屏显示）
          if (isWide) ...[
            IconButton(
              icon: Icon(
                Icons.swap_horiz,
                color: useHorizontal ? Colors.teal : null,
              ),
              onPressed: () {
                final newVal = !_horizontalLayout;
                setState(() => _horizontalLayout = newVal);
                _savePref('buildHorizontalLayout', newVal);
              },
              tooltip: _t(
                _horizontalLayout ? '切回上下布局' : '切换为左右布局',
                _horizontalLayout ? 'Back to vertical' : 'Side-by-side layout',
              ),
            ),
            // 左右布局左栏比例（可调）
            PopupMenuButton<int>(
              icon: const Icon(Icons.tune),
              tooltip: _t('左栏比例', 'Left ratio'),
              onSelected: (v) {
                setState(() => _leftRatio = v);
                _savePref('buildHorizontalSplit', v);
              },
              itemBuilder: (_) => [30, 35, 40, 45, 50, 55, 60, 65, 70]
                  .map(
                    (n) => PopupMenuItem(
                      value: n,
                      child: Text(
                        n == _leftRatio ? '左栏 $n% ✓' : '左栏 $n%',
                        style: TextStyle(
                          fontWeight: n == _leftRatio
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          IconButton(
            icon: Icon(
              _showImages ? Icons.image : Icons.text_fields,
              color: _showImages ? Colors.orange : null,
            ),
            onPressed: () {
              final newVal = !_showImages;
              setState(() => _showImages = newVal);
              _savePref('buildShowImages', newVal);
            },
            tooltip: _showImages ? _t('文字模式', 'Text') : _t('图片模式', 'Image'),
          ),
          PopupMenuButton<int>(
            icon: Icon(Icons.grid_view, size: 20),
            tooltip: _t('每行数量', 'Columns'),
            onSelected: (v) {
              setState(() => _gridColumns = v);
              _savePref('buildGridColumns', v);
            },
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
      body: useHorizontal
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: _leftRatio,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [buildAssemblyArea(), buildButtonRow()],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Flexible(
                  flex: 100 - _leftRatio,
                  child: SingleChildScrollView(child: buildPartsSelector()),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  buildAssemblyArea(),
                  buildButtonRow(),
                  const Divider(height: 1),
                  buildPartsSelector(),
                ],
              ),
            ),
    );
  }

  // ==================== 组车区 ====================
  Widget buildAssemblyArea() {
    final inAssignMode =
        _pendingAssignLevel != null || _pendingAssignBonus != null;
    return Column(
      children: [
        if (_isAssemblyMode && inAssignMode) buildAssignHint(),
        for (int i = 0; i < _vehicles.length; i++) ...[
          buildSingleVehicleArea(_vehicles[i], i),
          if (_isAssemblyMode && i < _vehicles.length - 1)
            const Divider(height: 8),
        ],
      ],
    );
  }

  /// 批量赋值模式提示条
  Widget buildAssignHint() {
    final isLv = _pendingAssignLevel != null;
    final color = isLv ? Colors.blue : Colors.deepPurple;
    final msg = isLv
        ? _t(
            '等级赋值模式：点击组车区部件设为 Lv$_pendingAssignLevel，再次点击按钮取消',
            'Level mode: tap parts to set Lv$_pendingAssignLevel, tap the button again to cancel',
          )
        : _t(
            '额外加成赋值模式：点击组车区部件设为 +$_pendingAssignBonus%，再次点击按钮取消',
            'Bonus mode: tap parts to set +$_pendingAssignBonus%, tap the button again to cancel',
          );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(
        msg,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildSingleVehicleArea(_VehicleBuild vh, int vi) {
    final v = vi == _activeIndex
        ? _validation
        : CarValidation.compute(
            vh.body,
            vh.weapons,
            vh.wheels,
            vh.gadgets,
            vh.extraWeapon,
            _partLevels,
            _partExtraBonus,
          );
    final powerOk = v.powerSupply >= v.powerConsumption;
    final isActive = vi == _activeIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _activeIndex = vi),
      child: Container(
        padding: const EdgeInsets.all(6),
        color: isActive
            ? (isDark ? const Color(0xFF0D1B2A) : Colors.blue[50])
            : _isAssemblyMode
            ? (isDark ? Colors.grey.shade900 : Colors.grey[100])
            : (isDark ? Colors.teal.shade900 : Colors.teal[50]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // —— 操作按钮（数据查询模式隐藏） ——
            if (_isAssemblyMode)
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 保存到车库（点击选择车位）
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.save_alt,
                        size: 18,
                        color: Colors.teal,
                      ),
                      tooltip: _t('保存到车库', 'Save to Garage'),
                      onPressed: () => _saveVehicleToGarage(vh),
                    ),
                    const SizedBox(width: 2),
                    // 批量等级赋值（点击进入/退出赋值模式）
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.format_list_numbered,
                        size: 18,
                        color: _pendingAssignLevel != null ? Colors.blue : null,
                      ),
                      tooltip: _t('批量等级赋值', 'Set Levels'),
                      onPressed: _startBatchLevel,
                    ),
                    const SizedBox(width: 2),
                    // 批量额外加成赋值（点击进入/退出赋值模式）
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.work_outline,
                        size: 18,
                        color: _pendingAssignBonus != null
                            ? Colors.deepPurple
                            : null,
                      ),
                      tooltip: _t('批量额外加成赋值', 'Set Extra Bonus'),
                      onPressed: _startBatchBonus,
                    ),
                    const SizedBox(width: 2),
                    // 删除组车区（仅图标）
                    if (_vehicles.length > 1)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red,
                        ),
                        tooltip: _t('删除组车区', 'Delete'),
                        onPressed: () => _removeVehicle(vi),
                      ),
                  ],
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
                statChip('HP', '${v.hp.floor()}', Colors.blue),
                const SizedBox(width: 4),
                statChip('ATK', '${v.atk.floor()}', Colors.red),
                const SizedBox(width: 4),
                statChip(
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
                statChip(
                  _t('插槽', 'Slots'),
                  '${_t('武器', 'Wpn')}${v.numWeapons}/${v.numWeaponSlots} ${_t('车轮', 'Whl')}${v.numWheels}/${v.numWheelSlots} ${_t('配件', 'Gad')}${v.numGadgets}/${v.numGadgetSlots}${v.numExtraWeapons > 0 ? ' ${_t('额外武', 'X-Wpn')}1' : ''}',
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
                    statChip(
                      '${_t('车身', 'Body')}+${v.bodyBonusPct}%',
                      '',
                      Colors.orange,
                    ),
                  if (v.weaponBonusPct > 0) ...[
                    const SizedBox(width: 4),
                    statChip(
                      '${_t('攻击', 'ATK')}+${v.weaponBonusPct}%',
                      '',
                      Colors.red,
                    ),
                  ],
                  if (v.wheelBonusPct > 0) ...[
                    const SizedBox(width: 4),
                    statChip(
                      '${_t('车轮', 'Wheel')}+${v.wheelBonusPct}%',
                      '',
                      Colors.green,
                    ),
                  ],
                  if (v.gadgetBonusPct > 0) ...[
                    const SizedBox(width: 4),
                    statChip(
                      '${_t('配件', 'Gadget')}+${v.gadgetBonusPct}%',
                      '',
                      Colors.purple,
                    ),
                  ],
                  if (v.sponsorBonusPct > 0) ...[
                    const SizedBox(width: 4),
                    statChip(
                      '${_t('赞助', 'Sponsor')}+${v.sponsorBonusPct}%',
                      '',
                      Colors.teal,
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 6),
            // ---- 插槽行（自动换行，最多两行） ----
            LayoutBuilder(
              builder: (context, constraints) {
                final totalSlots =
                    1 +
                    v.numWeaponSlots +
                    v.numWheelSlots +
                    v.numGadgetSlots +
                    (vh.extraWeapon != null ? 1 : 0);
                // 每行槽位数：按总槽数均分到最多两行
                final slotsPerLine = (totalSlots / 2).ceil();
                const spacing = 6.0;
                final slotWidth =
                    ((constraints.maxWidth - spacing * (slotsPerLine - 1)) /
                            slotsPerLine)
                        .clamp(75.0, 120.0);
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    buildSlot(
                      _t('车身', 'Body'),
                      vh.body,
                      Colors.orange,
                      () => setState(() => vh.body = null),
                      slotWidth,
                    ),
                    ...List.generate(
                      v.numWeaponSlots,
                      (i) => buildSlot(
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
                    // 额外武器槽（仅在有武器时显示；不占普通武器槽位、不计算电力）
                    if (vh.extraWeapon != null)
                      buildSlot(
                        _t('额外武', 'X-Wpn'),
                        vh.extraWeapon,
                        Colors.brown,
                        () => setState(() => vh.extraWeapon = null),
                        slotWidth,
                      ),
                    ...List.generate(
                      v.numWheelSlots,
                      (i) => buildSlot(
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
                    ...List.generate(
                      v.numGadgetSlots,
                      (i) => buildSlot(
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
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget statChip(String label, String value, Color color) {
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

  Widget buildSlot(
    String label,
    PartData? part,
    Color color,
    VoidCallback onRemove,
    double w,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: part != null ? () => _handleSlotTap(part, onRemove) : null,
      child: Container(
        width: w,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: part != null ? 2 : 1),
          borderRadius: BorderRadius.circular(6),
          color: part != null
              ? color.withValues(alpha: 0.15)
              : (isDark ? Colors.grey.shade900 : Colors.white),
        ),
        child: part != null
            ? buildSlotContent(part, color, onRemove)
            : Center(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ),
      ),
    );
  }

  Widget buildSlotContent(PartData part, Color color, VoidCallback onRemove) {
    final lv = _level(part);
    final xb = _extraBonus(part);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 深色模式下使用浅色文字，避免与深色背景无法区分
    final subColor = isDark ? Colors.white70 : Colors.grey[700];
    final dropdownColor = isDark ? Colors.white : Colors.black;
    // 计算赋值后的数据（含额外加成独立乘区）
    final hp = part.hp(lv) * (1 + xb / 100.0);
    final atk = part.atk(lv) * (1 + xb / 100.0);
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
        Column(
          children: [
            Text(
              'HP${hp.floor()}',
              style: TextStyle(fontSize: 8, color: subColor),
            ),
            Text(
              'ATK${atk.floor()}',
              style: TextStyle(fontSize: 8, color: subColor),
            ),
          ],
        ),
        SizedBox(
          width: 60,
          height: 18,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: lv.clamp(1, part.maxLevel),
              isDense: true,
              isExpanded: true,
              style: TextStyle(fontSize: 10, color: dropdownColor),
              items: List.generate(
                part.maxLevel,
                (i) =>
                    DropdownMenuItem(value: i + 1, child: Text('Lv${i + 1}')),
              ),
              onChanged: (v) => setState(() => _partLevels[part.id] = v!),
            ),
          ),
        ),
        // 额外加成（独立乘区，下拉选择，与等级设置一致）
        SizedBox(
          width: 60,
          height: 18,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: xb,
              isDense: true,
              isExpanded: true,
              style: TextStyle(fontSize: 10, color: dropdownColor),
              items: [
                for (int pct = 0; pct <= 150; pct += 10)
                  DropdownMenuItem(value: pct, child: Text('+$pct%')),
              ],
              onChanged: (v) => setState(() => _partExtraBonus[part.id] = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildButtonRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => setState(() {
                _isAssemblyMode = !_isAssemblyMode;
                _pendingAssignLevel = null;
                _pendingAssignBonus = null;
              }),
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
                _isFilterMode
                    ? _t('筛选', 'Filter')
                    : _t('精确检索', 'Precise Search'),
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
  Widget buildPartsSelector() {
    // 根据当前模式筛选部件
    List<PartData> parts;
    final db = PartDatabase.partsForServer(widget.server);
    if (_isFilterMode) {
      // 筛选模式：按分类 + 稀有度筛选
      parts = db.where((p) {
        if (_selectedCategories.isNotEmpty &&
            !_selectedCategories.contains(p.category))
          return false;
        if (_selectedRarities.isNotEmpty &&
            !_selectedRarities.contains(p.rarity))
          return false;
        return true;
      }).toList();
    } else {
      // 精确检索模式：文字搜索 + 类型/ATK/HP 筛选 + 排序
      final q = _searchController.text.trim().toLowerCase();
      parts = db.where((p) {
        if (q.isNotEmpty &&
            !(p.id.toLowerCase().contains(q) ||
                p.name.toLowerCase().contains(q) ||
                p.nameZh.contains(q) ||
                p.nameJa.contains(q))) {
          return false;
        }
        if (_searchCategories.isNotEmpty &&
            !_searchCategories.contains(p.category)) {
          return false;
        }
        if (_searchRarities.isNotEmpty && !_searchRarities.contains(p.rarity)) {
          return false;
        }
        if (_searchMinAtk > 0 && p.atk1 < _searchMinAtk) {
          return false;
        }
        if (_searchMinHp > 0 && p.hp1 < _searchMinHp) {
          return false;
        }
        return true;
      }).toList();
      // 排序
      switch (_searchSort) {
        case 1:
          parts.sort((a, b) => a.atk1.compareTo(b.atk1));
          break;
        case 2:
          parts.sort((a, b) => b.atk1.compareTo(a.atk1));
          break;
        case 3:
          parts.sort((a, b) => a.hp1.compareTo(b.hp1));
          break;
        case 4:
          parts.sort((a, b) => b.hp1.compareTo(a.hp1));
          break;
      }
    }

    return Column(
      children: [
        // ---- 筛选/搜索控件 ----
        if (_isFilterMode) buildFilterChips() else buildSearchBar(),
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
            itemBuilder: (_, i) => buildPartCard(parts[i]),
          ),
        ),
      ],
    );
  }

  Widget buildFilterChips() {
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

  /// 水平居中的可滚动按钮行（内容不足时居中，超出时可横向滚动）
  Widget buildCenteredChipRow(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        );
      },
    );
  }

  Widget buildSearchBar() {
    return Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 12,
              ),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        // 类型筛选
        Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: buildCenteredChipRow(
            PartCategory.values.map((cat) {
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
              final selected = _searchCategories.contains(cat);
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
                      _searchCategories.add(cat);
                    } else {
                      _searchCategories.remove(cat);
                    }
                  }),
                ),
              );
            }).toList(),
          ),
        ),
        // 稀有度筛选
        Container(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          child: buildCenteredChipRow(
            Rarity.values.map((r) {
              final selected = _searchRarities.contains(r);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(
                    r.name.toUpperCase(),
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _searchRarities.add(r);
                    } else {
                      _searchRarities.remove(r);
                    }
                  }),
                ),
              );
            }).toList(),
          ),
        ),
        // ATK / HP 手动输入筛选
        Container(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: buildMinInput(
                  label: _t('ATK≥', 'ATK≥'),
                  controller: _searchAtkController,
                  onChanged: (_) => setState(() {
                    _searchMinAtk = parseMin(_searchAtkController.text);
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: buildMinInput(
                  label: _t('HP≥', 'HP≥'),
                  controller: _searchHpController,
                  onChanged: (_) => setState(() {
                    _searchMinHp = parseMin(_searchHpController.text);
                  }),
                ),
              ),
            ],
          ),
        ),
        // 排序
        Container(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          child: buildCenteredChipRow([
            for (final s in const [
              (1, 'ATK↑', 'ATK↑'),
              (2, 'ATK↓', 'ATK↓'),
              (3, 'HP↑', 'HP↑'),
              (4, 'HP↓', 'HP↓'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(
                    _t(s.$2, s.$3),
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: _searchSort == s.$1,
                  onSelected: (v) => setState(() => _searchSort = v ? s.$1 : 0),
                ),
              ),
          ]),
        ),
      ],
    );
  }

  /// 解析手动输入的下限值（非法/负数视为 0=不限）
  int parseMin(String text) {
    final v = int.tryParse(text.trim());
    return v == null || v < 0 ? 0 : v;
  }

  /// 精确检索：ATK/HP 筛选下限手动输入框
  Widget buildMinInput({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: _t('不限', 'Any'),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: onChanged,
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

  Widget buildPartCard(PartData part) {
    final isUsed = _isPartUsedAnywhere(part);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _isAssemblyMode ? tryAddPart(part) : showPartData(part),
      child: Card(
        color: _isAssemblyMode && isUsed
            ? (isDark ? Colors.green.shade900 : Colors.green[100])
            : !_isAssemblyMode
            ? (isDark ? Colors.teal.shade900 : Colors.teal[50])
            : null,
        elevation: isUsed ? 4 : 1,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: _showImages
              ? Stack(
                  children: [
                    // 部件图片（铺满卡片，边框较大时自动放大保持比例）
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(1),
                        child: Image.asset(
                          part.imagePath(widget.server),
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
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    if (part.atk1 > 0)
                      Text(
                        'ATK ${part.atk1}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
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

  void tryAddPart(PartData part) {
    setState(() {
      final v = _activeVehicle;

      // 如果已被其他车辆使用 → 先移除
      for (final other in _vehicles) {
        if (other == v) continue;
        if (other.body?.id == part.id) other.body = null;
        if (other.extraWeapon?.id == part.id) other.extraWeapon = null;
        other.weapons.removeWhere((p) => p.id == part.id);
        other.wheels.removeWhere((p) => p.id == part.id);
        other.gadgets.removeWhere((p) => p.id == part.id);
      }

      switch (part.category) {
        case PartCategory.body:
          if (v.body?.id == part.id) {
            v.clear();
            _partLevels.remove(part.id);
            _partExtraBonus.remove(part.id);
          } else {
            v.clear();
            v.body = part;
            _partLevels[part.id] ??= 1;
          }
        case PartCategory.weapon:
          if (v.weapons.any((p) => p.id == part.id)) {
            v.weapons.removeWhere((p) => p.id == part.id);
            _partLevels.remove(part.id);
            _partExtraBonus.remove(part.id);
          } else if (v.extraWeapon?.id == part.id) {
            v.extraWeapon = null;
            _partLevels.remove(part.id);
            _partExtraBonus.remove(part.id);
          } else {
            // 普通武器槽未满 → 加入普通武器；否则放入额外武器槽
            final freeNormal = (v.body?.slots?.weapon ?? 0) - v.weapons.length;
            if (freeNormal > 0) {
              v.weapons.add(part);
            } else {
              if (v.extraWeapon != null) {
                _partLevels.remove(v.extraWeapon!.id);
                _partExtraBonus.remove(v.extraWeapon!.id);
              }
              v.extraWeapon = part;
            }
            _partLevels[part.id] ??= 1;
          }
        case PartCategory.wheel:
          if (v.wheels.any((p) => p.id == part.id)) {
            v.wheels.removeWhere((p) => p.id == part.id);
            _partLevels.remove(part.id);
            _partExtraBonus.remove(part.id);
          } else {
            v.wheels.add(part);
            _partLevels[part.id] ??= 1;
          }
        case PartCategory.gadget:
          if (v.gadgets.any((p) => p.id == part.id)) {
            v.gadgets.removeWhere((p) => p.id == part.id);
            _partLevels.remove(part.id);
            _partExtraBonus.remove(part.id);
          } else {
            v.gadgets.add(part);
            _partLevels[part.id] ??= 1;
          }
      }
    });
  }

  void showPartData(PartData part) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PartDataScreen(
          part: part,
          locale: widget.locale,
          server: widget.server,
        ),
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
  final int numExtraWeapons;
  final int numWheels;
  final int numGadgets;
  final int numBodySlots;
  final int numWeaponSlots;
  final int numExtraWeaponSlots;
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
    required this.numExtraWeapons,
    required this.numWheels,
    required this.numGadgets,
    required this.numBodySlots,
    required this.numWeaponSlots,
    required this.numExtraWeaponSlots,
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
    numExtraWeapons: 0,
    numWheels: 0,
    numGadgets: 0,
    numBodySlots: 0,
    numWeaponSlots: 0,
    numExtraWeaponSlots: 0,
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
    PartData? extraWeapon,
    Map<String, int> levels,
    Map<String, int> extraBonuses,
  ) {
    // allParts：参与 HP/ATK/加成/赞助计算（含额外武器）
    // powerParts：参与电力计算（不含额外武器，额外武器不耗电）
    final allParts = <PartData>[];
    final powerParts = <PartData>[];
    if (body != null) {
      allParts.add(body);
      powerParts.add(body);
    }
    allParts.addAll(weapons);
    powerParts.addAll(weapons);
    allParts.addAll(wheels);
    powerParts.addAll(wheels);
    allParts.addAll(gadgets);
    powerParts.addAll(gadgets);
    if (extraWeapon != null) allParts.add(extraWeapon);

    int lv(PartData p) => (levels[p.id] ?? 1).clamp(1, p.maxLevel);

    // 额外加成：独立乘区，0~150%，10%一档
    int xb(PartData p) =>
        ((extraBonuses[p.id] ?? 0).clamp(0, 150) / 10).floor() * 10;

    // Slot limits from body
    final numBodies = body != null ? 1 : 0;
    final numWeapons = weapons.length;
    final numExtraWeapons = extraWeapon != null ? 1 : 0;
    final numWheels = wheels.length;
    final numGadgets = gadgets.length;
    final numBodySlots = 1;
    final numWeaponSlots = body?.slots?.weapon ?? 0;
    final numExtraWeaponSlots = body != null ? 1 : 0;
    final numWheelSlots = body?.slots?.wheel ?? 0;
    final numGadgetSlots = body?.slots?.gadget ?? 0;

    // Power（额外武器不计电力）
    final powerSupply = powerParts.fold(
      0,
      (s, p) => s + (p.power > 0 ? p.power : 0),
    );
    final powerConsumption = powerParts.fold(
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

    // HP/ATK：分类加成与额外加成为独立乘区，逐部件相乘
    // HP = Σ hp*(1+分类加成/100)*(1+额外加成/100)，ATK 同理
    double hp = 0, atk = 0;
    for (final p in allParts) {
      final hpV = p.hp(lv(p));
      final atkV = p.atk(lv(p));
      final xm = 1 + xb(p) / 100.0;
      switch (p.category) {
        case PartCategory.body:
          hp += hpV * (1 + bodyBonusPct / 100.0) * xm;
          break;
        case PartCategory.weapon:
          atk += atkV * (1 + weaponBonusPct / 100.0) * xm;
          break;
        case PartCategory.wheel:
          hp += hpV * (1 + wheelBonusPct / 100.0) * xm;
          atk += atkV * (1 + wheelBonusPct / 100.0) * xm;
          break;
        case PartCategory.gadget:
          hp += hpV * (1 + gadgetBonusPct / 100.0) * xm;
          break;
      }
    }
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
      numExtraWeapons: numExtraWeapons,
      numWheels: numWheels,
      numGadgets: numGadgets,
      numBodySlots: numBodySlots,
      numWeaponSlots: numWeaponSlots,
      numExtraWeaponSlots: numExtraWeaponSlots,
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
  final String server;
  const _PartDataScreen({
    required this.part,
    this.locale = 'zh',
    this.server = 'cn',
  });

  @override
  Widget build(BuildContext context) {
    String t(String zh, String en) => locale == 'zh' ? zh : en;
    final sd = kPartShapeData[part.id];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(pn(part, locale)), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ---- 概览卡片 ----
            Card(
              color: categoryColor(part.category).withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      categoryIcon(part.category),
                      size: 40,
                      color: categoryColor(part.category),
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
              chip(t('HP基础', 'Base HP'), part.hp1.toString(), Colors.blue),
            if (part.atk1 > 0)
              chip(t('ATK基础', 'Base ATK'), part.atk1.toString(), Colors.red),
            chip(
              t('电力', 'PWR'),
              part.power >= 0 ? '+${part.power}' : part.power.toString(),
              Colors.amber[800]!,
            ),
            if (part.slots != null)
              chip(t('插槽', 'Slots'), part.slotsLabelEn(locale), Colors.grey),
            if (part.bonus != null)
              chip(t('加成', 'Bonus'), part.bonusLabelEn(locale), Colors.orange),
            if (part.partClass != PartClass.none)
              chip(t('类型', 'Class'), part.classLabelEn(locale), Colors.brown),
            if (part.mHp1 > 0)
              chip(t('随从HP', 'Minion HP'), part.mHp1.toString(), Colors.teal),
            // ---- 形状 / 插槽位置 / 面积 / 密度 / 重量（仅国际服） ----
            if (server == 'intl' && sd != null) ...[
              const SizedBox(height: 12),
              Text(
                t('形状与物理数据', 'Shape & Physics'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              PartShapeView(data: sd, locale: locale),
              const SizedBox(height: 4),
              Text(
                t(
                  '形状数据仅供参考，未确认完全准确',
                  'Shape data for reference only, not verified',
                ),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              chip(t('面积', 'Area'), sd.area.toStringAsFixed(1), Colors.indigo),
              chip(t('密度', 'Density'), '${sd.density}', Colors.brown),
              chip(
                t('重量', 'Weight'),
                sd.weight.toStringAsFixed(1),
                Colors.deepOrange,
              ),
              chip(
                t('形状', 'Shape'),
                sd.shapeType == 'circle'
                    ? 'circle r=${sd.radius}'
                    : 'polygon ${sd.points?.length}点',
                Colors.grey,
              ),
            ],
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
                headingRowColor: WidgetStateProperty.all(
                  isDark ? const Color(0xFF0D1B2A) : Colors.blue[50],
                ),
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
                            color: incCash > 0
                                ? (isDark ? Colors.white : Colors.black)
                                : Colors.grey,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          incPerToken,
                          style: TextStyle(
                            fontSize: 12,
                            color: incToken > 0
                                ? (isDark ? Colors.white : Colors.black)
                                : Colors.grey,
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

  Widget chip(String label, String value, Color color) {
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

  IconData categoryIcon(PartCategory c) {
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

  Color categoryColor(PartCategory c) {
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
  final String currentServer;
  final bool currentShowSnackBar;
  final bool currentDarkMode;
  final String currentGithubUpdateUrl;
  final String currentMirrorUrl;

  const SettingsScreen({
    super.key,
    required this.currentLocale,
    this.currentServer = 'cn',
    required this.currentShowSnackBar,
    this.currentDarkMode = false,
    required this.currentGithubUpdateUrl,
    required this.currentMirrorUrl,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String locale;
  late String server;
  late bool showSnackBar;
  late bool darkMode;
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
    server = widget.currentServer;
    // 国服只能使用中文
    if (server == 'cn') {
      locale = 'zh';
    }
    showSnackBar = widget.currentShowSnackBar;
    darkMode = widget.currentDarkMode;
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
    return PopScope<Map<String, dynamic>>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, {
            'locale': locale,
            'server': server,
            'showSnackBar': showSnackBar,
            'darkMode': darkMode,
            'githubUpdateUrl': updateUrlController.text.trim(),
            'mirrorUrl': mirrorController.text.trim(),
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(locale == 'zh' ? '设置' : 'Settings'),
          centerTitle: true,
        ),
        body: ListView(
          children: [
            const SizedBox(height: 12),
            // ---- 服务器 ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                locale == 'zh' ? '服务器' : 'Server',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: Text(locale == 'zh' ? '国服' : 'CN Server'),
              subtitle: server == 'cn'
                  ? Text(
                      locale == 'zh' ? '仅支持中文' : 'Chinese only',
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
              leading: Radio<String>(
                value: 'cn',
                groupValue: server,
                onChanged: (value) {
                  setState(() {
                    server = value!;
                    // 国服只能使用中文
                    if (server == 'cn' && locale != 'zh') {
                      locale = 'zh';
                    }
                  });
                },
              ),
            ),
            ListTile(
              title: Text(locale == 'zh' ? '国际服' : 'International'),
              leading: Radio<String>(
                value: 'intl',
                groupValue: server,
                onChanged: (value) {
                  setState(() => server = value!);
                },
              ),
            ),
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
              subtitle: server == 'cn'
                  ? Text(
                      locale == 'zh' ? '国服下不可用' : 'Unavailable on CN server',
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
              enabled: server != 'cn',
              leading: Radio<String>(
                value: 'en',
                groupValue: locale,
                onChanged: server == 'cn'
                    ? null
                    : (value) {
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
            SwitchListTile(
              title: Text(locale == 'zh' ? '夜间模式' : 'Dark mode'),
              subtitle: Text(locale == 'zh' ? '使用深色主题' : 'Use dark theme'),
              value: darkMode,
              onChanged: (value) {
                setState(() {
                  darkMode = value;
                });
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'locale': locale,
                    'server': server,
                    'showSnackBar': showSnackBar,
                    'darkMode': darkMode,
                    'githubUpdateUrl': updateUrlController.text.trim(),
                    'mirrorUrl': mirrorController.text.trim(),
                  });
                },
                child: Text(locale == 'zh' ? '保存' : 'Save'),
              ),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
                final uri = Uri.parse(
                  'https://github.com/InspiraFinder/CatsKit',
                );
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
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Navimoe 链接图标与 Navimoe 文字对齐（紧跟文字行）
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Navimoe C.A.T.S. Engine'),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    locale == 'zh'
                        ? '感谢 "威廉博士" 国际服限定部件的图片'
                        : 'Thanks to "威廉博士" for intl-exclusive part images',
                  ),
                  const SizedBox(height: 2),
                  Text(locale == 'zh' ? '国服数据提供：防防猫' : 'CN data by: 防防猫'),
                  const SizedBox(height: 2),
                  Text(
                    locale == 'zh'
                        ? '感谢 "三体老鸽子", "木小七" 对本项目的贡献'
                        : 'Thanks to "三体老鸽子", "木小七" for their contributions',
                  ),
                  const SizedBox(height: 2),
                  Text(
                    locale == 'zh'
                        ? '感谢各位反馈者对本项目的支持'
                        : 'Thanks to all feedback providers',
                  ),
                ],
              ),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => showNetworkDiagnosis(context, locale),
            ),
            const SizedBox(height: 16),
            const Divider(),
            // ---- 测试群 ----
            ListTile(
              leading: const Icon(Icons.groups, color: Colors.blue),
              title: Text(locale == 'zh' ? '测试群' : 'Test Group'),
              subtitle: Text(
                locale == 'zh' ? 'QQ测试群：791499287' : 'QQ Test Group: 791499287',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _importFromMyGang,
                icon: const Icon(Icons.groups),
                label: const Text('从我的帮派导入名单'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
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

  /// 从「我的帮派」导入成员名单（userId 依次填入输入框，覆盖前 N 个框）
  Future<void> _importFromMyGang() async {
    final slots = await GangStore.load();
    if (!mounted) return;
    final filled = <int>[
      for (int i = 0; i < GangStore.slotCount; i++)
        if (slots[i] != null && !slots[i]!.isEmpty) i,
    ];
    if (filled.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('我的帮派还没有数据，请先在「帮派统计」导入'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('从我的帮派导入名单'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final i in filled)
              ListTile(
                dense: true,
                leading: const Icon(Icons.groups, color: Colors.teal),
                title: Text(
                  slots[i]!.name.isEmpty ? '帮派 ${i + 1}' : slots[i]!.name,
                ),
                subtitle: Text('${slots[i]!.memberCount} 名成员'),
                onTap: () => Navigator.pop(ctx, i),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final userIds = [for (final m in slots[selected]!.members) m.userId];
    setState(() {
      for (int i = 0; i < controllers.length; i++) {
        controllers[i].text = i < userIds.length ? userIds[i] : '';
      }
    });
    final n = userIds.length > controllers.length
        ? controllers.length
        : userIds.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已导入 $n 名成员名单'),
        duration: const Duration(seconds: 1),
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
