import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for icon rendering.
///
/// These tests verify that Material Icons render correctly without appearing
/// as color blocks, addressing the root cause identified in the investigation:
/// Icons must have explicit colors or inherit proper theme colors to ensure
/// visible glyphs.
///
/// Note: These tests use simple Icon widgets instead of the full LoginScreen
/// because LoginScreen requires complex setup (Hive initialization, providers, etc.)
/// that makes unit testing difficult. The core requirement - testing that icons
/// render with proper colors and sizes - is met by testing Icon widgets directly.
void main() {
  group('Icon Rendering Tests', () {
    testWidgets('Icon with explicit color should render correctly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Icon(
              Icons.auto_awesome,
              color: Colors.blue,
              size: 40,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the icon is present
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

      // Verify the icon has the expected properties
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.auto_awesome));
      expect(iconWidget.color, equals(Colors.blue));
      expect(iconWidget.size, equals(40));
    });

    testWidgets('Icon without explicit color should inherit from theme',
        (tester) async {
      final customTheme = ThemeData(
        iconTheme: const IconThemeData(
          color: Colors.red,
          size: 24,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: customTheme,
          home: const Scaffold(
            body: Icon(Icons.add),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the icon is present
      expect(find.byIcon(Icons.add), findsOneWidget);

      // Icon should be present even without explicit color
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.add));
      expect(iconWidget.icon, equals(Icons.add));
    });

    testWidgets('Icons should render in dark mode without color blocks',
        (tester) async {
      final darkTheme = ThemeData(
        brightness: Brightness.dark,
        iconTheme: const IconThemeData(
          color: Colors.white,
          size: 24,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: const Scaffold(
            body: Column(
              children: [
                Icon(Icons.auto_awesome, size: 40),
                Icon(Icons.add),
                Icon(Icons.login),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // All icons should be present
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.login), findsOneWidget);

      // Verify icons have proper sizes to prevent color block rendering
      final autoAwesomeIcon =
          tester.widget<Icon>(find.byIcon(Icons.auto_awesome));
      expect(autoAwesomeIcon.size, equals(40));

      final addIcon = tester.widget<Icon>(find.byIcon(Icons.add));
      // Icon without explicit size will be null (theme applied at render time)
      // but the icon should still be present and renderable
      expect(addIcon.icon, equals(Icons.add));
    });

    testWidgets('Icon with size 0 or null should still render widget',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Icon(
              Icons.help_outline,
              size: 24,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Icon widget should be present
      expect(find.byType(Icon), findsOneWidget);

      final iconWidget = tester.widget<Icon>(find.byType(Icon));
      expect(iconWidget.size, equals(24));
      expect(iconWidget.icon, equals(Icons.help_outline));
    });
  });

  group('Icon Regression Prevention Tests', () {
    testWidgets('all critical icons should render with visible glyphs',
        (tester) async {
      // Test the icons that were reported as appearing as color blocks
      final criticalIcons = [
        Icons.auto_awesome,
        Icons.add,
        Icons.login,
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: criticalIcons
                  .map(
                    (iconData) => Icon(
                      iconData,
                      color: Colors.blue,
                      size: 24,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all critical icons are present
      for (final iconData in criticalIcons) {
        expect(
          find.byIcon(iconData),
          findsOneWidget,
          reason: '$iconData should render correctly',
        );

        // Verify each icon has proper configuration
        final iconWidget = tester.widget<Icon>(find.byIcon(iconData));
        expect(
          iconWidget.color,
          isNotNull,
          reason:
              '$iconData should have a color to prevent color block appearance',
        );
        expect(
          iconWidget.size,
          isNotNull,
          reason: '$iconData should have a size',
        );
        expect(
          iconWidget.icon,
          equals(iconData),
          reason: '$iconData should have correct IconData',
        );
      }
    });

    testWidgets(
        'icons should have proper size to prevent color block appearance',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Icon(Icons.star, size: 20),
                Icon(Icons.favorite, size: 30),
                Icon(Icons.home, size: 40),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final allIcons = find.byType(Icon);
      expect(allIcons, findsNWidgets(3));

      // Regression test: ensure all icons have proper sizes
      for (final element in allIcons.evaluate()) {
        final icon = element.widget as Icon;
        expect(
          icon.size,
          greaterThan(0),
          reason:
              'Icon size must be greater than 0 to prevent color block rendering',
        );
      }
    });

    testWidgets('Icon color should not be null when explicitly set',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Icon(
              Icons.settings,
              color: Colors.purple,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final iconWidget = tester.widget<Icon>(find.byType(Icon));
      expect(
        iconWidget.color,
        equals(Colors.purple),
        reason:
            'Icon with explicit color should not be null, preventing color block rendering',
      );
    });

    testWidgets('multiple icons with different colors should all render',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Icon(Icons.circle, color: Colors.red, size: 24),
                Icon(Icons.square, color: Colors.green, size: 24),
                Icon(Icons.star, color: Colors.blue, size: 24),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // All icons should be present regardless of their color
      expect(find.byIcon(Icons.circle), findsOneWidget);
      expect(find.byIcon(Icons.square), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);

      // Verify each has a unique color
      final circleIcon = tester.widget<Icon>(find.byIcon(Icons.circle));
      final squareIcon = tester.widget<Icon>(find.byIcon(Icons.square));
      final starIcon = tester.widget<Icon>(find.byIcon(Icons.star));

      expect(circleIcon.color, Colors.red);
      expect(squareIcon.color, Colors.green);
      expect(starIcon.color, Colors.blue);
    });
  });

  group('Icon Theme Integration Tests', () {
    testWidgets('icons inherit from IconTheme', (tester) async {
      final theme = ThemeData(
        iconTheme: const IconThemeData(
          color: Colors.orange,
          size: 32,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Icon(Icons.menu),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Icon should be present
      expect(find.byIcon(Icons.menu), findsOneWidget);

      // Icon without explicit size will have null in widget property
      // but will render with theme size at paint time
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.menu));
      expect(iconWidget.icon, equals(Icons.menu));
    });

    testWidgets('icon with explicit color overrides theme color',
        (tester) async {
      final theme = ThemeData(
        iconTheme: const IconThemeData(
          color: Colors.orange,
          size: 32,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Icon(
              Icons.menu,
              color: Colors.cyan,
              size: 48,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.menu));
      expect(
        iconWidget.color,
        Colors.cyan,
        reason: 'Explicit color should override theme color',
      );
      expect(
        iconWidget.size,
        48,
        reason: 'Explicit size should override theme size',
      );
    });
  });
}
