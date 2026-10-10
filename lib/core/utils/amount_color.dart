import 'package:flutter/material.dart';

import '../../models/tx_type.dart';

/// 全局金额配色：支出 - 红、收入 + 绿、转账中性灰（开发文档 §7.2）
/// 放在 UI 层，避免领域层依赖 Flutter。
Color amountColor(BuildContext context, TxType type) {
  switch (type) {
    case TxType.expense:
      return const Color(0xFFD32F2F);
    case TxType.income:
      return const Color(0xFF2E7D32);
    case TxType.transfer:
      return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

/// 不依赖 BuildContext 的转账灰（用于非 UI 场景）
const Color kTransferGrey = Color(0xFF757575);
