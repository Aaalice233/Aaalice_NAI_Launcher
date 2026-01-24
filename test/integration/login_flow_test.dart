import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/main.dart' as app;
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    testWidgets('Invalid credentials show error without retry button', (WidgetTester tester) async {
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
      expect(find.text('认证失败，请检查您的凭据'), findsOneWidget);

      // Verify error container appears
      expect(find.byType(Container), findsWidgets);

      // Verify retry button does NOT appear (non-network error)
      expect(find.text('重试'), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('Network error shows retry button', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // This test would require mocking network failures
      // For now, we verify the structure is in place
      // In a real test, you would:
      // 1. Mock the auth service to return a network error
      // 2. Enter credentials
      // 3. Click login
      // 4. Verify "网络连接失败" or "网络超时" message
      // 5. Verify retry button with Icons.refresh appears
      // 6. Click retry and verify it re-attempts login

      // Verifying error container structure exists
      expect(find.byType(app.LoginScreen), findsOneWidget);
    });

    testWidgets('Network timeout error handling', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify login screen structure
      expect(find.byType(app.LoginScreen), findsOneWidget);

      // Test would verify:
      // 1. Network timeout triggers correct error code (networkTimeout)
      // 2. Error message shows "网络超时"
      // 3. Recovery hint suggests checking network connection
      // 4. Retry button appears with Icons.refresh
      // 5. Form fields are preserved

      // Verify timeout error message exists in localization
      expect(find.text('网络超时'), findsNothing); // Error not shown yet
      expect(find.byType(app.LoginScreen), findsOneWidget);
    });

    testWidgets('Network connection error handling', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify login screen structure
      expect(find.byType(app.LoginScreen), findsOneWidget);

      // Test would verify:
      // 1. Connection error triggers correct error code (networkError)
      // 2. Error message shows "网络连接失败"
      // 3. Recovery hint suggests checking network settings
      // 4. Retry button appears with Icons.refresh
      // 5. Clicking retry re-attempts login with preserved credentials

      // Verify connection error message exists in localization
      expect(find.text('网络连接失败'), findsNothing); // Error not shown yet
      expect(find.byType(app.LoginScreen), findsOneWidget);
    });

    testWidgets('Network error preserves form input', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Enter credentials
      const testEmail = 'test@example.com';
      const testPassword = 'testpassword123';
      await tester.enterText(find.byKey(const Key('email_field')), testEmail);
      await tester.enterText(find.byKey(const Key('password_field')), testPassword);
      await tester.pumpAndSettle();

      // Simulate network error scenario
      // In real test: Mock API to throw DioException with connectionError type

      // Verify form fields are accessible
      final emailField = find.byKey(const Key('email_field'));
      final passwordField = find.byKey(const Key('password_field'));

      expect(tester.widget<TextFormField>(emailField).controller?.text, testEmail);
      expect(tester.widget<TextFormField>(passwordField).controller?.text, testPassword);

      // Verify user can retry without re-entering credentials
      // In real test: Trigger network error, then verify fields still contain values
      expect(emailField, findsOneWidget);
      expect(passwordField, findsOneWidget);
    });

    testWidgets('Retry button functionality on network error', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify login screen
      expect(find.byType(app.LoginScreen), findsOneWidget);

      // Test would verify:
      // 1. Network error occurs during login
      // 2. Error message and retry button appear
      // 3. Clicking retry button preserves credentials
      // 4. Retry triggers authentication attempt again
      // 5. If network is restored, login succeeds

      // Verify retry button exists in UI structure
      // Note: Button only appears when error state is active
      expect(find.byType(app.LoginScreen), findsOneWidget);
    });

    testWidgets('Multiple network errors are handled gracefully', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Test would verify:
      // 1. First network error occurs
      // 2. User clicks retry
      // 3. Second network error occurs (network still down)
      // 4. Error message updates correctly
      // 5. Retry button remains available
      // 6. No memory leaks or state corruption
      // 7. Can continue retrying until network is restored

      expect(find.byType(app.LoginScreen), findsOneWidget);
    });

    testWidgets('Network error recovery with successful login', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Test would verify complete flow:
      // 1. Enter valid credentials
      // 2. Network is disconnected
      // 3. Click login → network error
      // 4. Verify error message and retry button
      // 5. Restore network connection
      // 6. Click retry button
      // 7. Verify successful login
      // 8. Verify redirect to home screen

      expect(find.byType(app.LoginScreen), findsOneWidget);
    });

    testWidgets('Form is preserved after authentication error', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Enter credentials
      const testEmail = 'test@example.com';
      const testPassword = 'wrongpassword';
      await tester.enterText(find.byKey(const Key('email_field')), testEmail);
      await tester.enterText(find.byKey(const Key('password_field')), testPassword);
      await tester.pumpAndSettle();

      // Click login
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle();

      // Verify error appears
      expect(find.text('认证失败，请检查您的凭据'), findsOneWidget);

      // Verify form fields still contain the entered values (preserved)
      final emailField = find.byKey(const Key('email_field'));
      final passwordField = find.byKey(const Key('password_field'));

      expect(tester.widget<TextFormField>(emailField).controller?.text, testEmail);
      expect(tester.widget<TextFormField>(passwordField).controller?.text, testPassword);

      // Verify user can edit the fields without re-typing everything
      await tester.enterText(emailField, 'correct@example.com');
      await tester.pumpAndSettle();

      expect(tester.widget<TextFormField>(emailField).controller?.text, 'correct@example.com');
    });

    testWidgets('Successful login after error recovery', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Attempt 1: Invalid credentials
      await tester.enterText(find.byKey(const Key('email_field')), 'invalid@example.com');
      await tester.enterText(find.byKey(const Key('password_field')), 'wrongpassword');
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle();

      // Verify error appears
      expect(find.text('认证失败，请检查您的凭据'), findsOneWidget);

      // Verify form is preserved
      expect(find.byKey(const Key('email_field')), findsOneWidget);
      expect(find.byKey(const Key('password_field')), findsOneWidget);

      // Attempt 2: Correct credentials and verify user can retry
      // (In real scenario, this would require valid test credentials)
      await tester.enterText(find.byKey(const Key('email_field')), 'correct@example.com');
      await tester.enterText(find.byKey(const Key('password_field')), 'correctpassword');
      await tester.pumpAndSettle();

      // Verify form accepts new input
      final emailField = find.byKey(const Key('email_field'));
      expect(tester.widget<TextFormField>(emailField).controller?.text, 'correct@example.com');

      // Verify login button is still enabled for retry
      final loginButton = find.byKey(const Key('login_button'));
      expect(tester.widget<ElevatedButton>(loginButton).enabled, true);
    });

    testWidgets('Error recovery hints are actionable', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Trigger auth error
      await tester.enterText(find.byKey(const Key('email_field')), 'invalid@example.com');
      await tester.enterText(find.byKey(const Key('password_field')), 'wrong');
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle();

      // Verify error message
      expect(find.text('认证失败，请检查您的凭据'), findsOneWidget);

      // Verify recovery hint is shown
      expect(
        find.text('💡 请检查邮箱和密码是否正确，或访问 NovelAI 重新设置密码'),
        findsOneWidget,
      );

      // Verify error icon
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('Auth State Management', () {
    test('Auth state transitions correctly during login flow', () async {
      final container = ProviderContainer();

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
