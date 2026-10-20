import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/shortcuts/shortcuts.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/fixed_tags_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_metadata_panel.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/prompt_copy_dialog.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/prompt_section.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/file_image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/shortcuts/shortcuts.dart';

void main() {
  testWidgets('file size and modified time arrive from the async stat', (
    tester,
  ) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('detail_panel_file_info_'),
    ))!;
    addTearDown(() async {
      // Image 读取可能在 fake async 结束后才释放句柄，清理尽力而为。
      for (var attempt = 0; attempt < 10; attempt++) {
        try {
          if (directory.existsSync()) await directory.delete(recursive: true);
          return;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      }
    });
    // 放行真实事件循环后自动补全会去问 path_provider，桩成临时目录即可。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => directory.path,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          ),
    );
    final file = File('${directory.path}${Platform.pathSeparator}shot.png')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 4, height: 4)));
    final detail = FileImageDetailData(
      filePath: file.path,
      initialMetadata: const NaiImageMetadata(
        seed: 7,
        prompt: '1girl, silver hair',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DetailMetadataPanel(currentImage: detail, expandedWidth: 600),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('shot.png'), findsOneWidget);
    expect(find.text('文件大小'), findsNothing);

    // 文件 stat 只在真实事件循环里推进，pump 之间必须放行 runAsync。
    for (var attempt = 0; attempt < 50; attempt++) {
      if (find.text('文件大小').evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    expect(find.text('文件大小'), findsOneWidget);
    expect(find.text('${file.lengthSync()} B'), findsOneWidget);
    expect(find.text('修改时间'), findsOneWidget);
  });

  testWidgets(
    'resolution uses encoded image size instead of request metadata',
    (tester) async {
      final image = img.Image(width: 640, height: 960);
      final detail = GeneratedImageDetailData(
        imageBytes: Uint8List.fromList(img.encodePng(image)),
        metadata: const NaiImageMetadata(seed: 123, width: 1792, height: 896),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DetailMetadataPanel(
                currentImage: detail,
                expandedWidth: 600,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      for (var attempt = 0; attempt < 20; attempt++) {
        if (find.text('640 × 960').evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('640 × 960'), findsOneWidget);
      expect(find.text('1792 × 896'), findsNothing);
    },
  );

  testWidgets(
    'legacy metadata matches current fixed library and opens copy categories',
    (tester) async {
      final image = img.Image(width: 1, height: 1);
      final detail = GeneratedImageDetailData(
        imageBytes: Uint8List.fromList(img.encodePng(image)),
        metadata: const NaiImageMetadata(
          prompt: 'private prefix, 1girl, blue hair',
          negativePrompt: 'bad hands',
          characterInfos: [CharacterPromptInfo(prompt: 'rabbit girl')],
        ),
      );
      final fixedEntry = FixedTagEntry.create(
        name: 'private',
        content: 'private prefix',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fixedTagsNotifierProvider.overrideWith(
              () => _FakeFixedTagsNotifier(fixedEntry),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DetailMetadataPanel(
                currentImage: detail,
                expandedWidth: 600,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sections = tester
          .widgetList<PromptSection>(find.byType(PromptSection))
          .toList();
      expect(sections, hasLength(2));
      final mainSection = sections.first;
      expect(mainSection.fixedTags, contains('private prefix'));
      expect(mainSection.characterTags, contains('rabbit girl'));
      expect(mainSection.onCopy, isNotNull);
      expect(sections.last.isNegative, isTrue);
      expect(find.byIcon(Icons.library_add), findsNWidgets(2));
      expect(find.byType(AnimatedCrossFade), findsNothing);
      expect(
        find.descendant(
          of: find.byType(PromptSection),
          matching: find.byType(AnimatedSize),
        ),
        findsNWidgets(2),
      );

      final copyFuture = mainSection.onCopy!();
      await tester.pumpAndSettle();

      expect(find.byType(PromptCopyDialog), findsOneWidget);
      final categoryTiles = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      expect(categoryTiles, hasLength(4));
      expect(categoryTiles.last.onChanged, isNotNull);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await copyFuture;
    },
  );

  testWidgets('copy all TAGs writes the complete local prompt export', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final image = img.Image(width: 1, height: 1);
    final detail = GeneratedImageDetailData(
      imageBytes: Uint8List.fromList(img.encodePng(image)),
      metadata: const NaiImageMetadata(
        prompt: '{{1girl}}, blue hair',
        negativePrompt: '[lowres]',
        characterInfos: [
          CharacterPromptInfo(prompt: 'red hair', negativePrompt: 'bad hands'),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DetailMetadataPanel(currentImage: detail, expandedWidth: 360),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final copyAll = find.text('复制全部 TAG');
    await tester.ensureVisible(copyAll);
    await tester.tap(copyAll);
    await tester.pump();

    expect(
      clipboardText,
      startsWith(
        'positive: {{1girl}}, blue hair | red hair\n'
        'negative: [lowres] | bad hands',
      ),
    );
    expect(clipboardText, isNot('{}'));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('keeps a comma inside nested weights as one detail chip', (
    tester,
  ) async {
    const fragment = '{{{blue_eyes, long_hair}}}';
    final image = img.Image(width: 1, height: 1);
    final detail = GeneratedImageDetailData(
      imageBytes: Uint8List.fromList(img.encodePng(image)),
      metadata: const NaiImageMetadata(prompt: '$fragment, city'),
    );
    final fixedEntry = FixedTagEntry.create(
      name: 'weighted group',
      content: fragment,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fixedTagsNotifierProvider.overrideWith(
            () => _FakeFixedTagsNotifier(fixedEntry),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DetailMetadataPanel(currentImage: detail, expandedWidth: 600),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final section = tester
        .widgetList<PromptSection>(find.byType(PromptSection))
        .first;
    expect(section.tags, const [fragment, 'city']);
    expect(section.fixedTags, contains(fragment));
    expect(find.textContaining(fragment), findsOneWidget);
    expect(find.text('{{{blue_eyes'), findsNothing);
    expect(find.text('long_hair}}}'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('marks only the fixed occurrence when a negative tag repeats', (
    tester,
  ) async {
    final image = img.Image(width: 1, height: 1);
    final detail = GeneratedImageDetailData(
      imageBytes: Uint8List.fromList(img.encodePng(image)),
      metadata: const NaiImageMetadata(
        negativePrompt: 'lowres, nsfw, lowres',
        fixedNegativePrefixTags: ['lowres'],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DetailMetadataPanel(currentImage: detail, expandedWidth: 600),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final section = tester
        .widgetList<PromptSection>(find.byType(PromptSection))
        .singleWhere((section) => section.isNegative);
    await tester.tap(find.text(section.title));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    expect(find.text('lowres'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Ctrl+C copies selected metadata text before the viewer shortcut',
    (tester) async {
      const selectedText = 'nai-diffusion-4-5-full';
      var copiedPrompt = false;
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final image = img.Image(width: 1, height: 1);
      final detail = GeneratedImageDetailData(
        imageBytes: Uint8List.fromList(img.encodePng(image)),
        metadata: const NaiImageMetadata(model: selectedText, seed: 123),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shortcutConfigNotifierProvider.overrideWith(
              _FakeShortcutConfigNotifier.new,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PageShortcuts(
                contextType: ShortcutContext.viewer,
                shortcuts: {
                  ShortcutIds.copyPrompt: () {
                    copiedPrompt = true;
                  },
                },
                child: DetailMetadataPanel(
                  currentImage: detail,
                  expandedWidth: 600,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editable = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .singleWhere((widget) => widget.controller.text == selectedText);
      editable.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: selectedText.length,
      );
      editable.focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(clipboardText, selectedText);
      expect(copiedPrompt, isFalse);
    },
  );

  testWidgets('切图后上一张晚到的元数据既不在加载时显示，也不覆盖当前图', (tester) async {
    final slowRead = Completer<NaiImageMetadata?>();
    final slow = FileImageDetailData(
      filePath: _neverCreatedPath('slow'),
      readCachedMetadata: (_) => slowRead.future,
    );
    final current = FileImageDetailData(
      filePath: _neverCreatedPath('current'),
      initialMetadata: const NaiImageMetadata(prompt: 'blue sky'),
    );
    final loadingText = lookupAppLocalizations(
      const Locale('zh'),
    ).detail_parsingMetadata;
    unawaited(slow.prefetchMetadata());

    await tester.pumpWidget(_panelApp(current));
    expect(find.textContaining('blue sky'), findsWidgets);

    await tester.pumpWidget(_panelApp(slow));
    expect(find.text(loadingText), findsOneWidget);
    expect(find.textContaining('blue sky'), findsNothing);

    await tester.pumpWidget(_panelApp(current));
    slowRead.complete(const NaiImageMetadata(prompt: 'red moon'));
    await tester.pump();

    expect(find.textContaining('blue sky'), findsWidgets);
    expect(find.textContaining('red moon'), findsNothing);
  });

  testWidgets('解析结果为空时结束加载并显示无元数据', (tester) async {
    final image = _PendingMetadataDetail('plain');
    final l10n = lookupAppLocalizations(const Locale('zh'));

    await tester.pumpWidget(_panelApp(image));
    expect(find.text(l10n.detail_parsingMetadata), findsOneWidget);

    image.metadataLoad.complete(null);
    await tester.pump();

    expect(find.text(l10n.detail_parsingMetadata), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(l10n.detail_noMetadata), findsOneWidget);
  });

  testWidgets('读取元数据失败时按无元数据收尾', (tester) async {
    final image = _PendingMetadataDetail('locked');
    final l10n = lookupAppLocalizations(const Locale('zh'));

    await tester.pumpWidget(_panelApp(image));
    image.metadataLoad.completeError(
      const FileSystemException('locked', 'locked.png'),
    );
    await tester.pump();

    expect(find.text(l10n.detail_parsingMetadata), findsNothing);
    expect(find.text(l10n.detail_noMetadata), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('上一张晚到的空结果不会提前结束当前图的加载', (tester) async {
    final previous = _PendingMetadataDetail('previous');
    final current = _PendingMetadataDetail('current');
    final l10n = lookupAppLocalizations(const Locale('zh'));

    await tester.pumpWidget(_panelApp(previous));
    await tester.pumpWidget(_panelApp(current));
    previous.metadataLoad.complete(null);
    await tester.pump();

    expect(find.text(l10n.detail_parsingMetadata), findsOneWidget);
    expect(find.text(l10n.detail_noMetadata), findsNothing);

    current.metadataLoad.complete(const NaiImageMetadata(prompt: 'blue sky'));
    await tester.pump();

    expect(find.text(l10n.detail_parsingMetadata), findsNothing);
    expect(find.textContaining('blue sky'), findsWidgets);
  });

  testWidgets('解析中与无元数据时都先显示文件基本信息', (tester) async {
    final image = _PendingMetadataDetail(
      'plain',
      fileInfo: FileInfo(
        path: _neverCreatedPath('plain'),
        fileName: 'plain.png',
        size: 2048,
      ),
    );
    final l10n = lookupAppLocalizations(const Locale('zh'));

    await tester.pumpWidget(_panelApp(image));
    expect(find.text(l10n.detail_basicInfo), findsOneWidget);
    expect(find.text('plain.png'), findsOneWidget);
    expect(find.text(l10n.detail_parsingMetadata), findsOneWidget);

    image.metadataLoad.complete(null);
    await tester.pump();

    expect(find.text('plain.png'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(find.text(l10n.detail_noMetadata), findsOneWidget);
    expect(find.text(l10n.gallery_generationParams), findsNothing);
  });

  testWidgets('无元数据时实际分辨率归入基本信息', (tester) async {
    final image = _PendingMetadataDetail('memory');
    final l10n = lookupAppLocalizations(const Locale('zh'));

    await tester.pumpWidget(_panelApp(image));
    image.metadataLoad.complete(null);
    await tester.pump();

    expect(find.text(l10n.detail_basicInfo), findsOneWidget);
    expect(find.text(l10n.gallery_metaResolution), findsOneWidget);
    expect(find.text('1 × 1'), findsOneWidget);
    expect(find.text(l10n.detail_noMetadata), findsOneWidget);
  });

  testWidgets('有元数据时分辨率只出现在生成参数里', (tester) async {
    final image = _PendingMetadataDetail('generated');
    final l10n = lookupAppLocalizations(const Locale('zh'));

    await tester.pumpWidget(_panelApp(image));
    image.metadataLoad.complete(const NaiImageMetadata(prompt: 'blue sky'));
    await tester.pump();

    expect(find.text(l10n.gallery_generationParams), findsOneWidget);
    expect(find.text(l10n.gallery_metaResolution), findsOneWidget);
    expect(find.text('1 × 1'), findsOneWidget);
    // 内存图没有文件信息，分辨率又归生成参数，基本信息整组不出现
    expect(find.text(l10n.detail_basicInfo), findsNothing);
  });

  testWidgets('窄屏三倍字号下无元数据状态可滚动到底且不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final image = _PendingMetadataDetail(
      'scaled',
      fileInfo: FileInfo(
        path: _neverCreatedPath('scaled'),
        fileName: 'a_long_generated_file_name_for_scale_check.png',
        size: 4 * 1024 * 1024,
      ),
    );
    final l10n = lookupAppLocalizations(const Locale('zh'));

    await tester.pumpWidget(_panelApp(image, expandedWidth: 320, textScale: 3));
    image.metadataLoad.complete(null);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.text('a_long_generated_file_name_for_scale_check.png'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text(l10n.detail_noMetadata),
      120,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text(l10n.detail_noMetadata), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final _onePixelPng = Uint8List.fromList(
  img.encodePng(img.Image(width: 1, height: 1)),
);

class _PendingMetadataDetail extends ImageDetailData {
  _PendingMetadataDetail(this.identifier, {this.fileInfo});

  @override
  final String identifier;

  @override
  final FileInfo? fileInfo;

  final metadataLoad = Completer<NaiImageMetadata?>();

  @override
  Future<NaiImageMetadata?> getMetadataAsync() => metadataLoad.future;

  @override
  ImageProvider getImageProvider() => MemoryImage(_onePixelPng);

  @override
  Future<Uint8List> getImageBytes() async => _onePixelPng;

  @override
  NaiImageMetadata? get metadata => null;

  @override
  bool get isFavorite => false;

  @override
  bool get showSaveButton => false;

  @override
  bool get showCopyButton => false;

  @override
  bool get showSaveAsButton => false;

  @override
  bool get showFavoriteButton => false;

  @override
  bool get preserveOriginalBytesOnSave => false;
}

String _neverCreatedPath(String name) =>
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'detail_panel_never_created_$name.png';

Widget _panelApp(
  ImageDetailData image, {
  double expandedWidth = 600,
  double textScale = 1,
}) {
  return ProviderScope(
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
      home: Scaffold(
        body: DetailMetadataPanel(
          currentImage: image,
          expandedWidth: expandedWidth,
        ),
      ),
    ),
  );
}

class _FakeFixedTagsNotifier extends FixedTagsNotifier {
  _FakeFixedTagsNotifier(this.entry);

  final FixedTagEntry entry;

  @override
  FixedTagsState build() => FixedTagsState(entries: [entry]);
}

class _FakeShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}
