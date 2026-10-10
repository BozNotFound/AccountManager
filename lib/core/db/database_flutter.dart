import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';

import 'database.dart';

/// Flutter 侧胶水：提供真实的 DatabaseFactory 与数据库目录。
/// 仅此文件依赖 Flutter 插件 sqflite，数据层其余部分保持纯 Dart。
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  LedgerDatabase? _ledger;

  Future<LedgerDatabase> get ledger async {
    final cached = _ledger;
    if (cached != null) return cached;
    final dir = await sqflite.getDatabasesPath();
    return _ledger = LedgerDatabase(
      factory: sqflite.databaseFactory,
      path: p.join(dir, LedgerSchema.dbFileName),
    );
  }

  Future<Database> get database async => (await ledger).database;

  Future<void> close() async {
    await _ledger?.close();
    _ledger = null;
  }
}
