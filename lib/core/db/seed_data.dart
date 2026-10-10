import 'package:sqflite_common/sqlite_api.dart';

import '../../models/tx_type.dart';

/// 预置数据（开发文档 §6.1 分类、§6.3 商户关键词规则）
class SeedData {
  SeedData._();

  /// (名称, emoji, 类型)
  static const List<(String, String, TxType)> categories = [
    ('餐饮', '🍜', TxType.expense),
    ('交通', '🚌', TxType.expense),
    ('购物', '🛍️', TxType.expense),
    ('居住', '🏠', TxType.expense),
    ('娱乐', '🎮', TxType.expense),
    ('医疗', '💊', TxType.expense),
    ('人情', '🧧', TxType.expense),
    ('其他', '📦', TxType.expense),
    ('工资', '💰', TxType.income),
    ('红包/礼金', '🎁', TxType.income),
    ('其他', '📦', TxType.income),
  ];

  /// (关键词, 分类名, 分类类型)
  static const List<(String, String, TxType)> merchantRules = [
    ('美团', '餐饮', TxType.expense),
    ('饿了么', '餐饮', TxType.expense),
    ('肯德基', '餐饮', TxType.expense),
    ('麦当劳', '餐饮', TxType.expense),
    ('星巴克', '餐饮', TxType.expense),
    ('瑞幸', '餐饮', TxType.expense),
    ('面馆', '餐饮', TxType.expense),
    ('餐厅', '餐饮', TxType.expense),
    ('高德打车', '交通', TxType.expense),
    ('滴滴', '交通', TxType.expense),
    ('地铁', '交通', TxType.expense),
    ('公交', '交通', TxType.expense),
    ('铁路', '交通', TxType.expense),
    ('12306', '交通', TxType.expense),
    ('加油', '交通', TxType.expense),
    ('沃尔玛', '购物', TxType.expense),
    ('超市', '购物', TxType.expense),
    ('便利店', '购物', TxType.expense),
    ('LAWSON', '购物', TxType.expense),
    ('盒马', '购物', TxType.expense),
    ('京东', '购物', TxType.expense),
    ('淘宝', '购物', TxType.expense),
    ('拼多多', '购物', TxType.expense),
    ('医院', '医疗', TxType.expense),
    ('药房', '医疗', TxType.expense),
    ('诊所', '医疗', TxType.expense),
    ('电影', '娱乐', TxType.expense),
    ('游戏', '娱乐', TxType.expense),
    ('Steam', '娱乐', TxType.expense),
    ('Valve', '娱乐', TxType.expense),
    ('哔哩哔哩', '娱乐', TxType.expense),
    ('漫画', '娱乐', TxType.expense),
    ('充电', '娱乐', TxType.expense),
    ('红包', '人情', TxType.expense),
    ('礼金', '人情', TxType.expense),
  ];

  /// 建库时写入种子数据
  static Future<void> insertAll(Database db) async {
    final batch = db.batch();

    for (var i = 0; i < categories.length; i++) {
      final (name, icon, type) = categories[i];
      batch.insert('categories', {
        'name': name,
        'icon': icon,
        'type': type.dbValue,
        'use_count': 0,
        'sort': i,
        'is_preset': 1,
      });
    }
    await batch.commit(noResult: true);

    // 分类 id 需回查后才能建映射
    final rows = await db.query('categories', columns: ['id', 'name', 'type']);
    int? findId(String name, TxType type) {
      for (final r in rows) {
        if (r['name'] == name && r['type'] == type.dbValue) return r['id'] as int;
      }
      return null;
    }

    final ruleBatch = db.batch();
    for (final (keyword, categoryName, type) in merchantRules) {
      final categoryId = findId(categoryName, type);
      if (categoryId == null) continue;
      ruleBatch.insert(
        'merchant_rules',
        {
          'keyword': keyword,
          'category_id': categoryId,
          'hit_count': 1,
          'source': 'preset',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await ruleBatch.commit(noResult: true);
  }
}
