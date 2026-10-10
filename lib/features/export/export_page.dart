import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services.dart';
import '../../core/utils/csv.dart';
import '../../core/utils/datetime_utils.dart';
import '../../models/transaction.dart';
import '../common/month_switcher.dart';
import 'transaction_csv.dart';

/// F6 导出 CSV
///
/// 当前实现：生成 CSV 文本（UTF-8 BOM + CRLF，Excel 可直接打开）并送入系统剪贴板，
/// 由用户自行粘贴保存。落盘/分享方式待确认后再接入（见 README 待办）。
class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  DateTime _month = DateTimeUtils.monthStart(DateTime.now());
  bool _all = false;
  List<Transaction> _txs = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final txs = _all
        ? await Services.transactions.listAll()
        : await Services.transactions.listByMonth(_month);
    if (!mounted) return;
    setState(() {
      _txs = txs;
      _loading = false;
    });
  }

  Future<List<Transaction>> _fetch() => _all
      ? Services.transactions.listAll()
      : Services.transactions.listByMonth(_month);

  Future<String> _buildCsv(List<Transaction> txs) async {
    final categories = await Services.categories.listAll();
    final names = <int, String>{
      for (final c in categories)
        if (c.id != null) c.id!: c.name,
    };
    return TransactionCsv.build(txs, categoryNames: names);
  }

  Future<void> _copyToClipboard() async {
    final txs = await _fetch();
    if (txs.isEmpty) {
      _toast('该范围内没有记录');
      return;
    }
    final csv = await _buildCsv(txs);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    _toast('已复制 ${txs.length} 笔记录（${txs.length + 1} 行 CSV）');
  }

  Future<void> _preview() async {
    final txs = await _fetch();
    if (txs.isEmpty) {
      _toast('该范围内没有记录');
      return;
    }
    final csv = await _buildCsv(txs);
    final lines = csv
        .replaceFirst(Csv.bom, '')
        .split('\r\n')
        .where((line) => line.isNotEmpty)
        .toList();
    final shown = lines.take(6).join('\n');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('预览（共 ${lines.length} 行，显示前 ${lines.length < 6 ? lines.length : 6} 行）'),
        content: SingleChildScrollView(
          child: Text(shown, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final variant = Theme.of(context).colorScheme.onSurfaceVariant;
    final fileName = TransactionCsv.fileName(month: _all ? null : _month, now: DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('导出 CSV')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('导出范围', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('指定月份'), icon: Icon(Icons.calendar_month)),
                ButtonSegment(value: true, label: Text('全部'), icon: Icon(Icons.all_inbox)),
              ],
              selected: {_all},
              onSelectionChanged: (selection) {
                setState(() => _all = selection.first);
                _load();
              },
            ),
          ),
          if (!_all)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: MonthSwitcher(
                  month: _month,
                  onChanged: (month) {
                    setState(() => _month = DateTimeUtils.monthStart(month));
                    _load();
                  },
                ),
              ),
            ),
          const Divider(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _loading ? '统计中…' : '将导出 ${_txs.length} 笔记录',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text('文件名：$fileName', style: TextStyle(fontSize: 12, color: variant)),
                if (!_loading && _txs.isNotEmpty)
                  Text(
                    '日期范围：${DateTimeUtils.dayKey(_txs.last.transDate)} ~ '
                    '${DateTimeUtils.dayKey(_txs.first.transDate)}',
                    style: TextStyle(fontSize: 12, color: variant),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _loading || _txs.isEmpty ? null : _copyToClipboard,
                      icon: const Icon(Icons.copy_all),
                      label: const Text('生成并复制 CSV'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _loading || _txs.isEmpty ? null : _preview,
                      child: const Text('预览'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  child: Text(
                    '格式：UTF-8（带 BOM）+ CRLF 换行，Excel 直接打开不乱码。\n'
                    '字段：${TransactionCsv.header.join(' / ')}\n\n'
                    '本 App 不申请任何权限，因此不直接写磁盘：生成后请粘贴到备忘录、'
                    '文本编辑器或云盘客户端中保存为 .csv 文件。',
                    style: TextStyle(fontSize: 12, color: variant, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
