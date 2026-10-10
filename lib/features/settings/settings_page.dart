import 'package:flutter/material.dart';

import '../../core/utils/datetime_utils.dart';
import '../category/category_manage_page.dart';
import '../export/export_page.dart';
import '../stats/stats_page.dart';

/// 设置页：分类管理 / 统计 / 导出 / 关于
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('分类管理'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const CategoryManagePage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.pie_chart_outline),
            title: const Text('月度统计'),
            subtitle: const Text('首页顶部汇总卡也可直接点开'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => StatsPage(initialMonth: DateTimeUtils.monthStart(DateTime.now())),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('导出 CSV'),
            subtitle: const Text('指定月份或全部，Excel 可直接打开'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const ExportPage()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('关于与隐私'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('关于'),
                content: const Text(
                  '本地记账 App（个人自用）\n\n'
                  '· 不申请任何权限，不含 INTERNET 权限\n'
                  '· 不联网，所有数据仅保存在本机 SQLite\n'
                  '· 卸载 App 即删除全部数据\n',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
