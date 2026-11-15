import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/services/prompt_token_counter_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/prompt_token_count_bar.dart';

void main() {
  group('PromptTokenCountBar', () {
    testWidgets('shows current token usage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PromptTokenCountBar(
              usage: PromptTokenUsage(
                usedTokens: 128,
                limit: 512,
              ),
            ),
          ),
        ),
      );

      expect(find.text('128 / 512'), findsOneWidget);
    });

    testWidgets('uses error color when usage exceeds limit', (tester) async {
      final theme = ThemeData.light();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme,
          home: const Scaffold(
            body: PromptTokenCountBar(
              usage: PromptTokenUsage(
                usedTokens: 520,
                limit: 512,
              ),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('520 / 512'));
      expect(text.style?.color, equals(theme.colorScheme.error));
    });

    testWidgets('shows breakdown tooltip when composition is available',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PromptTokenCountBar(
              usage: PromptTokenUsage(
                usedTokens: 121,
                limit: 512,
                breakdown: [
                  PromptTokenBreakdownEntry(label: '提示词', tokens: 100),
                  PromptTokenBreakdownEntry(label: '固定词', tokens: 20),
                  PromptTokenBreakdownEntry(label: '网页端校准', tokens: 1),
                ],
              ),
            ),
          ),
        ),
      );

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(
        tooltip.message,
        equals('提示词 100\n固定词 20\n网页端校准 1'),
      );
    });

    testWidgets('shows whole-prompt adjustment when breakdown sum differs',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PromptTokenCountBar(
              usage: PromptTokenUsage(
                usedTokens: 129,
                limit: 512,
                breakdown: [
                  PromptTokenBreakdownEntry(label: '提示词', tokens: 100),
                  PromptTokenBreakdownEntry(label: '固定词', tokens: 20),
                  PromptTokenBreakdownEntry(label: '网页端校准', tokens: 1),
                ],
              ),
            ),
          ),
        ),
      );

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(
        tooltip.message,
        equals('提示词 100\n固定词 28\n网页端校准 1'),
      );
    });

    testWidgets('keeps previous token usage while reloading', (tester) async {
      var loading = false;
      final dep = Provider<bool>((ref) => loading);
      final usageProvider = FutureProvider<PromptTokenUsage?>((ref) {
        if (ref.watch(dep)) return Completer<PromptTokenUsage?>().future;
        return const PromptTokenUsage(
          usedTokens: 128,
          limit: 512,
        );
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(usageProvider);
      loading = true;
      container.invalidate(dep);
      final reloadingUsage = container.read(usageProvider);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PromptTokenCountAsyncBar(usage: reloadingUsage),
          ),
        ),
      );

      expect(find.text('128 / 512'), findsOneWidget);
    });
  });
}
