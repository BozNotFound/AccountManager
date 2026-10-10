import 'package:flutter/material.dart';

import '../../core/utils/amount_input.dart';
import '../../models/tx_type.dart';

/// 手动记账大键盘（位置固定：底部区域）
class NumberKeyboard extends StatelessWidget {
  const NumberKeyboard({
    super.key,
    required this.onKey,
    required this.onDone,
    required this.canSave,
  });

  final void Function(String key) onKey;
  final VoidCallback onDone;
  final bool canSave;

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'del'];

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 2.6,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (final key in keys)
                TextButton(
                  onPressed: () => onKey(key),
                  child: Text(
                    key == 'del' ? '退格' : key,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSave ? onDone : null,
              child: const Text('完成'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 金额展示区（位置固定：分类网格上方）
class AmountDisplay extends StatelessWidget {
  const AmountDisplay({super.key, required this.input, required this.type});

  final AmountInput input;
  final TxType type;

  @override
  Widget build(BuildContext context) {
    final color = type == TxType.income
        ? const Color(0xFF2E7D32)
        : const Color(0xFFD32F2F);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(type == TxType.income ? '+' : '-', style: TextStyle(fontSize: 24, color: color)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              input.display,
              key: const Key('amount_text'),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w500, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
