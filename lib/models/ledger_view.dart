import 'transaction.dart';
import 'tx_type.dart';

/// 月度汇总：转账不计入（开发文档 §F5）。金额单位统一为「分」。
class MonthSummary {
  const MonthSummary({
    this.expenseCents = 0,
    this.incomeCents = 0,
  });

  final int expenseCents;
  final int incomeCents;

  int get balanceCents => incomeCents - expenseCents;
}

/// 首页按日分组（开发文档 §F3）
class DayGroup {
  const DayGroup({
    required this.day,
    required this.items,
    required this.expenseCents,
    required this.incomeCents,
  });

  /// 'yyyy-MM-dd'
  final String day;
  final List<Transaction> items;

  /// 当日支出/收入小计，单位「分」
  final int expenseCents;
  final int incomeCents;

  static DayGroup from(String day, List<Transaction> items) {
    var expenseCents = 0;
    var incomeCents = 0;
    for (final t in items) {
      if (t.type == TxType.expense) expenseCents += t.amountCents;
      if (t.type == TxType.income) incomeCents += t.amountCents;
    }
    return DayGroup(
      day: day,
      items: items,
      expenseCents: expenseCents,
      incomeCents: incomeCents,
    );
  }
}
