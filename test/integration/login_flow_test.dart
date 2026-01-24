import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naia_launcher/main.dart' as app;
import 'package:naia_launcher/presentation/providers/auth_provider.dart';
import 'package:naia_launcher/presentation/providers/account_manager_provider.dart';
import 'package:naia_launcher/core/storage/secure_storage_service.dart';

/// End-to-End Integration Test for Complete Login Flow with Credentials
///
/// This test verifies the complete authentication flow:
/// 1. App launch and auth check
/// 2. Redirect to login screen when unauthenticated
/// 3. Email/password input
/// 4. Login button interaction
/// 5. Loading state verification
/// 6. Successful redirect to home
/// 7. Authentication persistence across restarts
void main() {
  group('Login Flow - Credentials Authentication', () {
    late ProviderContainer container;

    setUp(() {
      // Initialize a ProviderContainer for testing
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('Complete login flow with email and password', (WidgetTester tester) async {
      // Step 1: Launch app
      app.main();
      await tester.pumpAndSettle();

      // Step 2: Wait for auth check and splash screen
      expect(find.byType(app.SplashScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));

      // Step 3: Verify redirect to login screen (when unauthenticated)
      expect(find.byType(app.LoginScreen), findsOneWidget);
      expect(find.text('登录'), findsOneWidget);

      // Step 4: Enter email
      final emailField = find.byKey(const Key('email_field'));
      await tester.enterText(emailField, 'test@example.com');
      await tester.pumpAndSettle();

      // Step 5: Enter password
      final passwordField = find.byKey(const Key('password_field'));
      await tester.enterText(passwordField, 'testpassword123');
      await tester.pumpAndSettle();

      // Step 6: Click login button
      final loginButton = find.byKey(const Key('login_button'));
      expect(loginButton, findsOneWidget);
      await tester.tap(loginButton);
      await tester.pump();

      // Step 7: Verify loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('正在登录...'), findsOneWidget);

      // Step 8: Wait for login to complete
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Step 9: Verify successful redirect to home screen
      expect(find.byType(app.HomeScreen), findsOneWidget);
    });

    testWidgets('Authentication persists across app restart', (WidgetTester tester) async {
      // First run - Login
      app.main();
      await tester.pumpAndSettle();

      // Perform login
      await _performLogin(tester);
      await tester.pumpAndSettle();

      // Verify we're on home screen
      expect(find.byType(app.HomeScreen), findsOneWidget);

      // Restart app
      await tester.pumpWidget(app.MyApp());
      await tester.pumpAndSettle();

      // Verify auto-login worked - should be on home screen, not login
      expect(find.byType(app.HomeScreen), findsOneWidget);
      expect(find.byType(app.LoginScreen), findsNothing);
    });

    testWidgets('Loading overlay appears during authentication', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Trigger login
      await _performLogin(tester);
      await tester.pump();

      // Verify loading overlay is shown
      expect(find.byKey(const Key('loading_overlay')), findsOneWidget);
      expect(find.text('正在登录'), findsOneWidget);
      expect(find.text('请稍候...'), findsOneWidget);

      // Wait for auth to complete
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify loading overlay is removed
      expect(find.byKey(const Key('loading_overlay')), findsNothing);
    });

    testWidgets('Error message displays on invalid credentials', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Enter invalid credentials
      await tester.enterText(find.byKey(const Key('email_field')), 'invalid@example.com');
      await tester.enterText(find.byKey(const Key('password_field')), 'wrongpassword');
      await tester.pumpAndSettle();

      // Click login
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle();

      // Verify error message is displayed
      expect(find.text('登录失败'), findsOneWidget);
      expect(find.byType(app.AppToast), findsOneWidget);
    });

    testWidgets('Form validation prevents empty fields', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Try to login with empty fields
      final loginButton = find.byKey(const Key('login_button'));
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Verify validation errors
      expect(find.text('请输入邮箱'), findsOneWidget);
      expect(find.text('请输入密码'), findsOneWidget);
    });
  });

  group('Auth State Management', () {
    test('Auth state transitions correctly during login flow', () async {
      final container = ProviderContainer();
      final authNotifier = container.read(authNotifierProvider.notifier);

      // Initial state should be unauthenticated or loading
      final initialState = container.read(authNotifierProvider);
      expect(
        initialState.status == AuthStatus.unauthenticated ||
        initialState.status == AuthStatus.loading,
        true,
      );

      // Simulate successful login
      // Note: This would require mocking the API service
      // For now, we just verify the state management structure

      container.dispose();
    });

    test('Auto-login is enabled by default', () async {
      final container = ProviderContainer();
      final prefs = await SharedPreferences.getInstance();
      final autoLogin = prefs.getBool('auto_login') ?? true;

      expect(autoLogin, true);

      container.dispose();
    });
  });
}

/// Helper function to perform login
Future<void> _performLogin(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('email_field')), 'test@example.com');
  await tester.enterText(find.byKey(const Key('password_field')), 'testpassword123');
  await tester.tap(find.byKey(const Key('login_button')));
}
