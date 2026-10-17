import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../data/models/online_gallery/danbooru_post.dart';
import '../../providers/online_gallery_output_filter_provider.dart';
import '../../providers/online_gallery_prompt_tag_settings_provider.dart';
import '../../providers/online_gallery_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../selection/card_selection_scope.dart';
import '../../services/gallery_prompt_projection_service.dart';
import '../../widgets/shortcuts/shortcut_aware_widget.dart';

/// 在线画廊的按键层：画廊列表快捷键与卡片多选，覆盖顶栏、网格与分页条
class OnlineGalleryShortcuts extends ConsumerWidget {
  const OnlineGalleryShortcuts({
    super.key,
    required this.posts,
    required this.shortcuts,
    required this.child,
  });

  final List<GalleryItem> posts;

  /// 页面快捷键动作映射，按用户配置分派
  final Map<String, VoidCallback> shortcuts;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CardSelectionScope(
      selection: ref.watch(onlineGallerySelectionNotifierProvider),
      commands: ref.read(onlineGallerySelectionNotifierProvider.notifier),
      orderedIds: const GalleryPromptProjectionService().selectableStableKeys(
        items: posts,
        promptTagSettings: ref.watch(onlineGalleryPromptTagSettingsProvider),
        outputFilter: ref.watch(onlineGalleryOutputFilterProvider),
        detailForItem: ref
            .read(onlineGalleryNotifierProvider.notifier)
            .peekDetail,
      ),
      child: CardSelectionPageShortcuts(
        contextType: ShortcutContext.gallery,
        shortcuts: shortcuts,
        child: child,
      ),
    );
  }
}
