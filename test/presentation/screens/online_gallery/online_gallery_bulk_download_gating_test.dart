import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_state.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_selection_actions.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_action.dart';

/// 批量下载要先选一个输出目录再往里写盘，iOS 上
/// `FileExportService.pickExportDirectory` 只能返回 null。
/// 上游无条件渲染该项，在 iOS 上就是一个点了没反应的死按钮。
void main() {
  tearDown(() => PlatformCapabilities.debugOverride = null);

  testWidgets('iOS 多选栏隐藏批量下载但保留其余批量动作', (tester) async {
    final ids = await _actionIds(tester, TargetPlatform.iOS);

    expect(ids, isNot(contains(ImageCardActionId.save)));
    expect(ids, contains(ImageCardActionId.addToQueue));
    expect(ids, isNotEmpty);
  });

  testWidgets('桌面端仍提供批量下载', (tester) async {
    final ids = await _actionIds(tester, TargetPlatform.windows);

    expect(ids, contains(ImageCardActionId.save));
  });
}

Future<List<ImageCardActionId>> _actionIds(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
    platform,
  );
  const post = DanbooruPost(
    id: 1,
    site: 'danbooru',
    rating: 'g',
    width: 1200,
    height: 800,
    tagStringGeneral: 'solo',
    fileExt: 'jpg',
    previewFileUrl: 'https://cdn.donmai.us/preview/1.jpg',
  );
  const state = OnlineGalleryState(searchCache: ModeCache(posts: [post]));
  late List<ImageCardAction> actions;

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) {
            actions = OnlineGallerySelectionActions(
              context: context,
              ref: ref,
            ).buildActions(state, {post.stableKey});
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );

  return actions.map((action) => action.id).toList(growable: false);
}
