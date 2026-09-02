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

  test('every visited shell branch remains mounted', () {
    expect(keptAliveAppBranches, AppBranch.values.toSet());
  });

  test(
    'compact navigation keeps core branches visible and routes the rest to more',
    () {
      expect(mobileNavigationBranches, [
        AppBranch.generation,
        AppBranch.localGallery,
        AppBranch.onlineGallery,
        AppBranch.tagLibrary,
      ]);

      for (final branch in mobileNavigationBranches) {
        expect(
          mobileNavigationIndexForBranch(branch.index),
          mobileNavigationBranches.indexOf(branch),
        );
      }

      expect(
        mobileNavigationIndexForBranch(AppBranch.settings.index),
        mobileMoreNavigationIndex,
      );
      expect(
        mobileNavigationIndexForBranch(AppBranch.vibeLibrary.index),
        mobileMoreNavigationIndex,
      );
    },
  );
}
