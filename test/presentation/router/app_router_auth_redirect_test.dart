import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/router/app_routes.dart';

void main() {
  group('resolveAuthRedirect', () {
    test('keeps the main screen available while signed out', () {
      expect(
        resolveAuthRedirect(
          status: AuthStatus.unauthenticated,
          isAuthenticated: false,
          matchedLocation: AppRoutes.home,
        ),
        isNull,
      );
    });

    test('keeps local gallery available while signed out', () {
      expect(
        resolveAuthRedirect(
          status: AuthStatus.unauthenticated,
          isAuthenticated: false,
          matchedLocation: AppRoutes.localGallery,
        ),
        isNull,
      );
    });

    test('keeps the login page available while signed out', () {
      expect(
        resolveAuthRedirect(
          status: AuthStatus.unauthenticated,
          isAuthenticated: false,
          matchedLocation: AppRoutes.login,
        ),
        isNull,
      );
    });

    test('returns to the main screen after login', () {
      expect(
        resolveAuthRedirect(
          status: AuthStatus.authenticated,
          isAuthenticated: true,
          matchedLocation: AppRoutes.login,
        ),
        AppRoutes.home,
      );
    });
  });
}
