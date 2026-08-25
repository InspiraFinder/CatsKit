import 'package:flutter/material.dart';

/// 在图片上绘制 OCR 文字识别框（BoxFit.contain 等比缩放 + 居中偏移）。
///
/// 时间计算、帮派统计等模块共用，避免重复实现。
class OcrBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> items;
  final int imageWidth;
  final int imageHeight;
  final double displayWidth;
  final double displayHeight;

  OcrBoxPainter({
    required this.items,
    required this.imageWidth,
    required this.imageHeight,
    required this.displayWidth,
    required this.displayHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageWidth <= 0 || imageHeight <= 0) return;

    // BoxFit.contain 缩放比例与居中偏移
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
  bool shouldRepaint(covariant OcrBoxPainter oldDelegate) => true;
}
