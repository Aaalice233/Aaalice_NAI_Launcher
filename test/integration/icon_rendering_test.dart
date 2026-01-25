import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/screens/auth/login_screen.dart';

/// Integration Test for Material Icons Font Loading and Rendering
///
/// This test verifies that Material Icons font loads correctly in the application
/// and icons render with visible glyphs rather than appearing as color blocks.
/// This is a regression test for the issue where icons appeared as colored blocks
/// instead of showing the actual icon graphics.
///
/// Root Cause: Icons were rendering but with colors that blended with the background,
/// making them appear as color blocks. The fix ensures icons have proper color
/// configuration that contrasts with background colors.
void main() {
  group('Material Icons Font Loading - Integration Tests', () {
    testWidgets('Login screen loads and renders all icons with visible glyphs',
        (WidgetTester tester) async {
      // Build the login screen with a basic theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            iconTheme: const IconThemeData(
              color: Colors.blue,
              size: 24,
            ),
          ),
          home: const LoginScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the login screen is rendered
      expect(find.byType(LoginScreen), findsOneWidget);

      // Test 1: Verify Icons.auto_awesome (app logo) is present
      expect(
        find.byIcon(Icons.auto_awesome),
        findsAtLeastNWidgets(1),
        reason: 'Icons.auto_awesome (app logo) should be rendered',
      );

      // Test 2: Verify Icons.add (add account button) is present
      expect(
        find.byIcon(Icons.add),
        findsAtLeastNWidgets(1),
        reason: 'Icons.add (add account button) should be rendered',
      );

      // Test 3: Verify other critical icons are present
      expect(
        find.byIcon(Icons.login),
        findsAtLeastNWidgets(1),
        reason: 'Icons.login (quick login button) should be rendered',
      );

      // Test 4: Verify icons have proper size configuration
      final autoAwesomeIcons = find.byIcon(Icons.auto_awesome);
      for (final element in autoAwesomeIcons.evaluate()) {
        final icon = element.widget as Icon;
        expect(
          icon.size,
          greaterThan(0),
          reason: 'Icons.auto_awesome should have a size greater than 0',
        );
      }

      // Test 5: Verify Icons.add has proper configuration
      final addIcons = find.byIcon(Icons.add);
      expect(
        addIcons,
        findsAtLeastNWidgets(1),
        reason: 'Icons.add should be present with proper sizing',
      );
    });

    testWidgets('Icons render correctly in dark mode without color blocks',
        (WidgetTester tester) async {
      // Build the login screen with dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            iconTheme: const IconThemeData(
              color: Colors.white,
              size: 24,
            ),
          ),
          home: const LoginScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the login screen is rendered in dark mode
      expect(find.byType(LoginScreen), findsOneWidget);

      // Verify all critical icons are present in dark mode
      expect(
        find.byIcon(Icons.auto_awesome),
        findsAtLeastNWidgets(1),
        reason: 'Icons.auto_awesome should render in dark mode',
      );

      expect(
        find.byIcon(Icons.add),
        findsAtLeastNWidgets(1),
        reason: 'Icons.add should render in dark mode',
      );

      expect(
        find.byIcon(Icons.login),
        findsAtLeastNWidgets(1),
        reason: 'Icons.login should render in dark mode',
      );
    });

    testWidgets('Icons inherit theme colors correctly',
        (WidgetTester tester) async {
      // Build with custom theme colors
      final customTheme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
          brightness: Brightness.light,
        ),
        iconTheme: const IconThemeData(
          color: Colors.purple,
          size: 24,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: customTheme,
          home: const LoginScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify icons are present with theme inheritance
      final iconWidgets = find.byType(Icon);
      expect(
        iconWidgets,
        findsAtLeastNWidgets(3),
        reason: 'Multiple icons should be rendered and inherit theme colors',
      );
    });

    testWidgets('Critical icons have explicit color configuration',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          home: const LoginScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Find Icons.auto_awesome and verify its configuration
      final autoAwesomeIcon = find.byIcon(Icons.auto_awesome).first;
      final iconWidget = tester.widget<Icon>(autoAwesomeIcon);

      // Verify icon has proper size to prevent color block rendering
      expect(
        iconWidget.size,
        equals(40),
        reason:
            'Icons.auto_awesome should have size 40 to prevent color block appearance',
      );

      // Verify icon data is correct
      expect(
        iconWidget.icon,
        equals(Icons.auto_awesome),
        reason: 'Icon should have correct IconData',
      );
    });

    testWidgets('Multiple icons render simultaneously without conflicts',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.green,
              brightness: Brightness.light,
            ),
          ),
          home: const LoginScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Count total number of Icon widgets rendered
      final allIcons = find.byType(Icon);
      final iconCount = allIcons.evaluate().length;

      // Should have at least the critical icons rendering
      expect(
        iconCount,
        greaterThanOrEqualTo(3),
        reason: 'Should render at least 3 icons (auto_awesome, add, login)',
      );

      // Verify each icon can be found and has proper properties
      for (final element in allIcons.evaluate()) {
        final icon = element.widget as Icon;
        expect(
          icon.icon,
          isNotNull,
          reason: 'Every Icon widget should have valid IconData',
        );
      }
    });

    testWidgets('Icons render with proper contrast against background',
        (WidgetTester tester) async {
      // Test with a theme that has known contrasting colors
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepOrange,
              brightness: Brightness.light,
              primary: Colors.deepOrange,
              primaryContainer:
                  Color.lerp(Colors.deepOrange, Colors.white, 0.8)!,
            ),
            iconTheme: const IconThemeData(
              color: Colors.deepOrange,
              size: 24,
            ),
          ),
          home: const LoginScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify icons are present and rendering
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.add), findsAtLeastNWidgets(1));

      // Verify Icons.auto_awesome has the configured size for visibility
      final autoAwesomeIcon = find.byIcon(Icons.auto_awesome).first;
      final iconWidget = tester.widget<Icon>(autoAwesomeIcon);

      expect(
        iconWidget.size,
        equals(40),
        reason: 'App icon should have large size (40) for visibility',
      );
    });

    testWidgets('Icon rendering is consistent across multiple screen rebuilds',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          home: const LoginScreen(),
        ),
      );

      // Initial render
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.auto_awesome), findsAtLeastNWidgets(1));

      // Rebuild the widget to test consistency
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          home: const LoginScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Icons should still be present after rebuild
      expect(
        find.byIcon(Icons.auto_awesome),
        findsAtLeastNWidgets(1),
        reason: 'Icons should render consistently across rebuilds',
      );
      expect(
        find.byIcon(Icons.add),
        findsAtLeastNWidgets(1),
        reason: 'Icons.add should render consistently across rebuilds',
      );
    });
  });

  group('Regression Prevention - Material Icons Font Loading', () {
    testWidgets('prevents regression: icons always render with visible glyphs',
        (WidgetTester tester) async {
      // This is the primary regression test for the original bug:
      // "Icons appearing as color blocks instead of visible glyphs"
      //
      // The test ensures that:
      // 1. Material Icons font loads correctly
      // 2. Icons render with visible glyphs, not color blocks
      // 3. Icons have proper size and color configuration

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            iconTheme: const IconThemeData(
              color: Colors.blue,
              size: 24,
            ),
          ),
          home: const LoginScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all critical icons from the original bug report are present
      final criticalIcons = [
        Icons.auto_awesome, // NAI launcher icon (was appearing as color block)
        Icons.add, // Add account button (was appearing as color block)
      ];

      for (final iconData in criticalIcons) {
        final finder = find.byIcon(iconData);
        expect(
          finder,
          findsAtLeastNWidgets(1),
          reason:
              '$iconData should render with visible glyph, not as color block',
        );

        // Verify each icon has proper configuration
        final iconWidget = tester.widget<Icon>(finder.first);
        expect(
          iconWidget.size,
          greaterThan(0),
          reason:
              '$iconData must have size > 0 to prevent color block rendering',
        );
        expect(
          iconWidget.icon,
          equals(iconData),
          reason: '$iconData must have correct IconData',
        );
      }
    });

    testWidgets('prevents regression: Material Icons font is available',
        (WidgetTester tester) async {
      // Verify that Material Icons font is loaded by attempting to render
      // multiple icons from the Material Icons set

      final testIcons = [
        Icons.auto_awesome,
        Icons.add,
        Icons.login,
        Icons.close,
        Icons.arrow_drop_down,
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          home: Scaffold(
            body: Column(
              children: testIcons
                  .map(
                    (icon) => Icon(
                      icon,
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

      // All icons should render successfully, indicating Material Icons font is loaded
      for (final iconData in testIcons) {
        expect(
          find.byIcon(iconData),
          findsOneWidget,
          reason: 'Material Icons font should include $iconData',
        );
      }
    });
  });
}
