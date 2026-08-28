import 'package:flutter/material.dart';

import '../../../data/models/online_gallery/danbooru_post.dart';
import 'online_gallery_detail_launcher.dart';
import 'online_gallery_selection_actions.dart';

/// Typed command surface shared by the shell, toolbar and gallery content.
/// Feature widgets depend on this object rather than bound parent-State methods
/// or an expanding list of callback slots.
class OnlineGalleryScreenCommands {
  const OnlineGalleryScreenCommands({
    required this.detailLauncher,
    required this.selectionActions,
  });

  final OnlineGalleryDetailLauncher detailLauncher;
  final OnlineGallerySelectionActions selectionActions;

  Future<void> showDetail(BuildContext context, GalleryItem item) =>
      detailLauncher.show(context, item);

  Future<bool> toggleFavorite(BuildContext context, GalleryItem item) =>
      detailLauncher.toggleFavorite(context, item);

  Future<void> downloadSelected() => selectionActions.downloadSelected();

  Future<void> addSelectedToQueue() => selectionActions.addSelectedToQueue();

  Future<void> favoriteSelected() => selectionActions.favoriteSelected();
}
