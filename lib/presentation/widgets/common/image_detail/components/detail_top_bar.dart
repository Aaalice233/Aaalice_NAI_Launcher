import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/mosaic/mosaic_derivative_registry.dart';
import '../../../../../core/storage/local_storage_service.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../../core/watermark/watermark_derivative_registry.dart';
import '../../../../../data/models/gallery/local_image_record.dart';
import '../../../../../data/models/gallery/nai_image_metadata.dart';
import '../../../../providers/local_gallery_provider.dart';
import '../../../../providers/mosaic_settings_provider.dart';
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

  /// 复制「去除元数据」的副本。
  ///
  /// 【偏离上游】上游只有 [onCopyImage] 一个复制动作，是否去元数据取决于
  /// `shareImageSettingsProvider.effectiveStripMetadataForCopyAndDrag`
  /// （= `assetProtectionMode && stripMetadataForCopyAndDrag`），
  /// 而 `assetProtectionMode` 默认 false ——**上游默认的复制是带元数据的**。
  /// 用户点名要的是「复制永远不带元数据」，所以这里加一个绕过全局开关的
  /// 常驻动作，把上游那个跟随设置的复制降级成次要入口。
  final VoidCallback? onCopyImageClean;

  /// 显式保存到系统相册（iOS）。
  ///
  /// 【偏离上游】上游 Android 侧是「出图/保存即无条件发布到系统相册」
  /// （`publishToSystemGallery` 等约 10 个调用点，由
  /// `PlatformCapabilities.supportsSystemGalleryExport` 统一放行，无设置项可关）。
  /// 我们的产品决定是保存只写应用自管的本地图库，进系统相册必须由用户主动点，
  /// 因此这条入口只由 `IosPhotoLibraryService.isSupported` 门控，
  /// 与 `supportsSystemGalleryExport` 完全解耦。
  final VoidCallback? onSaveToAlbum;
  final VoidCallback? onShare;
  final VoidCallback? onWatermark;
  final VoidCallback? onMosaic;
  final VoidCallback? onSendToImg2Img;
  final VoidCallback? onSendToReversePrompt;

  /// 兜底解析出来的元数据，优先于 [ImageDetailData.metadata] 这个数据库快照。
  ///
  /// 【偏离上游】上游这里直接读 `currentImage.metadata`。那是本地图库数据库里的
  /// 快照，iOS 覆盖安装后应用容器 UUID 变化、快照里的绝对路径全部失效，
  /// 快照读回 null，「复用参数」按钮会**直接从顶栏消失**。
  /// 上游只修了点击之后的行为（改走文件级 `resolveLocalGalleryMetadata`），
  /// 没修按钮显隐——这是 iOS 特有问题，上游不会修。
  final NaiImageMetadata? metadataOverride;

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
    this.onCopyImageClean,
    this.onSaveToAlbum,
    this.onShare,
    this.onWatermark,
    this.onMosaic,
    this.onSendToImg2Img,
    this.onSendToReversePrompt,
    this.metadataOverride,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metadata = metadataOverride ?? currentImage.metadata;

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
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
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

            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: _DetailTopBarActions(
                currentImage: currentImage,
                hasMetadata: metadata != null,
                onShowMetadata: onShowMetadata,
                onReuseMetadata: onReuseMetadata,
                onFavoriteToggle: onFavoriteToggle,
                onSave: onSave,
                onCopyImage: onCopyImage,
                onCopyImageClean: onCopyImageClean,
                onSaveToAlbum: onSaveToAlbum,
                onShare: onShare,
                onWatermark: onWatermark,
                onMosaic: onMosaic,
                onSendToImg2Img: onSendToImg2Img,
                onSendToReversePrompt: onSendToReversePrompt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _DetailOverflowAction {
  save,
  saveToAlbum,
  share,
  favorite,
  reuse,
  imageToImage,
  reversePrompt,
  copy,
  watermark,
  mosaic,
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
    this.onCopyImageClean,
    this.onSaveToAlbum,
    this.onShare,
    this.onWatermark,
    this.onMosaic,
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
  final VoidCallback? onCopyImageClean;
  final VoidCallback? onSaveToAlbum;
  final VoidCallback? onShare;
  final VoidCallback? onWatermark;
  final VoidCallback? onMosaic;
  final VoidCallback? onSendToImg2Img;
  final VoidCallback? onSendToReversePrompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final compact =
            constraints.maxWidth < 720 || textScaler.scale(1) >= 1.3;
        final veryCompact =
            constraints.maxWidth < 420 || textScaler.scale(1) >= 2;
        return _buildActions(context, ref, compact, veryCompact);
      },
    );
  }

  Widget _buildActions(
    BuildContext context,
    WidgetRef ref,
    bool compact,
    bool veryCompact,
  ) {
    final l10n = context.l10n;
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
    final mosaicEnabled = ref.watch(
      mosaicSettingsProvider.select((state) => state.configuration.enabled),
    );
    final isMosaicDerivative =
        currentImage is LocalImageDetailData &&
        MosaicDerivativeRegistry(
          ref.read(localStorageServiceProvider),
        ).isDerivative(currentImage.identifier);
    final mosaicLabel = isMosaicDerivative
        ? l10n.mosaic_actionRegenerate
        : l10n.mosaic_actionCreate;
    final favorite = currentImage.showFavoriteButton && onFavoriteToggle != null
        ? _buildFavorite(ref)
        : null;

    if (compact) {
      final overflowActions = <PopupMenuEntry<_DetailOverflowAction>>[
        if (veryCompact && currentImage.showSaveButton && onSave != null)
          PopupMenuItem(
            value: _DetailOverflowAction.save,
            child: ListTile(
              leading: const Icon(Icons.save_alt),
              title: Text(l10n.common_save),
            ),
          ),
        // 保存到系统相册：显式动作，固定收进溢出菜单（不与上游的「保存」混淆）
        if (onSaveToAlbum != null)
          PopupMenuItem(
            value: _DetailOverflowAction.saveToAlbum,
            child: ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.image_saveToAlbum),
            ),
          ),
        if (veryCompact && onShare != null)
          PopupMenuItem(
            value: _DetailOverflowAction.share,
            child: ListTile(
              leading: const Icon(Icons.share_rounded),
              title: Text(l10n.common_share),
            ),
          ),
        if (veryCompact && favorite != null)
          PopupMenuItem(
            value: _DetailOverflowAction.favorite,
            child: ListTile(
              leading: Icon(
                currentImage.isFavorite
                    ? Icons.favorite
                    : Icons.favorite_border,
              ),
              title: Text(
                currentImage.isFavorite
                    ? l10n.common_unfavorite
                    : l10n.common_favorite,
              ),
            ),
          ),
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
        // 【偏离上游】上游这条就是唯一的复制入口，且默认带元数据。
        // 我们把它降级成次要入口并改用明确文案，常驻顶栏的是去元数据版本。
        if (onCopyImage != null)
          PopupMenuItem(
            value: _DetailOverflowAction.copy,
            child: ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: Text(
                onCopyImageClean != null
                    ? l10n.image_copyWithMetadata
                    : l10n.shortcut_action_copy_image,
              ),
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
        if (mosaicEnabled && onMosaic != null)
          PopupMenuItem(
            value: _DetailOverflowAction.mosaic,
            child: ListTile(
              leading: const Icon(Icons.grid_on_rounded),
              title: Text(mosaicLabel),
            ),
          ),
      ];
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!veryCompact && currentImage.showSaveButton && onSave != null)
            IconButton(
              icon: const Icon(Icons.save_alt, color: Colors.white),
              onPressed: onSave,
              tooltip: l10n.common_save,
            ),
          if (!veryCompact && onShare != null)
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              onPressed: onShare,
              tooltip: l10n.common_share,
            ),
          if (!veryCompact && favorite != null) favorite,
          // 【偏离上游】去元数据复制常驻顶栏（含 veryCompact），不进溢出菜单：
          // 这是用户点名的高频动作，硬传 stripMetadataOverride: true，
          // 不跟随 shareImageSettingsProvider。
          if (onCopyImageClean != null)
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.white),
              onPressed: onCopyImageClean,
              tooltip: l10n.image_copyCleanImage,
            ),
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
                  case _DetailOverflowAction.save:
                    onSave?.call();
                    break;
                  case _DetailOverflowAction.saveToAlbum:
                    onSaveToAlbum?.call();
                    break;
                  case _DetailOverflowAction.share:
                    onShare?.call();
                    break;
                  case _DetailOverflowAction.favorite:
                    onFavoriteToggle?.call();
                    break;
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
                  case _DetailOverflowAction.mosaic:
                    onMosaic?.call();
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
        // 保存到系统相册（宽屏，如 iPad 横屏）：与上面的「保存」是两件事
        if (onSaveToAlbum != null)
          IconButton(
            icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
            onPressed: onSaveToAlbum,
            tooltip: l10n.image_saveToAlbum,
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
        if (mosaicEnabled && onMosaic != null)
          IconButton(
            icon: const Icon(Icons.grid_on_rounded, color: Colors.white),
            onPressed: onMosaic,
            tooltip: mosaicLabel,
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
        // 【偏离上游】宽屏同时给两个复制按钮：常驻的去元数据版本（用户点名），
        // 以及上游那个跟随「分享保护」设置的版本。桌面端空间够，不做降级。
        if (onCopyImageClean != null)
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white),
            onPressed: onCopyImageClean,
            tooltip: l10n.image_copyCleanImage,
          ),
        if (onCopyImage != null)
          IconButton(
            icon: Icon(
              onCopyImageClean != null ? Icons.copy_all_outlined : Icons.copy,
              color: Colors.white,
            ),
            onPressed: onCopyImage,
            tooltip: onCopyImageClean != null
                ? l10n.image_copyWithMetadata
                : l10n.shortcut_action_copy_image,
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
