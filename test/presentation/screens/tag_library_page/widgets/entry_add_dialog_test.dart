import 'dart:async';
import 'dart:io';

import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/prompt_assistant/widgets/prompt_assistant_overlay.dart';
import 'package:nai_launcher/presentation/prompt_assistant/widgets/prompt_assistant_toolbar.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/entry_add_dialog.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

import '../../../../helpers/memory_local_storage.dart';

void main() {
  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('footer stays fully visible at $width / ${scale}x with IME', (
        tester,
      ) async {
        await _pumpLauncher(
          tester,
          size: Size(width, 700),
          textScaler: TextScaler.linear(scale),
          padding: const EdgeInsets.only(top: 24, bottom: 16),
          viewInsets: const EdgeInsets.only(bottom: 180),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        final footer = find.byKey(
          const ValueKey('entry-add-dialog-content-footer'),
        );
        final form = find.byKey(const Key('entry-add-dialog-scroll'));
        final before = tester.getRect(footer);
        expect(before.top, greaterThanOrEqualTo(tester.getRect(form).bottom));
        expect(
          before.bottom,
          lessThanOrEqualTo(
            tester.getRect(find.widgetWithText(FilledButton, '保存')).top,
          ),
        );
        expect(before.bottom, lessThanOrEqualTo(520));
        expect(find.descendant(of: form, matching: footer), findsNothing);
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(of: form, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(tester.getRect(footer), before);
        position.jumpTo(0);
        await tester.pumpAndSettle();
        expect(tester.getRect(footer), before);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('320px、3x 字号、IME 与 SafeArea 下 bottom sheet 全部操作可达', (
    tester,
  ) async {
    await _pumpLauncher(
      tester,
      size: const Size(320, 900),
      textScaler: const TextScaler.linear(3),
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 20),
      viewInsets: const EdgeInsets.only(bottom: 280),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);

    final surface = tester.getRect(
      find.byKey(const ValueKey('adaptive-bottom-sheet')),
    );
    expect(surface.left, greaterThanOrEqualTo(12));
    expect(surface.right, lessThanOrEqualTo(308));
    expect(surface.top, greaterThanOrEqualTo(24));
    expect(surface.bottom, lessThanOrEqualTo(620));

    final scrollable = find
        .descendant(
          of: find.byKey(const Key('entry-add-dialog-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final label in ['预览图', '名称', '分类', '标签', '提示词内容']) {
      final target = find.text(label);
      await tester.scrollUntilVisible(target, 180, scrollable: scrollable);
      expect(target, findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    final save = find.widgetWithText(FilledButton, '保存');
    final cancel = find.widgetWithText(TextButton, '取消');
    expect(save, findsOneWidget);
    expect(cancel, findsOneWidget);
    expect(surface.contains(tester.getCenter(save)), isTrue);
    expect(surface.contains(tester.getCenter(cancel)), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Medium 在 IME 导致短高度时保留居中表单且避开键盘', (tester) async {
    await _pumpLauncher(
      tester,
      size: const Size(700, 720),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      viewInsets: const EdgeInsets.only(bottom: 180),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsNothing);
    final panelFinder = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(panelFinder, findsOneWidget);
    final panel = tester.getRect(panelFinder);
    expect(panel.top, greaterThanOrEqualTo(24));
    expect(panel.bottom, lessThanOrEqualTo(540));
    expect(find.byKey(const Key('entry-add-dialog-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Expanded 使用居中弹窗并保留关闭结果', (tester) async {
    var completed = false;
    await _pumpLauncher(
      tester,
      size: const Size(1180, 800),
      onCompleted: () => completed = true,
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final panelFinder = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(panelFinder, findsOneWidget);
    final panel = tester.getRect(panelFinder);
    expect(panel.width, 700);
    expect(panel.height, 680);
    expect(panel.center.dx, moreOrLessEquals(590));
    expect(panel.center.dy, moreOrLessEquals(400));
    expect(find.byType(Dialog), findsNothing);

    final thumbnailSection = tester.getRect(
      find.byKey(const Key('entry-add-dialog-thumbnail-section')),
    );
    final editor = tester.getRect(
      find.byKey(const Key('entry-add-dialog-content-editor')),
    );
    expect(thumbnailSection.width, 220);
    expect(thumbnailSection.height, greaterThan(240));
    final squarePreview = tester.getRect(
      find.byKey(const ValueKey('entry-thumbnail-square-preview')),
    );
    expect(squarePreview.size, const Size.square(220));
    expect(editor.height, greaterThanOrEqualTo(176));
    expect(editor.top, lessThan(490));
    final contentInput = find.descendant(
      of: find.byKey(const Key('entry-add-dialog-content-editor')),
      matching: find.byType(ThemedInput),
    );
    expect(contentInput, findsOneWidget);
    final contentPadding = tester
        .widget<ThemedInput>(contentInput)
        .decoration!
        .contentPadding!
        .resolve(TextDirection.ltr);
    expect(contentPadding.bottom, 60);
    final contentFooter = find.byKey(
      const ValueKey('entry-add-dialog-content-footer'),
    );
    final assistant = find.byType(PromptAssistantOverlay);
    expect(contentFooter, findsOneWidget);
    expect(assistant, findsOneWidget);
    final toolbar = find.descendant(
      of: assistant,
      matching: find.byType(PromptAssistantToolbar),
    );
    final collapsedAssistantHeight = tester.getSize(toolbar).height;
    expect(
      find.descendant(
        of: contentFooter,
        matching: find.byKey(const ValueKey('tag-mode-button')),
      ),
      findsOneWidget,
    );
    final formViewport = tester.getRect(
      find.byKey(const Key('entry-add-dialog-scroll')),
    );
    expect(
      tester.getTopLeft(contentFooter).dy,
      closeTo(formViewport.bottom + 4, 1),
    );
    expect(
      tester.widget<PromptAssistantOverlay>(assistant).placement,
      PromptAssistantPlacement.viewport,
    );
    expect(
      tester.widget<PromptAssistantOverlay>(assistant).stripFixedTagsFromInput,
      false,
    );
    expect(
      tester.getTopRight(toolbar).dx,
      closeTo(tester.getTopRight(contentInput).dx - 4, 1),
    );

    final dialogScrollable = find
        .descendant(
          of: find.byKey(const Key('entry-add-dialog-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(dialogScrollable, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: assistant,
        matching: find.byIcon(Icons.auto_awesome_rounded),
      ),
    );
    await tester.pumpAndSettle();
    final expandedAssistantRect = tester.getRect(toolbar);
    expect(
      expandedAssistantRect.height,
      closeTo(collapsedAssistantHeight, .01),
    );
    final footerRect = tester.getRect(contentInput);
    expect(expandedAssistantRect.left, greaterThanOrEqualTo(footerRect.left));
    expect(expandedAssistantRect.right, lessThanOrEqualTo(footerRect.right));
    expect(expandedAssistantRect.top, greaterThanOrEqualTo(footerRect.top));
    expect(expandedAssistantRect.bottom, lessThanOrEqualTo(footerRect.bottom));

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已有预览图时在方形区域标出卡片显示范围', (tester) async {
    final testImage = File('assets/icons/android/playstore-icon.png').absolute;
    await _cacheFileImage(tester, testImage);
    final entry = TagLibraryEntry(
      id: 'entry-with-preview',
      name: '测试词条',
      content: '1girl',
      thumbnail: testImage.path,
      thumbnailOffsetX: 0.4,
      thumbnailOffsetY: -0.3,
      thumbnailScale: 1.5,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await _pumpLauncher(tester, size: const Size(1180, 800), entry: entry);

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final preview = tester.getRect(
      find.byKey(const ValueKey('entry-thumbnail-square-preview')),
    );
    final frame = tester.getRect(
      find.byKey(const ValueKey('entry-thumbnail-card-frame')),
    );
    expect(preview.size, const Size.square(220));
    expect(frame.width / frame.height, closeTo(2.5, 0.01));
    expect(preview.contains(frame.topLeft), isTrue);
    expect(preview.contains(frame.bottomRight), isTrue);
    expect(frame.center.dx, greaterThan(preview.center.dx));
    expect(frame.center.dy, lessThan(preview.center.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long text and tags grow the editor and only the form scrolls', (
    tester,
  ) async {
    final entry = TagLibraryEntry(
      id: 'long-entry',
      name: 'Long entry',
      content: List.generate(150, (index) => 'detailed_tag_$index').join(', '),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await _pumpLauncher(tester, size: const Size(1180, 800), entry: entry);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    final editor = find.byKey(const Key('entry-add-dialog-content-editor'));
    final form = find.byKey(const Key('entry-add-dialog-scroll'));
    final footer = find.byKey(
      const ValueKey('entry-add-dialog-content-footer'),
    );
    final footerBefore = tester.getRect(footer);
    for (final tags in [false, true]) {
      if (tags) {
        await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
        await tester.pumpAndSettle();
      }
      expect(tester.getSize(editor).height, greaterThan(176));
      for (final element
          in find
              .descendant(of: editor, matching: find.byType(Scrollable))
              .evaluate()) {
        final state = (element as StatefulElement).state as ScrollableState;
        expect(state.position.maxScrollExtent, closeTo(0, .01));
      }
      final outer = tester
          .state<ScrollableState>(
            find.descendant(of: form, matching: find.byType(Scrollable)).first,
          )
          .position;
      expect(outer.maxScrollExtent, greaterThan(0));
      outer.jumpTo(outer.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.getRect(footer), footerBefore);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('系统返回关闭表单且 Future<void> 正常完成', (tester) async {
    var completed = false;
    await _pumpLauncher(
      tester,
      size: const Size(320, 700),
      onCompleted: () => completed = true,
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(completed, isFalse);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsNothing);
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _cacheFileImage(WidgetTester tester, File file) async {
  await tester.runAsync(() async {
    final completed = Completer<void>();
    final stream = FileImage(file).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, __) {
        if (!completed.isCompleted) completed.complete();
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!completed.isCompleted) {
          completed.completeError(error, stackTrace);
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    await completed.future;
  });
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required Size size,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  VoidCallback? onCompleted,
  TagLibraryEntry? entry,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWith((ref) => MemoryLocalStorage()),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            padding: padding,
            viewPadding: padding,
            viewInsets: viewInsets,
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  await EntryAddDialog.show(
                    context,
                    categories: const [],
                    entry: entry,
                  );
                  onCompleted?.call();
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
