import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/stats_view.dart';

/// 分类占比调色板（饼图与图例共用，保证颜色一致）
/// 用中等饱和色，浅色/深色主题下都能分辨。
const List<Color> kPiePalette = [
  Color(0xFFE57373),
  Color(0xFF64B5F6),
  Color(0xFF81C784),
  Color(0xFFFFB74D),
  Color(0xFFBA68C8),
  Color(0xFF4DB6AC),
  Color(0xFFF06292),
  Color(0xFFA1887F),
  Color(0xFF9575CD),
  Color(0xFF90A4AE),
];

Color pieColorAt(int index) => kPiePalette[index % kPiePalette.length];

/// 手绘环形图（不引 fl_chart，保持依赖最少）
///
/// 支持点击扇区，回调命中的分类索引；命中空白/圆环空心处不触发。
class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({
    super.key,
    required this.stats,
    this.diameter = 168,
    this.holeRatio = 0.58,
    this.children = const [],
    this.onSliceTap,
  });

  final List<CategoryStat> stats;
  final double diameter;

  /// 空心半径占比，甜甜圈效果
  final double holeRatio;

  /// 圆环中心叠加的内容（如合计金额）
  final List<Widget> children;

  final void Function(int index)? onSliceTap;

  @override
  Widget build(BuildContext context) {
    final emptyColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: GestureDetector(
        onTapUp: onSliceTap == null
            ? null
            : (details) {
                final index = _hitTest(details.localPosition);
                if (index != null) onSliceTap!(index);
              },
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(diameter),
              painter: _RingPainter(
                ratios: [for (final s in stats) s.ratio],
                colors: [for (var i = 0; i < stats.length; i++) pieColorAt(i)],
                emptyColor: emptyColor,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  /// 角度命中：以 12 点方向为 0，顺时针累加（与绘制顺序一致）
  int? _hitTest(Offset local) {
    if (stats.isEmpty) return null;
    final center = Offset(diameter / 2, diameter / 2);
    final vector = local - center;
    final distance = vector.distance;
    final outer = diameter / 2;
    final inner = outer * holeRatio;
    if (distance < inner || distance > outer) return null;

    var angle = math.atan2(vector.dy, vector.dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    var acc = 0.0;
    for (var i = 0; i < stats.length; i++) {
      acc += stats[i].ratio * 2 * math.pi;
      if (angle <= acc) return i;
    }
    return stats.length - 1;
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.ratios,
    required this.colors,
    required this.emptyColor,
  });

  final List<double> ratios;
  final List<Color> colors;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 22.0;
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    if (ratios.isEmpty || ratios.every((r) => r <= 0)) {
      canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = emptyColor);
      return;
    }

    // 扇区之间留 1.5° 缝隙，视觉上更易区分
    const gap = 0.026;
    var start = -math.pi / 2;
    for (var i = 0; i < ratios.length; i++) {
      final sweep = ratios[i] * 2 * math.pi;
      final drawSweep = ratios.length == 1 ? sweep : math.max(sweep - gap, 0.006);
      canvas.drawArc(rect, start, drawSweep, false, paint..color = colors[i]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ratios != ratios ||
      old.colors != colors ||
      old.emptyColor != emptyColor;
}
