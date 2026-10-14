import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_category_provider.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_provider.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_selection_provider.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/vibe_library_screen.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_library_toolbar.dart';

void main() {
  testWidgets('搜索框点外部失焦后 Ctrl+A 仍全选 Vibe', (tester) async {
    final container = ProviderContainer(
      overrides: [
        generationParamsNotifierProvider.overrideWith(
          _TestGenerationParamsNotifier.new,
        ),
        vibeLibraryNotifierProvider.overrideWith(_TwoEntryNotifier.new),
        vibeLibraryCategoryNotifierProvider.overrideWith(
          _EmptyCategoryNotifier.new,
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

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(container.read(vibeLibrarySelectionNotifierProvider).selectedIds, {
      'first',
      'second',
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
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

class _EmptyCategoryNotifier extends VibeLibraryCategoryNotifier {
  @override
  VibeLibraryCategoryState build() => const VibeLibraryCategoryState();
}

VibeLibraryEntry _entry(String id) => VibeLibraryEntry(
  id: id,
  name: id,
  vibeDisplayName: id,
  vibeEncoding: 'encoding',
  createdAt: DateTime(2025),
);
