import '../../core/shortcuts/default_shortcuts.dart';

/// Stateful shell branches in route-tree order.
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

/// Compact navigation keeps the four highest-frequency destinations visible.
/// Every other branch is represented by the labelled “more” destination.
const List<AppBranch> mobileNavigationBranches = [
  AppBranch.generation,
  AppBranch.localGallery,
  AppBranch.onlineGallery,
  AppBranch.tagLibrary,
];

const int mobileMoreNavigationIndex = 4;

int mobileNavigationIndexForBranch(int branchIndex) {
  final index = mobileNavigationBranches.indexWhere(
    (branch) => branch.index == branchIndex,
  );
  return index < 0 ? mobileMoreNavigationIndex : index;
}
