import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/utils/amount_input.dart';
import '../../core/utils/datetime_utils.dart';
import '../../core/utils/money.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../models/tx_type.dart';
import 'number_keyboard.dart';

/// F1 手动快速记账页（UI 仅确定位置，不做视觉打磨）
/// 自上而下：收支切换 → 金额 → 分类网格 → 日期/备注 → 大键盘
class EntryPage extends StatefulWidget {
  const EntryPage({super.key, this.initial});

  /// 为空表示新建，否则为编辑
  final Transaction? initial;

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  final AmountInput _input = AmountInput();

  late TxType _type;
  List<Category> _categories = const [];
  int? _categoryId;
  late DateTime _date;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  bool _saving = false;

  bool get _isEditing => widget.initial != null;

  /// 转账记录不支持改类型（避免误转为收支）
  bool get _typeLocked => widget.initial?.type == TxType.transfer;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _type = initial?.type ?? TxType.expense;
    _date = initial?.transDate ?? DateTime.now();
    _categoryId = initial?.categoryId;
    _noteController.text = initial?.note ?? '';
    _merchantController.text = initial?.merchant ?? '';
    if (initial != null) {
      _input.setRaw(Money.plainCents(initial.amountCents));
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (_type == TxType.transfer) {
      setState(() => _categories = const []);
      return;
    }
    final list = await Services.categories.listByType(_type);
    if (!mounted) return;
    setState(() {
      _categories = list;
      if (_categoryId != null && !list.any((c) => c.id == _categoryId)) {
        _categoryId = null;
      }
    });
  }

  Future<void> _switchType(TxType type) async {
    if (type == _type) return;
    setState(() {
      _type = type;
      _categoryId = null;
    });
    await _loadCategories();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute);
    });
  }

  Future<void> _save() async {
    final amountCents = _input.cents;
    if (amountCents == null) {
      _toast('请输入有效金额');
      return;
    }
    if (_type != TxType.transfer && _categoryId == null) {
      _toast('请选择分类');
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final tx = Transaction(
      id: widget.initial?.id,
      type: _type,
      amountCents: amountCents,
      categoryId: _categoryId,
      merchant: _merchantController.text.trim(),
      note: _noteController.text.trim(),
      transDate: _date,
      source: widget.initial?.source ?? 'manual',
      createdAt: widget.initial?.createdAt ?? now,
      updatedAt: now,
    );

    // 重复检测：同日 + 同额 + 同商户（仅提示，不拦截）
    if (!_isEditing) {
      final dup = await Services.transactions.countDuplicates(tx);
      if (dup > 0 && mounted) {
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('疑似重复'),
            content: const Text('当天已有一笔相同金额、相同商户的记录，仍要保存吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('仍然保存')),
            ],
          ),
        );
        if (go != true) {
          setState(() => _saving = false);
          return;
        }
      }
    }

    try {
      if (_isEditing) {
        await Services.transactions.update(tx);
      } else {
        await Services.transactions.insert(tx);
        if (_categoryId != null) {
          await Services.categories.incrementUseCount(_categoryId!);
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('保存失败：$e');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑' : '记一笔'),
        actions: [
          if (_typeLocked)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: Text('转账记录')),
            ),
        ],
      ),
      body: Column(
        children: [
          _typeSelector(),
          AmountDisplay(input: _input, type: _type),
          _metaRow(),
          Expanded(child: _categoryGrid()),
          NumberKeyboard(
            onKey: (key) => setState(() => _input.press(key)),
            onDone: _saving ? () {} : _save,
            canSave: _input.isValid && !_saving,
          ),
        ],
      ),
    );
  }

  Widget _typeSelector() {
    if (_typeLocked) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SegmentedButton<TxType>(
        segments: const [
          ButtonSegment(value: TxType.expense, label: Text('支出')),
          ButtonSegment(value: TxType.income, label: Text('收入')),
        ],
        selected: {_type},
        onSelectionChanged: (set) => _switchType(set.first),
      ),
    );
  }

  Widget _metaRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event, size: 18),
            label: Text(
              '${_date.year}-${_date.month.toString().padLeft(2, '0')}-'
              '${_date.day.toString().padLeft(2, '0')} ${DateTimeUtils.timeLabel(_date)}',
            ),
          ),
          const Spacer(),
          Expanded(
            child: TextField(
              controller: _noteController,
              decoration: const InputDecoration(hintText: '备注（可选）', isDense: true),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryGrid() {
    if (_type == TxType.transfer) {
      return const Center(child: Text('转账记录不计入支出/收入统计'));
    }
    if (_categories.isEmpty) {
      return const Center(child: Text('暂无分类，请先在 设置 → 分类管理 中添加'));
    }
    return GridView.count(
      crossAxisCount: 4,
      padding: const EdgeInsets.all(12),
      childAspectRatio: 1.15,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final category in _categories)
          InkWell(
            onTap: () => setState(() => _categoryId = category.id),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: _categoryId == category.id
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerLow,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(category.icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(category.name, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
