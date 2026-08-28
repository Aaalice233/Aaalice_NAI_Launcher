import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/router/app_router.dart';

void main() {
  test(
    'router facade exports route, redirect, branch, shell, and provider API',
    () {
      expect(AppRoutes.home, '/');
      expect(AppRoutes.localGallery, '/local-gallery');
      expect(AppRouteNames.onlineGallery, 'onlineGallery');
      expect(AppBranch.values.length, 9);
      expect(MainShell, isNotNull);
      expect(appRouterProvider, isNotNull);
      expect(
        resolveAuthRedirect(
          status: AuthStatus.authenticated,
          isAuthenticated: true,
          matchedLocation: AppRoutes.login,
        ),
        AppRoutes.home,
      );
    },
  );
}
