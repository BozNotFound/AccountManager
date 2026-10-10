// 命令行工具，靠 print 输出分析结果，属预期用法
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart' show Severity;

/// 进程内静态分析（等价于 `flutter analyze`）。
///
/// 背景：某些受限环境下无法创建带管道的子进程，`flutter analyze` / `dart analyze`
/// 需要拉起 analysis server 子进程从而失败。本脚本直接用 package:analyzer
/// 在进程内分析整个工程。
///
/// 用法：dart tool/analyze_project.dart
Future<void> main(List<String> args) async {
  final root = Directory.current.path;
  final collection = AnalysisContextCollection(includedPaths: [root]);

  var files = 0;
  var errors = 0;
  var warnings = 0;
  var hints = 0;
  final lines = <String>[];

  for (final context in collection.contexts) {
    final analyzed = context.contextRoot
        .analyzedFiles()
        .where((path) => path.endsWith('.dart'))
        .where((path) => !path.contains('/.dart_tool/'))
        .where((path) => !path.contains(r'\.dart_tool\'))
        .where((path) => !path.contains('/build/'))
        .toList()
      ..sort();

    for (final path in analyzed) {
      final result = await context.currentSession.getResolvedUnit(path);
      if (result is! ResolvedUnitResult) continue;
      files++;

      for (final issue in result.errors) {
        final message = issue.message;
        // dart:ui 由 Flutter 引擎提供，脱离 flutter 工具时无法解析，属已知噪音
        if (message.contains('dart:ui')) continue;

        final line = result.lineInfo.getLocation(issue.offset).lineNumber;
        final text = '${_relative(root, path)}:$line  ${issue.severity.name.toUpperCase()}  '
            '${issue.errorCode.name}  $message';
        switch (issue.severity) {
          case Severity.error:
            errors++;
            lines.add(text);
          case Severity.warning:
            warnings++;
            lines.add(text);
          case Severity.info:
            hints++;
        }
      }
    }
  }

  for (final line in lines) {
    print(line);
  }
  print('');
  print('分析文件 $files 个：错误 $errors，警告 $warnings，提示 $hints');
  if (errors > 0) {
    exitCode = 1;
  }
}

String _relative(String root, String path) {
  final normalizedRoot = root.replaceAll(r'\', '/');
  final normalizedPath = path.replaceAll(r'\', '/');
  if (normalizedPath.startsWith(normalizedRoot)) {
    return normalizedPath.substring(normalizedRoot.length + 1);
  }
  return normalizedPath;
}
