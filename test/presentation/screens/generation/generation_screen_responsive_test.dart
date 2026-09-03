import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/layout_state_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/desktop_layout.dart';
import 'package:nai_launcher/presentation/screens/generation/generation_screen.dart';
import 'package:nai_launcher/presentation/screens/generation/mobile_layout.dart';
import 'package:nai_launcher/presentation/screens/generation/web_style_layout.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/fixed_tags_sidebar.dart';

import '../../../helpers/flutter_error_collector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('generation-screen-');
    Hive.init(hiveDirectory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    await Hive.openBox<dynamic>(StorageKeys.historyBox);
  });

  tearDownAll(() async {
    PlatformCapabilities.debugOverride = null;
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  tearDown(() {
    PlatformCapabilities.debugOverride = null;
  });

  testWidgets('generation composition follows local width under touch input', (
    tester,
  ) async {
    final flutterErrors = FlutterErrorCollector.install(tester);
    addTearDown(flutterErrors.restoreAndAssertNoErrors);
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );

    for (final width in [360.0, 700.0, 840.0, 899.0, 999.0]) {
      await tester.binding.setSurfaceSize(Size(width, 760));
      await _pumpGeneration(tester);
      await tester.pump(const Duration(milliseconds: 100));

      final usesExpandedComposition = width >= 840;
      final expandedLayouts = find.byWidgetPredicate(
        (widget) =>
            widget is DesktopGenerationLayout ||
            widget is WebStyleGenerationLayout,
      );
      expect(
        expandedLayouts,
        usesExpandedComposition ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(MobileGenerationLayout),
        usesExpandedComposition ? findsNothing : findsOneWidget,
      );
      if (!usesExpandedComposition) {
        expect(find.text('Canvas'), findsOneWidget);
        expect(find.byIcon(Icons.brush_outlined), findsOneWidget);
      }
      flutterErrors.expectNoErrors(reason: 'width=$width');
    }

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'expanded precise-pointer layout starts at 840 without overflow',
    (tester) async {
      final flutterErrors = FlutterErrorCollector.install(tester);
      addTearDown(flutterErrors.restoreAndAssertNoErrors);
      PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
        TargetPlatform.windows,
      );
      const pointerPolicy = InteractionPolicy(
        modality: InteractionModality.pointer,
        touchAvailable: false,
        precisePointerAvailable: true,
      );

      for (final width in [840.0, 899.0, 999.0, 1180.0, 1600.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        await _pumpGeneration(tester, interactionPolicy: pointerPolicy);
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DesktopGenerationLayout ||
                widget is WebStyleGenerationLayout,
          ),
          findsOneWidget,
        );
        expect(find.byType(MobileGenerationLayout), findsNothing);
        final workspaceHeaderCount =
            find
                .byKey(const ValueKey('classic-generation-workspace-header'))
                .evaluate()
                .length +
            find
                .byKey(const ValueKey('web-generation-workspace-header'))
                .evaluate()
                .length;
        expect(workspaceHeaderCount, 1);
        expect(find.text('Canvas'), findsOneWidget);
        expect(find.byIcon(Icons.brush_outlined), findsOneWidget);
        flutterErrors.expectNoErrors(reason: 'width=$width');
      }

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('layout state survives the 840 precise-pointer boundary', (
    tester,
  ) async {
    final flutterErrors = FlutterErrorCollector.install(tester);
    addTearDown(flutterErrors.restoreAndAssertNoErrors);
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    const pointerPolicy = InteractionPolicy(
      modality: InteractionModality.pointer,
      touchAvailable: false,
      precisePointerAvailable: true,
    );
    final container = ProviderContainer(
      overrides: [
        shortcutConfigNotifierProvider.overrideWith(
          _FakeShortcutConfigNotifier.new,
        ),
        layoutStateNotifierProvider.overrideWith(
          _ExpandedFixedTagsLayoutNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(839, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpGeneration(
      tester,
      container: container,
      interactionPolicy: pointerPolicy,
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MobileGenerationLayout), findsOneWidget);
    expect(
      find.byKey(const Key('generation-fixed-tags-overlay')),
      findsOneWidget,
    );

    await tester.binding.setSurfaceSize(const Size(840, 760));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MobileGenerationLayout), findsNothing);
    expect(
      container.read(layoutStateNotifierProvider).fixedTagsSidebarExpanded,
      isTrue,
    );

    await tester.binding.setSurfaceSize(const Size(839, 760));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('generation-fixed-tags-overlay')),
      findsOneWidget,
    );
    flutterErrors.expectNoErrors(reason: '839↔840 boundary transition');
  });

  testWidgets('prompt editing state survives the 839 to 840 layout switch', (
    tester,
  ) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    const pointerPolicy = InteractionPolicy(
      modality: InteractionModality.pointer,
      touchAvailable: false,
      precisePointerAvailable: true,
    );
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWith(
          (ref) => _PromptStateTestStorage(),
        ),
        shortcutConfigNotifierProvider.overrideWith(
          _FakeShortcutConfigNotifier.new,
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(839, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpGeneration(
      tester,
      container: container,
      interactionPolicy: pointerPolicy,
    );
    await tester.pump(const Duration(milliseconds: 100));

    final positiveMode = find.byKey(
      const ValueKey('generation_prompt_compact_positive_mode'),
    );
    final negativeMode = find.byKey(
      const ValueKey('generation_prompt_compact_negative_mode'),
    );
    expect(positiveMode, findsOneWidget);
    expect(negativeMode, findsOneWidget);
    await tester.tap(negativeMode);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('generation_prompt_negative_input')),
      findsOneWidget,
    );
    await tester.tap(positiveMode);
    await tester.pump();

    final mobileEditor = find.descendant(
      of: find.byKey(const ValueKey('generation_prompt_positive_input')),
      matching: find.byType(EditableText),
    );
    expect(mobileEditor, findsOneWidget);
    final before = tester.widget<EditableText>(mobileEditor);
    await tester.tap(mobileEditor);
    await tester.pump();
    expect(before.focusNode.hasFocus, isTrue);
    final focusedEditingValue = before.controller.value;

    await tester.binding.setSurfaceSize(const Size(840, 700));
    await tester.pump();

    final desktopEditor = find.descendant(
      of: find.byKey(const ValueKey('generation_prompt_positive_input')),
      matching: find.byType(EditableText),
    );
    expect(desktopEditor, findsOneWidget);
    final after = tester.widget<EditableText>(desktopEditor);
    expect(identical(after.controller, before.controller), isTrue);
    expect(after.controller.value, focusedEditingValue);
    expect(identical(after.focusNode, before.focusNode), isTrue);
    expect(after.focusNode.hasFocus, isTrue);
    after.focusNode.unfocus();
    tester.testTextInput.hide();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets(
    '320-wide 3x compact layout keeps focused prompt and actions above IME',
    (tester) async {
      final flutterErrors = FlutterErrorCollector.install(tester);
      addTearDown(flutterErrors.restoreAndAssertNoErrors);
      PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
        TargetPlatform.android,
      );
      const size = Size(320, 760);
      const safePadding = EdgeInsets.only(top: 24, bottom: 16);
      const keyboardInset = 300.0;
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => _PromptStateTestStorage(),
          ),
          shortcutConfigNotifierProvider.overrideWith(
            _FakeShortcutConfigNotifier.new,
          ),
        ],
      );

      await _pumpGeneration(
        tester,
        container: container,
        textScaler: const TextScaler.linear(3),
        padding: safePadding,
        viewPadding: safePadding,
        viewInsets: const EdgeInsets.only(bottom: keyboardInset),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MobileGenerationLayout), findsOneWidget);
      final launcher = find.byKey(
        const ValueKey('generation-collapsed-prompt-launcher'),
      );
      expect(launcher.hitTestable(), findsOneWidget);
      await tester.tap(launcher);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final promptInput = find.descendant(
        of: find.byKey(
          const ValueKey('generation_prompt_positive_input'),
          skipOffstage: false,
        ),
        matching: find.byType(EditableText, skipOffstage: false),
      );
      expect(promptInput, findsOneWidget);
      await tester.ensureVisible(promptInput);
      await tester.pump();
      await tester.tap(promptInput);
      await tester.pump();
      expect(
        tester.widget<EditableText>(promptInput).focusNode.hasFocus,
        isTrue,
      );

      final usableRect = Rect.fromLTRB(
        0,
        safePadding.top,
        size.width,
        size.height - keyboardInset,
      );
      final promptSurface = find.byKey(
        const ValueKey('generation_prompt_compact_surface'),
      );
      final closeAction = find.byKey(
        const ValueKey('generation-prompt-editor-close'),
      );
      for (final criticalControl in [promptSurface, closeAction]) {
        final controlRect = tester.getRect(criticalControl);
        expect(
          controlRect.left >= usableRect.left &&
              controlRect.top >= usableRect.top &&
              controlRect.right <= usableRect.right &&
              controlRect.bottom <= usableRect.bottom,
          isTrue,
          reason: '$criticalControl should remain inside the usable viewport',
        );
      }
      expect(closeAction.hitTestable(), findsOneWidget);
      flutterErrors.expectNoErrors(
        reason: '320 width with 3x text, SafeArea, and IME',
      );

      await tester.tap(closeAction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(milliseconds: 200));
    },
  );

  testWidgets('fixed-tags state survives overlay to side-panel transition', (
    tester,
  ) async {
    final flutterErrors = FlutterErrorCollector.install(tester);
    addTearDown(flutterErrors.restoreAndAssertNoErrors);
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
    final container = ProviderContainer(
      overrides: [
        shortcutConfigNotifierProvider.overrideWith(
          _FakeShortcutConfigNotifier.new,
        ),
        layoutStateNotifierProvider.overrideWith(
          _ExpandedFixedTagsLayoutNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.binding.setSurfaceSize(const Size(700, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpGeneration(tester, container: container);
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const Key('generation-fixed-tags-overlay')),
      findsOneWidget,
    );
    expect(find.byType(FixedTagsSidebar), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(900, 760));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(
      find.byKey(const Key('generation-fixed-tags-overlay')),
      findsNothing,
    );
    expect(find.byType(FixedTagsSidebar), findsOneWidget);
    expect(
      container.read(layoutStateNotifierProvider).fixedTagsSidebarExpanded,
      isTrue,
    );
    flutterErrors.expectNoErrors(
      reason: 'fixed-tags overlay to side-panel transition',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 150));
  });
}

Future<void> _pumpGeneration(
  WidgetTester tester, {
  ProviderContainer? container,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewPadding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  InteractionPolicy? interactionPolicy,
}) {
  final app = MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: true,
        textScaler: textScaler,
        padding: padding,
        viewPadding: viewPadding,
        viewInsets: viewInsets,
      ),
      child: child!,
    ),
    home: InteractionPolicyScope(
      initialPolicy: interactionPolicy,
      child: const Scaffold(body: GenerationScreen()),
    ),
  );
  if (container != null) {
    return tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: app),
    );
  }
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        shortcutConfigNotifierProvider.overrideWith(
          _FakeShortcutConfigNotifier.new,
        ),
      ],
      child: app,
    ),
  );
}

class _ExpandedFixedTagsLayoutNotifier extends LayoutStateNotifier {
  @override
  LayoutState build() => const LayoutState(fixedTagsSidebarExpanded: true);
}

class _FakeShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

class _PromptStateTestStorage extends LocalStorageService {
  bool _maximized = false;

  @override
  bool getPromptMaximized() => _maximized;

  @override
  Future<void> setPromptMaximized(bool maximized) async {
    _maximized = maximized;
  }
}
