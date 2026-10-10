/// 日期工具。DB 统一存 'yyyy-MM-dd HH:mm'（开发文档 §4.1 trans_date）
class DateTimeUtils {
  DateTimeUtils._();

  static String _pad2(int v) => v.toString().padLeft(2, '0');

  static String toDb(DateTime dt) =>
      '${dt.year}-${_pad2(dt.month)}-${_pad2(dt.day)} ${_pad2(dt.hour)}:${_pad2(dt.minute)}';

  static DateTime fromDb(String value) => DateTime.tryParse(value) ?? DateTime(1970);

  /// 'yyyy-MM-dd'
  static String dayKey(DateTime dt) => '${dt.year}-${_pad2(dt.month)}-${_pad2(dt.day)}';

  /// 'yyyy-MM'
  static String monthKey(DateTime dt) => '${dt.year}-${_pad2(dt.month)}';

  /// 不含右端点的下月首日，用于 [start, end) 查询
  static DateTime monthStart(DateTime dt) => DateTime(dt.year, dt.month, 1);

  static DateTime nextMonthStart(DateTime dt) =>
      dt.month == 12 ? DateTime(dt.year + 1, 1, 1) : DateTime(dt.year, dt.month + 1, 1);

  static DateTime addMonths(DateTime dt, int delta) {
    final total = dt.year * 12 + (dt.month - 1) + delta;
    return DateTime(total ~/ 12, total % 12 + 1, 1);
  }

  /// '2026年10月'
  static String monthLabel(DateTime dt) => '${dt.year}年${dt.month}月';

  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  /// '10月5日 周日'
  static String dayLabel(String dayKey) {
    final dt = DateTime.tryParse(dayKey);
    if (dt == null) return dayKey;
    return '${dt.month}月${dt.day}日 ${_weekdays[dt.weekday - 1]}';
  }

  /// '19:54'
  static String timeLabel(DateTime dt) => '${_pad2(dt.hour)}:${_pad2(dt.minute)}';
}
