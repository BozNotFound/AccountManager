import 'package:flutter/material.dart';

import 'app.dart';
import 'core/db/database_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 预建库 + 写入种子分类，避免首帧后再建库
  await AppDatabase.instance.database;
  runApp(const LedgerApp());
}
