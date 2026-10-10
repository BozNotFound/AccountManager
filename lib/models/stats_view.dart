import 'ledger_view.dart';

/// 分类占比条目（开发文档 §F5 饼图与排行）
class CategoryStat {
  const CategoryStat({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.totalCents,
    required this.count,
    required this.ratio,
  });

  /// null 表示「未分类」
  final int? categoryId;
  final String name;

  /// emoji 图标
  final String icon;

  /// 该分类合计（恒为正数，单位「分」）
  final int totalCents;

  /// 笔数
  final int count;

  /// 占本期总支出的比例，0.0 ~ 1.0
  final double ratio;

  static const fallbackName = '未分类';
  static const fallbackIcon = '📦';
}

/// 环比（本期 vs 上期，开发文档 §F5）
/// 上期为 0 时百分比无定义，返回 null，界面显示「—」
class MonthComparison {
  const MonthComparison({required this.current, required this.previous});

  final MonthSummary current;
  final MonthSummary previous;

  double? get expenseChange => ratio(current.expenseCents, previous.expenseCents);
  double? get incomeChange => ratio(current.incomeCents, previous.incomeCents);

  /// 结余环比：上期为负（亏）时用绝对值做分母，方向仍有意义
  double? get balanceChange => ratio(current.balanceCents, previous.balanceCents);

  /// 入参为「分」，返回比例（double）
  static double? ratio(int current, int previous) {
    if (previous == 0) return null;
    return (current - previous) / previous.abs();
  }
}
