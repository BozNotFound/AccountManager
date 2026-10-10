import 'package:flutter/material.dart';

import '../../core/utils/datetime_utils.dart';

/// 月份切换器（首页与统计页共用外观）
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onChanged,
    this.compact = false,
  });

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  /// true 时用于 AppBar title 内部的窄布局
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = compact ? Theme.of(context).textTheme.titleMedium : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => onChanged(DateTimeUtils.addMonths(month, -1)),
          icon: const Icon(Icons.chevron_left),
          tooltip: '上一月',
          visualDensity: VisualDensity.compact,
        ),
        Text(DateTimeUtils.monthLabel(month), style: style),
        IconButton(
          onPressed: () => onChanged(DateTimeUtils.addMonths(month, 1)),
          icon: const Icon(Icons.chevron_right),
          tooltip: '下一月',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
