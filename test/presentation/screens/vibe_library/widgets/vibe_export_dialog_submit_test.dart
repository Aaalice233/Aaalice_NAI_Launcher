import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_category.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_export_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  late Directory tempDirectory;
  late Directory outputDirectory;
  late _DirectoryPicker picker;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'vibe_export_dialog_test_',
    );
    outputDirectory = Directory(p.join(tempDirectory.path, 'vibe-out'));
    PathProviderPlatform.instance = _TempPathProvider(tempDirectory.path);
    picker = _DirectoryPicker(outputDirectory.path);
    FilePicker.platform = picker;
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  testWidgets('提交导出只写出当前选中的 Vibe', (tester) async {
    await _pumpExportDialog(tester);

    await tester.tap(_entryCheckbox('VibeGamma'));
    await tester.pump();

    await tester.tap(find.widgetWithIcon(FilledButton, Icons.file_download));
    // 文件出现时写入可能仍在途，成功提示要等全部写入 await 完才弹出
    await _settleExport(tester, () => find.text('导出成功').evaluate().isNotEmpty);

    expect(picker.requestedDirectory, isTrue);
    final written = _exportedFiles(outputDirectory);
    expect(written.map(p.basename).toSet(), {
      'VibeAlpha.naiv4vibe',
      'VibeBeta.naiv4vibe',
    });

    final alpha =
        jsonDecode(File(written.first).readAsStringSync())
            as Map<String, dynamic>;
    expect(alpha['name'], isIn(const ['VibeAlpha', 'VibeBeta']));
    expect(alpha['type'], 'encoding');
    expect(alpha['encodings'], isA<Map<String, dynamic>>());

    await _dismissToast(tester);
  });

  testWidgets('全不选后导出按钮不可用且不询问保存位置', (tester) async {
    await _pumpExportDialog(tester);

    await tester.tap(find.byTooltip('全不选'));
    await tester.pump();

    final exportButton = tester.widget<FilledButton>(
      find.widgetWithIcon(FilledButton, Icons.file_download),
    );
    expect(exportButton.onPressed, isNull);
    expect(picker.requestedDirectory, isFalse);
    expect(_exportedFiles(outputDirectory), isEmpty);
  });
}

Future<void> _pumpExportDialog(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 900);
  addTearDown(tester.view.reset);

  final category = VibeLibraryCategory(
    id: 'style',
    name: '风格',
    createdAt: DateTime(2026),
  );
  final entries = [
    _buildEntry(id: 'vibe-a', displayName: 'VibeAlpha', categoryId: 'style'),
    _buildEntry(id: 'vibe-b', displayName: 'VibeBeta', categoryId: 'style'),
    _buildEntry(id: 'vibe-c', displayName: 'VibeGamma'),
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        generationParamsNotifierProvider.overrideWith(
          _MemoryGenerationParamsNotifier.new,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => VibeExportDialog.show(
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
  bool Function() done, {
  Duration limit = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(limit);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('导出未在时限内写出结果');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pump();
  }
}

Future<void> _dismissToast(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

List<String> _exportedFiles(Directory directory) {
  if (!directory.existsSync()) return const [];
  return directory
      .listSync()
      .whereType<File>()
      .map((file) => file.path)
      .where((path) => path.endsWith('.naiv4vibe'))
      .toList(growable: false)
    ..sort();
}

Finder _entryCheckbox(String displayName) => find.descendant(
  of: find.ancestor(
    of: find.text(displayName),
    matching: find.byType(InkWell),
  ).first,
  matching: find.byType(Checkbox),
);

VibeLibraryEntry _buildEntry({
  required String id,
  required String displayName,
  String? categoryId,
}) {
  return VibeLibraryEntry(
    id: id,
    name: displayName,
    vibeDisplayName: displayName,
    vibeEncoding: 'ZW5jb2RlZA==',
    strength: 0.6,
    infoExtracted: 0.7,
    sourceTypeIndex: VibeSourceType.naiv4vibe.index,
    categoryId: categoryId,
    createdAt: DateTime(2026, 4, 14),
  );
}

class _MemoryGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() => const ImageParams();
}

/// 假写入器：把批量导出重定向到测试临时目录。
class _DirectoryPicker extends FilePicker {
  _DirectoryPicker(this.directory);

  final String directory;
  bool requestedDirectory = false;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async {
    requestedDirectory = true;
    return directory;
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async => null;
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
