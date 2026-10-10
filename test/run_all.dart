// 测试入口靠 print 输出结果，属预期用法
// ignore_for_file: avoid_print

import 'dart:io';

import 'amount_input_test.dart' as amount;
import 'csv_test.dart' as csv;
import 'datetime_utils_test.dart' as datetime;
import 'money_test.dart' as money;
import 'repositories_test.dart' as repositories;
import 'stats_test.dart' as stats;
import 'support/check.dart' as check;

/// 纯 Dart 测试入口（无需 Flutter 运行时）：
///   `<dart-sdk>/dart.exe test/run_all.dart`
/// 说明：领域层（models/repositories/core）不依赖 Flutter，故可直接用 Dart VM 执行。
Future<void> main() async {
  money.run();
  amount.run();
  datetime.run();
  csv.run();
  await repositories.run();
  await stats.run();

  print('\n──────────────────────────────');
  print('通过 ${check.passedCount}  失败 ${check.failedCount}');
  if (check.failedCount > 0) {
    print('失败用例：');
    for (final failure in check.failures) {
      print('  · $failure');
    }
    exitCode = 1;
  }
}
