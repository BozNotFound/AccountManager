/// 记账类型。DB 中存字符串（见开发文档 §4.1）。
/// 注意：本文件属于领域层，不得 import Flutter，以便纯 Dart 环境下运行单元测试。
enum TxType {
  expense('expense', '支出'),
  income('income', '收入'),
  transfer('transfer', '转账');

  const TxType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static TxType fromDb(String value) =>
      TxType.values.firstWhere((e) => e.dbValue == value, orElse: () => TxType.expense);

  /// 转账不计入支出/收入统计（开发文档 §F3/F5）
  bool get countsInStats => this != TxType.transfer;
}
