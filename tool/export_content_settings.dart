// 从一份 settings.hive 中抽取「内容类」设置键（固定词 / 词库），
// 输出为「设置 - 存储 - 导入配置」可直接导入的 JSON。
//
// 用法: dart run tool/export_content_settings.dart <hive目录> [输出.json]
// 注意: 请对 settings.hive 的副本操作，Hive 打开 box 需要写权限。
//
// 偏离上游：上游 v4.2.1 没有本地配置导出/导入（只走云同步），本脚本与
// LocalStorageService.exportSettings/importSettings 是同一套私有能力的一部分。
// 输出格式与 buildSettingsExportDocument 一致（带版本信封）；
// contentKeys 必须与 local_storage_service.dart 的 contentSettingKeys 保持一致。
import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';

/// 与 LocalStorageService.contentSettingKeys 一一对应。
const contentKeys = [
  'fixed_tags_data',
  'fixed_tag_links_data',
  'fixed_tag_categories_data',
  'tag_library_entries_data',
  'tag_library_categories_data',
];

/// 与 LocalStorageService.settingsExportFormatVersion 保持一致。
const exportFormatVersion = 1;

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: dart run tool/export_content_settings.dart <hive_dir> [out.json]',
    );
    exit(64);
  }
  Hive.init(args[0]);
  final box = await Hive.openBox('settings');
  final settings = <String, dynamic>{};
  for (final key in contentKeys) {
    final value = box.get(key);
    if (value != null) {
      settings[key] = value;
    } else {
      stdout.writeln('missing: $key');
    }
  }
  final document = <String, dynamic>{
    'formatVersion': exportFormatVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'settings': settings,
  };
  final out = args.length > 1 ? args[1] : 'pc_content_settings.json';
  await File(
    out,
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(document));
  for (final entry in settings.entries) {
    stdout.writeln('${entry.key}: ${entry.value.toString().length} chars');
  }
  stdout.writeln('written: $out (${settings.length} keys)');
  await box.close();
}
