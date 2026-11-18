import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/prompt_assistant/widgets/prompt_assistant_dock.dart';
import 'package:nai_launcher/presentation/prompt_assistant/widgets/prompt_assistant_overlay.dart';

import '../../../helpers/memory_local_storage.dart';

const _sessionId = 'dock_test';
const _toolbarKey = ValueKey('prompt_assistant_toolbar_$_sessionId');
const _stripKey = ValueKey('dock-strip');
const _hostKey = ValueKey('dock-host');

class _StatefulStrip extends StatefulWidget {
  const _StatefulStrip() : super(key: _stripKey);

  @override
  State<_StatefulStrip> createState() => _StatefulStripState();
}

class _StatefulStripState extends State<_StatefulStrip> {
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 32,
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text('strip'),
    ),
  );
}

Future<TextEditingController> _pump(
  WidgetTester tester, {
  required double width,
  double scale = 1,
  bool enabled = true,
  TextDirection direction = TextDirection.ltr,
}) async {
  final controller = TextEditingController(text: 'cat, dog');
  addTearDown(controller.dispose);
  await tester.binding.setSurfaceSize(Size(width, 400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWith((ref) => MemoryLocalStorage()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Directionality(textDirection: direction, child: child!),
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: _hostKey,
              width: width - 32,
              child: PromptAssistantDock(
                assistant: PromptAssistantOverlay(
                  placement: PromptAssistantPlacement.inline,
                  iconOnly: true,
                  enabled: enabled,
                  sessionId: _sessionId,
                  controller: controller,
                  onChanged: (_) {},
                  onOpenSettings: () {},
                ),
                child: const _StatefulStrip(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('docked assistant reserves its slot and expands over the '
          'strip ($width, ${scale}x)', (tester) async {
        final controller = await _pump(tester, width: width, scale: scale);
        final host = tester.getRect(find.byKey(_hostKey));
        final strip = tester.getRect(find.byKey(_stripKey));
        final collapsed = tester.getRect(find.byKey(_toolbarKey));

        expect(collapsed.right, closeTo(host.right, 0.1));
        expect(
          strip.right,
          closeTo(collapsed.left - PromptAssistantDock.gap, 0.1),
        );
        expect(strip.left, closeTo(host.left, 0.1));
        expect(collapsed.center.dy, closeTo(strip.center.dy, 0.5));
        expect(find.text('strip').hitTestable(), findsOneWidget);

        await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
        await tester.pumpAndSettle();

        final expanded = tester.getRect(find.byKey(_toolbarKey));
        expect(tester.getRect(find.byKey(_stripKey)), strip);
        expect(expanded.right, closeTo(collapsed.right, 0.1));
        expect(expanded.top, closeTo(collapsed.top, 0.1));
        expect(expanded.left, greaterThanOrEqualTo(host.left - 0.1));
        expect(expanded.width, greaterThan(collapsed.width));
        expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

        await tester.tapAt(host.topLeft - const Offset(8, 8));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byKey(_toolbarKey)), collapsed);
        expect(controller.text, 'cat, dog');
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('hidden assistant releases its slot without rebuilding the '
      'strip', (tester) async {
    await _pump(tester, width: 600);
    final state = tester.state(find.byKey(_stripKey));
    final host = tester.getRect(find.byKey(_hostKey));
    expect(tester.getRect(find.byKey(_stripKey)).right, lessThan(host.right));

    await _pump(tester, width: 600, enabled: false);
    expect(find.byKey(_toolbarKey), findsNothing);
    expect(tester.state(find.byKey(_stripKey)), same(state));
    expect(tester.getRect(find.byKey(_stripKey)).right, host.right);
    expect(tester.takeException(), isNull);
  });

  testWidgets('docked assistant mirrors to the start edge in RTL', (
    tester,
  ) async {
    await _pump(tester, width: 600, direction: TextDirection.rtl);
    final host = tester.getRect(find.byKey(_hostKey));
    final strip = tester.getRect(find.byKey(_stripKey));
    final collapsed = tester.getRect(find.byKey(_toolbarKey));

    expect(collapsed.left, closeTo(host.left, 0.1));
    expect(strip.left, closeTo(collapsed.right + PromptAssistantDock.gap, 0.1));
    expect(strip.right, closeTo(host.right, 0.1));
    expect(tester.takeException(), isNull);
  });
}
