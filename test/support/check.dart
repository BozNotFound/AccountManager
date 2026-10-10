// 极简断言框架要往控制台打结果，属预期用法
// ignore_for_file: avoid_print

/// 极简断言框架（纯 Dart，无 Flutter 依赖）
/// 用途：在当前环境下用 `dart test_run.dart` 进程内执行；
/// 后续环境允许时同样可换成 flutter_test，不影响被测代码。
library;

int _passed = 0;
int _failed = 0;
final List<String> _failures = [];

int get passedCount => _passed;
int get failedCount => _failed;
List<String> get failures => List.unmodifiable(_failures);

void describe(String title, void Function() body) {
  print('\n▶ $title');
  body();
}

/// 异步用例分组标题（异步用例请直接使用 checkAsync + section）
void section(String title) {
  print('\n▶ $title');
}

void check(String name, void Function() body) {
  try {
    body();
    _passed++;
    print('  ✓ $name');
  } catch (e) {
    _failed++;
    _failures.add('$name → $e');
    print('  ✗ $name  →  $e');
  }
}

Future<void> checkAsync(String name, Future<void> Function() body) async {
  try {
    await body();
    _passed++;
    print('  ✓ $name');
  } catch (e) {
    _failed++;
    _failures.add('$name → $e');
    print('  ✗ $name  →  $e');
  }
}

void expectEq(Object? actual, Object? expected) {
  if (actual != expected) {
    throw StateError('期望 <$expected>，实际 <$actual>');
  }
}

void expectTrue(bool value, [String? message]) {
  if (!value) throw StateError(message ?? '期望 true，实际 false');
}

void expectFalse(bool value, [String? message]) {
  if (value) throw StateError(message ?? '期望 false，实际 true');
}

void expectNull(Object? value, [String? message]) {
  if (value != null) throw StateError(message ?? '期望 null，实际 <$value>');
}

void expectNotNull(Object? value, [String? message]) {
  if (value == null) throw StateError(message ?? '期望非 null，实际 null');
}

/// 断言抛出 StateError（用于"分类下有流水禁止删除"等场景）
void expectStateError(void Function() body, [String? message]) {
  try {
    body();
  } catch (e) {
    if (e is StateError) return;
    throw StateError('期望 StateError，实际 ${e.runtimeType}: $e');
  }
  throw StateError(message ?? '期望抛出 StateError，但没有抛出');
}

/// 浮点近似相等（用于比例、金额除法等）
void expectClose(double actual, double expected, [double epsilon = 1e-9]) {
  if ((actual - expected).abs() > epsilon) {
    throw StateError('期望 ≈$expected，实际 $actual（容差 $epsilon）');
  }
}
