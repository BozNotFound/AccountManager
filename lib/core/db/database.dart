import 'package:sqflite_common/sqlite_api.dart';

import 'seed_data.dart';

/// 表结构与种子数据（开发文档 §4.1）。
/// 本文件属于数据层，仅依赖纯 Dart 的 sqflite_common，不依赖 Flutter，便于测试。
abstract class LedgerSchema {
  /// v1 → v2：金额由 REAL（元）改为 INTEGER（分），彻底消除浮点累加误差。
  static const int version = 2;
  static const String dbFileName = 'ledger.db';

  /// transactions 建表语句（v2）。
  /// `amount_cents` 单位为「分」，整数存储：SUM 精确、可做 OCR 校验和比对。
  /// [table] 仅迁移时改成临时表名。
  static String transactionsDdl([String table = 'transactions']) => '''
      CREATE TABLE $table (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        type         TEXT NOT NULL CHECK(type IN ('expense','income','transfer')),
        amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
        category_id  INTEGER REFERENCES categories(id),
        merchant     TEXT DEFAULT '',
        note         TEXT DEFAULT '',
        trans_date   TEXT NOT NULL,
        source       TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','ocr')),
        created_at   TEXT NOT NULL,
        updated_at   TEXT NOT NULL
      )
    ''';

  static Future<void> create(Database db) async {
    await db.execute(transactionsDdl());
    await db.execute('CREATE INDEX idx_trans_date ON transactions(trans_date)');
    await db.execute('CREATE INDEX idx_trans_cat ON transactions(category_id)');

    await db.execute('''
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

    await db.execute('''
      CREATE TABLE merchant_rules (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword     TEXT UNIQUE NOT NULL,
        category_id INTEGER NOT NULL REFERENCES categories(id),
        hit_count   INTEGER DEFAULT 1,
        source      TEXT NOT NULL DEFAULT 'preset' CHECK(source IN ('preset','learned'))
      )
    ''');

    await db.execute('''
      CREATE TABLE ocr_batches (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path   TEXT,
        source_app   TEXT,
        parsed_count INTEGER,
        created_at   TEXT
      )
    ''');

    await SeedData.insertAll(db);
  }

  /// v1 → v2：`amount REAL`（元）迁移为 `amount_cents INTEGER`（分）。
  ///
  /// SQLite 不支持直接改列类型，故走「建新表 → 拷贝并换算 → 删旧表 → 改名」。
  /// 旧值以 `ROUND(amount * 100)` 精确换算，不丢分。
  static Future<void> upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(transactionsDdl('transactions_v2'));
      await db.execute('''
        INSERT INTO transactions_v2
          (id, type, amount_cents, category_id, merchant, note,
           trans_date, source, created_at, updated_at)
        SELECT id, type, CAST(ROUND(amount * 100) AS INTEGER), category_id, merchant, note,
               trans_date, source, created_at, updated_at
        FROM transactions
      ''');
      await db.execute('DROP TABLE transactions');
      await db.execute('ALTER TABLE transactions_v2 RENAME TO transactions');
      await db.execute('CREATE INDEX idx_trans_date ON transactions(trans_date)');
      await db.execute('CREATE INDEX idx_trans_cat ON transactions(category_id)');
    }
  }
}

/// 数据库句柄：注入 DatabaseFactory 与路径，便于在 App / 测试间复用同一套 schema。
class LedgerDatabase {
  LedgerDatabase({required this.factory, required this.path});

  final DatabaseFactory factory;
  final String path;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() => factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: LedgerSchema.version,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, version) => LedgerSchema.create(db),
          onUpgrade: LedgerSchema.upgrade,
        ),
      );

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
