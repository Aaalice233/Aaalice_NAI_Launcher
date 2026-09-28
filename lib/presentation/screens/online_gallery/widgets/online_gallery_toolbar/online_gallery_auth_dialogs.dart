import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/online_gallery/danbooru_post.dart';
import '../../../../adaptive/adaptive_presenter.dart';
import '../../../../providers/online_gallery_provider.dart';
import '../../../../widgets/danbooru_login_dialog.dart';
import '../../../../widgets/gelbooru_credentials_dialog.dart';
import 'online_gallery_toolbar_bindings.dart';

class OnlineGalleryAuthDialogs {
  const OnlineGalleryAuthDialogs(this.bindings);

  final OnlineGalleryToolbarBindings bindings;

  Future<void> showDanbooruLogin(BuildContext context) async {
    final loggedIn = await AdaptivePresenter.showPanel<bool>(
      context: context,
      title: context.l10n.danbooru_loginTitle,
      initialChildSize: 0.82,
      minChildSize: 0.58,
      maxChildSize: 0.96,
      dialogWidth: 440,
      builder: (_, scrollController) => DanbooruLoginDialog(
        embedded: true,
        scrollController: scrollController,
      ),
    );
    if (loggedIn != true || !context.mounted) return;
    final state = bindings.ref.read(onlineGalleryNotifierProvider);
    if (state.viewMode == GalleryViewMode.favorites &&
        state.favoritesSourceId == GallerySourceId.danbooru) {
      await bindings.commands.gallery.refresh();
    }
  }

  Future<void> showGelbooruCredentials(BuildContext context) {
    return AdaptivePresenter.showPanel<void>(
      context: context,
      title: context.l10n.gelbooru_configureTitle,
      initialChildSize: 0.86,
      minChildSize: 0.58,
      maxChildSize: 0.96,
      dialogWidth: 480,
      builder: (_, scrollController) => GelbooruCredentialsDialog(
        embedded: true,
        scrollController: scrollController,
      ),
    );
  }
}
