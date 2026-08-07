import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/presentation/router/app_branch.dart';

void main() {
  test('global navigation shortcuts map to their actual shell branches', () {
    expect(globalNavigationShortcutBranches, {
      ShortcutIds.navigateToGeneration: AppBranch.generation,
      ShortcutIds.navigateToLocalGallery: AppBranch.localGallery,
      ShortcutIds.navigateToOnlineGallery: AppBranch.onlineGallery,
      ShortcutIds.navigateToSettings: AppBranch.settings,
      ShortcutIds.navigateToRandomConfig: AppBranch.promptConfig,
      ShortcutIds.navigateToStatistics: AppBranch.statistics,
      ShortcutIds.navigateToTagLibrary: AppBranch.tagLibrary,
      ShortcutIds.navigateToVibeLibrary: AppBranch.vibeLibrary,
    });
  });

  test('mobile navigation maps settings and gallery branches correctly', () {
    expect(
      mobileNavigationIndexForBranch(AppBranch.generation.index),
      mobileNavigationBranches.indexOf(AppBranch.generation),
    );
    expect(
      mobileNavigationIndexForBranch(AppBranch.localGallery.index),
      mobileNavigationBranches.indexOf(AppBranch.localGallery),
    );
    expect(
      mobileNavigationIndexForBranch(AppBranch.onlineGallery.index),
      mobileNavigationBranches.indexOf(AppBranch.localGallery),
    );
    expect(
      mobileNavigationIndexForBranch(AppBranch.settings.index),
      mobileNavigationBranches.indexOf(AppBranch.settings),
    );
  });
}
