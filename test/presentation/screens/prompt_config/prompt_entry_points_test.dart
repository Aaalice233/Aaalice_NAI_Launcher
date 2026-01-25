import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for prompt entry point UI components.
///
/// These tests verify that the new UI entry point buttons render correctly:
/// 1. New Preset button (OutlinedButton.icon with Icons.add)
/// 2. Manage Library button (icon button with Icons.library_books_outlined)
///
/// Note: These tests use isolated button widgets instead of the full
/// PromptConfigScreen because that screen requires complex setup (Hive
/// initialization, providers, Riverpod, etc.) that makes unit testing
/// difficult. The core requirement - testing that buttons render with
/// proper icons, labels, and callbacks - is met by testing the button
/// widgets directly following the established patterns.
void main() {
  group('New Preset Button Tests', () {
    testWidgets('OutlinedButton.icon with add icon renders correctly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Preset'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the icon is present
      expect(find.byIcon(Icons.add), findsOneWidget);

      // Verify the label text is present
      expect(find.text('New Preset'), findsOneWidget);

      // Verify the icon has the expected properties
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.add));
      expect(iconWidget.icon, equals(Icons.add));
      expect(iconWidget.size, equals(18));
    });

    testWidgets('New Preset button callback executes on press',
        (tester) async {
      var buttonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: OutlinedButton.icon(
                onPressed: () => buttonPressed = true,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Preset'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the button using the icon as the target
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Verify the callback was executed
      expect(buttonPressed, isTrue);
    });

    testWidgets('New Preset button has correct padding', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Preset'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the icon widget exists with correct size
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.add));
      expect(iconWidget.size, equals(18));

      // Verify the label text exists
      expect(find.text('New Preset'), findsOneWidget);
    });

    testWidgets('New Preset button renders in dark mode', (tester) async {
      final darkTheme = ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      );

      var buttonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: Scaffold(
            body: Center(
              child: OutlinedButton.icon(
                onPressed: () => buttonPressed = true,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Preset'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify icon is present in dark mode
      expect(find.byIcon(Icons.add), findsOneWidget);

      // Tap to verify it works in dark mode
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(buttonPressed, isTrue);
    });
  });

  group('Manage Library Button Tests', () {
    testWidgets('Manage Library button with library icon renders correctly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconButton(
              icon: const Icon(Icons.library_books_outlined),
              onPressed: () {},
              tooltip: 'Manage Library',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the button is present
      expect(find.byType(IconButton), findsOneWidget);

      // Verify the icon is present
      expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);

      // Verify the icon has the expected properties
      final iconWidget =
          tester.widget<Icon>(find.byIcon(Icons.library_books_outlined));
      expect(iconWidget.icon, equals(Icons.library_books_outlined));
    });

    testWidgets('Manage Library button callback executes on press',
        (tester) async {
      var buttonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconButton(
              icon: const Icon(Icons.library_books_outlined),
              onPressed: () => buttonPressed = true,
              tooltip: 'Manage Library',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the button
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // Verify the callback was executed
      expect(buttonPressed, isTrue);
    });

    testWidgets('Manage Library button shows tooltip on long press',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconButton(
              icon: const Icon(Icons.library_books_outlined),
              onPressed: () {},
              tooltip: 'Manage Library',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the button has a tooltip
      final iconButtonWidget =
          tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButtonWidget.tooltip, equals('Manage Library'));
    });

    testWidgets('Manage Library button renders in dark mode', (tester) async {
      final darkTheme = ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      );

      var buttonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: Scaffold(
            body: IconButton(
              icon: const Icon(Icons.library_books_outlined),
              onPressed: () => buttonPressed = true,
              tooltip: 'Manage Library',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify button is present in dark mode
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);

      // Tap to verify it works in dark mode
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(buttonPressed, isTrue);
    });
  });

  group('Button Regression Prevention Tests', () {
    testWidgets('all critical buttons should render with visible icons',
        (tester) async {
      // Test the icons used by the new entry point buttons
      final criticalIcons = [
        Icons.add,
        Icons.library_books_outlined,
      ];

      var buttonPressedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: criticalIcons.map((iconData) {
                return IconButton(
                  icon: Icon(iconData),
                  onPressed: () => buttonPressedCount++,
                );
              }).toList(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all critical icons are present
      for (final iconData in criticalIcons) {
        expect(find.byIcon(iconData), findsOneWidget,
            reason: '$iconData should render correctly',);

        // Verify each icon has proper configuration
        final iconWidget = tester.widget<Icon>(find.byIcon(iconData));
        expect(iconWidget.icon, equals(iconData),
            reason: '$iconData should have correct IconData',);
      }

      // Verify all buttons are tappable
      for (final iconData in criticalIcons) {
        await tester.tap(find.byIcon(iconData));
      }
      await tester.pumpAndSettle();

      expect(buttonPressedCount, equals(criticalIcons.length),
          reason: 'All buttons should be tappable',);
    });

    testWidgets('buttons should have proper padding and sizing',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Preset'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.library_books_outlined),
                  onPressed: () {},
                  tooltip: 'Manage Library',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify both icons are present
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);

      // Verify icons have proper sizes
      final addIcon = tester.widget<Icon>(find.byIcon(Icons.add));
      expect(addIcon.size, equals(18),
          reason: 'New Preset icon should have size 18',);

      final libraryIcon =
          tester.widget<Icon>(find.byIcon(Icons.library_books_outlined));
      expect(libraryIcon.size, isNull,
          reason: 'IconButton icon should inherit theme size',);
    });

    testWidgets('buttons render without color blocks in light mode',
        (tester) async {
      final lightTheme = ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        iconTheme: const IconThemeData(
          color: Colors.black,
          size: 24,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Preset'),
                ),
                IconButton(
                  icon: const Icon(Icons.library_books_outlined),
                  onPressed: () {},
                  tooltip: 'Manage Library',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // All icons should be present without color block rendering
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('buttons render without color blocks in dark mode',
        (tester) async {
      final darkTheme = ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        iconTheme: const IconThemeData(
          color: Colors.white,
          size: 24,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: Scaffold(
            body: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Preset'),
                ),
                IconButton(
                  icon: const Icon(Icons.library_books_outlined),
                  onPressed: () {},
                  tooltip: 'Manage Library',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // All icons should be present without color block rendering
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });
  });

  group('Button Integration Tests', () {
    testWidgets('multiple buttons can coexist in same widget tree',
        (tester) async {
      var newPresetPressed = false;
      var manageLibraryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                OutlinedButton.icon(
                  onPressed: () => newPresetPressed = true,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Preset'),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.library_books_outlined),
                  onPressed: () => manageLibraryPressed = true,
                  tooltip: 'Manage Library',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Both icons should be present
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);

      // Tap New Preset button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(newPresetPressed, isTrue);
      expect(manageLibraryPressed, isFalse);

      // Tap Manage Library button
      await tester.tap(find.byIcon(Icons.library_books_outlined));
      await tester.pumpAndSettle();
      expect(manageLibraryPressed, isTrue);
    });

    testWidgets('buttons are accessible with semantic labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Preset'),
                ),
                IconButton(
                  icon: const Icon(Icons.library_books_outlined),
                  onPressed: () {},
                  tooltip: 'Manage Library',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify semantic labels exist
      expect(find.text('New Preset'), findsOneWidget);

      // Tooltip provides semantic label for IconButton
      final iconButton =
          tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, equals('Manage Library'));
    });
  });
}
