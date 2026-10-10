import 'package:sqflite_common/sqlite_api.dart' as sqflite;

import '../models/category.dart';
import '../models/tx_type.dart';

/// 分类读写（开发文档 §F2）
class CategoryRepository {
  CategoryRepository({required Future<sqflite.Database> db}) : _db = db;

  final Future<sqflite.Database> _db;

  /// 常用优先，其次按 sort
  Future<List<Category>> listByType(TxType type) async {
    final db = await _db;
    final rows = await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type.dbValue],
      orderBy: 'use_count DESC, sort ASC, id ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<List<Category>> listAll() async {
    final db = await _db;
    final rows = await db.query('categories', orderBy: 'type ASC, sort ASC, id ASC');
    return rows.map(Category.fromMap).toList();
  }

  Future<Category?> findById(int id) async {
    final db = await _db;
    final rows = await db.query('categories', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Category.fromMap(rows.first);
  }

  Future<int> insert(Category category) async {
    final db = await _db;
    final map = category.toMap()..remove('id');
    return db.insert('categories', map);
  }

  Future<void> update(Category category) async {
    assert(category.id != null, '更新分类必须带 id');
    final db = await _db;
    await db.update('categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
  }

  /// 名下有流水时禁止删除（开发文档 §F2）
  Future<void> delete(int id) async {
    final used = await countTransactions(id);
    if (used > 0) {
      throw StateError('该分类下还有 $used 笔流水，请先改分类');
    }
    final db = await _db;
    await db.delete('categories', where: 'id = ? AND is_preset = 0', whereArgs: [id]);
  }

  Future<int> countTransactions(int categoryId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM transactions WHERE category_id = ?',
      [categoryId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// 记账后累加使用频次，用于常用分类置顶
  Future<void> incrementUseCount(int categoryId) async {
    final db = await _db;
    await db.rawUpdate(
      'UPDATE categories SET use_count = use_count + 1 WHERE id = ?',
      [categoryId],
    );
  }
}
