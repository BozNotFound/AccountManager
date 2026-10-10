import '../../core/utils/csv.dart';
import '../../core/utils/datetime_utils.dart';
import '../../core/utils/money.dart';
import '../../models/transaction.dart';

/// 流水 → CSV 文本（开发文档 §F6）。纯 Dart，便于单元测试。
///
/// 字段顺序固定为：`id, type, amount, category, merchant, note, date, source, created_at`
///
/// **type 与 source 输出英文**（`expense`/`income`/`transfer`、`manual`/`ocr`），
/// 便于程序化处理、也便于将来做 CSV 导入回填；`category` 仍是中文分类名（给人看）。
class TransactionCsv {
  TransactionCsv._();

  static const header = <String>[
    'id',
    'type',
    'amount',
    'category',
    'merchant',
    'note',
    'date',
    'source',
    'created_at',
  ];

  static const uncategorized = '未分类';

  /// [categoryNames] 为 分类id → 分类名 的映射（分类被删时回落到「未分类」）
  static String build(
    List<Transaction> transactions, {
    required Map<int, String> categoryNames,
  }) {
    return Csv.build([
      header,
      for (final tx in transactions) _row(tx, categoryNames),
    ]);
  }

  static List<Object?> _row(Transaction tx, Map<int, String> categoryNames) {
    final categoryId = tx.categoryId;
    return [
      tx.id,
      tx.type.dbValue, // expense / income / transfer（英文）
      // 不带千分位与符号，Excel 识别为数值；方向由 type 列表达
      Money.plainCents(tx.amountCents),
      categoryId == null ? uncategorized : (categoryNames[categoryId] ?? uncategorized),
      tx.merchant,
      tx.note,
      DateTimeUtils.toDb(tx.transDate),
      tx.source, // manual / ocr（英文）
      DateTimeUtils.toDb(tx.createdAt),
    ];
  }

  /// 导出文件名：按月 `ledger_2026-10.csv`，全量 `ledger_all_2026-10-08.csv`
  static String fileName({DateTime? month, required DateTime now}) => month == null
      ? 'ledger_all_${DateTimeUtils.dayKey(now)}.csv'
      : 'ledger_${DateTimeUtils.monthKey(month)}.csv';
}
