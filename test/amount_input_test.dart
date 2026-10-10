import 'package:ledger_app/core/utils/amount_input.dart';

import 'support/check.dart';

void run() {
  describe('AmountInput 金额输入缓冲', () {
    check('数字拼接与首字符 0 处理', () {
      final input = AmountInput();
      expectEq(input.display, '0');
      input.press('0');
      input.press('0');
      expectEq(input.raw, '0');
      input.press('5');
      expectEq(input.raw, '5');
      input.press('2');
      expectEq(input.raw, '52');
    });

    check('小数点最多一个，小数最多两位', () {
      final input = AmountInput();
      input.press('1');
      input.press('.');
      input.press('2');
      input.press('.');
      expectEq(input.raw, '1.2');
      input.press('5');
      input.press('9');
      expectEq(input.raw, '1.25');
      expectEq(input.cents, 125);
    });

    check('以小数点开头补 0', () {
      final input = AmountInput();
      input.press('.');
      input.press('5');
      expectEq(input.raw, '0.5');
    });

    check('整数部分上限 8 位', () {
      final input = AmountInput();
      for (var i = 0; i < 12; i++) {
        input.press('9');
      }
      expectEq(input.raw.length, AmountInput.maxIntDigits);
    });

    check('退格与清空', () {
      final input = AmountInput();
      input.press('1');
      input.press('2');
      input.press('del');
      expectEq(input.raw, '1');
      input.press('clear');
      expectEq(input.raw, '');
      expectNull(input.cents);
      expectFalse(input.isValid);
    });

    check('仅小数点时不可保存', () {
      final input = AmountInput();
      input.press('1');
      input.press('.');
      expectNull(input.cents);
      expectFalse(input.isValid);
    });

    check('金额换算为分（整数）', () {
      final input = AmountInput();
      for (final ch in '1234.56'.split('')) {
        input.press(ch);
      }
      expectEq(input.cents, 123456);
      expectTrue(input.isValid);
    });
  });
}
