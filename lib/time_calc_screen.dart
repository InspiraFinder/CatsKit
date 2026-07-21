import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// 战斗时间计算界面
class TimeCalcScreen extends StatefulWidget {
  final String locale;
  const TimeCalcScreen({super.key, this.locale = 'zh'});

  @override
  State<TimeCalcScreen> createState() => _TimeCalcScreenState();
}

class _TimeCalcScreenState extends State<TimeCalcScreen> {
  bool get _isZh => widget.locale == 'zh';
  final ImagePicker _picker = ImagePicker();
  File? _image;
  bool _isProcessing = false;
  String? _error;

  // OCR 原始字段
  String _rawMyScorePerMin = '';
  String _rawMyScore = '';
  String _rawScoreLine = '';
  String _rawTimeLeft = '';
  String _rawEnemyScore = '';
  String _rawEnemyScorePerMin = '';

  // 计算结果
  String? _resultTimeLeft;
  String? _resultEndTime;
  String? _resultWinner;
  String? _resultMyFinalScore;
  String? _resultEnemyFinalScore;
  bool _hasResult = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _error = null;
        _hasResult = false;
      });
      _calculate();
    }
  }

  /// 解析剩余时间字符串为分钟数
  double? _parseTimeToMinutes(String timeStr) {
    timeStr = timeStr.toLowerCase().trim();
    double total = 0;
    // 匹配 "Xh YYm" / "Xm" / "Xh" 等格式
    // 匹配 "Xh YYm" / "Xm" / "Xh" / "X时Y分" / "X分" / "X时" 等格式
    final hourReg = RegExp(r'(\d+)\s*h');
    final minReg = RegExp(r'(\d+)\s*m');
    final cnHourReg = RegExp(r'(\d+)\s*时');
    final cnMinReg = RegExp(r'(\d+)\s*分');
    final hourMatch =
        hourReg.firstMatch(timeStr) ?? cnHourReg.firstMatch(timeStr);
    final minMatch = minReg.firstMatch(timeStr) ?? cnMinReg.firstMatch(timeStr);
    if (hourMatch != null) total += int.parse(hourMatch.group(1)!) * 60.0;
    if (minMatch != null) total += int.parse(minMatch.group(1)!);
    return total > 0 ? total : null;
  }

  /// 按语言格式化分钟数
  String _formatMinutes(double minutes) {
    final totalMin = minutes.round();
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (_isZh) {
      if (h > 0 && m > 0) return '$h时$m分';
      if (h > 0) return '$h时';
      return '$m分';
    } else {
      if (h > 0 && m > 0) return '${h}h ${m}m';
      if (h > 0) return '${h}h';
      return '${m}m';
    }
  }

  Future<void> _calculate() async {
    if (_image == null) return;

    setState(() => _isProcessing = true);

    try {
      final scriptPath =
          '${Directory.current.path}${Platform.pathSeparator}assets${Platform.pathSeparator}ocr${Platform.pathSeparator}catskit_ocr.py';
      final encodedPath = base64Encode(utf8.encode(_image!.path));

      final result = await Process.run('python', [
        scriptPath,
        encodedPath,
      ], workingDirectory: Directory.current.path);

      if (result.exitCode != 0) {
        final stderr = result.stderr.toString().trim();
        throw Exception(
          stderr.isNotEmpty ? stderr : '进程退出码: ${result.exitCode}',
        );
      }

      final json = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
      if (json['error'] != null) throw Exception(json['error'] as String);

      final fields = json['fields'] as Map<String, dynamic>? ?? {};

      final myScorePerMin = fields['my_score_per_min'] as String? ?? '';
      final myScore = fields['my_score'] as String? ?? '';
      final scoreLine = fields['score_line'] as String? ?? '';
      final timeLeft = fields['time_left'] as String? ?? '';
      final enemyScore = fields['enemy_score'] as String? ?? '';
      final enemyScorePerMin = fields['enemy_score_per_min'] as String? ?? '';

      // ---- 结算逻辑 ----
      final now = DateTime.now();
      String resultTimeLeft = '未知';
      String? resultEndTime;
      String resultWinner = '无法判定';
      String resultMyFinal = myScore;
      String resultEnemyFinal = enemyScore;

      final remainingMin = _parseTimeToMinutes(timeLeft);
      // 实际结束分钟数（默认正常结束，若有队伍达线则提前）
      double actualEndMin = remainingMin ?? 0;

      if (remainingMin != null && remainingMin > 0) {
        // 解析分数
        final myScoreVal = int.tryParse(myScore.replaceAll(',', ''));
        final enemyScoreVal = int.tryParse(enemyScore.replaceAll(',', ''));
        final scoreLineVal = int.tryParse(scoreLine.replaceAll(',', ''));

        // 解析每分钟得分（去掉 + 号，空值视为 0）
        final mySPM =
            int.tryParse(
              myScorePerMin.replaceAll('+', '').replaceAll(',', ''),
            ) ??
            0;
        final enemySPM =
            int.tryParse(
              enemyScorePerMin.replaceAll('+', '').replaceAll(',', ''),
            ) ??
            0;

        if (myScoreVal != null &&
            enemyScoreVal != null &&
            scoreLineVal != null) {
          String winner;
          int myFinal, enemyFinal;

          // 每分钟得分至少为 0
          final effMySPM = mySPM > 0 ? mySPM : 0;
          final effEnemySPM = enemySPM > 0 ? enemySPM : 0;

          // ---- 情况 1：已有一方达到/超过分数线 ----
          if (myScoreVal >= scoreLineVal && enemyScoreVal < scoreLineVal) {
            winner = '我方获胜 🏆';
            myFinal = myScoreVal;
            enemyFinal = enemyScoreVal;
            actualEndMin = 0;
          } else if (enemyScoreVal >= scoreLineVal &&
              myScoreVal < scoreLineVal) {
            winner = '敌方获胜';
            enemyFinal = enemyScoreVal;
            myFinal = myScoreVal;
            actualEndMin = 0;
          } else if (myScoreVal >= scoreLineVal &&
              enemyScoreVal >= scoreLineVal) {
            // 双方都已达线（极少见）
            if (myScoreVal >= enemyScoreVal) {
              winner = '我方获胜 🏆';
            } else {
              winner = '敌方获胜';
            }
            myFinal = myScoreVal;
            enemyFinal = enemyScoreVal;
            actualEndMin = 0;
          } else {
            // ---- 情况 2：双方都未达线，计算谁会先到 ----
            double? timeMe; // 我到达线所需分钟
            double? timeEnemy; // 敌方到达线所需分钟

            if (effMySPM > 0) {
              timeMe = (scoreLineVal - myScoreVal) / effMySPM;
            }
            if (effEnemySPM > 0) {
              timeEnemy = (scoreLineVal - enemyScoreVal) / effEnemySPM;
            }

            // 我方能到达且先于敌方到达/敌方无法到达
            if (timeMe != null &&
                timeMe <= remainingMin &&
                (timeEnemy == null || timeMe < timeEnemy)) {
              winner = '我方获胜 🏆';
              myFinal = scoreLineVal;
              enemyFinal = enemyScoreVal + (effEnemySPM * timeMe).round();
              actualEndMin = timeMe;
            }
            // 敌方先到达
            else if (timeEnemy != null &&
                timeEnemy <= remainingMin &&
                (timeMe == null || timeEnemy < timeMe)) {
              winner = '敌方获胜';
              enemyFinal = scoreLineVal;
              myFinal = myScoreVal + (effMySPM * timeEnemy).round();
              actualEndMin = timeEnemy;
            }
            // 同时到达
            else if (timeMe != null &&
                timeEnemy != null &&
                timeMe <= remainingMin &&
                (timeMe - timeEnemy).abs() < 0.01) {
              winner = '平局';
              myFinal = scoreLineVal;
              enemyFinal = scoreLineVal;
              actualEndMin = timeMe;
            }
            // 无人能在剩余时间内到达 → 时间结束时比分数
            else {
              myFinal = myScoreVal + (effMySPM * remainingMin).round();
              enemyFinal = enemyScoreVal + (effEnemySPM * remainingMin).round();
              if (myFinal > enemyFinal) {
                winner = '我方获胜 🏆';
              } else if (enemyFinal > myFinal) {
                winner = '敌方获胜';
              } else {
                winner = '平局';
              }
            }
          }

          resultMyFinal = myFinal.toString();
          resultEnemyFinal = enemyFinal.toString();
          resultWinner = winner;

          // 计算结束时间：取达线时间与正常结束时间中较早者
          final endMin = actualEndMin < remainingMin
              ? actualEndMin
              : remainingMin;
          final endTime = now.add(Duration(minutes: endMin.round()));
          resultEndTime =
              '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
          resultTimeLeft = _formatMinutes(endMin);
        } else if (myScoreVal != null && enemyScoreVal != null) {
          // 缺少每分钟得分，只能按当前分数判断
          if (myScoreVal > enemyScoreVal) {
            resultWinner = '我方领先';
          } else if (enemyScoreVal > myScoreVal) {
            resultWinner = '敌方领先';
          } else {
            resultWinner = '平局';
          }
        }
      }

      // 如果还没设置结束时间（如缺少分数线时），用正常剩余时间
      if (resultEndTime == null && remainingMin != null && remainingMin > 0) {
        final endTime = now.add(Duration(minutes: remainingMin.round()));
        resultEndTime =
            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
        resultTimeLeft = _formatMinutes(remainingMin);
      }

      if (!mounted) return;
      setState(() {
        _rawMyScorePerMin = myScorePerMin;
        _rawMyScore = myScore;
        _rawScoreLine = scoreLine;
        _rawTimeLeft = timeLeft;
        _rawEnemyScore = enemyScore;
        _rawEnemyScorePerMin = enemyScorePerMin;
        _resultTimeLeft = resultTimeLeft;
        _resultEndTime = resultEndTime;
        _resultWinner = resultWinner;
        _resultMyFinalScore = resultMyFinal;
        _resultEnemyFinalScore = resultEnemyFinal;
        _hasResult = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '计算失败: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('时间计算'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: _showPickOptions,
            tooltip: '选择图片',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ---- 图片预览 ----
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[100],
              child: _image != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(_image!, fit: BoxFit.contain),
                        if (_isProcessing)
                          Container(
                            color: Colors.black26,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    '计算中...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            '点击右上角选择截图',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red[700], fontSize: 14),
                ),
              ),

            if (!_isProcessing && _image != null && !_hasResult)
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _calculate,
                  icon: const Icon(Icons.calculate),
                  label: const Text('开始计算'),
                ),
              ),

            // ---- 识别数据 ----
            if (_hasResult) ...[
              _buildSectionCard(
                _isZh ? '原始数据' : 'Raw Data',
                Icons.abc,
                Colors.blue,
                [
                  _dataRow(_isZh ? '我方每分钟得分' : 'Our SPM', _rawMyScorePerMin),
                  _dataRow(_isZh ? '我方分数' : 'Our Score', _rawMyScore),
                  _dataRow(_isZh ? '分数线' : 'Target Score', _rawScoreLine),
                  _dataRow(_isZh ? '剩余时间' : 'Time Left', _rawTimeLeft),
                  _dataRow(_isZh ? '敌方分数' : 'Enemy Score', _rawEnemyScore),
                  _dataRow(
                    _isZh ? '敌方每分钟得分' : 'Enemy SPM',
                    _rawEnemyScorePerMin,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ---- 结算结果 ----
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _dataRow(String label, String value) {
    final isEmpty = value.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: Text(
              isEmpty ? '-' : value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isEmpty ? Colors.grey[400] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 4,
        color: Colors.blue[50],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.blue[200]!, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events, size: 22, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    _isZh ? '结算结果' : 'Result',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(),
              _resultRow(
                Icons.timer_outlined,
                _isZh ? '剩余时间' : 'Time Left',
                _resultTimeLeft ?? '',
              ),
              if (_resultEndTime != null)
                _resultRow(
                  Icons.schedule,
                  _isZh ? '战斗结束' : 'End Time',
                  _resultEndTime!,
                ),
              const SizedBox(height: 8),
              _resultRow(
                Icons.emoji_events,
                _isZh ? '胜利方' : 'Winner',
                _resultWinner ?? '',
              ),
              const SizedBox(height: 8),
              _resultRow(
                Icons.people,
                _isZh ? '我方最终分数' : 'Our Final Score',
                _resultMyFinalScore ?? '',
              ),
              _resultRow(
                Icons.people_outline,
                _isZh ? '敌方最终分数' : 'Enemy Final Score',
                _resultEnemyFinalScore ?? '',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue[700]),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
          const Spacer(),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
