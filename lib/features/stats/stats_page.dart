import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/utils/datetime_utils.dart';
import '../../core/utils/money.dart';
import '../../models/ledger_view.dart';
import '../../models/stats_view.dart';
import '../common/month_switcher.dart';
import 'category_detail_page.dart';
import 'pie_chart.dart';

/// F5 月度统计页：总览 + 环比 + 分类占比饼图 + 分类排行（可下钻）
class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.initialMonth});

  final DateTime initialMonth;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  static const _expenseColor = Color(0xFFD32F2F);
  static const _incomeColor = Color(0xFF2E7D32);

  late DateTime _month = DateTimeUtils.monthStart(widget.initialMonth);
  MonthComparison _comparison = const MonthComparison(
    current: MonthSummary(),
    previous: MonthSummary(),
  );
  List<CategoryStat> _stats = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final comparison = await Services.transactions.monthComparison(_month);
    final stats = await Services.transactions.expenseByCategory(_month);
    if (!mounted) return;
    setState(() {
      _comparison = comparison;
      _stats = stats;
      _loading = false;
    });
  }

  void _changeMonth(DateTime month) {
    setState(() => _month = DateTimeUtils.monthStart(month));
    _reload();
  }

  Future<void> _openDetail(CategoryStat stat) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryDetailPage(
          month: _month,
          categoryId: stat.categoryId,
          categoryName: stat.name,
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: MonthSwitcher(month: _month, onChanged: _changeMonth, compact: true),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _overview(),
                const SizedBox(height: 4),
                if (_stats.isEmpty) _emptyExpense() else ...[
                  _pieSection(),
                  const Divider(height: 24),
                  _rankSection(),
                ],
              ],
            ),
    );
  }

  // ── 总览 ────────────────────────────────────────────────

  Widget _overview() {
    final current = _comparison.current;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metric(
            label: '支出',
            value: Money.formatCents(current.expenseCents),
            valueColor: _expenseColor,
            change: _comparison.expenseChange,
            higherIsBetter: false,
          ),
          _metric(
            label: '收入',
            value: Money.formatCents(current.incomeCents),
            valueColor: _incomeColor,
            change: _comparison.incomeChange,
            higherIsBetter: true,
          ),
          _metric(
            label: '结余',
            value: Money.formatCents(current.balanceCents),
            valueColor: Theme.of(context).colorScheme.onSurface,
            change: _comparison.balanceChange,
            higherIsBetter: null, // 中性色，避免误导
          ),
        ],
      ),
    );
  }

  Widget _metric({
    required String label,
    required String value,
    required Color valueColor,
    required double? change,
    required bool? higherIsBetter,
  }) {
    final variant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: valueColor),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _changeLabel(change),
              style: TextStyle(
                fontSize: 11,
                color: higherIsBetter == null ? variant : _changeColor(change, higherIsBetter),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _changeLabel(double? change) {
    if (change == null) return '较上月 —';
    final arrow = change >= 0 ? '↑' : '↓';
    return '较上月 $arrow${(change.abs() * 100).toStringAsFixed(1)}%';
  }

  Color _changeColor(double? change, bool higherIsBetter) {
    if (change == null || change == 0) {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }
    final up = change > 0;
    final good = higherIsBetter ? up : !up;
    return good ? _incomeColor : _expenseColor;
  }

  // ── 饼图 ────────────────────────────────────────────────

  Widget _pieSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          CategoryPieChart(
            stats: _stats,
            onSliceTap: (index) => _openDetail(_stats[index]),
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('本月支出', style: TextStyle(fontSize: 11)),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 92,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Money.formatCents(_comparison.current.expenseCents),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < _stats.length; i++) _legendItem(_stats[i], i),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(CategoryStat stat, int index) {
    return InkWell(
      onTap: () => _openDetail(stat),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: pieColorAt(index), shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              '${stat.name} ${(stat.ratio * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ── 排行 ────────────────────────────────────────────────

  Widget _rankSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('分类排行', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        for (var i = 0; i < _stats.length; i++) _rankItem(_stats[i], i),
      ],
    );
  }

  Widget _rankItem(CategoryStat stat, int index) {
    final variant = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: () => _openDetail(stat),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: pieColorAt(index), shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Text(stat.icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(child: Text(stat.name, overflow: TextOverflow.ellipsis)),
                Text('${stat.count} 笔', style: TextStyle(fontSize: 11, color: variant)),
                const SizedBox(width: 12),
                Text(
                  Money.formatCents(stat.totalCents),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: stat.ratio,
                minHeight: 5,
                color: pieColorAt(index),
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyExpense() {
    final variant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
      child: Column(
        children: [
          Text('本月还没有支出记录', style: TextStyle(fontSize: 14, color: variant)),
          const SizedBox(height: 8),
          Text(
            '记一笔之后，这里会显示分类占比与排行',
            style: TextStyle(fontSize: 12, color: variant),
          ),
        ],
      ),
    );
  }
}
