import '../../core/shortcuts/default_shortcuts.dart';

/// Stateful shell branches in the same order as [appRouterProvider].
enum AppBranch {
  generation,
  localGallery,
  onlineGallery,
  settings,
  promptConfig,
  statistics,
  tagLibrary,
  vibeLibrary,
  preciseRefLibrary,
}

/// Global navigation shortcuts and their destination branches.
const Map<String, AppBranch> globalNavigationShortcutBranches = {
  ShortcutIds.navigateToGeneration: AppBranch.generation,
  ShortcutIds.navigateToLocalGallery: AppBranch.localGallery,
  ShortcutIds.navigateToOnlineGallery: AppBranch.onlineGallery,
  ShortcutIds.navigateToSettings: AppBranch.settings,
  ShortcutIds.navigateToRandomConfig: AppBranch.promptConfig,
  ShortcutIds.navigateToStatistics: AppBranch.statistics,
  ShortcutIds.navigateToTagLibrary: AppBranch.tagLibrary,
  ShortcutIds.navigateToVibeLibrary: AppBranch.vibeLibrary,
};

/// Mobile navigation only exposes generation, local gallery, and settings.
const List<AppBranch> mobileNavigationBranches = [
  AppBranch.generation,
  AppBranch.localGallery,
  AppBranch.settings,
];

int mobileNavigationIndexForBranch(int branchIndex) {
  if (branchIndex == AppBranch.settings.index) {
    return mobileNavigationBranches.indexOf(AppBranch.settings);
  }
  if (branchIndex == AppBranch.localGallery.index ||
      branchIndex == AppBranch.onlineGallery.index) {
    return mobileNavigationBranches.indexOf(AppBranch.localGallery);
  }
  return mobileNavigationBranches.indexOf(AppBranch.generation);
}
