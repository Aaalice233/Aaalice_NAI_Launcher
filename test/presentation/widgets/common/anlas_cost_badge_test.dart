import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/providers/cost_estimate_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/anlas_cost_badge.dart';

void main() {
  group('AnlasCostBadge', () {
    testWidgets('hides when generating', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFreeGenerationProvider.overrideWith((ref) => false),
            estimatedCostProvider.overrideWith((ref) => 10),
            isBalanceInsufficientProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AnlasCostBadge(isGenerating: true),
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsNothing);
      expect(find.text('10'), findsNothing);
    });

    testWidgets('hides when free', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFreeGenerationProvider.overrideWith((ref) => true),
            estimatedCostProvider.overrideWith((ref) => 0),
            isBalanceInsufficientProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AnlasCostBadge(isGenerating: false),
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('shows cost when not generating and not free', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFreeGenerationProvider.overrideWith((ref) => false),
            estimatedCostProvider.overrideWith((ref) => 10),
            isBalanceInsufficientProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AnlasCostBadge(isGenerating: false),
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('shows a placeholder while the cost is computing', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFreeGenerationProvider.overrideWith((ref) => false),
            estimatedCostProvider.overrideWith((ref) => null),
            isBalanceInsufficientProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AnlasCostBadge(isGenerating: false)),
          ),
        ),
      );

      expect(find.text('--'), findsOneWidget);
      expect(find.text('null'), findsNothing);
    });

    testWidgets('shows error color when balance insufficient', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFreeGenerationProvider.overrideWith((ref) => false),
            estimatedCostProvider.overrideWith((ref) => 100),
            isBalanceInsufficientProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light(error: Colors.red),
            ),
            home: const Scaffold(
              body: AnlasCostBadge(isGenerating: false),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(
        (decoration.color as Color).toARGB32(),
        equals(Colors.red.withValues(alpha: 0.9).toARGB32()),
      );
    });

    testWidgets('shows primary container color when balance sufficient',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFreeGenerationProvider.overrideWith((ref) => false),
            estimatedCostProvider.overrideWith((ref) => 5),
            isBalanceInsufficientProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            theme: ThemeData(
              colorScheme:
                  const ColorScheme.light(primaryContainer: Colors.blue),
            ),
            home: const Scaffold(
              body: AnlasCostBadge(isGenerating: false),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(
        (decoration.color as Color).toARGB32(),
        equals(Colors.blue.withValues(alpha: 0.9).toARGB32()),
      );
    });
  });
}
