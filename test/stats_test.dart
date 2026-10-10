import 'package:ledger_app/core/db/database.dart';
import 'package:ledger_app/models/category.dart';
import 'package:ledger_app/models/transaction.dart';
import 'package:ledger_app/models/tx_type.dart';
import 'package:ledger_app/repositories/category_repository.dart';
import 'package:ledger_app/repositories/transaction_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as dbf;

import 'support/check.dart';

/// M6 统计聚合与环比（真实 SQLite）。金额单位统一为「分」。
Future<void> run() async {
  dbf.sqfliteFfiInit();
  dbf.databaseFactory = dbf.databaseFactoryFfi;

  late LedgerDatabase ledger;
  late CategoryRepository categories;
  late TransactionRepository transactions;

  Future<void> openDb() async {
    ledger = LedgerDatabase(factory: dbf.databaseFactory, path: dbf.inMemoryDatabasePath);
    final db = await ledger.database;
    categories = CategoryRepository(db: Future.value(db));
    transactions = TransactionRepository(db: Future.value(db));
  }

  Future<void> closeDb() async => ledger.close();

  /// [cents] 单位：分
  Future<int> add(
    TxType type,
    int cents,
    DateTime date, {
    int? categoryId,
    String merchant = '',
  }) async {
    final now = DateTime.now();
    return transactions.insert(Transaction(
      type: type,
      amountCents: cents,
      categoryId: categoryId,
      merchant: merchant,
      transDate: date,
      createdAt: now,
      updatedAt: now,
    ));
  }

  section('M6 分类占比聚合');

  await checkAsync('按金额降序，未分类归并一条，比例合计为 1', () async {
    await openDb();
    final expenseCategories = await categories.listByType(TxType.expense);
    final first = expenseCategories[0];
    final second = expenseCategories[1];

    await add(TxType.expense, 6000, DateTime(2026, 10, 2, 12), categoryId: first.id);
    await add(TxType.expense, 4000, DateTime(2026, 10, 3, 12), categoryId: first.id);
    await add(TxType.expense, 5000, DateTime(2026, 10, 4, 12), categoryId: second.id);
    await add(TxType.expense, 2550, DateTime(2026, 10, 5, 12));

    final stats = await transactions.expenseByCategory(DateTime(2026, 10, 15));
    expectEq(stats.length, 3);
    expectEq(stats[0].categoryId, first.id);
    expectEq(stats[0].totalCents, 10000);
    expectEq(stats[0].count, 2);
    expectEq(stats[1].totalCents, 5000);
    expectEq(stats[2].categoryId, null);
    expectEq(stats[2].name, '未分类');
    expectEq(stats[2].icon, '📦');
    expectEq(stats[2].totalCents, 2550);

    var ratioSum = 0.0;
    for (final stat in stats) {
      ratioSum += stat.ratio;
    }
    expectClose(ratioSum, 1.0);
    expectClose(stats[0].ratio, 10000 / 17550);
    await closeDb();
  });

  await checkAsync('转账与收入不计入支出占比', () async {
    await openDb();
    final incomeCategory = (await categories.listByType(TxType.income)).first;
    await add(TxType.expense, 10000, DateTime(2026, 10, 2, 12));
    await add(TxType.transfer, 100000, DateTime(2026, 10, 3, 12));
    await add(TxType.income, 200000, DateTime(2026, 10, 4, 12), categoryId: incomeCategory.id);

    final stats = await transactions.expenseByCategory(DateTime(2026, 10, 15));
    expectEq(stats.length, 1);
    expectEq(stats.first.totalCents, 10000);
    await closeDb();
  });

  await checkAsync('跨月隔离：9 月支出不出现在 10 月', () async {
    await openDb();
    await add(TxType.expense, 20000, DateTime(2026, 9, 30, 23, 59));
    await add(TxType.expense, 1000, DateTime(2026, 10, 1, 0, 1));

    final october = await transactions.expenseByCategory(DateTime(2026, 10, 15));
    expectEq(october.length, 1);
    expectEq(october.first.totalCents, 1000);
    expectEq(october.first.count, 1);
    await closeDb();
  });

  await checkAsync('整数分累加：0.1 元 + 0.2 元 精确等于 0.3 元（10 + 20 = 30 分）', () async {
    await openDb();
    await add(TxType.expense, 10, DateTime(2026, 10, 2, 12));
    await add(TxType.expense, 20, DateTime(2026, 10, 2, 13));

    final stats = await transactions.expenseByCategory(DateTime(2026, 10, 15));
    // 若用 REAL 累加会得到 0.30000000000000004；整数分下是精确的 30
    expectEq(stats.first.totalCents, 30);
    await closeDb();
  });

  await checkAsync('大量小额累加不丢精度（100 笔 0.01 元 = 1.00 元）', () async {
    await openDb();
    for (var i = 0; i < 100; i++) {
      await add(TxType.expense, 1, DateTime(2026, 10, 2, 12));
    }
    final stats = await transactions.expenseByCategory(DateTime(2026, 10, 15));
    expectEq(stats.first.totalCents, 100);
    expectEq(stats.first.count, 100);
    await closeDb();
  });

  await checkAsync('下钻查询：只含该分类该月，且时间倒序', () async {
    await openDb();
    final first = (await categories.listByType(TxType.expense))[0];
    await add(TxType.expense, 1000, DateTime(2026, 10, 2, 9), categoryId: first.id);
    await add(TxType.expense, 2000, DateTime(2026, 10, 6, 9), categoryId: first.id);
    await add(TxType.expense, 3000, DateTime(2026, 9, 6, 9), categoryId: first.id);
    await add(TxType.expense, 4000, DateTime(2026, 10, 6, 10));

    final list = await transactions.listByMonthAndCategory(
      DateTime(2026, 10, 15),
      categoryId: first.id,
    );
    expectEq(list.length, 2);
    expectEq(list.first.amountCents, 2000);
    expectEq(list.last.amountCents, 1000);

    final uncategorized = await transactions.listByMonthAndCategory(
      DateTime(2026, 10, 15),
      categoryId: null,
    );
    expectEq(uncategorized.length, 1);
    expectEq(uncategorized.first.amountCents, 4000);
    await closeDb();
  });

  await checkAsync('自定义分类被用于统计', () async {
    await openDb();
    final id = await categories.insert(
      const Category(name: '宠物', icon: '🐱', type: TxType.expense),
    );
    await add(TxType.expense, 8888, DateTime(2026, 10, 7, 9), categoryId: id);

    final stats = await transactions.expenseByCategory(DateTime(2026, 10, 15));
    expectEq(stats.length, 1);
    expectEq(stats.first.name, '宠物');
    expectEq(stats.first.icon, '🐱');
    expectEq(stats.first.totalCents, 8888);
    await closeDb();
  });

  section('M6 环比');

  await checkAsync('支出环比：下降 50%', () async {
    await openDb();
    await add(TxType.expense, 20000, DateTime(2026, 9, 10, 12));
    await add(TxType.expense, 10000, DateTime(2026, 10, 10, 12));

    final comparison = await transactions.monthComparison(DateTime(2026, 10, 15));
    expectClose(comparison.expenseChange!, -0.5);
    expectEq(comparison.current.expenseCents, 10000);
    expectEq(comparison.previous.expenseCents, 20000);
    await closeDb();
  });

  await checkAsync('上月为 0 时环比返回 null（界面显示「—」）', () async {
    await openDb();
    await add(TxType.expense, 20000, DateTime(2026, 9, 10, 12));

    // 9 月的上月（8 月）无数据
    final comparison = await transactions.monthComparison(DateTime(2026, 9, 15));
    expectNull(comparison.expenseChange);
    expectNull(comparison.incomeChange);
    expectNull(comparison.balanceChange);
    await closeDb();
  });

  await checkAsync('结余由负转正：+550%', () async {
    await openDb();
    await add(TxType.expense, 20000, DateTime(2026, 9, 10, 12)); // 9 月结余 -200 元
    await add(TxType.expense, 10000, DateTime(2026, 10, 10, 12));
    final incomeCategory = (await categories.listByType(TxType.income)).first;
    await add(TxType.income, 100000, DateTime(2026, 10, 11, 12), categoryId: incomeCategory.id);

    final comparison = await transactions.monthComparison(DateTime(2026, 10, 15));
    expectEq(comparison.previous.balanceCents, -20000);
    expectEq(comparison.current.balanceCents, 90000);
    expectClose(comparison.balanceChange!, 5.5);
    await closeDb();
  });

  await checkAsync('收支不变时环比为 0（非 null）', () async {
    await openDb();
    await add(TxType.expense, 10000, DateTime(2026, 9, 10, 12));
    await add(TxType.expense, 10000, DateTime(2026, 10, 10, 12));

    final comparison = await transactions.monthComparison(DateTime(2026, 10, 15));
    expectEq(comparison.expenseChange, 0.0);
    await closeDb();
  });

  section('M7 全量查询');

  await checkAsync('listAll 返回全部月份且时间倒序', () async {
    await openDb();
    await add(TxType.expense, 1000, DateTime(2026, 9, 10, 12));
    await add(TxType.expense, 2000, DateTime(2026, 10, 10, 12));

    final all = await transactions.listAll();
    expectEq(all.length, 2);
    expectEq(all.first.amountCents, 2000);
    expectEq(all.last.amountCents, 1000);
    await closeDb();
  });
}
