import 'package:sqflite_common/sqlite_api.dart' as sqflite;

import '../core/utils/datetime_utils.dart';
import '../models/ledger_view.dart';
import '../models/stats_view.dart';
import '../models/transaction.dart';
import '../models/tx_type.dart';

/// 流水读写与统计（开发文档 §F3/F5）。所有参数均走绑定，防注入。
class TransactionRepository {
  TransactionRepository({required Future<sqflite.Database> db}) : _db = db;

  final Future<sqflite.Database> _db;

  Future<int> insert(Transaction tx) async {
    final db = await _db;
    final map = tx.toMap()..remove('id');
    return db.insert('transactions', map);
  }

  Future<void> update(Transaction tx) async {
    assert(tx.id != null, '更新流水必须带 id');
    final db = await _db;
    final map = tx.toMap()..remove('id');
    await db.update('transactions', map, where: 'id = ?', whereArgs: [tx.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<Transaction?> findById(int id) async {
    final db = await _db;
    final rows = await db.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Transaction.fromMap(rows.first);
  }

  /// 某月流水，按时间倒序
  Future<List<Transaction>> listByMonth(DateTime month) async {
    final db = await _db;
    final rows = await db.query(
      'transactions',
      where: 'trans_date >= ? AND trans_date < ?',
      whereArgs: [
        DateTimeUtils.toDb(DateTimeUtils.monthStart(month)),
        DateTimeUtils.toDb(DateTimeUtils.nextMonthStart(month)),
      ],
      orderBy: 'trans_date DESC, id DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  /// 首页按日分组（倒序），每组含当日支出/收入小计
  Future<List<DayGroup>> listMonthGrouped(DateTime month) async {
    final list = await listByMonth(month);
    final map = <String, List<Transaction>>{};
    for (final tx in list) {
      map.putIfAbsent(DateTimeUtils.dayKey(tx.transDate), () => []).add(tx);
    }
    final days = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return days.map((day) => DayGroup.from(day, map[day]!)).toList();
  }

  /// 月度汇总，转账不计入（开发文档 §F5）。金额为整数分，SUM 结果精确。
  Future<MonthSummary> monthSummary(DateTime month) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT type, SUM(amount_cents) AS total
      FROM transactions
      WHERE trans_date >= ? AND trans_date < ? AND type IN ('expense','income')
      GROUP BY type
      ''',
      [
        DateTimeUtils.toDb(DateTimeUtils.monthStart(month)),
        DateTimeUtils.toDb(DateTimeUtils.nextMonthStart(month)),
      ],
    );
    var expenseCents = 0;
    var incomeCents = 0;
    for (final row in rows) {
      final total = ((row['total'] as num?) ?? 0).toInt();
      if (row['type'] == TxType.expense.dbValue) expenseCents = total;
      if (row['type'] == TxType.income.dbValue) incomeCents = total;
    }
    return MonthSummary(expenseCents: expenseCents, incomeCents: incomeCents);
  }

  /// 重复检测：同一天 + 同金额 + 同商户（开发文档 §F4，运行时查询，不落库标记）
  Future<int> countDuplicates(Transaction tx) async {
    final db = await _db;
    final start = DateTime(tx.transDate.year, tx.transDate.month, tx.transDate.day);
    final end = start.add(const Duration(days: 1));
    final excludeId = tx.id == null ? -1 : tx.id!;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS c FROM transactions
      WHERE type = ? AND amount_cents = ? AND merchant = ?
        AND trans_date >= ? AND trans_date < ? AND id != ?
      ''',
      [
        tx.type.dbValue,
        tx.amountCents,
        tx.merchant,
        DateTimeUtils.toDb(start),
        DateTimeUtils.toDb(end),
        excludeId,
      ],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// 本月 vs 上月的汇总对比（开发文档 §F5 环比）
  Future<MonthComparison> monthComparison(DateTime month) async {
    final current = await monthSummary(month);
    final previous = await monthSummary(DateTimeUtils.addMonths(month, -1));
    return MonthComparison(current: current, previous: previous);
  }

  /// 某月支出按分类聚合（开发文档 §F5 饼图/排行），按金额降序。
  ///
  /// 金额本就是以「分」存的整数，SUM 结果天然精确，无 0.01 级浮点误差。
  Future<List<CategoryStat>> expenseByCategory(DateTime month) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT t.category_id      AS category_id,
             c.name             AS name,
             c.icon             AS icon,
             SUM(t.amount_cents) AS cents,
             COUNT(*)           AS cnt
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.type = 'expense' AND t.trans_date >= ? AND t.trans_date < ?
      GROUP BY t.category_id
      ORDER BY cents DESC
      ''',
      [
        DateTimeUtils.toDb(DateTimeUtils.monthStart(month)),
        DateTimeUtils.toDb(DateTimeUtils.nextMonthStart(month)),
      ],
    );

    var grandCents = 0;
    for (final row in rows) {
      grandCents += ((row['cents'] as num?) ?? 0).toInt();
    }

    return [
      for (final row in rows)
        () {
          final cents = ((row['cents'] as num?) ?? 0).toInt();
          return CategoryStat(
            categoryId: row['category_id'] as int?,
            name: (row['name'] as String?) ?? CategoryStat.fallbackName,
            icon: (row['icon'] as String?) ?? CategoryStat.fallbackIcon,
            totalCents: cents,
            count: ((row['cnt'] as num?) ?? 0).toInt(),
            ratio: grandCents == 0 ? 0 : cents / grandCents,
          );
        }(),
    ];
  }

  /// 某月某分类的明细（开发文档 §F5 饼图下钻）；[categoryId] 为 null 时取未分类
  Future<List<Transaction>> listByMonthAndCategory(
    DateTime month, {
    required int? categoryId,
  }) async {
    final db = await _db;
    final start = DateTimeUtils.toDb(DateTimeUtils.monthStart(month));
    final end = DateTimeUtils.toDb(DateTimeUtils.nextMonthStart(month));
    final rows = await db.query(
      'transactions',
      where: categoryId == null
          ? 'category_id IS NULL AND trans_date >= ? AND trans_date < ?'
          : 'category_id = ? AND trans_date >= ? AND trans_date < ?',
      whereArgs: categoryId == null ? [start, end] : [categoryId, start, end],
      orderBy: 'trans_date DESC, id DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  /// 全量流水（按时间倒序），供 CSV 全量导出
  Future<List<Transaction>> listAll() async {
    final db = await _db;
    final rows = await db.query('transactions', orderBy: 'trans_date DESC, id DESC');
    return rows.map(Transaction.fromMap).toList();
  }
}
