import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/save_naming/image_save_naming.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/save_naming/save_naming_preview_sample.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/save_naming/save_naming_tile.dart';

import '../../../../../helpers/memory_local_storage.dart';
import '../../../../../helpers/reachability_expectations.dart';

final _sample = SaveNamingPreviewSample.builtIn(
  DateTime(2026, 10, 12, 14, 30, 5),
);

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _pumpHost(
  WidgetTester tester,
  MemoryLocalStorage storage, {
  double width = 1180,
  double height = 900,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        saveNamingPreviewSampleProvider.overrideWith((ref) async => _sample),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: ListView(children: const [SaveNamingTile()])),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(_key('save-naming-tile'));
  await tester.pumpAndSettle();
}

// 正文是惰性列表，屏外的分组还没构建，先滚到构建范围内再按焦点方式露出。
Future<void> _reveal(
  WidgetTester tester,
  Finder finder, {
  String scrollView = 'save-naming-form-scroll',
}) async {
  await scrollUntilBuilt(tester, finder, _key(scrollView));
  await revealOnScreen(tester, finder);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<String> _previewPath(WidgetTester tester) async {
  await _reveal(tester, _key('save-naming-preview-path'));
  return tester.widget<SelectableText>(_key('save-naming-preview-path')).data!;
}

Future<void> _revealPreview(WidgetTester tester) =>
    _reveal(tester, _key('save-naming-preview'));

FilledButton _saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, '保存'));

void main() {
  testWidgets('tile previews the current rule and saves a new one', (
    tester,
  ) async {
    final storage = MemoryLocalStorage();
    await _pumpHost(tester, storage);

    expect(find.textContaining('示例：'), findsOneWidget);
    await _openForm(tester);
    expect(await _previewPath(tester), '2026-10-12/14-30-05-1234567890.png');
    expect(find.text('示例使用内置样例数据'), findsOneWidget);

    await _tapVisible(tester, _key('save-naming-folder-none'));
    await _tapVisible(tester, _key('save-naming-file-name-promptSeed'));

    final expected = ImageSaveNaming(
      folderTemplate: SaveFolderPreset.none.template,
      fileNameTemplate: SaveFileNamePreset.promptSeed.template,
    );
    final path = await _previewPath(tester);
    expect(path, expected.resolve(_sample.context).relativeFileName);
    expect(path, startsWith('1girl, solo'));
    expect(path, endsWith(' s-1234567890.png'));

    await _tapVisible(tester, find.widgetWithText(FilledButton, '保存'));

    expect(storage.values[StorageKeys.imageSaveFolderTemplate], '');
    expect(
      storage.values[StorageKeys.imageSaveFileNameTemplate],
      SaveFileNamePreset.promptSeed.template,
    );
    expect(_key('save-naming-preview'), findsNothing);
  });

  testWidgets('invalid custom templates block saving until fixed', (
    tester,
  ) async {
    final storage = MemoryLocalStorage();
    await _pumpHost(tester, storage);
    await _openForm(tester);

    await _tapVisible(tester, _key('save-naming-file-name-custom'));
    final field = _key('save-naming-file-name-template');
    expect(
      tester.widget<TextField>(field).controller!.text,
      ImageSaveNaming.defaultFileNameTemplate,
    );

    await tester.enterText(field, '{sampler}');
    await tester.pumpAndSettle();
    expect(find.text('未知字段“sampler”'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);
    await _revealPreview(tester);
    expect(_key('save-naming-preview-path'), findsNothing);

    await tester.enterText(field, '');
    await tester.pumpAndSettle();
    expect(find.text('文件名模板不能为空'), findsOneWidget);

    await tester.enterText(field, 'img_');
    await tester.pumpAndSettle();
    await _tapVisible(tester, _key('save-naming-file-name-insert-seed'));
    expect(tester.widget<TextField>(field).controller!.text, 'img_{seed}');
    expect(_saveButton(tester).onPressed, isNotNull);
    expect(await _previewPath(tester), '2026-10-12/img_1234567890.png');

    await _tapVisible(tester, find.widgetWithText(FilledButton, '保存'));
    expect(storage.values[StorageKeys.imageSaveFileNameTemplate], 'img_{seed}');
  });

  testWidgets('warns when the path no longer carries a date', (tester) async {
    await _pumpHost(tester, MemoryLocalStorage());
    await _openForm(tester);
    await _revealPreview(tester);
    expect(_key('save-naming-omits-date-hint'), findsNothing);

    await _tapVisible(tester, _key('save-naming-folder-none'));
    await _revealPreview(tester);
    expect(_key('save-naming-omits-date-hint'), findsOneWidget);

    await _tapVisible(tester, _key('save-naming-file-name-dateTimeSeed'));
    await _revealPreview(tester);
    expect(_key('save-naming-omits-date-hint'), findsNothing);
  });

  testWidgets('restore defaults and cancel leave storage untouched', (
    tester,
  ) async {
    final storage = MemoryLocalStorage()
      ..values[StorageKeys.imageSaveFolderTemplate] = '{model}'
      ..values[StorageKeys.imageSaveFileNameTemplate] = '{prompt}';
    await _pumpHost(tester, storage);
    await _openForm(tester);

    expect(
      tester
          .widget<TextField>(_key('save-naming-folder-template'))
          .controller!
          .text,
      '{model}',
    );
    await _tapVisible(tester, _key('save-naming-restore-defaults'));
    expect(_key('save-naming-folder-template'), findsNothing);
    expect(await _previewPath(tester), '2026-10-12/14-30-05-1234567890.png');

    await _tapVisible(tester, find.widgetWithText(TextButton, '取消'));
    expect(storage.values[StorageKeys.imageSaveFolderTemplate], '{model}');
    expect(storage.values[StorageKeys.imageSaveFileNameTemplate], '{prompt}');
  });

  testWidgets('syntax help lists fields, filters and live examples', (
    tester,
  ) async {
    await _pumpHost(tester, MemoryLocalStorage());
    await _openForm(tester);

    await _tapVisible(tester, _key('save-naming-syntax-help'));

    expect(_key('save-naming-help-fields'), findsOneWidget);
    await _reveal(
      tester,
      _key('save-naming-help-examples'),
      scrollView: 'save-naming-help-scroll',
    );
    expect(find.text('{date}_{index|pad:3}'), findsOneWidget);
    expect(find.text('2026-10-12_001.png'), findsOneWidget);
  });

  for (final width in const [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final textScale in const [1.0, 3.0]) {
      testWidgets(
        'every group and action stays reachable at ${width.toInt()}px, '
        '${textScale}x text',
        (tester) async {
          await _pumpHost(
            tester,
            MemoryLocalStorage(),
            width: width,
            height: 720,
            textScale: textScale,
          );
          await _openForm(tester);
          await _tapVisible(tester, _key('save-naming-folder-custom'));
          await _tapVisible(tester, _key('save-naming-file-name-custom'));
          await _reveal(tester, _key('save-naming-folder-template'));
          expect(
            find.descendant(
              of: _key('save-naming-folder'),
              matching: _key('save-naming-folder-template'),
            ),
            findsOneWidget,
          );

          for (final key in const [
            'save-naming-folder-byDate',
            'save-naming-folder-template',
            'save-naming-file-name-timeSeed',
            'save-naming-file-name-template',
            'save-naming-syntax-help',
          ]) {
            await _reveal(tester, _key(key));
            expectReachable(tester, _key(key), reason: key);
          }
          // 大字号下插入按钮可能宽于横向滚动条，只要求能点中并生效。
          for (final (section, token) in const [
            ('folder', 'date'),
            ('file-name', 'prompt'),
          ]) {
            final field = _key('save-naming-$section-template');
            await _tapVisible(
              tester,
              _key('save-naming-$section-insert-$token'),
            );
            await _reveal(tester, field);
            expect(
              tester.widget<TextField>(field).controller!.text,
              endsWith('{$token}'),
              reason: section,
            );
          }
          final preview = _key('save-naming-preview-path');
          await _reveal(tester, preview);
          expect(
            visibleViewRect(tester).overlaps(tester.getRect(preview)),
            isTrue,
          );
          expectReachable(
            tester,
            find.widgetWithText(FilledButton, '保存'),
            reason: 'save',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
