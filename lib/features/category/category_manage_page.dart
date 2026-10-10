import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../models/category.dart';
import '../../models/tx_type.dart';

/// F2 分类管理（设置 → 分类管理）
class CategoryManagePage extends StatefulWidget {
  const CategoryManagePage({super.key});

  @override
  State<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends State<CategoryManagePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  List<Category> _expense = const [];
  List<Category> _income = const [];
  bool _loading = true;

  TxType get _currentType =>
      _tab.index == 0 ? TxType.expense : TxType.income;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final expense = await Services.categories.listByType(TxType.expense);
    final income = await Services.categories.listByType(TxType.income);
    if (!mounted) return;
    setState(() {
      _expense = expense;
      _income = income;
      _loading = false;
    });
  }

  Future<void> _edit({Category? category}) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    final iconController = TextEditingController(text: category?.icon ?? '📦');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category == null ? '新增分类' : '编辑分类'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '分类名称'),
              maxLength: 8,
            ),
            TextField(
              controller: iconController,
              decoration: const InputDecoration(labelText: '图标（emoji，如 🍜）'),
              maxLength: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;

    final name = nameController.text.trim();
    final icon = iconController.text.trim();
    if (name.isEmpty) {
      _toast('分类名称不能为空');
      return;
    }
    if (category == null) {
      await Services.categories.insert(
        Category(name: name, icon: icon.isEmpty ? '📦' : icon, type: _currentType),
      );
    } else {
      await Services.categories
          .update(category.copyWith(name: name, icon: icon.isEmpty ? '📦' : icon));
    }
    await _reload();
  }

  Future<void> _delete(Category category) async {
    try {
      await Services.categories.delete(category.id!);
      await _reload();
    } on StateError catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final list = _currentType == TxType.expense ? _expense : _income;

    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: '支出分类'), Tab(text: '收入分类')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                for (final category in list)
                  ListTile(
                    leading: Text(category.icon, style: const TextStyle(fontSize: 20)),
                    title: Text(category.name),
                    subtitle: Text('已用 ${category.useCount} 次'
                        '${category.isPreset ? ' · 预置' : ''}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _edit(category: category),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: category.isPreset ? null : () => _delete(category),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('提示：预置分类不可删除；已被流水使用的分类需先改分类再删除。',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('新增分类'),
      ),
    );
  }
}
