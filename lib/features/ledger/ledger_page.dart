import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/utils/amount_color.dart';
import '../../core/utils/datetime_utils.dart';
import '../../core/utils/money.dart';
import '../../models/category.dart';
import '../../models/ledger_view.dart';
import '../../models/transaction.dart';
import '../../models/tx_type.dart';
import '../manual_entry/entry_page.dart';
import '../settings/settings_page.dart';
import '../stats/stats_page.dart';

/// F3 流水列表（首页）
/// 自上而下：月份切换 → 当月汇总 → 按日分组列表 → 记一笔 FAB
class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  DateTime _month = DateTimeUtils.monthStart(DateTime.now());
  List<DayGroup> _groups = const [];
  MonthSummary _summary = const MonthSummary();
  Map<int, Category> _categoryMap = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final groups = await Services.transactions.listMonthGrouped(_month);
    final summary = await Services.transactions.monthSummary(_month);
    final categories = await Services.categories.listAll();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _summary = summary;
      _categoryMap = {
        for (final c in categories)
          if (c.id != null) c.id!: c,
      };
      _loading = false;
    });
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTimeUtils.addMonths(_month, delta));
    _reload();
  }

  Future<void> _openEntry({Transaction? initial}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EntryPage(initial: initial)),
    );
    if (saved == true) await _reload();
  }

  Future<void> _openStats() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => StatsPage(initialMonth: _month)),
    );
    await _reload();
  }

  Future<void> _showActions(Transaction tx) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openEntry(initial: tx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _confirmDelete(tx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Transaction tx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这笔记录？'),
        content: Text('${_titleOf(tx)}  ${Money.formatCents(tx.amountCents)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await Services.transactions.delete(tx.id!);
    await _reload();
  }

  String _titleOf(Transaction tx) {
    if (tx.merchant.isNotEmpty) return tx.merchant;
    if (tx.note.isNotEmpty) return tx.note;
    if (tx.type == TxType.transfer) return '转账';
    final category = tx.categoryId == null ? null : _categoryMap[tx.categoryId];
    return category?.name ?? '未分类';
  }

  String _iconOf(Transaction tx) {
    if (tx.type == TxType.transfer) return '🔁';
    final category = tx.categoryId == null ? null : _categoryMap[tx.categoryId];
    return category?.icon ?? '📦';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left),
              tooltip: '上一月',
            ),
            Text(DateTimeUtils.monthLabel(_month)),
            IconButton(
              onPressed: () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right),
              tooltip: '下一月',
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '图片记账',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('图片记账将在 M4 实现')),
            ),
            icon: const Icon(Icons.image_outlined),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
              await _reload();
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _summaryCard(),
          Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _list()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEntry(),
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
    );
  }

  Widget _summaryCard() {
    // 开发文档 §7.1：点击汇总卡进入统计页
    return InkWell(
      onTap: _openStats,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Row(
          children: [
            _summaryItem('支出', Money.formatCents(_summary.expenseCents), const Color(0xFFD32F2F)),
            _summaryItem('收入', Money.formatCents(_summary.incomeCents), const Color(0xFF2E7D32)),
            _summaryItem(
              '结余',
              Money.formatCents(_summary.balanceCents),
              Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }

  Widget _list() {
    if (_groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('本月还没有记录'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(onPressed: () => _openEntry(), child: const Text('记一笔')),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('图片记账将在 M4 实现')),
                  ),
                  child: const Text('图片记账'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Text(DateTimeUtils.dayLabel(group.day), style: const TextStyle(fontSize: 12)),
                  const Spacer(),
                  if (group.expenseCents > 0)
                    Text('支出 ${Money.formatCents(group.expenseCents)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFD32F2F))),
                  if (group.incomeCents > 0) ...[
                    const SizedBox(width: 10),
                    Text('收入 ${Money.formatCents(group.incomeCents)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32))),
                  ],
                ],
              ),
            ),
            for (final tx in group.items) _tile(tx),
          ],
        );
      },
    );
  }

  Widget _tile(Transaction tx) {
    final isTransfer = tx.type == TxType.transfer;
    final color = amountColor(context, tx.type);
    return ListTile(
      onTap: () => _showActions(tx),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(_iconOf(tx)),
      ),
      title: Row(
        children: [
          Flexible(child: Text(_titleOf(tx), overflow: TextOverflow.ellipsis)),
          if (isTransfer)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: const Text('转账', style: TextStyle(fontSize: 10)),
            ),
        ],
      ),
      subtitle: Text(
        DateTimeUtils.timeLabel(tx.transDate) +
            (tx.note.isEmpty ? '' : ' · ${tx.note}'),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Text(
        Money.signedCents(tx.amountCents,
            isExpense: tx.type == TxType.expense, isTransfer: isTransfer),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: color),
      ),
    );
  }
}
