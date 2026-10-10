import 'tx_type.dart';

/// 分类（一级分类，不做二级，开发文档 §F2）
class Category {
  const Category({
    this.id,
    required this.name,
    required this.icon,
    required this.type,
    this.useCount = 0,
    this.sort = 0,
    this.isPreset = false,
  });

  final int? id;
  final String name;

  /// emoji 图标
  final String icon;

  /// 仅 expense / income
  final TxType type;
  final int useCount;
  final int sort;
  final bool isPreset;

  Category copyWith({
    int? id,
    String? name,
    String? icon,
    TxType? type,
    int? useCount,
    int? sort,
    bool? isPreset,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      useCount: useCount ?? this.useCount,
      sort: sort ?? this.sort,
      isPreset: isPreset ?? this.isPreset,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'icon': icon,
        'type': type.dbValue,
        'use_count': useCount,
        'sort': sort,
        'is_preset': isPreset ? 1 : 0,
      };

  factory Category.fromMap(Map<String, Object?> map) => Category(
        id: map['id'] as int?,
        name: (map['name'] as String?) ?? '',
        icon: (map['icon'] as String?) ?? '📦',
        type: TxType.fromDb((map['type'] as String?) ?? 'expense'),
        useCount: (map['use_count'] as int?) ?? 0,
        sort: (map['sort'] as int?) ?? 0,
        isPreset: ((map['is_preset'] as int?) ?? 0) == 1,
      );

  @override
  String toString() => 'Category(id: $id, name: $name, type: ${type.dbValue})';
}
