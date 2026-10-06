import 'package:flutter/material.dart';

/// 自绘的紧凑滑条 —— **故意不用 Material 的 [Slider]**。
///
/// Material 的 Slider 内部总会包一层 `OverlayPortal`，于是：
///
/// * 放进弹窗（＝ 推入的路由）里，Windows 的 UIA 桥会收到一个没人认领的
///   语义节点（flutter#190357）；
/// * 同一个合并组里的两个 `OverlayPortal` 锚点还会被并成一个节点
///   （flutter#182444）。
///
/// 两种情况都会让引擎反复打印
/// `Failed to update ui::AXTree, error: N will not be in the tree and is not the new root`，
/// 而且在 Windows 上会把无障碍树「冻住」（屏幕阅读器一直读旧界面）。
///
/// 这里改用 `GestureDetector` + 自绘轨道：外观与交互和 Slider 一致（点一下跳过去、
/// 按住横拖、可按等分对齐），语义仍按 slider 上报（`Semantics.slider` +
/// `value` / `increasedValue` / `decreasedValue`），但不再产生任何 `OverlayPortal`。
///
/// 用法：[min] / [max] / [value] 都是**真实单位**（不必是 0..1）；
/// [divisions] > 0 时拖动结果对齐到等分；[formatValue] 非空时屏幕阅读器还能
/// 用「加一档 / 减一档」操作。
class MiniSlider extends StatelessWidget {
  const MiniSlider({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    this.divisions = 0,
    this.formatValue,
    this.height = 30,
    this.thumbSize = 16,
    this.trackHeight = 4,
  });

  /// 值域下限（含）
  final double min;

  /// 值域上限（含）
  final double max;

  /// 真实单位的当前值（内部会夹到 `[min, max]`）
  final double value;

  /// 传 `null` 表示禁用（只读展示）
  final ValueChanged<double>? onChanged;

  /// > 0 时把拖动结果对齐到等分（例如 1..26 级 → divisions = 25）
  final int divisions;

  /// 给屏幕阅读器读的文本：`(v) => '${v.round()}'` / `(v) => '45%'` …
  final String Function(double)? formatValue;

  /// 控件总高（默认 30，比 Material 的 Slider 省 18px）
  final double height;

  final double thumbSize;
  final double trackHeight;

  double get _span => max - min;

  double get _clamped => _span <= 0 ? min : value.clamp(min, max);

  double get _fraction =>
      _span <= 0 ? 0 : ((_clamped - min) / _span).clamp(0.0, 1.0);

  double _snap(double fraction) {
    final f = fraction.clamp(0.0, 1.0);
    if (divisions <= 0) return f;
    return (f * divisions).round() / divisions;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onChanged != null;
    final active = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    final inactive = theme.colorScheme.surfaceContainerHighest;
    final f = _fraction;
    final step = divisions > 0 ? _span / divisions : 0.0;
    // ⚠️ 有「加/减一档」动作时，value 与 increased/decreasedValue 必须同时给出，
    // 否则框架会断言失败（SemanticsNode.updateWith）。
    final canStep = enabled && step > 0 && formatValue != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final travel = (w - thumbSize) < 0 ? 0.0 : (w - thumbSize);

        void emit(Offset local) {
          final callback = onChanged;
          if (callback == null || w <= 0) return;
          callback(min + _snap(local.dx / w) * _span);
        }

        return Semantics(
          slider: true,
          enabled: enabled,
          value: formatValue?.call(_clamped) ?? '',
          increasedValue: canStep
              ? formatValue!((_clamped + step).clamp(min, max))
              : '',
          decreasedValue: canStep
              ? formatValue!((_clamped - step).clamp(min, max))
              : '',
          onIncrease: canStep
              ? () => onChanged!((_clamped + step).clamp(min, max))
              : null,
          onDecrease: canStep
              ? () => onChanged!((_clamped - step).clamp(min, max))
              : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (d) => emit(d.localPosition) : null,
            onHorizontalDragStart: enabled
                ? (d) => emit(d.localPosition)
                : null,
            onHorizontalDragUpdate: enabled
                ? (d) => emit(d.localPosition)
                : null,
            child: SizedBox(
              height: height,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 0,
                    right: 0,
                    top: (height - trackHeight) / 2,
                    height: trackHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: inactive,
                        borderRadius: BorderRadius.circular(trackHeight / 2),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: (height - trackHeight) / 2,
                    width: f * w,
                    height: trackHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: active,
                        borderRadius: BorderRadius.circular(trackHeight / 2),
                      ),
                    ),
                  ),
                  Positioned(
                    left: f * travel,
                    top: (height - thumbSize) / 2,
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: active,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
