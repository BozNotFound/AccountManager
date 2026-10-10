import 'package:ledger_app/core/utils/datetime_utils.dart';

import 'support/check.dart';

void run() {
  describe('DateTimeUtils 日期工具', () {
    check('DB 字符串往返', () {
      final dt = DateTime(2026, 10, 5, 19, 54);
      expectEq(DateTimeUtils.toDb(dt), '2026-10-05 19:54');
      expectEq(DateTimeUtils.fromDb('2026-10-05 19:54'), dt);
    });

    check('dayKey / monthKey 补零', () {
      final dt = DateTime(2026, 1, 9, 8, 5);
      expectEq(DateTimeUtils.dayKey(dt), '2026-01-09');
      expectEq(DateTimeUtils.monthKey(dt), '2026-01');
    });

    check('月份边界（12 月跨年）', () {
      final dec = DateTime(2026, 12, 15);
      expectEq(DateTimeUtils.monthStart(dec), DateTime(2026, 12, 1));
      expectEq(DateTimeUtils.nextMonthStart(dec), DateTime(2027, 1, 1));
      expectEq(DateTimeUtils.addMonths(dec, 1), DateTime(2027, 1, 1));
      expectEq(DateTimeUtils.addMonths(dec, -11), DateTime(2026, 1, 1));
    });

    check('年份回退', () {
      expectEq(DateTimeUtils.addMonths(DateTime(2026, 1, 31), -1), DateTime(2025, 12, 1));
    });

    check('展示标签', () {
      expectEq(DateTimeUtils.monthLabel(DateTime(2026, 10, 3)), '2026年10月');
      expectEq(DateTimeUtils.dayLabel('2026-10-05'), '10月5日 周一');
      expectEq(DateTimeUtils.timeLabel(DateTime(2026, 10, 5, 9, 5)), '09:05');
    });
  });
}
