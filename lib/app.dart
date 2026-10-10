import 'package:flutter/material.dart';

import 'features/ledger/ledger_page.dart';

class LedgerApp extends StatelessWidget {
  const LedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2F6B4F);

    return MaterialApp(
      title: '记账',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const LedgerPage(),
    );
  }
}
