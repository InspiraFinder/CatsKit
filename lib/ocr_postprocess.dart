/// 时间计算模块 - OCR 识别后处理（纯逻辑，可独立测试）
///
/// 从 `time_calc_screen.dart` 提取而来，不依赖任何 Flutter UI / 平台代码，
/// 因此可以在 `test/androidocr` 下直接加载 JSON 测试集做回归验证。
///
/// 处理管线：
///   1. [splitCombinedItems]：把一行内合并的文本（如 `"+124) 19479"`）拆成独立项
///   2. [classifyByPosition]：语义识别 + 左右位置二分（不依赖三区水平边界），
///      提取 我方每分钟得分、我方分数、分数线、剩余时间、敌方分数、敌方每分钟得分
library;

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

/// 将合并文本（如 "+9 19479" / "+124) 19479"）拆分为独立项
///
/// [items] 为 OCR 结果：`{'text': String, 'x': int, 'y': int, 'w': int, 'h': int}`。
/// 返回同结构的拆分结果，无法拆分的项原样保留。
List<Map<String, dynamic>> splitCombinedItems(
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
    // 分数：优先排除与 SPM 重叠位置的匹配，
    // 避免 "+148 824" 中 SPM(148) 与分数(824) 同为 3 位时 reduce 选中同一个位置而无法拆分
    final scoreCandidates = spmItem == null
        ? scoreMatches
        : scoreMatches.where((m) => m.start != spmItem.start).toList();
    final scoreItem = scoreCandidates.isNotEmpty
        ? scoreCandidates.reduce(
            (a, b) => a.digits.length >= b.digits.length ? a : b,
          )
        : null;

    // 真实战场 SPM+SCORE 组合中至少一个数字带 +/- 号或紧邻 ) 括号
    // （如 "+148) 824"、"126) 67368"、"44051+38"）；裸数字文本
    // （如网速 "389 17,"、"389 174"）不应被拆分。
    bool hasSignOrParen(_NumMatch m) =>
        m.raw.contains('+') || m.raw.contains('-') || m.raw.contains(')');

    // 如果同时有 SPM 和 SCORE、不重叠，且符合真实组合特征，则拆分
    if (spmItem != null &&
        scoreItem != null &&
        spmItem.start != scoreItem.start &&
        (hasSignOrParen(spmItem) || hasSignOrParen(scoreItem))) {
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

/// 判断文本是否为「纯 0」数字（去除数字/空白/符号后无其他字符，且含 0）
/// 用于把独立的 `0`（如敌方零分）识别为零分保底，同时排除
/// `0天。|我的派`、`有爪你就来9` 这类混入中文/字母的噪声文本。
bool _isZeroOnlyText(String text) {
  final stripped = text.replaceAll(RegExp(r'[\d\s\.,\-+()]'), '');
  return stripped.isEmpty && text.contains('0');
}

/// 判断文本是否含时间单位（中文 分/时/吋，或英文 h/m），
/// 或疑似时间噪声（两个数字块且末块 ≤59，如 `238 39 O` ≈ `23时39分`，
/// 此时/分被 OCR 识别成数字/字母，无任何时间单位字符）。
bool _isTimeText(String text) {
  if (text.contains('分') || text.contains('时') || text.contains('吋')) {
    return true;
  }
  if (RegExp(r'\d+\s*[hm]', caseSensitive: false).hasMatch(text)) {
    return true;
  }
  final nums = RegExp(
    r'\d+',
  ).allMatches(text).map((m) => int.parse(m.group(0)!)).toList();
  return nums.length >= 2 && nums.last <= 59;
}

/// 从候选文本中提取剩余时间（语义识别，不依赖区域）
///
/// 中文：先归一化 OCR 形近误识别（吋→时、寸→时），排除「最后战争」总倒计时，
/// 优先返回「X时Y分」最完整且合法的结果；
/// 英文：兼容 `3m` / `2h` / `2h 30m` 等 h/m 格式，保留原文。
String _extractTime(List<Map<String, dynamic>> items) {
  final full = <String>[]; // X时Y分 / 英文完整 h/m
  final hourOnly = <String>[]; // X时 / Xh
  final minOnly = <String>[]; // Y分 / Ym

  for (final it in items) {
    var t = (it['text'] as String).trim();
    t = t.replaceAll('吋', '时').replaceAll('寸', '时');

    // 中文时间单位
    if (t.contains('分') || t.contains('时')) {
      // 排除「最后战争剩余时间」这类总战争倒计时（不是当前战斗倒计时）
      if (t.contains('战争')) continue;

      final hourM = RegExp(r'(\d+)\S*\s*时').firstMatch(t);
      final minM = RegExp(r'(\d+)\s*分').firstMatch(t);
      final hour = hourM == null ? null : int.tryParse(hourM.group(1)!);
      final min = minM == null ? null : int.tryParse(minM.group(1)!);
      final hourOk = hour != null && hour >= 0 && hour <= 23;
      final minOk = min != null && min >= 0 && min <= 59;

      if (hourOk && minOk) {
        full.add('$hour时$min分');
      } else if (hourOk) {
        hourOnly.add('$hour时');
      } else if (minOk) {
        minOnly.add('$min分');
      }
      continue;
    }

    // 英文时间单位（h / m），如 "3m"、"2h"、"2h 30m"
    final enM = RegExp(
      r'\d+\s*[hm]\s*(?:\d+\s*m)?',
      caseSensitive: false,
    ).firstMatch(t);
    if (enM != null) {
      full.add(enM.group(0)!.trim());
    }
  }
  if (full.isNotEmpty) return full.first;
  if (hourOnly.isNotEmpty) return hourOnly.first;
  if (minOnly.isNotEmpty) return minOnly.first;
  return '';
}

/// 按语义 + 左右位置识别 6 个字段（Android 端使用）
///
/// 早期版本依赖「按图片宽度百分比 38%/62% 划分左/中/右三区」的固定边界
/// （本意是自动识别文本背景白色矩形框边界），但该边界一直不够准确。
/// 现改为**不依赖三区水平边界**：
///   - 垂直先验：战场面板位于图片上部（cy < 30% 高度）
///   - 时间：语义识别（含「时/分」单位，排除「最后战争」总倒计时）
///   - 每分钟得分(SPM)：`+数字`（1-3 位且 ≤300）
///   - 分数线：非 SPM 数字中的最大值（先验：未达线前分数线 > 任何一方分数）
///   - 我方/敌方：按文本水平中心 cx 与中线(imgW/2)二分
///
/// 返回 `{'fields': Map<String, String>, 'boundaries': null}`；
/// [boundaries] 恒为 null（已弃用三区边界，UI 叠加层回退固定百分比）。
///
/// 注意：本函数会向传入的 items 中写入 `cx`/`cy` 派生字段。
Map<String, dynamic> classifyByPosition(
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

  if (items.isEmpty || imgW <= 0 || imgH <= 0) {
    return {'fields': result, 'boundaries': null};
  }

  // 派生中心坐标
  for (final it in items) {
    it['cx'] = (it['x'] as int) + (it['w'] as int) ~/ 2;
    it['cy'] = (it['y'] as int) + (it['h'] as int) ~/ 2;
  }

  // 战场面板位于图片上部
  final topItems = items
      .where((it) => (it['cy'] as int) < imgH * 0.30)
      .toList();
  if (topItems.isEmpty) {
    return {'fields': result, 'boundaries': null};
  }

  // 水平中线：左侧=我方，右侧=敌方
  final midX = imgW / 2;
  bool isLeft(Map<String, dynamic> it) => (it['cx'] as int) < midX;

  // ---- 时间：语义识别 ----
  result['time_left'] = _extractTime(topItems);

  // ---- SPM / 分数 / 分数线 ----
  final leftSpm = <(int, String)>[];
  final rightSpm = <(int, String)>[];
  final leftNum = <(int, String)>[];
  final rightNum = <(int, String)>[];
  final leftZero = <String>[]; // 纯 0 文本（零分保底）
  final rightZero = <String>[];

  for (final it in topItems) {
    final t = (it['text'] as String).trim().replaceAll(',', '');
    // 跳过时间文本，避免其中的数字混入分数/SPM
    if (_isTimeText(t)) continue;
    final digits = t.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) continue;
    final v = int.tryParse(digits);
    if (v == null) continue;

    final signed = t.startsWith('+') || t.startsWith('-');
    if (signed && v >= 1 && v <= 300) {
      // SPM：带 +/- 前缀，值 1-300，标准化为 +N
      final raw = '+$digits';
      if (isLeft(it)) {
        leftSpm.add((v, raw));
      } else {
        rightSpm.add((v, raw));
      }
    } else if (!signed && v <= 150000) {
      if (v >= 100) {
        // 普通数字：分数 / 分数线
        if (isLeft(it)) {
          leftNum.add((v, digits));
        } else {
          rightNum.add((v, digits));
        }
      } else if (v == 0 && _isZeroOnlyText(t)) {
        // 纯 0 文本：作为该侧「零分」保底
        if (isLeft(it)) {
          leftZero.add(digits);
        } else {
          rightZero.add(digits);
        }
      }
    }
  }

  // 取列表里值最大的项的原始文本
  String bestOf(List<(int, String)> list) {
    if (list.isEmpty) return '';
    var best = list.first;
    for (final e in list) {
      if (e.$1 > best.$1) best = e;
    }
    return best.$2;
  }

  // 取列表里最大值（int?）
  int? bestValue(List<(int, String)> list) {
    if (list.isEmpty) return null;
    var m = list.first.$1;
    for (final e in list) {
      if (e.$1 > m) m = e.$1;
    }
    return m;
  }

  result['my_score_per_min'] = bestOf(leftSpm);
  result['enemy_score_per_min'] = bestOf(rightSpm);

  // 分数线：所有非 SPM 数字中的最大值
  final allNum = [...leftNum, ...rightNum];
  final scoreLineVal = bestValue(allNum);
  if (scoreLineVal != null) {
    result['score_line'] = scoreLineVal.toString();
  }

  // 分数：排除分数线项后，左右各取最大
  String bestNumExcluding(List<(int, String)> list, int? exclude) {
    int? best;
    String? raw;
    for (final e in list) {
      if (exclude != null && e.$1 == exclude) continue;
      if (best == null || e.$1 > best) {
        best = e.$1;
        raw = e.$2;
      }
    }
    return raw ?? '';
  }

  result['my_score'] = bestNumExcluding(leftNum, scoreLineVal);
  if ((result['my_score'] ?? '').isEmpty && leftZero.isNotEmpty) {
    result['my_score'] = '0';
  }
  result['enemy_score'] = bestNumExcluding(rightNum, scoreLineVal);
  if ((result['enemy_score'] ?? '').isEmpty && rightZero.isNotEmpty) {
    result['enemy_score'] = '0';
  }

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

  return {'fields': result, 'boundaries': null};
}
