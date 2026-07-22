import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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
  // 识别到的文字框（用于叠加显示）
  List<Map<String, dynamic>> _textItems = [];
  bool _showOverlay = false;
  bool _showRegions = false;
  int _imageWidth = 0;
  int _imageHeight = 0;
  List<double>? _zoneBoundaries; // [leftBound, rightBound] 动态三区边界

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (pickedFile == null) return;

      // 将图片复制到应用缓存目录（兼容 content:// URI）
      final bytes = await pickedFile.readAsBytes();
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}${Platform.pathSeparator}ocr_input_${DateTime.now().millisecondsSinceEpoch}.tmp',
      );
      await tempFile.writeAsBytes(bytes, flush: true);

      // 获取图片尺寸
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _imageWidth = frame.image.width;
        _imageHeight = frame.image.height;
        codec.dispose();
      } catch (_) {
        _imageWidth = 0;
        _imageHeight = 0;
      }

      if (!mounted) return;
      setState(() {
        _image = tempFile;
        _error = null;
        _hasResult = false;
        _textItems = [];
        _showOverlay = false;
        _showRegions = false;
        _zoneBoundaries = null;
      });
      _calculate();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '图片处理失败: $e');
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

  /// Android：使用 Google ML Kit OCR（含图片预处理）
  Future<List<Map<String, dynamic>>> _runAndroidOcr(File image) async {
    if (!await image.exists()) throw Exception('图片文件不存在');

    // 预处理：生成 5 张变体图片
    final variants = await _generateVariants(image);
    final allResults = <List<Map<String, dynamic>>>[];

    for (final variant in variants) {
      try {
        final inputImage = InputImage.fromFilePath(variant.path);
        final recognizer = TextRecognizer(
          script: TextRecognitionScript.chinese,
        );
        try {
          final RecognizedText recognizedText = await recognizer.processImage(
            inputImage,
          );
          final items = <Map<String, dynamic>>[];
          for (final block in recognizedText.blocks) {
            for (final line in block.lines) {
              items.add({
                'text': line.text,
                'x': line.boundingBox.left.toInt(),
                'y': line.boundingBox.top.toInt(),
                'w': line.boundingBox.width.toInt(),
                'h': line.boundingBox.height.toInt(),
              });
            }
          }
          allResults.add(items);
        } finally {
          await recognizer.close();
        }
      } catch (_) {
        // 单张变体识别失败不影响整体
      }
      // 清理变体临时文件（保留原图）
      if (variant.path != image.path) {
        try {
          await variant.delete();
        } catch (_) {}
      }
    }

    // 合并各变体结果：以原图结果为主，用其他变体补充
    return _mergeResults(allResults, image);
  }

  /// 预处理图片，生成 5 张变体
  Future<List<File>> _generateVariants(File source) async {
    final bytes = await source.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final original = frame.image;
    final w = original.width;
    final h = original.height;
    codec.dispose();

    final tempDir = Directory.systemTemp;
    final List<File> files = [source]; // 第 0 张为原图

    // 缩放至标准分辨率
    int targetW, targetH;
    if (w * 9 > h * 16) {
      targetH = 720;
      targetW = (w * targetH / h).round();
    } else {
      targetW = 1280;
      targetH = (h * targetW / w).round();
    }

    // 获取原始 RGBA 字节
    final byteData = await original.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) return files;

    final srcPixels = byteData.buffer.asUint8List();
    final stride = w * 4;

    // ---- 生成 4 张变体 ----
    // 1. 左移 2 像素（最左2列移到右边）
    // 2. 右移 2 像素（最右2列移到左边）
    // 3. 蓝色通道（只保留 B 通道）
    // 4. 红色通道（只保留 R 通道）

    Future<File> saveImage(ui.Image img, String suffix) async {
      final pngData = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File(
        '${tempDir.path}${Platform.pathSeparator}ocr_var_$suffix.png',
      );
      if (pngData != null)
        await f.writeAsBytes(pngData.buffer.asUint8List(), flush: true);
      return f;
    }

    Future<void> processVariant(
      String name,
      void Function(Uint8List pixels, int w2, int h2) process,
    ) async {
      final w2 = w, h2 = h;
      final pixels = Uint8List.fromList(srcPixels);
      process(pixels, w2, h2);
      final img = await _pixelsToImage(pixels, w2, h2);
      files.add(await saveImage(img, name));
    }

    // 左移 2 像素
    await processVariant('shift_l', (p, w2, h2) {
      final s = w2 * 4;
      for (var y = 0; y < h2; y++) {
        final row = y * s;
        final left2 = p.sublist(row, row + 8);
        for (var x = 0; x < w2 - 2; x++) {
          final src = row + (x + 2) * 4;
          p[row + x * 4] = p[src];
          p[row + x * 4 + 1] = p[src + 1];
          p[row + x * 4 + 2] = p[src + 2];
          p[row + x * 4 + 3] = p[src + 3];
        }
        for (var i = 0; i < 8; i++) p[row + (w2 - 2) * 4 + i] = left2[i];
      }
    });

    // 右移 2 像素
    await processVariant('shift_r', (p, w2, h2) {
      final s = w2 * 4;
      for (var y = 0; y < h2; y++) {
        final row = y * s;
        final right2 = p.sublist(row + (w2 - 2) * 4, row + w2 * 4);
        for (var x = w2 - 1; x >= 2; x--) {
          final src = row + (x - 2) * 4;
          p[row + x * 4] = p[src];
          p[row + x * 4 + 1] = p[src + 1];
          p[row + x * 4 + 2] = p[src + 2];
          p[row + x * 4 + 3] = p[src + 3];
        }
        for (var i = 0; i < 8; i++) p[row + i] = right2[i];
      }
    });

    // 蓝色通道
    await processVariant('blue', (p, w2, h2) {
      for (var i = 0; i < p.length; i += 4) {
        p[i] = 0; // R = 0
        p[i + 1] = 0; // G = 0
        // B 和 A 保持不变
      }
    });

    // 红色通道
    await processVariant('red', (p, w2, h2) {
      for (var i = 0; i < p.length; i += 4) {
        p[i + 1] = 0; // G = 0
        p[i + 2] = 0; // B = 0
        // R 和 A 保持不变
      }
    });

    return files;
  }

  /// 将 RGBA 像素数据转为 ui.Image
  Future<ui.Image> _pixelsToImage(Uint8List pixels, int w, int h) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      w,
      h,
      ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );
    return completer.future;
  }

  /// 合并多张变体的 OCR 结果
  List<Map<String, dynamic>> _mergeResults(
    List<List<Map<String, dynamic>>> allResults,
    File originalImage,
  ) {
    if (allResults.isEmpty) return [];
    // 以原图结果（第一组）为主
    final primary = allResults.first;
    if (primary.isEmpty && allResults.length > 1) return allResults[1];

    // 用其他变体补充原图未识别到的文字
    final seenTexts = primary.map((it) => it['text'] as String).toSet();
    for (var i = 1; i < allResults.length; i++) {
      for (final item in allResults[i]) {
        final t = item['text'] as String;
        if (!seenTexts.contains(t)) {
          primary.add(item);
          seenTexts.add(t);
        }
      }
    }
    return primary;
  }

  /// 从纯文本中识别 6 个字段（不依赖坐标）
  Map<String, String> _classifyFromText(String text) {
    final result = {
      'my_score_per_min': '',
      'my_score': '',
      'score_line': '',
      'time_left': '',
      'enemy_score': '',
      'enemy_score_per_min': '',
    };

    // 提取 "+数字" 格式（每分钟得分）
    final plusNums = RegExp(r'\+\d+').allMatches(text).toList();
    if (plusNums.isNotEmpty) {
      result['my_score_per_min'] = plusNums[0].group(0) ?? '';
      if (plusNums.length > 1) {
        result['enemy_score_per_min'] = plusNums[1].group(0) ?? '';
      }
    }

    // 提取时间格式
    final timeMatch = RegExp(
      r'\d+\s*[hm时]',
      caseSensitive: false,
    ).firstMatch(text);
    if (timeMatch != null) {
      result['time_left'] = timeMatch.group(0) ?? '';
    }

    // 提取所有数字（3-7位）
    final numbers = RegExp(r'\b\d{3,7}\b').allMatches(text).toList();
    final numValues = numbers.map((m) => m.group(0) ?? '').toList();

    if (numValues.isNotEmpty) {
      numValues.sort((a, b) => int.parse(b).compareTo(int.parse(a)));
      result['score_line'] = numValues.first;
      if (numValues.length >= 3) {
        result['my_score'] = numValues[1];
        result['enemy_score'] = numValues[2];
      } else if (numValues.length == 2) {
        result['my_score'] = numValues[1];
      }
    }

    return result;
  }

  /// Windows/桌面：使用 Python RapidOCR
  Future<Map<String, String>> _runPythonOcr(File image) async {
    // 从 Flutter asset bundle 提取 Python 脚本到临时目录
    final byteData = await rootBundle.load('assets/ocr/catskit_ocr.py');
    final tempDir = Directory.systemTemp;
    final scriptFile = File(
      '${tempDir.path}${Platform.pathSeparator}catskit_ocr.py',
    );
    await scriptFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

    final encodedPath = base64Encode(utf8.encode(image.path));
    final result = await Process.run('python', [scriptFile.path, encodedPath]);

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      throw Exception(stderr.isNotEmpty ? stderr : '进程退出码: ${result.exitCode}');
    }

    final json = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    if (json['error'] != null) throw Exception(json['error'] as String);
    return (json['fields'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v as String? ?? ''),
    );
  }

  /// 将合并文本（如 "+9 19479" / "+124) 19479"）拆分为独立项
  List<Map<String, dynamic>> _splitCombinedItems(
    List<Map<String, dynamic>> items,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final it in items) {
      final text = it['text'] as String;
      final x = it['x'] as int;
      final w = it['w'] as int;
      final y = it['y'] as int;
      final h = it['h'] as int;

      // 找出所有数字序列及其前后缀
      // 匹配: 可选 +/-(，然后 1-6 位数字，可选 )/%等噪声字符
      final allMatches = <_NumMatch>[];
      for (final m in RegExp(r'[+\-]?\(?\d{1,7}\)?').allMatches(text)) {
        final raw = m.group(0)!;
        final digitsOnly = raw.replaceAll(RegExp(r'[^\d]'), '');
        if (digitsOnly.isEmpty) continue;
        final val = int.parse(digitsOnly);
        allMatches.add(
          _NumMatch(
            raw: raw,
            digits: digitsOnly,
            value: val,
            start: m.start,
            end: m.end,
          ),
        );
      }

      // 分类：SPM（1-3位, 值≤300）和 SCORE（值≤150000）
      final spmMatches = allMatches
          .where((m) => m.digits.length <= 3 && m.value <= 300)
          .toList();
      final scoreMatches = allMatches
          .where((m) => m.value <= 150000 && m.value >= 100)
          .toList();
      // 如果一个数字同时符合两者（如 "126"），SPM 优先取短的，SCORE 取长的
      final spmItem = spmMatches.isNotEmpty ? spmMatches.first : null;
      final scoreItem = scoreMatches.isNotEmpty
          ? scoreMatches.reduce(
              (a, b) => a.digits.length >= b.digits.length ? a : b,
            )
          : null;

      // 如果同时有 SPM 和 SCORE 且不重叠，则拆分
      if (spmItem != null &&
          scoreItem != null &&
          spmItem.start != scoreItem.start) {
        for (final m in [spmItem, scoreItem]) {
          // 提取时标准化：-号变+号，去掉噪声字符
          var clean = m.raw;
          if (clean.startsWith('-')) clean = '+${clean.substring(1)}';
          clean = clean.replaceAll(RegExp(r'[^+\d]'), '');
          if (clean.startsWith('+') && clean.length == 1) continue;
          // 保留原坐标（不估算位置，避免跨区错位）
          result.add({'text': clean, 'x': x, 'y': y, 'w': w, 'h': h});
        }
      } else {
        // 无法拆分，保留原文（不清除中文，避免 "20时 49分" 被破坏）
        result.add({'text': text.trim(), 'x': x, 'y': y, 'w': w, 'h': h});
      }
    }
    return result;
  }

  /// 根据文字坐标动态划定三区并分类（Android 端使用）
  Map<String, dynamic> _classifyByPosition(
    List<Map<String, dynamic>> items,
    int imgW,
    int imgH,
  ) {
    final result = {
      'my_score_per_min': '',
      'my_score': '',
      'score_line': '',
      'time_left': '',
      'enemy_score': '',
      'enemy_score_per_min': '',
    };

    if (items.isEmpty || imgW <= 0) {
      return {'fields': result, 'boundaries': null};
    }

    // 给每个 item 加上中心坐标
    for (final it in items) {
      it['cx'] = (it['x'] as int) + (it['w'] as int) ~/ 2;
      it['cy'] = (it['y'] as int) + (it['h'] as int) ~/ 2;
    }

    // 只分析顶部 30%
    final topItems = items
        .where((it) => (it['cy'] as int) < imgH * 0.30)
        .toList();
    if (topItems.isEmpty) {
      return {'fields': result, 'boundaries': null};
    }

    // 按 cx 排序
    topItems.sort((a, b) => (a['cx'] as int).compareTo(b['cx'] as int));

    // 用固定百分比划分三区（动态聚簇易被宽标题干扰）
    final lb = imgW * 0.38;
    final rb = imgW * 0.62;
    final groups = [
      topItems.where((it) => (it['cx'] as int) < lb).toList(),
      topItems
          .where((it) => (it['cx'] as int) >= lb && (it['cx'] as int) <= rb)
          .toList(),
      topItems.where((it) => (it['cx'] as int) > rb).toList(),
    ];

    // 取每组的最下行
    List<Map<String, dynamic>> bottomRow(List<Map<String, dynamic>> zone) {
      if (zone.isEmpty) return [];
      zone.sort((a, b) => (a['cy'] as int).compareTo(b['cy'] as int));
      final rows = <List<Map<String, dynamic>>>[];
      var cur = [zone.first];
      for (var i = 1; i < zone.length; i++) {
        final gap = (zone[i]['cy'] as int) - (cur.last['cy'] as int);
        final avgH = ((cur.last['h'] as int) + (zone[i]['h'] as int)) / 2;
        if (gap < avgH * 0.7) {
          cur.add(zone[i]);
        } else {
          rows.add(cur);
          cur = [zone[i]];
        }
      }
      if (cur.isNotEmpty) rows.add(cur);
      return rows.isNotEmpty ? rows.last : [];
    }

    /// 提取每分钟得分：值 1-300，可选 +/-
    String spm(List<Map<String, dynamic>> items) {
      final cand = <(String, int)>[];
      for (final it in items) {
        final t = (it['text'] as String).trim().replaceAll(',', '');
        final digits = t.replaceAll(RegExp(r'[^\d]'), '');
        if (digits.isEmpty) continue;
        final v = int.tryParse(digits);
        if (v != null && v >= 1 && v <= 300) {
          // 标准化：确保有 + 前缀
          final normalized = t.startsWith('-')
              ? '+$digits'
              : t.startsWith('+')
              ? t
              : '+$digits';
          cand.add((normalized, v));
        }
      }
      if (cand.isNotEmpty) {
        cand.sort((a, b) => b.$2.compareTo(a.$2));
        return cand.first.$1;
      }
      return '';
    }

    /// 提取分数：值 0-150000，排除以 + 开头且 ≤300 的 SPM 值
    String num(List<Map<String, dynamic>> items) {
      final cand = <(String, int)>[];
      for (final it in items) {
        final t = (it['text'] as String).trim().replaceAll(',', '');
        final digits = t.replaceAll(RegExp(r'[^\d]'), '');
        if (digits.isEmpty) continue;
        final v = int.tryParse(digits);
        if (v == null || v < 0 || v > 150000) continue;
        // 排除 SPM 格式：以 + 开头且值 ≤ 300
        if ((t.startsWith('+') || t.startsWith('-')) && v <= 300) continue;
        cand.add((digits, v));
      }
      if (cand.isNotEmpty) {
        cand.sort((a, b) => b.$2.compareTo(a.$2));
        return cand.first.$1;
      }
      return '';
    }

    /// 提取时间文本："Xh Ym" / "X时Y分" / "X分" / "X时" 等
    String tm(List<Map<String, dynamic>> items) {
      // 优先匹配含有明确时间单位的完整文本
      for (final it in items) {
        final t = (it['text'] as String).trim();
        if (t.contains('分') ||
            t.contains('时') ||
            RegExp(r'\d+\s*[hm]', caseSensitive: false).hasMatch(t))
          return t;
      }
      // 回退：扫描含两个数字的文本（如 "20 49" 可能是时间）
      for (final it in items) {
        final t = (it['text'] as String).trim();
        final nums = RegExp(r'\d+').allMatches(t).toList();
        if (nums.length >= 2) {
          final v1 = int.parse(nums[0].group(0)!);
          final v2 = int.parse(nums[1].group(0)!);
          // 小时 0-23，分钟 0-59
          if (v1 >= 0 && v1 <= 23 && v2 >= 0 && v2 <= 59) {
            return '$v1时$v2分';
          }
        }
      }
      return '';
    }

    // 三区分别取最下行提取字段
    final leftItems = groups.isNotEmpty ? groups[0] : <Map<String, dynamic>>[];
    final centerItems = groups.length > 1
        ? groups[1]
        : <Map<String, dynamic>>[];
    final rightItems = groups.length > 2 ? groups[2] : <Map<String, dynamic>>[];
    final leftGroup = bottomRow(leftItems);
    final centerGroup = bottomRow(centerItems);
    final rightGroup = bottomRow(rightItems);

    result['my_score_per_min'] = spm(leftGroup);
    result['my_score'] = num(leftGroup);
    // 时间从中区全部项中扫描（不限最下行）
    result['time_left'] = tm(
      centerGroup.isNotEmpty && tm(centerGroup).isNotEmpty
          ? centerGroup
          : centerItems,
    );
    result['score_line'] = num(centerGroup);
    result['enemy_score'] = num(rightGroup);
    result['enemy_score_per_min'] = spm(rightGroup);

    // ---- 后处理：左右两侧 SPM/分数互换修正 ----
    // 有时 SPM 较小被当作分数，较大的分数被当作 SPM
    void fixSwap(Map<String, dynamic> r, String spmKey, String scoreKey) {
      final spmV = int.tryParse((r[spmKey] as String).replaceAll('+', ''));
      final scoreV = int.tryParse((r[scoreKey] as String).replaceAll(',', ''));
      if (spmV != null &&
          scoreV != null &&
          spmV > 300 &&
          scoreV <= 300 &&
          scoreV > 0) {
        // 交换
        r[spmKey] = '+$scoreV';
        r[scoreKey] = spmV.toString();
      }
    }

    fixSwap(result, 'my_score_per_min', 'my_score');
    fixSwap(result, 'enemy_score_per_min', 'enemy_score');

    // 计算动态边界（各组最左和最右的 cx 范围）
    double l = 0, r = imgW.toDouble();
    if (groups.isNotEmpty && groups[0].isNotEmpty) {
      final g0 = groups[0];
      g0.sort((a, b) => (a['cx'] as int).compareTo(b['cx'] as int));
      if (groups.length > 1 && groups[1].isNotEmpty) {
        final g1 = groups[1];
        g1.sort((a, b) => (a['cx'] as int).compareTo(b['cx'] as int));
        l = ((g0.last['cx'] as int) + (g1.first['cx'] as int)) / 2;
      }
      if (groups.length > 2 && groups[2].isNotEmpty) {
        final g2 = groups[2];
        g2.sort((a, b) => (a['cx'] as int).compareTo(b['cx'] as int));
        if (groups.length > 1 && groups[1].isNotEmpty) {
          final g1 = groups[1];
          g1.sort((a, b) => (a['cx'] as int).compareTo(b['cx'] as int));
          r = ((g1.last['cx'] as int) + (g2.first['cx'] as int)) / 2;
        }
      }
    }
    final boundaries = [l, r];

    return {'fields': result, 'boundaries': boundaries};
  }

  Future<void> _calculate() async {
    if (_image == null) return;

    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      Map<String, String> fields = {};
      List<Map<String, dynamic>> androidItems = [];

      try {
        if (Platform.isAndroid) {
          androidItems = await _runAndroidOcr(_image!);
          // 拆分合并文本后再分类
          final splitItems = _splitCombinedItems(androidItems);
          final classified = _classifyByPosition(
            splitItems,
            _imageWidth,
            _imageHeight,
          );
          fields = classified['fields'] as Map<String, String>;
          _zoneBoundaries = classified['boundaries'] as List<double>?;
        } else {
          fields = await _runPythonOcr(_image!);
        }
      } catch (e) {
        throw Exception('OCR识别失败: $e');
      }

      final myScorePerMin = fields['my_score_per_min'] ?? '';
      final myScore = fields['my_score'] ?? '';
      final scoreLine = fields['score_line'] ?? '';
      final timeLeft = fields['time_left'] ?? '';
      final enemyScore = fields['enemy_score'] ?? '';
      final enemyScorePerMin = fields['enemy_score_per_min'] ?? '';

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
              final rm = remainingMin;
              myFinal = myScoreVal + (effMySPM * rm).round();
              enemyFinal = enemyScoreVal + (effEnemySPM * rm).round();
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
        _textItems = androidItems;
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

  /// 弹出识别文本列表
  void _showOcrTextList() {
    if (_textItems.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _isZh
                          ? '识别到的文本 (${_textItems.length}项)'
                          : 'OCR Text (${_textItems.length} items)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // 复制全部按钮
                    IconButton(
                      icon: const Icon(Icons.copy_all),
                      tooltip: _isZh ? '复制全部' : 'Copy all',
                      onPressed: () {
                        final allText = _textItems
                            .asMap()
                            .entries
                            .map((e) {
                              final it = e.value;
                              final text = it['text'] as String? ?? '';
                              final x = it['x'] as int? ?? 0;
                              final y = it['y'] as int? ?? 0;
                              final w = it['w'] as int? ?? 0;
                              final h = it['h'] as int? ?? 0;
                              return '${e.key + 1}. $text (x=$x y=$y w=$w h=$h)';
                            })
                            .join('\n');
                        Clipboard.setData(ClipboardData(text: allText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isZh
                                  ? '已复制 ${_textItems.length} 项'
                                  : 'Copied ${_textItems.length} items',
                              style: const TextStyle(fontSize: 12),
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _textItems.length,
                  itemBuilder: (context, index) {
                    final it = _textItems[index];
                    final text = it['text'] as String? ?? '';
                    final x = it['x'] as int? ?? 0;
                    final y = it['y'] as int? ?? 0;
                    final w = it['w'] as int? ?? 0;
                    final h = it['h'] as int? ?? 0;
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.blue[100],
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              text,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _isZh ? '已复制: $text' : 'Copied: $text',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            tooltip: _isZh ? '复制' : 'Copy',
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'x=$x y=$y w=$w h=$h',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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
          // 显示/隐藏识别框
          if (_textItems.isNotEmpty)
            IconButton(
              icon: Icon(
                _showOverlay ? Icons.text_fields : Icons.text_fields_outlined,
                color: _showOverlay ? Colors.blue : null,
              ),
              onPressed: () => setState(() => _showOverlay = !_showOverlay),
              tooltip: _isZh ? '显示识别框' : 'Toggle OCR boxes',
            ),
          // 显示/隐藏三区范围
          if (_textItems.isNotEmpty)
            IconButton(
              icon: Icon(
                _showRegions ? Icons.grid_view : Icons.grid_view_outlined,
                color: _showRegions ? Colors.orange : null,
              ),
              onPressed: () => setState(() => _showRegions = !_showRegions),
              tooltip: _isZh ? '显示区域划分' : 'Toggle regions',
            ),
          // 文字列表
          if (_textItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.list_alt),
              onPressed: _showOcrTextList,
              tooltip: _isZh ? '识别文本列表' : 'OCR text list',
            ),
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
                  ? LayoutBuilder(
                      builder: (context, constraints) => Stack(
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
                          // 识别框叠加层
                          if (_showOverlay && _textItems.isNotEmpty)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _OcrBoxPainter(
                                  items: _textItems,
                                  imageWidth: _imageWidth,
                                  imageHeight: _imageHeight,
                                  displayWidth: constraints.maxWidth,
                                  displayHeight: constraints.maxHeight,
                                ),
                              ),
                            ),
                          // 三区范围叠加层
                          if (_showRegions && _imageWidth > 0)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _RegionPainter(
                                  imageWidth: _imageWidth,
                                  imageHeight: _imageHeight,
                                  displayWidth: constraints.maxWidth,
                                  displayHeight: constraints.maxHeight,
                                  zoneBoundaries: _zoneBoundaries,
                                ),
                              ),
                            ),
                        ],
                      ),
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red[700], fontSize: 14),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _error!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已复制错误信息'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy, size: 14, color: Colors.red[700]),
                            const SizedBox(width: 4),
                            Text(
                              '复制',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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

/// 在图片上绘制 OCR 文字识别框的画笔
class _OcrBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> items;
  final int imageWidth;
  final int imageHeight;
  final double displayWidth;
  final double displayHeight;

  _OcrBoxPainter({
    required this.items,
    required this.imageWidth,
    required this.imageHeight,
    required this.displayWidth,
    required this.displayHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageWidth <= 0 || imageHeight <= 0) return;

    // 计算 BoxFit.contain 缩放比例和偏移
    final scaleX = displayWidth / imageWidth;
    final scaleY = displayHeight / imageHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final offsetX = (displayWidth - imageWidth * scale) / 2;
    final offsetY = (displayHeight - imageHeight * scale) / 2;

    for (final item in items) {
      final x = (item['x'] as num).toDouble();
      final y = (item['y'] as num).toDouble();
      final w = (item['w'] as num).toDouble();
      final h = (item['h'] as num).toDouble();
      final text = item['text'] as String? ?? '';

      final rect = Rect.fromLTWH(
        x * scale + offsetX,
        y * scale + offsetY,
        w * scale,
        h * scale,
      );

      // 半透明填充
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.blue.withAlpha(30)
          ..style = PaintingStyle.fill,
      );

      // 边框
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.blue
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );

      // 文字标签
      if (text.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              backgroundColor: Color(0xAA1565C0),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: rect.width);
        tp.paint(canvas, rect.topLeft);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OcrBoxPainter oldDelegate) => true;
}

/// 绘制左白、中灰、右白三区范围的画笔
class _RegionPainter extends CustomPainter {
  final int imageWidth;
  final int imageHeight;
  final double displayWidth;
  final double displayHeight;
  final List<double>? zoneBoundaries;

  _RegionPainter({
    required this.imageWidth,
    required this.imageHeight,
    required this.displayWidth,
    required this.displayHeight,
    this.zoneBoundaries,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageWidth <= 0 || imageHeight <= 0) return;

    // BoxFit.contain 缩放
    final sx = displayWidth / imageWidth;
    final sy = displayHeight / imageHeight;
    final s = sx < sy ? sx : sy;
    final ox = (displayWidth - imageWidth * s) / 2;
    final oy = (displayHeight - imageHeight * s) / 2;

    double tx(double x) => x * s + ox;
    double ty(double y) => y * s + oy;

    // 三区边界：优先使用动态边界，否则用百分比回退
    final leftBound = (zoneBoundaries != null && zoneBoundaries!.length >= 2)
        ? zoneBoundaries![0]
        : imageWidth * 0.38;
    final rightBound = (zoneBoundaries != null && zoneBoundaries!.length >= 2)
        ? zoneBoundaries![1]
        : imageWidth * 0.62;
    final top = 0.0;
    final bottom = imageHeight * 0.30;

    final leftRect = Rect.fromLTRB(tx(0), ty(top), tx(leftBound), ty(bottom));
    final centerRect = Rect.fromLTRB(
      tx(leftBound),
      ty(top),
      tx(rightBound),
      ty(bottom),
    );
    final rightRect = Rect.fromLTRB(
      tx(rightBound),
      ty(top),
      tx(imageWidth.toDouble()),
      ty(bottom),
    );

    // 左区：白色（半透明浅蓝）
    canvas.drawRect(
      leftRect,
      Paint()
        ..color = const Color(0x30_2196F3)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      leftRect,
      Paint()
        ..color = Colors.blue
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // 中区：灰色（半透明浅灰）
    canvas.drawRect(
      centerRect,
      Paint()
        ..color = const Color(0x30_9E9E9E)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      centerRect,
      Paint()
        ..color = Colors.grey
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // 右区：白色（半透明浅绿）
    canvas.drawRect(
      rightRect,
      Paint()
        ..color = const Color(0x30_4CAF50)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rightRect,
      Paint()
        ..color = Colors.green
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // 标签
    void drawLabel(String text, Rect rect) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            backgroundColor: Color(0xAA000000),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left + 4, rect.top + 4));
    }

    drawLabel('左区(我方)', leftRect);
    drawLabel('中区(时间/分数线)', centerRect);
    drawLabel('右区(敌方)', rightRect);
  }

  @override
  bool shouldRepaint(covariant _RegionPainter oldDelegate) => true;
}

/// OCR 文本中提取的数字匹配辅助类
class _NumMatch {
  final String raw;
  final String digits;
  final int value;
  final int start;
  final int end;
  const _NumMatch({
    required this.raw,
    required this.digits,
    required this.value,
    required this.start,
    required this.end,
  });
}
