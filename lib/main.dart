import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
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
      home: const MainMenuScreen(),
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
                MaterialPageRoute(builder: (_) => const BuildToolScreen()),
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
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _locale = result['locale'];
        _showSnackBar = result['showSnackBar'];
        githubUpdateUrl = result['githubUpdateUrl'] ?? githubUpdateUrl;
      });
      _showMessage('语言已切换', 'Language changed');
    }
  }
}

// ==================== 主菜单 ====================
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

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
                  MaterialPageRoute(builder: (_) => const BuildToolScreen()),
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
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 组车工具（占位） ====================
class BuildToolScreen extends StatelessWidget {
  const BuildToolScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  ),
                ),
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'menu', child: Text('返回主菜单')),
            const PopupMenuItem(value: 'vehicle', child: Text('查车工具')),
            const PopupMenuItem(value: 'settings', child: Text('通用设置')),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction, size: 80, color: Colors.orange[300]),
              const SizedBox(height: 24),
              const Text(
                '组车工具',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                '功能开发中，敬请期待...',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 设置界面 ====================
class SettingsScreen extends StatefulWidget {
  final String currentLocale;
  final bool currentShowSnackBar;
  final String currentGithubUpdateUrl;

  const SettingsScreen({
    super.key,
    required this.currentLocale,
    required this.currentShowSnackBar,
    required this.currentGithubUpdateUrl,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String locale;
  late bool showSnackBar;
  late TextEditingController _updateUrlController;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    locale = widget.currentLocale;
    showSnackBar = widget.currentShowSnackBar;
    _updateUrlController = TextEditingController(
      text: widget.currentGithubUpdateUrl,
    );
  }

  @override
  void dispose() {
    _updateUrlController.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    const apiUrl =
        'https://api.github.com/repos/InspiraFinder/CatsKit/releases/latest';

    setState(() => _isDownloading = true);

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
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(apiUrl));
      request.headers.set('User-Agent', 'CatsKit');
      request.headers.set('Accept', 'application/vnd.github+json');
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String? ?? 'unknown';
      final assets = json['assets'] as List<dynamic>? ?? [];

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isDownloading = false);

      if (assets.isEmpty) {
        // 没有 asset 时，直接填入 release 页面地址
        _updateUrlController.text =
            'https://github.com/InspiraFinder/CatsKit/releases/tag/$tagName';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('发现最新版 $tagName，已填入 release 页面地址')),
          );
        }
        return;
      }

      // 有 asset 时，取第一个可下载的文件
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
    } catch (e) {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setState(() => _isDownloading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('检查更新失败: $e')));
    }
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

    setState(() {
      _isDownloading = true;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final client = HttpClient();
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'CatsKit');
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final bytes = await response.fold<List<int>>(<int>[], (buffer, data) {
        buffer.addAll(data);
        return buffer;
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
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新包已下载到: ${outputFile.path}')));
    } catch (e) {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('下载失败: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
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
                          builder: (_) => const BuildToolScreen(),
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
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'locale': locale,
                  'showSnackBar': showSnackBar,
                  'githubUpdateUrl': _updateUrlController.text.trim(),
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
