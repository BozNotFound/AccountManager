import '../core/utils/datetime_utils.dart';
import 'tx_type.dart';

/// 一笔流水（对应 transactions 表，开发文档 §4.1）
class Transaction {
  const Transaction({
    this.id,
    required this.type,
    required this.amountCents,
    this.categoryId,
    this.merchant = '',
    this.note = '',
    required this.transDate,
    this.source = 'manual',
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final TxType type;

  /// 恒为正数，单位「分」，方向由 type 决定。
  /// 全项目统一整数分，避免浮点累加误差（见 core/utils/money.dart）。
  final int amountCents;
  final int? categoryId;
  final String merchant;
  final String note;
  final DateTime transDate;

  /// manual / ocr
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;

  Transaction copyWith({
    int? id,
    TxType? type,
    int? amountCents,
    int? categoryId,
    bool clearCategory = false,
    String? merchant,
    String? note,
    DateTime? transDate,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amountCents: amountCents ?? this.amountCents,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      merchant: merchant ?? this.merchant,
      note: note ?? this.note,
      transDate: transDate ?? this.transDate,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'type': type.dbValue,
        'amount_cents': amountCents,
        'category_id': categoryId,
        'merchant': merchant,
        'note': note,
        'trans_date': DateTimeUtils.toDb(transDate),
        'source': source,
        'created_at': DateTimeUtils.toDb(createdAt),
        'updated_at': DateTimeUtils.toDb(updatedAt),
      };

  factory Transaction.fromMap(Map<String, Object?> map) => Transaction(
        id: map['id'] as int?,
        type: TxType.fromDb((map['type'] as String?) ?? 'expense'),
        amountCents: ((map['amount_cents'] as num?) ?? 0).toInt(),
        categoryId: map['category_id'] as int?,
        merchant: (map['merchant'] as String?) ?? '',
        note: (map['note'] as String?) ?? '',
        transDate: DateTimeUtils.fromDb((map['trans_date'] as String?) ?? ''),
        source: (map['source'] as String?) ?? 'manual',
        createdAt: DateTimeUtils.fromDb((map['created_at'] as String?) ?? ''),
        updatedAt: DateTimeUtils.fromDb((map['updated_at'] as String?) ?? ''),
      );

  @override
  String toString() =>
      'Transaction(id: $id, type: ${type.dbValue}, amountCents: $amountCents, cat: $categoryId, date: $transDate)';
}
