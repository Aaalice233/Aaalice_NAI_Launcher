import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/pool_mapper_panel.dart';

void main() {
  group('PoolMapperPanel', () {
    testWidgets('should display pool ID input field', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PoolMapperPanel(
                poolId: '',
                onIdChanged: (_) {},
                onVerify: () {},
                isVerifying: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Danbooru Pool ID'), findsOneWidget);
    });

    testWidgets('should display verify button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PoolMapperPanel(
                poolId: '',
                onIdChanged: (_) {},
                onVerify: () {},
                isVerifying: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Verify'), findsOneWidget);
    });

    testWidgets('should call onIdChanged when text changes', (tester) async {
      String? capturedId;
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PoolMapperPanel(
                poolId: '',
                onIdChanged: (id) => capturedId = id,
                onVerify: () {},
                isVerifying: false,
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '12345');
      expect(capturedId, '12345');
    });

    testWidgets('should call onVerify when verify button tapped', (tester) async {
      bool verifyCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PoolMapperPanel(
                poolId: '12345',
                onIdChanged: (_) {},
                onVerify: () => verifyCalled = true,
                isVerifying: false,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Verify'));
      expect(verifyCalled, isTrue);
    });

    testWidgets('should show loading indicator when verifying', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PoolMapperPanel(
                poolId: '12345',
                onIdChanged: (_) {},
                onVerify: () {},
                isVerifying: true,
              ),
            ),
          ),
        ),
      );

      // Should show CircularProgressIndicator instead of text
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Verify'), findsNothing);
    });

    testWidgets('should display error message', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PoolMapperPanel(
                poolId: 'invalid',
                onIdChanged: (_) {},
                onVerify: () {},
                isVerifying: false,
                error: 'Invalid pool ID',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Invalid pool ID'), findsOneWidget);
    });

    testWidgets('should display preview tags', (tester) async {
      const previewTags = ['tag1', 'tag2', 'tag3'];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PoolMapperPanel(
                poolId: '12345',
                onIdChanged: (_) {},
                onVerify: () {},
                isVerifying: false,
                previewTags: previewTags,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('tag1'), findsOneWidget);
      expect(find.text('tag2'), findsOneWidget);
      expect(find.text('tag3'), findsOneWidget);
    });

    testWidgets('should show no preview message when empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PoolMapperPanel(
                poolId: '12345',
                onIdChanged: (_) {},
                onVerify: () {},
                isVerifying: false,
                previewTags: const [],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('No preview available'), findsOneWidget);
    });
  });
}
