import 'dart:io';

import 'package:ledger_app/core/db/database.dart';
import 'package:ledger_app/core/db/seed_data.dart';
import 'package:ledger_app/models/category.dart';
import 'package:ledger_app/models/transaction.dart';
import 'package:ledger_app/models/tx_type.dart';
import 'package:ledger_app/repositories/category_repository.dart';
import 'package:ledger_app/repositories/transaction_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as dbf;

import 'support/check.dart';

Future<void> run() async {
  dbf.sqfliteFfiInit();
  dbf.databaseFactory = dbf.databaseFactoryFfi;

  late LedgerDatabase ledger;
  late dbf.Database db;
  late CategoryRepository categories;
  late TransactionRepository transactions;

  Future<void> openDb() async {
    ledger = LedgerDatabase(factory: dbf.databaseFactory, path: dbf.inMemoryDatabasePath);
    db = await ledger.database;
    categories = CategoryRepository(db: Future.value(db));
    transactions = TransactionRepository(db: Future.value(db));
  }

  Future<void> closeDb() async => ledger.close();

  /// 金额单位统一为「分」
  Future<int> addExpense(int cents, DateTime date, {int? categoryId}) async {
    final now = DateTime.now();
    return transactions.insert(Transaction(
      type: TxType.expense,
      amountCents: cents,
      categoryId: categoryId,
      transDate: date,
      createdAt: now,
      updatedAt: now,
    ));
  }

  section('M1 建库与种子数据');

  await checkAsync('预置分类 8 支出 + 3 收入，餐饮在首位', () async {
    await openDb();
    final expense = await categories.listByType(TxType.expense);
    final income = await categories.listByType(TxType.income);
    expectEq(expense.length, 8);
    expectEq(income.length, 3);
    expectEq(expense.first.name, '餐饮');
    await closeDb();
  });

  await checkAsync('预置商户关键词规则写入且与分类正确关联', () async {
    await openDb();
    final rows = await db.query('merchant_rules');
    expectEq(rows.length, SeedData.merchantRules.length);
    final meituan = rows.firstWhere((r) => r['keyword'] == '美团');
    final expense = await categories.listByType(TxType.expense);
    expectEq(meituan['category_id'], expense.first.id);
    await closeDb();
  });

  await checkAsync('四张表全部建出', () async {
    await openDb();
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    final tables = rows.map((r) => r['name'] as String).toSet();
    expectTrue(tables.contains('transactions'), '缺少 transactions');
    expectTrue(tables.contains('categories'), '缺少 categories');
    expectTrue(tables.contains('merchant_rules'), '缺少 merchant_rules');
    expectTrue(tables.contains('ocr_batches'), '缺少 ocr_batches');
    await closeDb();
  });

  await checkAsync('transactions 金额列为 amount_cents 且为整数类型', () async {
    await openDb();
    final rows = await db.rawQuery('PRAGMA table_info(transactions)');
    final byName = {for (final r in rows) r['name'] as String: r};
    expectTrue(byName.containsKey('amount_cents'), '缺少 amount_cents 列');
    expectFalse(byName.containsKey('amount'), 'v1 的 amount 列不应存在');
    expectEq((byName['amount_cents']!['type'] as String).toUpperCase(), 'INTEGER');
    await closeDb();
  });

  section('M1 数据库迁移');

  await checkAsync('v1 → v2：REAL 元 → INTEGER 分，精度不丢', () async {
    final dir = await Directory.systemTemp.createTemp('ledger_migrate_');
    final path = '${dir.path}${Platform.pathSeparator}ledger.db';
    try {
      // 1) 先造一个 v1 结构的库：amount 为 REAL（单位：元）
      final v1 = await dbf.databaseFactory.openDatabase(
        path,
        options: dbf.OpenDatabaseOptions(
          version: 1,
          onCreate: (database, version) async {
            await database.execute('''
              CREATE TABLE transactions (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                type        TEXT NOT NULL CHECK(type IN ('expense','income','transfer')),
                amount      REAL NOT NULL CHECK(amount > 0),
                category_id INTEGER REFERENCES categories(id),
                merchant    TEXT DEFAULT '',
                note        TEXT DEFAULT '',
                trans_date  TEXT NOT NULL,
                source      TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','ocr')),
                created_at  TEXT NOT NULL,
                updated_at  TEXT NOT NULL
              )
            ''');
            await database.execute('CREATE INDEX idx_trans_date ON transactions(trans_date)');
            await database.execute('CREATE INDEX idx_trans_cat ON transactions(category_id)');
            await database.execute('''
              CREATE TABLE categories (
                id        INTEGER PRIMARY KEY AUTOINCREMENT,
                name      TEXT NOT NULL,
                icon      TEXT NOT NULL,
                type      TEXT NOT NULL CHECK(type IN ('expense','income')),
                use_count INTEGER DEFAULT 0,
                sort      INTEGER DEFAULT 0,
                is_preset INTEGER DEFAULT 0
              )
            ''');
            await database.execute('''
              CREATE TABLE merchant_rules (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                keyword     TEXT UNIQUE NOT NULL,
                category_id INTEGER NOT NULL REFERENCES categories(id),
                hit_count   INTEGER DEFAULT 1,
                source      TEXT NOT NULL DEFAULT 'preset' CHECK(source IN ('preset','learned'))
              )
            ''');
            await database.execute('''
              CREATE TABLE ocr_batches (
                id           INTEGER PRIMARY KEY AUTOINCREMENT,
                image_path   TEXT,
                source_app   TEXT,
                parsed_count INTEGER,
                created_at   TEXT
              )
            ''');
          },
        ),
      );
      await v1.insert('transactions', {
        'type': 'expense',
        'amount': 226.50, // 元（REAL）
        'merchant': '美团',
        'trans_date': '2026-10-03 12:00',
        'source': 'manual',
        'created_at': '2026-10-03 12:00',
        'updated_at': '2026-10-03 12:00',
      });
      await v1.insert('transactions', {
        'type': 'income',
        'amount': 1000.0,
        'trans_date': '2026-10-04 09:00',
        'source': 'ocr',
        'created_at': '2026-10-04 09:00',
        'updated_at': '2026-10-04 09:00',
      });
      await v1.close();

      // 2) 用 v2 打开同一路径 → 触发 onUpgrade
      final upgraded = LedgerDatabase(factory: dbf.databaseFactory, path: path);
      final v2db = await upgraded.database;
      final rows = await v2db.query('transactions', orderBy: 'id');
      expectEq(rows.length, 2);
      expectEq(rows[0]['amount_cents'], 22650); // 226.50 元 → 22650 分
      expectEq(rows[1]['amount_cents'], 100000); // 1000 元 → 100000 分
      expectEq(rows[0]['merchant'], '美团');
      expectEq(rows[1]['source'], 'ocr');
      expectFalse(rows[0].containsKey('amount'), 'v1 的 amount 列应已被移除');

      // 3) 迁移后的数据仍可正常聚合
      final summary = await TransactionRepository(db: Future.value(v2db))
          .monthSummary(DateTime(2026, 10, 15));
      expectEq(summary.expenseCents, 22650);
      expectEq(summary.incomeCents, 100000);

      await upgraded.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });

  section('M1/M3 流水读写与统计');

  await checkAsync('月度汇总：转账不计入，结余=收入-支出', () async {
    await openDb();
    final now = DateTime.now();
    final expenseCategory = (await categories.listByType(TxType.expense)).first;
    final incomeCategory = (await categories.listByType(TxType.income)).first;

    await transactions.insert(Transaction(
      type: TxType.expense,
      amountCents: 22650,
      categoryId: expenseCategory.id,
      transDate: DateTime(2026, 10, 3, 12),
      createdAt: now,
      updatedAt: now,
    ));
    await transactions.insert(Transaction(
      type: TxType.income,
      amountCents: 100000,
      categoryId: incomeCategory.id,
      transDate: DateTime(2026, 10, 3, 13),
      createdAt: now,
      updatedAt: now,
    ));
    await transactions.insert(Transaction(
      type: TxType.transfer,
      amountCents: 100000,
      merchant: '转账-转给老爸',
      transDate: DateTime(2026, 10, 3, 14),
      createdAt: now,
      updatedAt: now,
    ));

    final summary = await transactions.monthSummary(DateTime(2026, 10, 15));
    expectEq(summary.expenseCents, 22650);
    expectEq(summary.incomeCents, 100000);
    expectEq(summary.balanceCents, 77350);
    await closeDb();
  });

  await checkAsync('按日分组：倒序 + 当日小计', () async {
    await openDb();
    await addExpense(1000, DateTime(2026, 10, 3, 9));
    await addExpense(550, DateTime(2026, 10, 3, 20));
    await addExpense(800, DateTime(2026, 10, 5, 10));

    final groups = await transactions.listMonthGrouped(DateTime(2026, 10, 1));
    expectEq(groups.length, 2);
    expectEq(groups.first.day, '2026-10-05');
    expectEq(groups.last.day, '2026-10-03');
    expectEq(groups.last.expenseCents, 1550);
    expectEq(groups.last.items.length, 2);
    await closeDb();
  });

  await checkAsync('跨月查询隔离（月末 23:59 与月初 00:01）', () async {
    await openDb();
    await addExpense(1000, DateTime(2026, 9, 30, 23, 59));
    await addExpense(2000, DateTime(2026, 10, 1, 0, 1));
    final october = await transactions.listByMonth(DateTime(2026, 10, 1));
    expectEq(october.length, 1);
    expectEq(october.first.amountCents, 2000);
    await closeDb();
  });

  await checkAsync('编辑与删除', () async {
    await openDb();
    final id = await addExpense(1000, DateTime(2026, 10, 3, 9));
    final loaded = await transactions.findById(id);
    expectNotNull(loaded);
    expectEq(loaded!.amountCents, 1000);

    await transactions.update(loaded.copyWith(amountCents: 1250, note: '改过'));
    final updated = await transactions.findById(id);
    expectEq(updated!.amountCents, 1250);
    expectEq(updated.note, '改过');

    await transactions.delete(id);
    expectNull(await transactions.findById(id));
    await closeDb();
  });

  await checkAsync('重复检测：同日同额同商户命中，隔日不命中', () async {
    await openDb();
    final now = DateTime.now();
    final tx = Transaction(
      type: TxType.expense,
      amountCents: 2500,
      merchant: '美团',
      transDate: DateTime(2026, 10, 3, 12),
      createdAt: now,
      updatedAt: now,
    );
    expectEq(await transactions.countDuplicates(tx), 0);
    await transactions.insert(tx);
    expectEq(await transactions.countDuplicates(tx), 1);

    final other = tx.copyWith(transDate: DateTime(2026, 10, 4, 12));
    expectEq(await transactions.countDuplicates(other), 0);
    await closeDb();
  });

  section('M2 分类管理');

  await checkAsync('新增自定义分类可见', () async {
    await openDb();
    await categories.insert(
      const Category(name: '宠物', icon: '🐱', type: TxType.expense),
    );
    final list = await categories.listByType(TxType.expense);
    expectEq(list.length, 9);
    expectTrue(list.any((c) => c.name == '宠物'));
    await closeDb();
  });

  await checkAsync('名下有流水时禁止删除', () async {
    await openDb();
    final id = await categories.insert(
      const Category(name: '宠物', icon: '🐱', type: TxType.expense),
    );
    await addExpense(3000, DateTime(2026, 10, 3, 12), categoryId: id);

    var threwStateError = false;
    try {
      await categories.delete(id);
    } on StateError {
      threwStateError = true;
    }
    expectTrue(threwStateError, '期望抛出 StateError（分类下有流水）');
    await closeDb();
  });

  await checkAsync('预置分类不可删除', () async {
    await openDb();
    final preset = (await categories.listByType(TxType.expense)).first;
    await categories.delete(preset.id!);
    expectEq((await categories.listByType(TxType.expense)).length, 8);
    await closeDb();
  });

  await checkAsync('使用频次累加后置顶', () async {
    await openDb();
    final before = await categories.listByType(TxType.expense);
    final target = before.last;
    await categories.incrementUseCount(target.id!);
    final after = await categories.listByType(TxType.expense);
    expectEq(after.first.id, target.id);
    expectEq(after.first.useCount, 1);
    await closeDb();
  });
}
