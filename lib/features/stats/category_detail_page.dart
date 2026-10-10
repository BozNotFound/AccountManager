import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/utils/amount_color.dart';
import '../../core/utils/datetime_utils.dart';
import '../../core/utils/money.dart';
import '../../models/transaction.dart';
import '../../models/tx_type.dart';
import '../manual_entry/entry_page.dart';

/// F5 下钻页：某月某分类的明细列表
class CategoryDetailPage extends StatefulWidget {
  const CategoryDetailPage({
    super.key,
    required this.month,
    required this.categoryId,
    required this.categoryName,
  });

  final DateTime month;

  /// null 表示未分类
  final int? categoryId;
  final String categoryName;

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage> {
  List<Transaction> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final items = await Services.transactions.listByMonthAndCategory(
      widget.month,
      categoryId: widget.categoryId,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  /// 合计（分）
  int get _totalCents {
    var sum = 0;
    for (final tx in _items) {
      sum += tx.amountCents;
    }
    return sum;
  }

  Future<void> _edit(Transaction tx) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EntryPage(initial: tx)),
    );
    if (saved == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.categoryName, style: const TextStyle(fontSize: 16)),
            Text(
              DateTimeUtils.monthLabel(widget.month),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Row(
                    children: [
                      Text('合计 ${Money.formatCents(_totalCents)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${_items.length} 笔', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('本月该分类没有记录'))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final tx = _items[index];
                            final color = amountColor(context, tx.type);
                            final title = tx.merchant.isNotEmpty
                                ? tx.merchant
                                : (tx.note.isNotEmpty ? tx.note : widget.categoryName);
                            return ListTile(
                              onTap: () => _edit(tx),
                              title: Text(title, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                '${DateTimeUtils.dayKey(tx.transDate)} '
                                '${DateTimeUtils.timeLabel(tx.transDate)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Text(
                                Money.signedCents(
                                  tx.amountCents,
                                  isExpense: tx.type == TxType.expense,
                                  isTransfer: tx.type == TxType.transfer,
                                ),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: color,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
