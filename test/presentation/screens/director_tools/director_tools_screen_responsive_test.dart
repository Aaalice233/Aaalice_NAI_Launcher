import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/director_tools_notifier.dart';
import 'package:nai_launcher/presentation/screens/director_tools/director_tools_screen.dart';
import 'package:nai_launcher/presentation/services/image_workflow_launcher.dart';

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
        result: sourceImage,
      ),
    );

    expect(find.text('Source Image'), findsOneWidget);
    expect(find.text('Result'), findsOneWidget);
    await _scrollControlIntoView(tester, find.text('Use as Source').last);
    expect(find.text('Use as Source'), findsWidgets);
    expect(tester.takeException(), isNull);
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
      result: sourceImage,
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
          result: sourceImage,
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
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _testApp(
      size: size,
      textScale: textScale,
      initialState: initialState,
      notifier: notifier,
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
}) {
  return ProviderScope(
    overrides: [
      directorToolsNotifierProvider.overrideWith(
        () => notifier ?? _ScenarioDirectorToolsNotifier(initialState),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
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
    scrollable: find.byType(Scrollable).last,
  );
}

class _RecordingDirectorToolsNotifier extends _ScenarioDirectorToolsNotifier {
  _RecordingDirectorToolsNotifier(super.initialState);

  int runCalls = 0;

  @override
  Future<void> runTool() async {
    runCalls++;
  }
}

class _ScenarioDirectorToolsNotifier extends DirectorToolsNotifier {
  _ScenarioDirectorToolsNotifier(this.initialState);

  final DirectorToolsState initialState;

  @override
  DirectorToolsState build() => initialState;

  @override
  Future<void> init(Uint8List sourceImage, {String? initialPrompt}) async {
    state = initialState.copyWith(sourceImage: sourceImage);
  }

  @override
  Future<void> runTool() async {
    throw StateError('Widget tests must not execute Director Tools requests.');
  }
}
