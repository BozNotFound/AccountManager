import 'money.dart';

/// 大键盘金额输入缓冲（纯逻辑，便于单测）
/// 规则：整数部分最多 8 位、小数最多 2 位、最多一个小数点、首字符不能是小数点
class AmountInput {
  static const int maxIntDigits = 8;

  String _raw = '';

  String get raw => _raw;

  bool get isEmpty => _raw.isEmpty;

  /// 展示文本（空时显示 '0'）
  String get display => _raw.isEmpty ? '0' : _raw;

  /// 是否可保存（金额 > 0）
  bool get isValid => cents != null;

  /// 金额（单位：分，全项目统一用整数分存储）；不可保存时为 null
  int? get cents {
    if (_raw.isEmpty) return null;
    if (_raw.endsWith('.')) return null;
    return Money.parseCents(_raw);
  }

  /// 按下按键：'0'-'9' / '.' / 'del' / 'clear'
  void press(String key) {
    switch (key) {
      case 'del':
        backspace();
        return;
      case 'clear':
        _raw = '';
        return;
      case '.':
        _appendDot();
        return;
      default:
        if (key.length == 1 && key.codeUnitAt(0) >= 48 && key.codeUnitAt(0) <= 57) {
          _appendDigit(key);
        }
    }
  }

  void setRaw(String value) => _raw = value;

  void backspace() {
    if (_raw.isEmpty) return;
    _raw = _raw.substring(0, _raw.length - 1);
  }

  void _appendDot() {
    if (_raw.contains('.')) return;
    _raw = _raw.isEmpty ? '0.' : '$_raw.';
  }

  void _appendDigit(String digit) {
    final dotIndex = _raw.indexOf('.');
    if (dotIndex >= 0) {
      final decimals = _raw.length - dotIndex - 1;
      if (decimals >= 2) return;
    } else {
      if (_raw.length >= maxIntDigits) return;
      // 避免 '007'
      if (_raw == '0') {
        _raw = digit;
        return;
      }
    }
    _raw = '$_raw$digit';
  }
}
