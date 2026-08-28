import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../data/services/danbooru_auth_service.dart';
import '../../../../../data/services/gelbooru_auth_service.dart';
import '../../../../providers/online_gallery_provider.dart';
import '../../../../providers/selection_mode_provider.dart';
import '../../../online_gallery/online_gallery_screen_commands.dart';
import '../../../online_gallery/online_gallery_screen_controller.dart';

class OnlineGalleryToolbarViewData {
  const OnlineGalleryToolbarViewData({
    required this.gallery,
    required this.danbooruAuth,
    required this.gelbooruAuth,
    required this.selection,
  });

  final OnlineGalleryState gallery;
  final DanbooruAuthState danbooruAuth;
  final GelbooruAuthState gelbooruAuth;
  final SelectionModeState selection;
}

class OnlineGalleryToolbarCommands {
  const OnlineGalleryToolbarCommands({
    required this.gallery,
    required this.selection,
    required this.actions,
    required this.saveScrollOffset,
  });

  final OnlineGalleryNotifier gallery;
  final OnlineGallerySelectionNotifier selection;
  final OnlineGalleryScreenCommands actions;
  final VoidCallback saveScrollOffset;
}

class OnlineGalleryToolbarBindings {
  const OnlineGalleryToolbarBindings({
    required this.context,
    required this.ref,
    required this.controller,
    required this.data,
    required this.commands,
  });

  final BuildContext context;
  final WidgetRef ref;
  final OnlineGalleryScreenController controller;
  final OnlineGalleryToolbarViewData data;
  final OnlineGalleryToolbarCommands commands;

  OnlineGalleryToolbarBindings withGallery(OnlineGalleryState gallery) =>
      OnlineGalleryToolbarBindings(
        context: context,
        ref: ref,
        controller: controller,
        data: OnlineGalleryToolbarViewData(
          gallery: gallery,
          danbooruAuth: data.danbooruAuth,
          gelbooruAuth: data.gelbooruAuth,
          selection: data.selection,
        ),
        commands: commands,
      );
}
