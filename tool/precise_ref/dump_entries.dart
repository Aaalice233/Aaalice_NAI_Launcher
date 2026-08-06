// 诊断脚本：读取精准参考库 Hive box 副本，列出当前有效条目
//
// 用法：dart run tool/precise_ref/dump_entries.dart [hive目录]
// 默认读取 %LOCALAPPDATA%/Temp/precise_ref_diag 下的副本，避免与运行中的应用抢锁。
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:nai_launcher/data/models/precise_ref/precise_ref_library_entry.dart';

Future<void> main(List<String> args) async {
  final dir = args.isNotEmpty
      ? args.first
      : '${Platform.environment['LOCALAPPDATA']}\\Temp\\precise_ref_diag';
  Hive.init(dir);
  Hive.registerAdapter(PreciseRefLibraryEntryAdapter());

  final box = await Hive.openBox<PreciseRefLibraryEntry>(
    'precise_ref_library_entries',
  );
  stdout.writeln('有效条目数: ${box.length}');
  for (final e in box.values) {
    final fileExists = File(e.imagePath).existsSync();
    stdout.writeln(
      '${e.id.substring(0, 8)} | ${e.name} | type=${e.typeIndex} '
      '| fav=${e.isFavorite} | used=${e.usedCount} '
      '| file=${fileExists ? "OK" : "MISSING"}',
    );
  }
  await box.close();
}
