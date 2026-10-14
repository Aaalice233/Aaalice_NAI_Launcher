import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_category.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_category_provider.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_provider.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_selection_provider.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/vibe_library_screen.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/category/vibe_category_item.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_library_toolbar.dart';

void main() {
  final desktop = TargetPlatformVariant.only(TargetPlatform.windows);

  testWidgets('搜索框点外部失焦后 Ctrl+A 仍全选 Vibe', (tester) async {
    final container = await _pumpScreen(tester);
    final search = find.descendant(
      of: find.byType(GalleryLibrarySearchField),
      matching: find.byType(EditableText),
    );

    await tester.tap(search, kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(tester.widget<EditableText>(search).focusNode.hasFocus, isTrue);
    await tester.tapAt(const Offset(1300, 850), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(tester.widget<EditableText>(search).focusNode.hasFocus, isFalse);

    await _pressSelectAll(tester);

    expect(container.read(vibeLibrarySelectionNotifierProvider).selectedIds, {
      'first',
      'second',
    });
  }, variant: desktop);

  testWidgets('右键重命名分类后输入框拿到焦点，提交后 Ctrl+A 仍全选', (tester) async {
    final container = await _pumpScreen(tester);
    final categories = container.read(
      vibeLibraryCategoryNotifierProvider.notifier,
    );

    await tester.tap(
      find.text('分类A'),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名').last);
    // 菜单项在菜单关闭后延时切换到编辑态
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    final rename = find.descendant(
      of: find.byType(VibeCategoryItem),
      matching: find.byType(EditableText),
    );
    expect(rename, findsOneWidget);
    expect(
      tester.widget<EditableText>(rename).focusNode.hasPrimaryFocus,
      isTrue,
    );

    tester.testTextInput.enterText('分类B');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(rename, findsNothing);
    expect((categories as _OneCategoryNotifier).renames, [('a', '分类B')]);

    await _pressSelectAll(tester);
    expect(container.read(vibeLibrarySelectionNotifierProvider).selectedIds, {
      'first',
      'second',
    });
  }, variant: desktop);
}

Future<ProviderContainer> _pumpScreen(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      generationParamsNotifierProvider.overrideWith(
        _TestGenerationParamsNotifier.new,
      ),
      vibeLibraryNotifierProvider.overrideWith(_TwoEntryNotifier.new),
      vibeLibraryCategoryNotifierProvider.overrideWith(
        _OneCategoryNotifier.new,
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VibeLibraryScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

Future<void> _pressSelectAll(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

class _TwoEntryNotifier extends VibeLibraryNotifier {
  @override
  VibeLibraryState build() =>
      VibeLibraryState(entries: [_entry('first'), _entry('second')]);

  @override
  Future<void> initialize() async {}
}

class _TestGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() =>
      const ImageParams(model: ImageModels.animeDiffusionV45Full);
}

class _OneCategoryNotifier extends VibeLibraryCategoryNotifier {
  final renames = <(String, String)>[];

  @override
  VibeLibraryCategoryState build() => VibeLibraryCategoryState(
    categories: [
      VibeLibraryCategory(id: 'a', name: '分类A', createdAt: DateTime(2025)),
    ],
  );

  @override
  Future<VibeLibraryCategory?> renameCategory(
    String categoryId,
    String newName,
  ) async {
    renames.add((categoryId, newName));
    return null;
  }
}

VibeLibraryEntry _entry(String id) => VibeLibraryEntry(
  id: id,
  name: id,
  vibeDisplayName: id,
  vibeEncoding: 'encoding',
  createdAt: DateTime(2025),
);
