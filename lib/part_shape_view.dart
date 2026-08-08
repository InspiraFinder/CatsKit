import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'parts_shape_data.dart';

/// 生成六边形路径（顶部朝上）
Path hexagonPath(Offset center, double radius) {
  final path = Path();
  for (int i = 0; i < 6; i++) {
    final angle = -math.pi / 2 + math.pi / 3 * i;
    final p = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  return path;
}

/// 国际服部件形状 + 插槽位置展示（背景为统一方格纸）
class PartShapeView extends StatelessWidget {
  final PartShapeData data;
  final String locale;
  final double height;
  const PartShapeView({
    super.key,
    required this.data,
    required this.locale,
    this.height = 240,
  });

  String _t(String zh, String en) => locale == 'zh' ? zh : en;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CustomPaint(
              painter: _ShapePainter(data),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          children: [
            _legend('weapon', Colors.red, _t('武器', 'Weapon')),
            _legend('wheel', Colors.green, _t('车轮', 'Wheel')),
            _legend('gadget', Colors.purple, _t('配件', 'Gadget')),
            _legend('body', Colors.orange, _t('车身', 'Body')),
            _legend('special_weapon', Colors.brown, _t('特殊武器', 'Special')),
          ],
        ),
      ],
    );
  }

  Widget _legend(String type, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendMarker(type: type, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _ShapePainter extends CustomPainter {
  final PartShapeData data;
  _ShapePainter(this.data);

  static const double _pad = 18.0;
  static const double _gridSize = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    // 背景
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFAFAFA),
    );

    // 方格纸（单位长度统一）
    final gridPaint = Paint()
      ..color = const Color(0xFFE3E3E3)
      ..strokeWidth = 0.6;
    for (double x = 0; x <= size.width; x += _gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += _gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 形状包围盒（circle 以参考中心 (200,200) 为圆心）
    final bbox = _bbox();
    final contentW = size.width - 2 * _pad;
    final contentH = size.height - 2 * _pad;
    final bw = math.max(bbox.width, 0.001);
    final bh = math.max(bbox.height, 0.001);
    final scale = math.min(contentW / bw, contentH / bh);
    Offset tr(double x, double y) => Offset(
      (size.width - bbox.width * scale) / 2 - bbox.left * scale + x * scale,
      (size.height - bbox.height * scale) / 2 - bbox.top * scale + y * scale,
    );

    // 形状
    final shapeFill = Paint()..color = const Color(0x3364B5F6);
    final shapeStroke = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (data.shapeType == 'polygon') {
      final pts = data.points!;
      final path = Path()
        ..moveTo(tr(pts[0].dx, pts[0].dy).dx, tr(pts[0].dx, pts[0].dy).dy);
      for (final p in pts.skip(1)) {
        final q = tr(p.dx, p.dy);
        path.lineTo(q.dx, q.dy);
      }
      path.close();
      canvas.drawPath(path, shapeFill);
      canvas.drawPath(path, shapeStroke);
    } else {
      final r = (data.radius ?? 10.0) * scale;
      final center = tr(200.0, 200.0);
      canvas.drawCircle(center, r, shapeFill);
      canvas.drawCircle(center, r, shapeStroke);
    }

    // 插槽位置（武器=六边形，配件=正方形，其余=圆形）
    for (final slot in data.slots) {
      _drawSlot(canvas, tr(slot.x, slot.y), _slotColor(slot.type), slot.type);
    }
  }

  Rect _bbox() {
    if (data.shapeType == 'circle') {
      final r = data.radius ?? 10.0;
      // 圆形以参考中心 (200,200) 为圆心
      return Rect.fromCenter(
        center: const Offset(200, 200),
        width: 2 * r,
        height: 2 * r,
      );
    }
    final pts = data.points!;
    var minX = pts.first.dx, maxX = pts.first.dx;
    var minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Color _slotColor(String type) {
    switch (type) {
      case 'weapon':
        return Colors.red;
      case 'wheel':
        return Colors.green;
      case 'gadget':
        return Colors.purple;
      case 'body':
        return Colors.orange;
      case 'special_weapon':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  /// 按插槽类型绘制标记：武器=六边形，配件=正方形，其余=圆形
  void _drawSlot(Canvas canvas, Offset c, Color color, String type) {
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    switch (type) {
      case 'weapon':
        final path = hexagonPath(c, 5);
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        break;
      case 'special_weapon':
        // 菱形，用于标注特殊武器插槽位置
        final diamond = Path()
          ..moveTo(c.dx, c.dy - 6)
          ..lineTo(c.dx + 6, c.dy)
          ..lineTo(c.dx, c.dy + 6)
          ..lineTo(c.dx - 6, c.dy)
          ..close();
        canvas.drawPath(diamond, fill);
        canvas.drawPath(diamond, stroke);
        break;
      case 'gadget':
        final rect = Rect.fromCenter(center: c, width: 10, height: 10);
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
        break;
      default:
        canvas.drawCircle(c, 5, fill);
        canvas.drawCircle(c, 5, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _ShapePainter oldDelegate) =>
      oldDelegate.data != data;
}

/// 图例标记（按插槽类型绘制形状）
class _LegendMarker extends StatelessWidget {
  final String type;
  final Color color;
  const _LegendMarker({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(12, 12),
      painter: _MarkerPainter(type, color),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  final String type;
  final Color color;
  _MarkerPainter(this.type, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final fill = Paint()..color = color;
    if (type == 'weapon') {
      canvas.drawPath(hexagonPath(c, size.width / 2 - 1), fill);
    } else if (type == 'special_weapon') {
      final h = size.width / 2 - 1;
      final diamond = Path()
        ..moveTo(c.dx, c.dy - h)
        ..lineTo(c.dx + h, c.dy)
        ..lineTo(c.dx, c.dy + h)
        ..lineTo(c.dx - h, c.dy)
        ..close();
      canvas.drawPath(diamond, fill);
    } else if (type == 'gadget') {
      canvas.drawRect(
        Rect.fromCenter(
          center: c,
          width: size.width - 2,
          height: size.height - 2,
        ),
        fill,
      );
    } else {
      canvas.drawCircle(c, size.width / 2 - 1, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _MarkerPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
