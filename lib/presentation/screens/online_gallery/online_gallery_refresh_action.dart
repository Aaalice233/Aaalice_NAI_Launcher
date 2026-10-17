import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/online_gallery/danbooru_post.dart';
import '../../providers/online_gallery_provider.dart';
import '../../providers/quick_tag_cloud_gallery_provider.dart';
import 'online_gallery_screen_controller.dart';

/// 顶栏刷新按钮与刷新快捷键共用的刷新：按搜索框里尚未提交的草稿重新请求当前浏览
class OnlineGalleryRefreshAction {
  const OnlineGalleryRefreshAction({
    required this.ref,
    required this.controller,
  });

  final WidgetRef ref;
  final OnlineGalleryScreenController controller;

  void call() {
    final state = ref.read(onlineGalleryNotifierProvider);
    final notifier = ref.read(onlineGalleryNotifierProvider.notifier);
    if (state.activeSourceId == GallerySourceId.quickTagCloud) {
      notifier.clearDetailCache();
      ref.read(quickTagCloudGallerySourceAdapterProvider).invalidateCatalog();
      ref.invalidate(quickTagCloudCatalogProvider);
      final query = ref.read(quickTagCloudFilterProvider);
      if (query.codexId != 'all') {
        ref.invalidate(quickTagCloudCodexProvider(query.codexId));
      }
    }
    final query = switch (state.viewMode) {
      GalleryViewMode.search => controller.searchController.text,
      GalleryViewMode.popular => controller.popularSearchController.text,
      GalleryViewMode.favorites => controller.favoriteSearchController.text,
    };
    final prompt = state.viewMode == GalleryViewMode.popular
        ? controller.popularPromptSearchController.text
        : controller.promptSearchController.text;
    unawaited(notifier.refreshWithDraft(query: query, prompt: prompt));
    if (state.randomEnabled && controller.scrollController.hasClients) {
      controller.scrollController.jumpTo(0);
    }
  }
}
