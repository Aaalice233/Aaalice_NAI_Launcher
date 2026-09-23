import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/export_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  late Directory tempDirectory;
  late _CapturingSaveFilePicker picker;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'tag_library_export_dialog_test_',
    );
    PathProviderPlatform.instance = _TempPathProvider(tempDirectory.path);
    picker = _CapturingSaveFilePicker(
      Directory(p.join(tempDirectory.path, 'exports')),
    );
    FilePicker.platform = picker;
  });

  tearDown(() async {
    // 导出链路的临时文件清理可能仍在途，Windows 会短暂占用句柄。
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  testWidgets('提交导出时只打包当前选中的条目与分类', (tester) async {
    await _pumpExportDialog(tester);

    expect(find.text('导出 (3 项)'), findsOneWidget);
    await tester.tap(_entryCheckbox('条目乙'));
    await tester.pump();

    final exportButton = find.text('导出 (2 项)');
    await tester.ensureVisible(exportButton);
    await tester.tap(exportButton);
    await _settleExport(tester, picker);

    expect(picker.requestedExtensions, const ['zip']);
    expect(picker.requestedFileName, endsWith('.zip'));

    final archive = ZipDecoder().decodeBytes(picker.capturedBytes!);
    final memberNames = archive.files.map((file) => file.name).toSet();
    expect(memberNames, contains('entries/entry-a.json'));
    expect(memberNames, isNot(contains('entries/entry-b.json')));

    final manifest = _readJsonObject(archive, 'manifest.json');
    expect(manifest['entryCount'], 1);
    expect(manifest['categoryCount'], 1);
    expect(manifest['includeThumbnails'], isTrue);

    final categories = _readJsonList(archive, 'categories.json');
    expect(categories.map((c) => (c as Map)['id']), ['people']);
  });

  testWidgets('取消预览图后导出内容标记为不含预览图', (tester) async {
    await _pumpExportDialog(tester);

    final thumbnailOption = find.text('包含预览图');
    await tester.ensureVisible(thumbnailOption);
    await tester.tap(thumbnailOption);
    await tester.pump();

    final exportButton = find.text('导出 (3 项)');
    await tester.ensureVisible(exportButton);
    await tester.tap(exportButton);
    await _settleExport(tester, picker);

    final archive = ZipDecoder().decodeBytes(picker.capturedBytes!);
    final manifest = _readJsonObject(archive, 'manifest.json');
    expect(manifest['includeThumbnails'], isFalse);
    expect(manifest['entryCount'], 2);
  });

  testWidgets('全不选后导出按钮不可用', (tester) async {
    await _pumpExportDialog(tester);

    await tester.tap(find.text('全不选'));
    await tester.pump();

    final exportButton = tester.widget<FilledButton>(
      find.widgetWithIcon(FilledButton, Icons.file_download),
    );
    expect(exportButton.onPressed, isNull);
    expect(picker.saveRequested.isCompleted, isFalse);
  });
}

Future<void> _pumpExportDialog(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 900);
  addTearDown(tester.view.reset);

  final category = TagLibraryCategory(
    id: 'people',
    name: '人物',
    createdAt: DateTime(2026),
  );
  final entries = [
    TagLibraryEntry(
      id: 'entry-a',
      name: '条目甲',
      content: '1girl, portrait',
      categoryId: category.id,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    TagLibraryEntry(
      id: 'entry-b',
      name: '条目乙',
      content: '1boy, landscape',
      categoryId: category.id,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => ExportDialog.show(
                  context,
                  entries: entries,
                  categories: [category],
                ),
                child: const Text('打开导出'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('打开导出'));
  await tester.pumpAndSettle();
}

/// 导出链路同时跨越真实 IO 与测试假时钟，必须交替推进两侧才能收敛。
Future<void> _settleExport(
  WidgetTester tester,
  _CapturingSaveFilePicker picker, {
  Duration limit = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(limit);
  while (!picker.saveRequested.isCompleted) {
    if (DateTime.now().isAfter(deadline)) {
      fail('导出未在时限内到达保存步骤');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pump();
  }
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pump();
  }
}

Finder _entryCheckbox(String displayName) => find.descendant(
  of: find.ancestor(
    of: find.text(displayName),
    matching: find.byType(InkWell),
  ).first,
  matching: find.byType(Checkbox),
);

Map<String, dynamic> _readJsonObject(Archive archive, String name) =>
    jsonDecode(_readText(archive, name)) as Map<String, dynamic>;

List<dynamic> _readJsonList(Archive archive, String name) =>
    jsonDecode(_readText(archive, name)) as List<dynamic>;

String _readText(Archive archive, String name) {
  final file = archive.findFile(name);
  expect(file, isNotNull, reason: '归档缺少 $name');
  return utf8.decode(file!.content as List<int>);
}

/// 假写入器：捕获真实写出的归档内容，并以“用户取消”结束保存流程。
class _CapturingSaveFilePicker extends FilePicker {
  _CapturingSaveFilePicker(this.exportsDirectory);

  final Directory exportsDirectory;
  final Completer<void> saveRequested = Completer<void>();

  String? requestedFileName;
  List<String>? requestedExtensions;
  Uint8List? capturedBytes;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    requestedFileName = fileName;
    requestedExtensions = allowedExtensions;
    final written = exportsDirectory
        .listSync()
        .whereType<File>()
        .toList(growable: false);
    if (written.length == 1) {
      capturedBytes = written.single.readAsBytesSync();
    }
    if (!saveRequested.isCompleted) saveRequested.complete();
    return null;
  }
}

class _TempPathProvider extends PathProviderPlatform {
  _TempPathProvider(this.root);

  final String root;

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}
