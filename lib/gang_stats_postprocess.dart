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
/// （示例 1920×1080：HP y≈961、ATK y≈958，电量在 ATK 右侧）。
/// 流程：
///   1. 只取图片下部区域（项中心 y > imgH * 0.7）的文字项；
///   2. 对每个文字项提取其最大数字，并记录 x 中心；
///   3. 按 x 中心从左到右排序，取前两个 = HP、ATK（第三个为电量，忽略）。
({int? hp, int? atk}) classifyHpAtk(
  List<Map<String, dynamic>> items,
  int imgW,
  int imgH,
) {
  final bottom = <({double x, int value})>[];
  for (final it in items) {
    final y = (it['y'] as num).toDouble();
    final h = (it['h'] as num).toDouble();
    // 非下部区域跳过
    if (y + h / 2 <= imgH * 0.7) continue;
    final v = extractNumberFromText(it['text'] as String? ?? '');
    if (v == null || v <= 0) continue;
    final x = (it['x'] as num).toDouble();
    final w = (it['w'] as num).toDouble();
    bottom.add((x: x + w / 2, value: v));
  }
  // 按 x 中心从左到右排序
  bottom.sort((a, b) => a.x.compareTo(b.x));
  int? hp = bottom.isNotEmpty ? bottom[0].value : null;
  int? atk = bottom.length > 1 ? bottom[1].value : null;
  return (hp: hp, atk: atk);
}
