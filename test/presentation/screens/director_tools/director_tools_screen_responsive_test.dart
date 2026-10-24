import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/services/pixel_snap/pixel_snap_progress.dart';
import 'package:nai_launcher/data/models/director/director_emotion.dart';
import 'package:nai_launcher/data/models/director/director_tool_output.dart';
import 'package:nai_launcher/data/models/director/director_tool_type.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/providers/director_tools_notifier.dart';
import 'package:nai_launcher/presentation/screens/director_tools/director_tools_screen.dart';
import 'package:nai_launcher/presentation/screens/director_tools/widgets/director_result_variant_selector.dart';
import 'package:nai_launcher/presentation/services/image_workflow_launcher.dart';
import 'package:nai_launcher/presentation/widgets/common/decoded_memory_image.dart';

const _tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
const _stackedLayoutKey = ValueKey('director-tools-stacked-layout');
const _sideBySideLayoutKey = ValueKey('director-tools-side-by-side-layout');

void main() {
  final sourceImage = Uint8List.fromList(base64Decode(_tinyPng));

  for (final scenario
      in <({Size size, double textScale, Key layout, String name})>[
        (
          size: const Size(320, 720),
          textScale: 1,
          layout: _stackedLayoutKey,
          name: '320 compact',
        ),
        (
          size: const Size(600, 720),
          textScale: 1,
          layout: _stackedLayoutKey,
          name: '600 medium without enough main area',
        ),
        (
          size: const Size(700, 720),
          textScale: 1,
          layout: _sideBySideLayoutKey,
          name: '700 medium with enough main area',
        ),
        (
          size: const Size(700, 720),
          textScale: 2,
          layout: _stackedLayoutKey,
          name: '700 medium with enlarged text',
        ),
        (
          size: const Size(839, 720),
          textScale: 1,
          layout: _sideBySideLayoutKey,
          name: '839 medium with enough main area',
        ),
        (
          size: const Size(840, 720),
          textScale: 1,
          layout: _sideBySideLayoutKey,
          name: '840 expanded',
        ),
        (
          size: const Size(1180, 720),
          textScale: 1,
          layout: _sideBySideLayoutKey,
          name: '1180 wide',
        ),
        (
          size: const Size(1600, 900),
          textScale: 1,
          layout: _sideBySideLayoutKey,
          name: '1600 extra wide',
        ),
        (
          size: const Size(760, 420),
          textScale: 1,
          layout: _stackedLayoutKey,
          name: 'short landscape',
        ),
        (
          size: const Size(600, 720),
          textScale: 3,
          layout: _stackedLayoutKey,
          name: '3x text',
        ),
      ]) {
    testWidgets('${scenario.name} keeps controls reachable without overflow', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        size: scenario.size,
        textScale: scenario.textScale,
        initialState: DirectorToolsState(sourceImage: sourceImage),
      );

      expect(find.byKey(scenario.layout), findsOneWidget);
      expect(find.text('Director Tools'), findsOneWidget);
      await _scrollControlIntoView(tester, find.text('Run Remove Background'));
      expect(find.text('Run Remove Background'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scenario in <({Size size, double textScale, String name})>[
    (size: const Size(320, 720), textScale: 1, name: '320 compact'),
    (size: const Size(600, 720), textScale: 1, name: '600 medium'),
    (size: const Size(840, 720), textScale: 1, name: '840 expanded'),
    (size: const Size(1180, 720), textScale: 1, name: '1180 wide'),
    (size: const Size(1600, 900), textScale: 1, name: '1600 extra wide'),
    (size: const Size(320, 720), textScale: 3, name: '320 with 3x text'),
    (size: const Size(840, 720), textScale: 3, name: '840 with 3x text'),
  ]) {
    testWidgets('Pixel Snap options stay reachable at ${scenario.name}', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        size: scenario.size,
        textScale: scenario.textScale,
        initialState: DirectorToolsState(
          selectedTool: DirectorToolType.pixelSnap,
          sourceImage: sourceImage,
          imageWidth: 512,
          imageHeight: 512,
        ),
      );

      await _expectSegmentsOnOneRow(tester, ['Off', 'Auto', 'Custom']);
      for (final label in [
        'Palettize',
        'Off',
        'Auto',
        'Custom',
        'Avoid Over-Refining',
        'Upscale',
        'Run Pixel Snap',
      ]) {
        await _scrollControlIntoView(tester, find.text(label));
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // 本机工具没有计费，Anlas 徽章必须不出现。
      expect(find.byIcon(Icons.diamond_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Pixel Snap progress keeps cancel reachable at 3x text', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      size: const Size(320, 720),
      textScale: 3,
      initialState: DirectorToolsState(
        selectedTool: DirectorToolType.pixelSnap,
        sourceImage: sourceImage,
        imageWidth: 512,
        imageHeight: 512,
        isRunning: true,
        progress: const PixelSnapProgress(PixelSnapStage.searchingPitch, 0.42),
      ),
    );

    await _scrollControlIntoView(tester, find.text('Cancel'));
    expect(find.text('Searching pixel size'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('running Pixel Snap skips the Anlas confirmation', (
    tester,
  ) async {
    final initialState = DirectorToolsState(
      selectedTool: DirectorToolType.pixelSnap,
      sourceImage: sourceImage,
      imageWidth: 512,
      imageHeight: 512,
    );
    final notifier = _RecordingDirectorToolsNotifier(initialState);
    await _pumpScreen(
      tester,
      size: const Size(840, 720),
      initialState: initialState,
      notifier: notifier,
    );

    final runButton = find.widgetWithText(FilledButton, 'Run Pixel Snap');
    await _scrollControlIntoView(tester, find.text('Run Pixel Snap'));
    await tester.ensureVisible(runButton);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(runButton).onPressed, isNotNull);
    await tester.tap(runButton);
    await tester.pumpAndSettle();

    expect(find.text('Confirm Anlas usage'), findsNothing);
    expect(notifier.runCalls, 1);
  });

  testWidgets('run stays disabled until the image cost can be estimated', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      size: const Size(840, 720),
      initialState: DirectorToolsState(sourceImage: sourceImage),
    );

    await _scrollControlIntoView(tester, find.text('Run Remove Background'));
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Run Remove Background'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('cancelling Anlas confirmation does not run the tool', (
    tester,
  ) async {
    final initialState = DirectorToolsState(
      sourceImage: sourceImage,
      imageWidth: 512,
      imageHeight: 512,
    );
    final notifier = _RecordingDirectorToolsNotifier(initialState);
    final expectedCost = initialState.estimatedAnlasCost();
    await _pumpScreen(
      tester,
      size: const Size(840, 720),
      initialState: initialState,
      notifier: notifier,
    );

    await _scrollControlIntoView(tester, find.text('Run Remove Background'));
    await tester.tap(
      find.widgetWithText(FilledButton, 'Run Remove Background'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Confirm Anlas usage'), findsOneWidget);
    expect(
      find.text(
        'Running Remove Background is estimated to cost $expectedCost Anlas. '
        'Do you want to continue?',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(notifier.runCalls, 0);
    expect(find.text('Confirm Anlas usage'), findsNothing);
  });

  testWidgets('confirming displayed Anlas cost runs the tool once', (
    tester,
  ) async {
    final initialState = DirectorToolsState(
      sourceImage: sourceImage,
      imageWidth: 512,
      imageHeight: 512,
    );
    final notifier = _RecordingDirectorToolsNotifier(initialState);
    final expectedCost = initialState.estimatedAnlasCost();
    await _pumpScreen(
      tester,
      size: const Size(840, 720),
      initialState: initialState,
      notifier: notifier,
    );

    await _scrollControlIntoView(tester, find.text('Run Remove Background'));
    await tester.tap(
      find.widgetWithText(FilledButton, 'Run Remove Background'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('$expectedCost Anlas'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(notifier.runCalls, 1);
    expect(find.text('Confirm Anlas usage'), findsNothing);
  });

  for (final outcome
      in <({String name, int selected, Set<int> failed, String message})>[
        (
          name: 'all saved',
          selected: 0,
          failed: const {},
          message: 'Remove Background completed',
        ),
        (
          name: 'every result failed',
          selected: 0,
          failed: const {0, 1, 2},
          message:
              'Remove Background completed, but the result could not be saved',
        ),
        (
          name: 'the selected result failed',
          selected: 1,
          failed: const {1},
          message:
              'Remove Background completed, but the selected result could not be saved (1 of 3 failed)',
        ),
        (
          name: 'another result failed',
          selected: 0,
          failed: const {2},
          message:
              'Remove Background completed, but 1 of 3 results could not be saved',
        ),
      ]) {
    testWidgets('registration toast when ${outcome.name}', (tester) async {
      final initialState = DirectorToolsState(
        sourceImage: sourceImage,
        imageWidth: 512,
        imageHeight: 512,
      );
      final notifier = _RegisteringDirectorToolsNotifier(
        initialState,
        selectedIndex: outcome.selected,
        failedIndices: outcome.failed,
      );
      await _pumpScreen(
        tester,
        size: const Size(840, 720),
        initialState: initialState,
        notifier: notifier,
      );

      await _scrollControlIntoView(tester, find.text('Run Remove Background'));
      await tester.tap(
        find.widgetWithText(FilledButton, 'Run Remove Background'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(notifier.registerCalls, 1);
      expect(find.text(outcome.message), findsOneWidget);
      expect(tester.takeException(), isNull);
      // 提示停留 3 秒再加退场动画，先放完再结束用例。
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('processing state remains visible and disables the run action', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      size: const Size(600, 720),
      initialState: DirectorToolsState(
        sourceImage: sourceImage,
        isRunning: true,
      ),
    );

    await _scrollControlIntoView(tester, find.text('Processing...'));
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Processing...'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error state remains readable without hiding the controls', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      size: const Size(600, 720),
      initialState: DirectorToolsState(
        sourceImage: sourceImage,
        error: 'synthetic failure',
      ),
    );

    await _scrollControlIntoView(tester, find.text('synthetic failure'));
    expect(find.text('synthetic failure'), findsOneWidget);
    expect(find.text('Run Remove Background'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('result state exposes comparison and apply actions', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      size: const Size(840, 720),
      initialState: DirectorToolsState(
        sourceImage: sourceImage,
        results: [DirectorToolImage(sourceImage)],
      ),
    );

    expect(find.text('Source Image'), findsOneWidget);
    expect(find.text('Result'), findsOneWidget);
    await _scrollControlIntoView(tester, find.text('Use as Source').last);
    expect(find.text('Use as Source'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in <({Size size, double textScale, String name})>[
    (size: const Size(320, 720), textScale: 1, name: '320 compact'),
    (size: const Size(600, 720), textScale: 1, name: '600 medium'),
    (size: const Size(840, 720), textScale: 1, name: '840 expanded'),
    (size: const Size(1180, 720), textScale: 1, name: '1180 wide'),
    (size: const Size(1600, 900), textScale: 1, name: '1600 extra wide'),
    (size: const Size(320, 720), textScale: 3, name: '320 with 3x text'),
    (size: const Size(840, 720), textScale: 3, name: '840 with 3x text'),
  ]) {
    testWidgets(
      'background removal variants stay switchable at ${scenario.name}',
      (tester) async {
        await _pumpScreen(
          tester,
          size: scenario.size,
          textScale: scenario.textScale,
          initialState: _backgroundRemovalResultState(sourceImage),
        );

        expect(find.text('Result · Masked'), findsOneWidget);
        await _expectSegmentsOnOneRow(tester, ['Masked', 'Generated', 'Blend']);

        await tester.ensureVisible(find.text('Blend'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Blend'));
        await tester.pumpAndSettle();

        expect(find.text('Result · Blend'), findsOneWidget);
        expect(_resultPreviewBytes(tester), same(_blendBytes));
        await _scrollControlIntoView(tester, find.text('Use as Source').last);
        expect(find.text('Use as Source'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scenario
      in <({Size size, double textScale, Locale locale, String name})>[
        (
          size: const Size(320, 720),
          textScale: 1,
          locale: const Locale('en'),
          name: '320 en',
        ),
        (
          size: const Size(600, 720),
          textScale: 1,
          locale: const Locale('en'),
          name: '600 en',
        ),
        (
          size: const Size(1180, 720),
          textScale: 1,
          locale: const Locale('en'),
          name: '1180 en',
        ),
        (
          size: const Size(320, 720),
          textScale: 3,
          locale: const Locale('en'),
          name: '320 en with 3x text',
        ),
        (
          size: const Size(320, 720),
          textScale: 3,
          locale: const Locale('ja'),
          name: '320 ja with 3x text',
        ),
        (
          size: const Size(840, 720),
          textScale: 3,
          locale: const Locale('ja'),
          name: '840 ja with 3x text',
        ),
      ]) {
    testWidgets('all emotions stay readable at ${scenario.name}', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        size: scenario.size,
        textScale: scenario.textScale,
        locale: scenario.locale,
        initialState: DirectorToolsState(
          selectedTool: DirectorToolType.fixEmotion,
          sourceImage: sourceImage,
          imageWidth: 512,
          imageHeight: 512,
        ),
      );

      final l10n = lookupAppLocalizations(scenario.locale);
      expect(DirectorEmotion.values, hasLength(24));
      for (final emotion in DirectorEmotion.values) {
        final label = emotion.label(l10n);
        await _scrollControlIntoView(tester, find.text(label));
        expect(find.text(label), findsOneWidget, reason: label);
        final chip = find.ancestor(
          of: find.text(label),
          matching: find.byType(ChoiceChip),
        );
        // 未选中与选中两态都要完整，选中标识不得挤占标签。
        for (final selected in <bool>[false, true]) {
          if (selected) {
            await tester.ensureVisible(chip);
            await tester.pump();
            await tester.tap(chip);
            await tester.pump();
          }
          expect(
            tester.widget<ChoiceChip>(chip).selected,
            emotion == DirectorEmotion.neutral || selected,
            reason: label,
          );
          _expectTextNotClipped(tester, label);
          expect(
            tester.getSize(chip).height,
            greaterThanOrEqualTo(44),
            reason: label,
          );
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('colorize defry row stays readable at 320 with 3x text', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      size: const Size(320, 720),
      textScale: 3,
      initialState: DirectorToolsState(
        selectedTool: DirectorToolType.colorize,
        sourceImage: sourceImage,
        imageWidth: 512,
        imageHeight: 512,
      ),
    );

    await _scrollControlIntoView(tester, find.text('Defry'));
    _expectTextNotClipped(tester, 'Defry');
    await _scrollControlIntoView(tester, find.text('Run Colorize'));
    expect(find.text('Run Colorize'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single result hides the variant switch', (tester) async {
    await _pumpScreen(
      tester,
      size: const Size(840, 720),
      initialState: DirectorToolsState(
        sourceImage: sourceImage,
        results: [DirectorToolImage(sourceImage)],
      ),
    );

    expect(find.byType(DirectorResultVariantSelector), findsNothing);
    expect(find.text('Result'), findsOneWidget);
  });

  testWidgets('apply hands the selected variant back to the workflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(840, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final workflow = _RecordingWorkflow();

    await tester.pumpWidget(
      _testApp(
        size: const Size(840, 720),
        initialState: _backgroundRemovalResultState(sourceImage),
        workflow: workflow,
        home: Consumer(
          builder: (context, ref, child) => Scaffold(
            body: FilledButton(
              onPressed: () => ImageWorkflowLauncher.openDirectorTools(
                context,
                ref,
                sourceImage,
              ),
              child: const Text('Open launcher'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open launcher'));
    await tester.pumpAndSettle();

    await _scrollControlIntoView(tester, find.text('Generated'));
    await tester.ensureVisible(find.text('Generated'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generated'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Use as Source'),
      ),
    );
    await tester.pumpAndSettle();

    expect(workflow.replaced, [same(_generatedBytes)]);
    expect(find.byType(DirectorToolsScreen), findsNothing);
  });

  testWidgets(
    'ImageWorkflowLauncher opens DirectorToolsScreen.show and returns',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _testApp(
          size: const Size(390, 720),
          initialState: DirectorToolsState(sourceImage: sourceImage),
          home: Consumer(
            builder: (context, ref, child) => Scaffold(
              body: FilledButton(
                onPressed: () => ImageWorkflowLauncher.openDirectorTools(
                  context,
                  ref,
                  sourceImage,
                ),
                child: const Text('Open launcher'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open launcher'));
      await tester.pumpAndSettle();
      expect(find.byType(DirectorToolsScreen), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(DirectorToolsScreen), findsNothing);
      expect(find.text('Open launcher'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('320 wide 3x route keeps system back reachable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testApp(
        size: const Size(320, 720),
        textScale: 3,
        initialState: DirectorToolsState(sourceImage: sourceImage),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () =>
                  DirectorToolsScreen.show(context, sourceImage: sourceImage),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('result app bar action uses the screen local width', (
    tester,
  ) async {
    const size = Size(840, 720);
    final initialState = DirectorToolsState(
      sourceImage: sourceImage,
      results: [DirectorToolImage(sourceImage)],
    );
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _testApp(
        size: size,
        initialState: initialState,
        home: Align(
          child: SizedBox(
            width: 500,
            child: DirectorToolsScreen(sourceImage: sourceImage),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final appBar = find.byType(AppBar);
    expect(
      find.descendant(
        of: appBar,
        matching: find.widgetWithText(TextButton, 'Use as Source'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: appBar, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('result apply returns bytes without running a paid operation', (
    tester,
  ) async {
    Uint8List? returned;
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testApp(
        size: const Size(320, 720),
        initialState: DirectorToolsState(
          sourceImage: sourceImage,
          results: [DirectorToolImage(sourceImage)],
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                returned = await DirectorToolsScreen.show(
                  context,
                  sourceImage: sourceImage,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(returned, sourceImage);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required Size size,
  required DirectorToolsState initialState,
  double textScale = 1,
  DirectorToolsNotifier? notifier,
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _testApp(
      size: size,
      textScale: textScale,
      initialState: initialState,
      notifier: notifier,
      locale: locale,
      home: DirectorToolsScreen(sourceImage: initialState.sourceImage!),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Widget _testApp({
  required Size size,
  required DirectorToolsState initialState,
  required Widget home,
  double textScale = 1,
  DirectorToolsNotifier? notifier,
  ImageWorkflowController? workflow,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      directorToolsNotifierProvider.overrideWith(
        () => notifier ?? _ScenarioDirectorToolsNotifier(initialState),
      ),
      if (workflow != null)
        imageWorkflowControllerProvider.overrideWith(() => workflow),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: size,
          textScaler: TextScaler.linear(textScale),
          padding: const EdgeInsets.only(top: 12, bottom: 16),
        ),
        child: InteractionPolicyScope(
          initialPolicy: const InteractionPolicy(
            modality: InteractionModality.touch,
            touchAvailable: true,
            precisePointerAvailable: false,
          ),
          child: child!,
        ),
      ),
      home: home,
    ),
  );
}

Future<void> _scrollControlIntoView(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .last,
  );
}

/// 分段选项同处一行、可横向滚到、标签不被截断且命中区不小于 44。
Future<void> _expectSegmentsOnOneRow(
  WidgetTester tester,
  List<String> labels,
) async {
  Finder segmentOf(String label) => find
      .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      )
      .first;

  await _scrollControlIntoView(tester, find.text(labels.first));
  final rowCenter = tester.getCenter(segmentOf(labels.first)).dy;
  for (final label in labels) {
    expect(
      tester.getCenter(segmentOf(label)).dy,
      moreOrLessEquals(rowCenter, epsilon: 0.5),
      reason: label,
    );
  }
  for (final label in labels) {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    final size = tester.getSize(segmentOf(label));
    expect(size.height, greaterThanOrEqualTo(44), reason: label);
    expect(size.width, greaterThanOrEqualTo(44), reason: label);
    _expectTextNotClipped(tester, label);
  }
}

void _expectTextNotClipped(WidgetTester tester, String label) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
  expect(paragraph.didExceedMaxLines, isFalse, reason: label);
  // 不折行的文本比单行宽度窄，就是被裁切或淡出了。
  if (!paragraph.softWrap) {
    expect(
      paragraph.size.width,
      greaterThanOrEqualTo(
        paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5,
      ),
      reason: label,
    );
  }
  // 折行后的文字仍须完整落在自身绘制区域内。
  expect(
    paragraph.size.height,
    greaterThanOrEqualTo(
      paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.5,
    ),
    reason: label,
  );
}

Uint8List _resultPreviewBytes(WidgetTester tester) => tester
    .widget<DecodedMemoryImage>(
      find.descendant(
        of: find.byKey(const ValueKey('director-result-preview')),
        matching: find.byType(DecodedMemoryImage),
      ),
    )
    .bytes;

class _RecordingDirectorToolsNotifier extends _ScenarioDirectorToolsNotifier {
  _RecordingDirectorToolsNotifier(super.initialState);

  int runCalls = 0;

  @override
  Future<void> runTool() async {
    runCalls++;
  }
}

/// 运行时直接给出背景移除的三张结果，登记按预设的失败序号返回，不碰真实历史与图库。
class _RegisteringDirectorToolsNotifier extends _ScenarioDirectorToolsNotifier {
  _RegisteringDirectorToolsNotifier(
    super.initialState, {
    required this.selectedIndex,
    required this.failedIndices,
  });

  final int selectedIndex;
  final Set<int> failedIndices;
  int registerCalls = 0;

  @override
  Future<void> runTool() async {
    state = _backgroundRemovalResultState(
      state.sourceImage!,
    ).copyWith(selectedResultIndex: selectedIndex);
  }

  @override
  Future<DirectorResultRegistration> registerResult() async {
    registerCalls++;
    return DirectorResultRegistration(
      total: state.results.length,
      selectedIndex: state.selectedResultIndex,
      failedIndices: failedIndices,
    );
  }
}

class _ScenarioDirectorToolsNotifier extends DirectorToolsNotifier {
  _ScenarioDirectorToolsNotifier(this.initialState);

  final DirectorToolsState initialState;

  @override
  DirectorToolsState build() => initialState;

  @override
  Future<void> init(Uint8List sourceImage) async {
    state = initialState.copyWith(sourceImage: sourceImage);
  }

  @override
  Future<void> runTool() async {
    throw StateError('Widget tests must not execute Director Tools requests.');
  }
}

final Uint8List _maskedBytes = _solidPng(255, 0, 0);
final Uint8List _generatedBytes = _solidPng(0, 255, 0);
final Uint8List _blendBytes = _solidPng(0, 0, 255);

Uint8List _solidPng(int r, int g, int b) {
  final image = img.Image(width: 2, height: 2)..clear(img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodePng(image));
}

DirectorToolsState _backgroundRemovalResultState(Uint8List sourceImage) =>
    DirectorToolsState(
      sourceImage: sourceImage,
      imageWidth: 512,
      imageHeight: 512,
      results: DirectorToolOutput.labelled([
        _maskedBytes,
        _generatedBytes,
        _blendBytes,
      ], variants: DirectorResultVariant.values).images,
    );

class _RecordingWorkflow extends ImageWorkflowController {
  final List<Uint8List> replaced = [];

  @override
  ImageWorkflowState build() => const ImageWorkflowState();

  @override
  void replaceSourceImage(
    Uint8List imageBytes, {
    int? sourceWidth,
    int? sourceHeight,
    bool autoAdapt = true,
  }) {
    replaced.add(imageBytes);
  }

  @override
  void setPanelExpanded(bool value) {}
}
