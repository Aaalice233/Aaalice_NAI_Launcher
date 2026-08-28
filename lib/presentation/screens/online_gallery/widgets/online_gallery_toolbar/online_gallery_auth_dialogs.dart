import 'package:flutter/material.dart';

import '../../../../../data/models/online_gallery/danbooru_post.dart';
import '../../../../providers/online_gallery_provider.dart';
import '../../../../widgets/danbooru_login_dialog.dart';
import '../../../../widgets/gelbooru_credentials_dialog.dart';
import 'online_gallery_toolbar_bindings.dart';

class OnlineGalleryAuthDialogs {
  const OnlineGalleryAuthDialogs(this.bindings);

  final OnlineGalleryToolbarBindings bindings;

  Future<void> showDanbooruLogin(BuildContext context) async {
    final loggedIn = await showDialog<bool>(
      context: context,
      builder: (_) => const DanbooruLoginDialog(),
    );
    if (loggedIn != true || !context.mounted) return;
    final state = bindings.ref.read(onlineGalleryNotifierProvider);
    if (state.viewMode == GalleryViewMode.favorites &&
        state.favoritesSourceId == GallerySourceId.danbooru) {
      await bindings.commands.gallery.refresh();
    }
  }

  void showGelbooruCredentials(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const GelbooruCredentialsDialog(),
    );
  }
}
