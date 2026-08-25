// 帮派统计后处理：纯逻辑、无 Flutter Widget 依赖，可独立测试。
//
// 输入为 OCR 引擎返回的文字项列表（每项含 text/x/y/w/h，坐标=原图像素），
// 参考时间计算模块 classifyByPosition 的位置分类思路，
// 从图片下部区域按位置顺序提取车辆 HP/ATK。

/// 从 OCR 文本中提取最大数值。
/// 支持千分位逗号与 K/M 后缀，例如：
///   "123,456" -> 123456；"12.5K" -> 12500；"1.2M" -> 1200000
/// 若文本含多个数字（如 "253467 40/45"），取其中最大值。
int? extractNumberFromText(String text) {
  int? best;
  for (final m in RegExp(
    r'(\d[\d,]*(?:\.\d+)?)\s*([KkMm])?',
  ).allMatches(text)) {
    final numStr = m.group(1)!.replaceAll(',', '');
    final value = double.tryParse(numStr);
    if (value == null) continue;
    final multiplier = switch (m.group(2)?.toLowerCase()) {
      'k' => 1000,
      'm' => 1000000,
      _ => 1,
    };
    final v = (value * multiplier).round();
    if (best == null || v > best) best = v;
  }
  return best;
}

/// 按位置分类识别车辆 HP/ATK（参考时间计算 classifyByPosition 思路）。
///
/// 车辆属性图中 HP/ATK/电量位于图片下部、同一行、从左到右排列
/// （2412×1080 中 HP y≈765、3200×1440 中 HP y≈769，比例随分辨率浮动）。
/// 流程：
///   1. 只取图片下部区域（项中心 y > imgH * 0.5）的文字项；
///   2. 按空白把每个文字项拆成 token，逐 token 提取数字，
///      并在框内按相对位置估算该数字的 x 中心
///      （处理 "185276 51697 25/35" 这类 HP/ATK/电量合并框）；
///   3. 按 x 中心把候选聚成"列组"（相邻差 <= 72px 视为同一位置，
///      因为同一 HP/ATK 的五变体会落在相近 x，而 HP 组与 ATK 组间距更大）；
///   4. 每组内投票取最可信值：出现次数最多的值优先；
///      若都只出现一次（个别变体 OCR 错字），取数值更大者
///      （完整数字 > 截断错字，如 185276 > 5276、179325 > 73325）；
///   5. 各组按平均 x 中心从左到右排序，取前两个 = HP、ATK。
({int? hp, int? atk}) classifyHpAtk(
  List<Map<String, dynamic>> items,
  int imgW,
  int imgH,
) {
  // HP/ATK 数值通常上千，电量/等级/百分比等小数字在此阈值以下，直接过滤
  const minValue = 1000;
  // 相邻候选 x 中心差 <= 此值视为同一列组（同一 HP/ATK 的多个变体）
  const clusterGap = 72.0;

  // 1. 收集下部区域每个文字项中所有"数字候选"（带估算的 x 中心）
  final candidates = <({int value, double cx})>[];
  for (final it in items) {
    final y = (it['y'] as num).toDouble();
    final h = (it['h'] as num).toDouble();
    // 非下部区域跳过
    if (y + h / 2 <= imgH * 0.5) continue;
    final x = (it['x'] as num).toDouble();
    final w = (it['w'] as num).toDouble();
    final text = (it['text'] as String? ?? '').trim();
    if (text.isEmpty) continue;
    // 按空白拆成 token，逐 token 提取数字，并在框内按相对位置估算 x 中心
    final tokens = text.split(RegExp(r'\s+'));
    for (var i = 0; i < tokens.length; i++) {
      final v = extractNumberFromText(tokens[i]);
      if (v == null || v <= minValue) continue;
      final rel = (i + 0.5) / tokens.length;
      candidates.add((value: v, cx: x + w * rel));
    }
  }
  if (candidates.isEmpty) return (hp: null, atk: null);

  // 2. 按 x 中心排序后贪心聚类成列组
  candidates.sort((a, b) => a.cx.compareTo(b.cx));
  final groups = <List<({int value, double cx})>>[];
  for (final c in candidates) {
    if (groups.isNotEmpty && c.cx - groups.last.last.cx <= clusterGap) {
      groups.last.add(c);
    } else {
      groups.add([c]);
    }
  }

  // 3. 每组取代表值：票数最多者优先；票数相同取数值更大者
  final reps = <({int value, double cx})>[];
  for (final g in groups) {
    final counts = <int, int>{};
    for (final c in g) {
      counts[c.value] = (counts[c.value] ?? 0) + 1;
    }
    final best = counts.entries.reduce((a, b) {
      if (a.value != b.value) return a.value > b.value ? a : b;
      return a.key > b.key ? a : b;
    });
    final avgCx = g.map((c) => c.cx).reduce((p, e) => p + e) / g.length;
    reps.add((value: best.key, cx: avgCx));
  }

  // 4. 按平均 x 中心从左到右排序，取前两个 = HP、ATK
  reps.sort((a, b) => a.cx.compareTo(b.cx));
  final hp = reps.isNotEmpty ? reps[0].value : null;
  final atk = reps.length > 1 ? reps[1].value : null;
  return (hp: hp, atk: atk);
}
