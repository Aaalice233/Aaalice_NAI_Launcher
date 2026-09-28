import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_approval.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/grunge_palette.dart';

void main() {
  Widget app({
    required double width,
    required Widget child,
    TextScaler textScaler = TextScaler.noScaling,
    ThemeData? theme,
  }) {
    return MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true, textScaler: textScaler),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    );
  }

  AgentChatApprovalCard approval({
    Key? key,
    String requestId = 'request-1',
    Map<String, dynamic>? args,
    int? estimatedAnlas = 12,
    ValueChanged<bool>? onResolve,
  }) {
    return AgentChatApprovalCard(
      key: key ?? ValueKey(requestId),
      toolName: 'submit_generation',
      args:
          args ??
          {
            'prompt': 'A detailed three-day weather chart',
            'model': 'nai-diffusion-4-full',
            'images': 1,
          },
      estimatedAnlas: estimatedAnlas,
      onResolve: onResolve ?? (_) {},
    );
  }

  testWidgets(
    'approval text and actions keep readable contrast in both themes',
    (tester) async {
      double contrast(Color foreground, Color background) {
        final a = Color.alphaBlend(foreground, background).computeLuminance();
        final b = background.computeLuminance();
        return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
      }

      for (final palette in [
        const GrungePalette().lightScheme,
        const GrungePalette().darkScheme,
      ]) {
        final scheme = resolveLayeredSurfaceColors(palette);
        await tester.pumpWidget(
          app(
            width: 600,
            theme: ThemeData(colorScheme: scheme),
            child: approval(),
          ),
        );
        final surface = tester.widget<Container>(
          find.byKey(const ValueKey('agent-chat-approval-surface')),
        );
        final background = (surface.decoration! as BoxDecoration).color!;
        expect(background.a, 1);
        for (final text
            in find
                .descendant(
                  of: find.byKey(const ValueKey('agent-chat-approval-surface')),
                  matching: find.byType(Text),
                )
                .evaluate()
                .map((element) => element.widget as Text)) {
          if (text.style?.color case final color?) {
            expect(
              contrast(color, background),
              greaterThanOrEqualTo(4.5),
              reason: text.data,
            );
          }
        }
        for (final button in [
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)),
          tester.widget<FilledButton>(find.byType(FilledButton)),
        ]) {
          final style = button.style!;
          expect(
            contrast(
              style.foregroundColor!.resolve({})!,
              style.backgroundColor!.resolve({})!,
            ),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
    },
  );

  testWidgets('is bounded at required widths with TextScaler 3', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 412.0, 600.0, 840.0, 1180.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(
        app(
          width: width,
          textScaler: const TextScaler.linear(3),
          child: approval(),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('agent-chat-approval-surface')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'width $width');

      final buttonFinder = find.byWidgetPredicate(
        (widget) => widget is ButtonStyleButton,
      );
      expect(buttonFinder, findsNWidgets(2));
      for (final element in buttonFinder.evaluate()) {
        expect(
          tester.getSize(find.byWidget(element.widget)).height,
          greaterThanOrEqualTo(48),
        );
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('shows an estimate only when authoritative estimate exists', (
    tester,
  ) async {
    await tester.pumpWidget(app(width: 360, child: approval()));
    expect(find.textContaining('12 Anlas'), findsOneWidget);

    await tester.pumpWidget(
      app(width: 360, child: approval(estimatedAnlas: null)),
    );
    expect(find.textContaining('Anlas'), findsNothing);
  });

  testWidgets('expands sanitized parameters without credentials or paths', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        width: 360,
        child: approval(
          args: {
            'api_token': 'pst-super-secret-token-value',
            'password': 'hunter2',
            'output_path': r'C:\Users\Alice\private\result.png',
            'image': Uint8List.fromList([1, 2, 3]),
            'prompt': 'safe prompt',
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-chat-approval-details')));
    await tester.pumpAndSettle();

    expect(find.textContaining('[redacted]'), findsWidgets);
    expect(find.textContaining('[local path]'), findsWidgets);
    expect(find.textContaining('[binary omitted]'), findsWidgets);
    expect(find.textContaining('safe prompt'), findsWidgets);
    expect(find.textContaining('pst-super-secret-token-value'), findsNothing);
    expect(find.textContaining(r'C:\Users\Alice'), findsNothing);
  });

  testWidgets(
    'same tool and arguments become actionable for a new request id',
    (tester) async {
      final decisions = <bool>[];
      await tester.pumpWidget(
        app(width: 360, child: approval(onResolve: decisions.add)),
      );

      final allow = find.byType(FilledButton);
      await tester.tap(allow);
      await tester.tap(allow);
      await tester.pump();
      expect(decisions, [isTrue]);

      await tester.pumpWidget(
        app(
          width: 360,
          child: approval(requestId: 'request-2', onResolve: decisions.add),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OutlinedButton));
      expect(decisions, [isTrue, isFalse]);
    },
  );

  testWidgets('delete approvals retain irreversible-risk wording', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        width: 360,
        child: AgentChatApprovalCard(
          toolName: 'delete_tag_library_entry',
          args: const {'id': 'entry-1'},
          estimatedAnlas: null,
          onResolve: (_) {},
        ),
      ),
    );

    expect(find.textContaining('cannot be undone'), findsOneWidget);
    expect(find.textContaining('Anlas'), findsNothing);
  });
}
