import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_category_provider.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_provider.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/vibe_library_screen.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_export_dialog_advanced.dart';

void main() {
  final desktop = TargetPlatformVariant.only(TargetPlatform.windows);

  testWidgets('默认 Ctrl+I 导入、Ctrl+E 导出', (tester) async {
    final harness = await _pumpScreen(tester, ShortcutConfig.createDefault());

    await harness.press(LogicalKeyboardKey.keyI, control: true);
    expect(harness.importPicks, 1);

    await harness.press(LogicalKeyboardKey.keyE, control: true);
    expect(find.byType(VibeExportDialogAdvanced), findsOneWidget);
  }, variant: desktop);

  testWidgets('改绑后按新组合键触发，原 Ctrl+I / Ctrl+E 不再触发', (tester) async {
    final harness = await _pumpScreen(
      tester,
      ShortcutConfig.createDefault()
          .setCustomShortcut(ShortcutIds.vibeImport, 'ctrl+shift+i')
          .setCustomShortcut(ShortcutIds.vibeExport, 'ctrl+shift+e'),
    );

    await harness.press(LogicalKeyboardKey.keyI, control: true);
    await harness.press(LogicalKeyboardKey.keyE, control: true);
    expect(harness.importPicks, 0);
    expect(find.byType(VibeExportDialogAdvanced), findsNothing);

    await harness.press(LogicalKeyboardKey.keyI, control: true, shift: true);
    expect(harness.importPicks, 1);
    await harness.press(LogicalKeyboardKey.keyE, control: true, shift: true);
    expect(find.byType(VibeExportDialogAdvanced), findsOneWidget);
  }, variant: desktop);

  testWidgets('单项禁用后不触发', (tester) async {
    final harness = await _pumpScreen(
      tester,
      ShortcutConfig.createDefault().setEnabled(ShortcutIds.vibeImport, false),
    );
    await harness.press(LogicalKeyboardKey.keyI, control: true);
    expect(harness.importPicks, 0);
  }, variant: desktop);

  testWidgets('快捷键总开关关闭时不触发', (tester) async {
    final harness = await _pumpScreen(
      tester,
      ShortcutConfig.createDefault().copyWith(enableShortcuts: false),
    );
    await harness.press(LogicalKeyboardKey.keyI, control: true);
    await harness.press(LogicalKeyboardKey.keyE, control: true);
    expect(harness.importPicks, 0);
    expect(find.byType(VibeExportDialogAdvanced), findsNothing);
  }, variant: desktop);
}

class _Harness {
  _Harness(this.tester);

  final WidgetTester tester;
  int importPicks = 0;

  Future<List<PlatformFile>?> pick() async {
    importPicks++;
    return null;
  }

  Future<void> press(
    LogicalKeyboardKey key, {
    bool control = false,
    bool shift = false,
  }) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }
}

Future<_Harness> _pumpScreen(WidgetTester tester, ShortcutConfig config) async {
  final harness = _Harness(tester);
  final container = ProviderContainer(
    overrides: [
      shortcutConfigNotifierProvider.overrideWith(
        () => _FixedShortcutConfigNotifier(config),
      ),
      generationParamsNotifierProvider.overrideWith(
        _TestGenerationParamsNotifier.new,
      ),
      vibeLibraryNotifierProvider.overrideWith(_TwoEntryNotifier.new),
      vibeLibraryCategoryNotifierProvider.overrideWith(_NoCategoryNotifier.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VibeLibraryScreen(pickImportFiles: harness.pick),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

class _FixedShortcutConfigNotifier extends ShortcutConfigNotifier {
  _FixedShortcutConfigNotifier(this.config);

  final ShortcutConfig config;

  @override
  Future<ShortcutConfig> build() async => config;
}

class _TwoEntryNotifier extends VibeLibraryNotifier {
  @override
  VibeLibraryState build() =>
      VibeLibraryState(entries: [_entry('first'), _entry('second')]);

  @override
  Future<void> initialize() async {}
}

class _NoCategoryNotifier extends VibeLibraryCategoryNotifier {
  @override
  VibeLibraryCategoryState build() => const VibeLibraryCategoryState();
}

class _TestGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() =>
      const ImageParams(model: ImageModels.animeDiffusionV45Full);
}

VibeLibraryEntry _entry(String id) => VibeLibraryEntry(
  id: id,
  name: id,
  vibeDisplayName: id,
  vibeEncoding: 'encoding',
  createdAt: DateTime(2025),
);
