/// CSV 文本生成（纯 Dart，不引第三方包）
///
/// Excel 兼容要点：UTF-8 BOM（否则中文乱码）+ CRLF 行尾。
class Csv {
  Csv._();

  /// UTF-8 BOM，Excel 打开中文不乱码的关键
  static const bom = '\uFEFF';

  static const _crlf = '\r\n';

  /// 单字段转义：含逗号/引号/换行时用双引号包裹，内部引号翻倍（RFC 4180）
  static String escape(String value) {
    final needQuote = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needQuote) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  static String row(List<Object?> cells) =>
      cells.map((cell) => escape(cell == null ? '' : '$cell')).join(',');

  /// 行列 → CSV 文本；[withBom] 默认 true
  static String build(List<List<Object?>> rows, {bool withBom = true}) {
    final buffer = StringBuffer();
    if (withBom) buffer.write(bom);
    for (final cells in rows) {
      buffer.write(row(cells));
      buffer.write(_crlf);
    }
    return buffer.toString();
  }
}
