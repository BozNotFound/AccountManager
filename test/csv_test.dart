import 'package:ledger_app/core/utils/csv.dart';
import 'package:ledger_app/features/export/transaction_csv.dart';
import 'package:ledger_app/models/transaction.dart';
import 'package:ledger_app/models/tx_type.dart';

import 'support/check.dart';

/// M7 CSV 生成（纯 Dart，无需数据库）
void run() {
  section('M7 CSV 文本生成');

  check('普通字段不加引号', () {
    expectEq(Csv.escape('餐饮'), '餐饮');
  });

  check('含逗号字段用双引号包裹', () {
    expectEq(Csv.escape('美团,外卖'), '"美团,外卖"');
  });

  check('内部引号翻倍（RFC 4180）', () {
    expectEq(Csv.escape('说"你好"'), '"说""你好"""');
  });

  check('含换行字段被包裹', () {
    expectEq(Csv.escape('第一行\n第二行'), '"第一行\n第二行"');
  });

  check('空值与 null 输出空字段', () {
    expectEq(Csv.row(['a', 'b,c', null]), 'a,"b,c",');
  });

  check('带 BOM + CRLF 行尾', () {
    final text = Csv.build([
      ['a', 'b'],
      ['c', 'd'],
    ]);
    expectTrue(text.startsWith(Csv.bom), '应以 BOM 开头');
    expectEq(text, '${Csv.bom}a,b\r\nc,d\r\n');
  });

  check('可关闭 BOM', () {
    expectEq(Csv.build([
      ['a'],
    ], withBom: false), 'a\r\n');
  });

  section('M7 流水 CSV 字段');

  String bodyOf(String csv) => csv
      .replaceFirst(Csv.bom, '')
      .split('\r\n')
      .where((line) => line.isNotEmpty)
      .skip(1)
      .join('\n');

  Transaction sample({
    int? id = 7,
    TxType type = TxType.expense,
    int amountCents = 1250,
    int? categoryId = 3,
    String merchant = '美团,外卖',
    String note = '午饭',
    String source = 'ocr',
  }) =>
      Transaction(
        id: id,
        type: type,
        amountCents: amountCents,
        categoryId: categoryId,
        merchant: merchant,
        note: note,
        transDate: DateTime(2026, 10, 3, 12, 30),
        source: source,
        createdAt: DateTime(2026, 10, 3, 12, 31),
        updatedAt: DateTime(2026, 10, 3, 12, 31),
      );

  check('表头字段顺序与开发文档 §F6 一致', () {
    final csv = TransactionCsv.build([], categoryNames: const {});
    expectEq(
      csv.replaceFirst(Csv.bom, '').trimRight(),
      'id,type,amount,category,merchant,note,date,source,created_at',
    );
  });

  check('行内容：type/source 英文、金额两位小数、字段转义、分类中文', () {
    final csv = TransactionCsv.build([sample()], categoryNames: const {3: '餐饮'});
    expectEq(
      bodyOf(csv),
      '7,expense,12.50,餐饮,"美团,外卖",午饭,2026-10-03 12:30,ocr,2026-10-03 12:31',
    );
  });

  check('type 三态输出英文（expense / income / transfer）', () {
    final expense = TransactionCsv.build([sample()], categoryNames: const {3: '餐饮'});
    expectTrue(bodyOf(expense).contains(',expense,'), '支出未输出 expense');

    final income = TransactionCsv.build(
      [sample(type: TxType.income, amountCents: 100000)],
      categoryNames: const {3: '餐饮'},
    );
    expectTrue(bodyOf(income).contains(',income,1000.00,'), '收入行不符：${bodyOf(income)}');

    final transfer = TransactionCsv.build(
      [sample(type: TxType.transfer, amountCents: 100000)],
      categoryNames: const {3: '餐饮'},
    );
    expectTrue(bodyOf(transfer).contains(',transfer,1000.00,'), '转账行不符：${bodyOf(transfer)}');
  });

  check('source 输出英文（manual / ocr）', () {
    final manual = TransactionCsv.build(
      [sample(source: 'manual')],
      categoryNames: const {3: '餐饮'},
    );
    expectTrue(bodyOf(manual).contains(',manual,'), '未输出 manual：${bodyOf(manual)}');

    final ocr = TransactionCsv.build([sample(source: 'ocr')], categoryNames: const {3: '餐饮'});
    expectTrue(bodyOf(ocr).contains(',ocr,'), '未输出 ocr：${bodyOf(ocr)}');
  });

  check('未分类（categoryId 为 null）落到「未分类」', () {
    final csv = TransactionCsv.build([sample(categoryId: null)], categoryNames: const {});
    expectTrue(bodyOf(csv).contains(',未分类,'), '未回落为「未分类」');
  });

  check('分类已被删除时回落「未分类」', () {
    final csv = TransactionCsv.build([sample(categoryId: 999)], categoryNames: const {3: '餐饮'});
    expectTrue(bodyOf(csv).contains(',未分类,'), '未回落为「未分类」');
  });

  check('金额不带千分位（Excel 识别为数值）', () {
    final csv =
        TransactionCsv.build([sample(amountCents: 1234560)], categoryNames: const {3: '餐饮'});
    expectTrue(bodyOf(csv).contains(',12345.60,'), '金额格式不符：${bodyOf(csv)}');
  });

  check('小于一元的金额补零（5 分 → 0.05）', () {
    final csv = TransactionCsv.build([sample(amountCents: 5)], categoryNames: const {3: '餐饮'});
    expectTrue(bodyOf(csv).contains(',0.05,'), '金额格式不符：${bodyOf(csv)}');
  });

  check('多笔按传入顺序逐行输出', () {
    final csv = TransactionCsv.build(
      [sample(id: 1), sample(id: 2), sample(id: 3)],
      categoryNames: const {3: '餐饮'},
    );
    final lines = csv.replaceFirst(Csv.bom, '').split('\r\n').where((l) => l.isNotEmpty).toList();
    expectEq(lines.length, 4);
    expectTrue(lines[1].startsWith('1,'), '第一行 id 不符');
    expectTrue(lines[3].startsWith('3,'), '第三行 id 不符');
  });

  section('M7 导出文件名');

  check('按月导出文件名', () {
    expectEq(
      TransactionCsv.fileName(month: DateTime(2026, 10, 3), now: DateTime(2026, 10, 8)),
      'ledger_2026-10.csv',
    );
  });

  check('全量导出文件名带当天日期', () {
    expectEq(
      TransactionCsv.fileName(month: null, now: DateTime(2026, 10, 8)),
      'ledger_all_2026-10-08.csv',
    );
  });
}
