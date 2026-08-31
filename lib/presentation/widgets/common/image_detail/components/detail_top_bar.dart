import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/storage/local_storage_service.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../../core/watermark/watermark_derivative_registry.dart';
import '../../../../../data/models/gallery/local_image_record.dart';
import '../../../../providers/local_gallery_provider.dart';
import '../../../../providers/watermark_settings_provider.dart';
import '../../animated_favorite_button.dart';
import '../image_detail_data.dart';

/// 顶部控制栏
///
/// 显示关闭按钮、图片索引信息和操作按钮
class DetailTopBar extends StatelessWidget {
  final int currentIndex;
  final int totalImages;
  final ImageDetailData currentImage;
  final VoidCallback onClose;
  final VoidCallback? onShowMetadata;
  final VoidCallback? onReuseMetadata;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onSave;
  final VoidCallback? onCopyImage;
  final VoidCallback? onShare;
  final VoidCallback? onWatermark;
  final VoidCallback? onSendToImg2Img;
  final VoidCallback? onSendToReversePrompt;

  const DetailTopBar({
    super.key,
    required this.currentIndex,
    required this.totalImages,
    required this.currentImage,
    required this.onClose,
    this.onShowMetadata,
    this.onReuseMetadata,
    this.onFavoriteToggle,
    this.onSave,
    this.onCopyImage,
    this.onShare,
    this.onWatermark,
    this.onSendToImg2Img,
    this.onSendToReversePrompt,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metadata = currentImage.metadata;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          // 关闭按钮
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
            tooltip: l10n.common_close,
          ),

          const SizedBox(width: 16),

          // 图片信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${currentIndex + 1} / $totalImages',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (metadata?.model != null)
                  Text(
                    metadata!.model!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          _DetailTopBarActions(
            currentImage: currentImage,
            hasMetadata: metadata != null,
            onShowMetadata: onShowMetadata,
            onReuseMetadata: onReuseMetadata,
            onFavoriteToggle: onFavoriteToggle,
            onSave: onSave,
            onCopyImage: onCopyImage,
            onShare: onShare,
            onWatermark: onWatermark,
            onSendToImg2Img: onSendToImg2Img,
            onSendToReversePrompt: onSendToReversePrompt,
          ),
        ],
      ),
    );
  }
}

enum _DetailOverflowAction {
  reuse,
  imageToImage,
  reversePrompt,
  copy,
  watermark,
}

class _DetailTopBarActions extends ConsumerWidget {
  const _DetailTopBarActions({
    required this.currentImage,
    required this.hasMetadata,
    this.onShowMetadata,
    this.onReuseMetadata,
    this.onFavoriteToggle,
    this.onSave,
    this.onCopyImage,
    this.onShare,
    this.onWatermark,
    this.onSendToImg2Img,
    this.onSendToReversePrompt,
  });

  final ImageDetailData currentImage;
  final bool hasMetadata;
  final VoidCallback? onShowMetadata;
  final VoidCallback? onReuseMetadata;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onSave;
  final VoidCallback? onCopyImage;
  final VoidCallback? onShare;
  final VoidCallback? onWatermark;
  final VoidCallback? onSendToImg2Img;
  final VoidCallback? onSendToReversePrompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final watermarkEnabled = ref.watch(
      watermarkSettingsProvider.select((state) => state.configuration.enabled),
    );
    final isWatermarkDerivative =
        currentImage is LocalImageDetailData &&
        WatermarkDerivativeRegistry(
          ref.read(localStorageServiceProvider),
        ).isDerivative(currentImage.identifier);
    final watermarkLabel = isWatermarkDerivative
        ? l10n.watermark_actionRegenerate
        : l10n.watermark_actionCreate;
    final favorite = currentImage.showFavoriteButton && onFavoriteToggle != null
        ? _buildFavorite(ref)
        : null;

    if (compact) {
      final overflowActions = <PopupMenuEntry<_DetailOverflowAction>>[
        if (hasMetadata && onReuseMetadata != null)
          PopupMenuItem(
            value: _DetailOverflowAction.reuse,
            child: ListTile(
              leading: const Icon(Icons.input),
              title: Text(l10n.shortcut_action_reuse_params),
            ),
          ),
        if (onSendToImg2Img != null)
          PopupMenuItem(
            value: _DetailOverflowAction.imageToImage,
            child: ListTile(
              leading: const Icon(Icons.image_search),
              title: Text(l10n.detail_sendToImg2Img),
            ),
          ),
        if (onSendToReversePrompt != null)
          PopupMenuItem(
            value: _DetailOverflowAction.reversePrompt,
            child: ListTile(
              leading: const Icon(Icons.auto_fix_high),
              title: Text(l10n.detail_sendToReversePrompt),
            ),
          ),
        if (onCopyImage != null)
          PopupMenuItem(
            value: _DetailOverflowAction.copy,
            child: ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.shortcut_action_copy_image),
            ),
          ),
        if (watermarkEnabled && onWatermark != null)
          PopupMenuItem(
            value: _DetailOverflowAction.watermark,
            child: ListTile(
              leading: const Icon(Icons.branding_watermark_outlined),
              title: Text(watermarkLabel),
            ),
          ),
      ];
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentImage.showSaveButton && onSave != null)
            IconButton(
              icon: const Icon(Icons.save_alt, color: Colors.white),
              onPressed: onSave,
              tooltip: l10n.common_save,
            ),
          if (onShare != null)
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              onPressed: onShare,
              tooltip: l10n.common_share,
            ),
          if (favorite != null) favorite,
          if (onShowMetadata != null)
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed: onShowMetadata,
              tooltip: l10n.detail_imageDetails,
            ),
          if (overflowActions.isNotEmpty)
            PopupMenuButton<_DetailOverflowAction>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              tooltip: l10n.nav_more,
              itemBuilder: (_) => overflowActions,
              onSelected: (action) {
                switch (action) {
                  case _DetailOverflowAction.reuse:
                    onReuseMetadata?.call();
                    break;
                  case _DetailOverflowAction.imageToImage:
                    onSendToImg2Img?.call();
                    break;
                  case _DetailOverflowAction.reversePrompt:
                    onSendToReversePrompt?.call();
                    break;
                  case _DetailOverflowAction.copy:
                    onCopyImage?.call();
                    break;
                  case _DetailOverflowAction.watermark:
                    onWatermark?.call();
                    break;
                }
              },
            ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (currentImage.showSaveButton && onSave != null)
          IconButton(
            icon: const Icon(Icons.save_alt, color: Colors.white),
            onPressed: onSave,
            tooltip: l10n.common_save,
          ),
        if (onShare != null)
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: onShare,
            tooltip: l10n.common_share,
          ),
        if (watermarkEnabled && onWatermark != null)
          IconButton(
            icon: const Icon(
              Icons.branding_watermark_outlined,
              color: Colors.white,
            ),
            onPressed: onWatermark,
            tooltip: watermarkLabel,
          ),
        if (hasMetadata && onReuseMetadata != null)
          IconButton(
            icon: const Icon(Icons.input, color: Colors.white),
            onPressed: onReuseMetadata,
            tooltip: l10n.shortcut_action_reuse_params,
          ),
        if (onSendToImg2Img != null)
          IconButton(
            icon: const Icon(Icons.image_search, color: Colors.white),
            onPressed: onSendToImg2Img,
            tooltip: l10n.detail_sendToImg2Img,
          ),
        if (onSendToReversePrompt != null)
          IconButton(
            icon: const Icon(Icons.auto_fix_high, color: Colors.white),
            onPressed: onSendToReversePrompt,
            tooltip: l10n.detail_sendToReversePrompt,
          ),
        if (onCopyImage != null)
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white),
            onPressed: onCopyImage,
            tooltip: l10n.shortcut_action_copy_image,
          ),
        if (favorite != null) favorite,
      ],
    );
  }

  Widget _buildFavorite(WidgetRef ref) {
    var isFavorite = currentImage.isFavorite;
    if (currentImage.identifier.isNotEmpty &&
        currentImage is LocalImageDetailData) {
      final galleryState = ref.watch(localGalleryNotifierProvider);
      final record = galleryState.currentImages
          .cast<LocalImageRecord?>()
          .firstWhere(
            (image) => image?.path == currentImage.identifier,
            orElse: () => null,
          );
      isFavorite = record?.isFavorite ?? isFavorite;
    }

    return SizedBox.square(
      dimension: 48,
      child: Center(
        child: AnimatedFavoriteButton(
          isFavorite: isFavorite,
          size: 24,
          inactiveColor: Colors.white,
          showBackground: true,
          backgroundColor: Colors.black.withValues(alpha: 0.4),
          onToggle: onFavoriteToggle,
        ),
      ),
    );
  }
}
