import 'package:ledger_app/core/utils/money.dart';

import 'support/check.dart';

void run() {
  describe('Money.formatCents 金额格式化（整数分 → 元）', () {
    check('千分位与两位小数', () {
      expectEq(Money.formatCents(0), '0.00');
      expectEq(Money.formatCents(1250), '12.50');
      expectEq(Money.formatCents(123450), '1,234.50');
      expectEq(Money.formatCents(123456789), '1,234,567.89');
      expectEq(Money.formatCents(122650), '1,226.50');
    });

    check('不足一元补零，不丢分', () {
      expectEq(Money.formatCents(5), '0.05');
      expectEq(Money.formatCents(50), '0.50');
      expectEq(Money.formatCents(100), '1.00');
    });

    check('负数（结余为负）', () {
      expectEq(Money.formatCents(-20000), '-200.00');
      expectEq(Money.formatCents(-5), '-0.05');
    });
  });

  describe('Money.plainCents 无千分位（CSV 与编辑回填）', () {
    check('整数分 → 元字符串', () {
      expectEq(Money.plainCents(1250), '12.50');
      expectEq(Money.plainCents(1234560), '12345.60');
      expectEq(Money.plainCents(5), '0.05');
      expectEq(Money.plainCents(0), '0.00');
    });
  });

  describe('Money.signedCents 带符号展示', () {
    check('支出带负号、收入带正号、转账无符号', () {
      expectEq(Money.signedCents(1000, isExpense: true, isTransfer: false), '-10.00');
      expectEq(Money.signedCents(100000, isExpense: false, isTransfer: false), '+1,000.00');
      expectEq(Money.signedCents(200000, isExpense: true, isTransfer: true), '2,000.00');
    });
  });

  describe('Money.parseCents 金额解析', () {
    check('容忍货币符号、千分位、空格', () {
      expectEq(Money.parseCents('¥931.92'), 93192);
      expectEq(Money.parseCents('1,000.00'), 100000);
      expectEq(Money.parseCents(' 25 '), 2500);
      expectEq(Money.parseCents('10.5'), 1050);
      expectEq(Money.parseCents('0.01'), 1);
      expectEq(Money.parseCents('0.1'), 10);
    });

    check('非法输入返回 null', () {
      expectNull(Money.parseCents(null));
      expectNull(Money.parseCents(''));
      expectNull(Money.parseCents('0'));
      expectNull(Money.parseCents('0.00'));
      expectNull(Money.parseCents('-10'));
      expectNull(Money.parseCents('10.999'));
      expectNull(Money.parseCents('abc'));
      expectNull(Money.parseCents('1.2.3'));
    });

    check('与 plainCents 往返一致（不丢分）', () {
      for (final cents in [1, 5, 99, 100, 1050, 2550, 93192, 123456789]) {
        expectEq(Money.parseCents(Money.plainCents(cents)), cents);
      }
    });
  });

  describe('整数分：浮点误差从根上消失', () {
    check('0.1 元 + 0.2 元 = 0.3 元（10 + 20 = 30 分）', () {
      final a = Money.parseCents('0.1')!;
      final b = Money.parseCents('0.2')!;
      expectEq(a + b, 30);
      expectEq(Money.plainCents(a + b), '0.30');
    });

    check('一千笔 0.1 元精确累加为 100.00 元', () {
      var total = 0;
      for (var i = 0; i < 1000; i++) {
        total += Money.parseCents('0.1')!;
      }
      expectEq(total, 10000);
      expectEq(Money.formatCents(total), '100.00');
    });
  });
}
