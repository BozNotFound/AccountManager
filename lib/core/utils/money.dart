/// 金额工具（不依赖 intl，保持依赖最少）
///
/// **全项目金额统一以「分」为单位的 `int` 存储与运算**，只在展示/导出时转成元。
/// 这样从根上避免浮点累加误差（浮点下 `0.1 + 0.2 != 0.3`），
/// 月度合计、分类占比、以及将来 OCR 的「校验和」比对才靠得住。
class Money {
  Money._();

  /// 123450（分） -> '1,234.50'（带千分位与两位小数，用于界面展示）
  static String formatCents(int cents) {
    final negative = cents < 0;
    final abs = cents.abs();
    return '${negative ? '-' : ''}${_group(abs ~/ 100)}.${_two(abs % 100)}';
  }

  /// 123450（分） -> '1234.50'（不带千分位，用于 CSV 与编辑页回填）
  static String plainCents(int cents) {
    final negative = cents < 0;
    final abs = cents.abs();
    return '${negative ? '-' : ''}${abs ~/ 100}.${_two(abs % 100)}';
  }

  /// 带符号展示：支出 '-12.00'，收入 '+12.00'，转账无符号
  static String signedCents(
    int cents, {
    required bool isExpense,
    required bool isTransfer,
  }) {
    if (isTransfer) return formatCents(cents);
    return '${isExpense ? '-' : '+'}${formatCents(cents)}';
  }

  /// 解析用户输入 / OCR 文本 -> 分。
  /// 容忍 ¥￥、千分位逗号、空格；最多 2 位小数；必须 > 0。
  /// 非法输入返回 null。
  static int? parseCents(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(RegExp(r'[¥￥,\s]'), '');
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
    if (match == null) return null;

    final yuan = int.tryParse(match.group(1)!);
    if (yuan == null) return null; // 位数多到溢出 int
    // '' -> '00'、'5' -> '50'、'92' -> '92'
    final fen = int.parse((match.group(2) ?? '').padRight(2, '0'));
    final cents = yuan * 100 + fen;
    return cents > 0 ? cents : null;
  }

  /// 整数部分加千分位：1234567 -> '1,234,567'
  static String _group(int yuan) {
    final text = yuan.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
      buffer.write(text[i]);
    }
    return buffer.toString();
  }

  /// 分值补零：5 -> '05'
  static String _two(int fen) => fen.toString().padLeft(2, '0');
}
