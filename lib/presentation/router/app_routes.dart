import '../providers/auth_provider.dart';

/// 应用路由路径。
abstract final class AppRoutes {
  static const String login = '/login';
  static const String home = '/';
  static const String generation = '/generation';
  static const String localGallery = '/local-gallery';
  static const String onlineGallery = '/online-gallery';
  static const String settings = '/settings';
  static const String cloudSyncSettings = '/settings?section=cloud-sync';
  static const String promptConfig = '/prompt-config';
  static const String slideshow = '/slideshow';
  static const String comparison = '/comparison';
  static const String statistics = '/statistics';
  static const String tagLibraryPage = '/tag-library';
  static const String vibeLibrary = '/vibe-library';
  static const String preciseRefLibrary = '/precise-ref-library';
}

/// 应用路由名称。
abstract final class AppRouteNames {
  static const String login = 'login';
  static const String home = 'home';
  static const String generation = 'generation';
  static const String localGallery = 'localGallery';
  static const String onlineGallery = 'onlineGallery';
  static const String settings = 'settings';
  static const String promptConfig = 'promptConfig';
  static const String slideshow = 'slideshow';
  static const String comparison = 'comparison';
  static const String statistics = 'statistics';
  static const String tagLibraryPage = 'tagLibraryPage';
  static const String vibeLibrary = 'vibeLibrary';
  static const String preciseRefLibrary = 'preciseRefLibrary';
}

String? resolveAuthRedirect({
  required AuthStatus status,
  required bool isAuthenticated,
  required String matchedLocation,
}) {
  final isLoading =
      status == AuthStatus.loading || status == AuthStatus.initial;
  if (isLoading) return null;

  final isLoggingIn = matchedLocation == AppRoutes.login;
  if (isAuthenticated && isLoggingIn) {
    return AppRoutes.home;
  }

  return null;
}
