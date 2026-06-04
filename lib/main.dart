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
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '查车工具',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<String> boxTexts = List<String>.filled(25, '');
  List<String> boxButtonNumbers = List<String>.filled(25, '');
  int selectedButton = 0;
  bool isClearMode = false;
  String _locale = 'zh'; // 'zh' 中文，'en' 英文

  // 辅助文本方法
  String _t(String zh, String en) {
    return _locale == 'zh' ? zh : en;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('查车工具', 'Vehicle Check Tool')),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(_t('菜单功能开发中', 'Menu under development')),
                  duration: const Duration(milliseconds: 800)),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              // 跳转到设置界面，等待返回的语言代码
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        SettingsScreen(currentLocale: _locale)),
              );
              if (result != null && result != _locale) {
                setState(() {
                  _locale = result;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(_t('语言已切换', 'Language changed')),
                      duration: const Duration(seconds: 1)),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildGridBoxes(),
              const SizedBox(height: 30),
              _buildButtonRow(),
              const SizedBox(height: 30),
              _buildActionRow(),
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
          String newStr = old.replaceAll(digit, '');
          boxButtonNumbers[i] = newStr;
          anyCleared = true;
        }
      }
    });
    if (anyCleared) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('已清除所有方框中的数字 $buttonNumber',
              'Cleared all boxes containing number $buttonNumber')),
          duration: const Duration(milliseconds: 800),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('没有找到包含数字 $buttonNumber 的方框',
              'No boxes found containing number $buttonNumber')),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  void _toggleButton(int buttonNumber) {
    setState(() {
      if (selectedButton == buttonNumber) {
        selectedButton = 0;
      } else {
        selectedButton = buttonNumber;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: selectedButton == 0
            ? Text(_t('已取消选择', 'Deselected'))
            : Text(_t('已选择按钮 P$selectedButton，现在可以点击方框',
                'Selected P$selectedButton, tap a box to add')),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: ElevatedButton(
              onPressed: _onImportPressed,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _t('导入', 'Import'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: isClearMode ? Colors.orange[800] : Colors.grey,
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
                    ? _t('清除模式 (开)', 'Clear Mode (ON)')
                    : _t('清除模式 (关)', 'Clear Mode (OFF)'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _t('清除全部', 'Clear All'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _toggleClearMode() {
    setState(() {
      isClearMode = !isClearMode;
      if (isClearMode) {
        selectedButton = 0;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isClearMode
            ? _t('清除模式已开启，点击方框清除数字，点击 P1-P6 清除所有对应的数字',
                'Clear mode ON: tap a box to clear its number, tap P1-P6 to clear matching numbers')
            : _t('清除模式已关闭', 'Clear mode OFF')),
        duration: const Duration(milliseconds: 1000),
      ),
    );
  }

  void _clearAllNumbers() {
    setState(() {
      for (int i = 0; i < boxButtonNumbers.length; i++) {
        boxButtonNumbers[i] = '';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t('已清除所有方框下方的数字', 'Cleared all numbers below boxes')),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _onGridBoxPressed(int boxIndex) {
    if (isClearMode) {
      setState(() {
        if (boxButtonNumbers[boxIndex].isNotEmpty) {
          boxButtonNumbers[boxIndex] = '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('已清除方框 ${boxIndex + 1} 下方的数字',
                  'Cleared number of box ${boxIndex + 1}')),
              duration: const Duration(milliseconds: 500),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('方框 ${boxIndex + 1} 下方本来就没有数字',
                  'Box ${boxIndex + 1} already has no number')),
              duration: const Duration(milliseconds: 500),
            ),
          );
        }
      });
      return;
    }

    if (selectedButton == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _t('请先选择一个按钮（P1-P6）', 'Please select a button first (P1-P6)')),
          duration: const Duration(milliseconds: 800),
        ),
      );
      return;
    }

    setState(() {
      String currentNumbers = boxButtonNumbers[boxIndex];
      if (currentNumbers.length < 3) {
        boxButtonNumbers[boxIndex] = currentNumbers + selectedButton.toString();
      } else {
        boxButtonNumbers[boxIndex] = selectedButton.toString();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t(
            '已向方框 ${boxIndex + 1} 添加按钮 $selectedButton，当前: ${boxButtonNumbers[boxIndex]}',
            'Added button $selectedButton to box ${boxIndex + 1}, now: ${boxButtonNumbers[boxIndex]}')),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _onImportPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImportScreen(
          initialBoxTexts: boxTexts,
          onImportConfirmed: (updatedTexts) {
            setState(() {
              boxTexts = updatedTexts;
            });
          },
        ),
      ),
    );
  }
}

// 设置界面
class SettingsScreen extends StatelessWidget {
  final String currentLocale;

  const SettingsScreen({Key? key, required this.currentLocale})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          ListTile(
            title: const Text('中文'),
            leading: Radio<String>(
              value: 'zh',
              groupValue: currentLocale,
              onChanged: (value) {
                Navigator.pop(context, 'zh');
              },
            ),
          ),
          ListTile(
            title: const Text('English'),
            leading: Radio<String>(
              value: 'en',
              groupValue: currentLocale,
              onChanged: (value) {
                Navigator.pop(context, 'en');
              },
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              currentLocale == 'zh'
                  ? '选择您喜欢的语言'
                  : 'Select your preferred language',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// 导入界面（保持不变，但增加简单国际化）
class ImportScreen extends StatefulWidget {
  final List<String> initialBoxTexts;
  final Function(List<String>) onImportConfirmed;

  const ImportScreen(
      {Key? key,
      required this.initialBoxTexts,
      required this.onImportConfirmed})
      : super(key: key);

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  late List<TextEditingController> controllers;

  @override
  void initState() {
    super.initState();
    controllers = List<TextEditingController>.generate(
      25,
      (index) => TextEditingController(text: widget.initialBoxTexts[index]),
    );
  }

  @override
  void dispose() {
    for (var controller in controllers) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入文本'),
        centerTitle: true,
      ),
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
                          child: Text('${index + 1}:',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: controllers[index],
                            decoration: InputDecoration(
                              hintText: '输入文本...',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('取消',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _onConfirmPressed,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('确定',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
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
    List<String> updatedTexts = controllers.map((c) => c.text).toList();
    widget.onImportConfirmed(updatedTexts);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导入成功！'), duration: Duration(seconds: 1)));
  }
}
