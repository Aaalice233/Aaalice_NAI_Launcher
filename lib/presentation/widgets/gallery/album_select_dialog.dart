import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/gallery_album.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../providers/gallery_album_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input_dialog.dart';

/// 相簿选择结果
class AlbumSelectResult {
  final String albumId;
  final String albumName;

  const AlbumSelectResult({required this.albumId, required this.albumName});
}

/// 相簿选择对话框
///
/// 选择一个相簿以加入图片；支持在对话框内直接新建相簿。
class AlbumSelectDialog extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const AlbumSelectDialog({super.key, this.scrollController});

  /// 显示相簿选择面板，取消时返回 null。
  static Future<AlbumSelectResult?> show(BuildContext context) {
    return AdaptivePresenter.showForm<AlbumSelectResult>(
      context: context,
      title: context.l10n.localGallery_albumSelectTitle,
      sideSheetWidth: 450,
      builder: (panelContext, scrollController) =>
          AlbumSelectDialog(scrollController: scrollController),
    );
  }

  @override
  ConsumerState<AlbumSelectDialog> createState() => _AlbumSelectDialogState();
}

class _AlbumSelectDialogState extends ConsumerState<AlbumSelectDialog> {
  final _filterController = TextEditingController();
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _filterController.addListener(_onFilterChanged);
  }

  void _onFilterChanged() {
    setState(() {
      _filterQuery = _filterController.text.trim().toLowerCase();
    });
  }

  @override
  void dispose() {
    _filterController.removeListener(_onFilterChanged);
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _createAlbum() async {
    final l10n = context.l10n;
    final name = await ThemedInputDialog.show(
      context: context,
      title: l10n.localGallery_createAlbumTitle,
      hintText: l10n.localGallery_createAlbumHint,
      confirmText: l10n.common_create,
      cancelText: l10n.common_cancel,
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    await ref
        .read(galleryAlbumNotifierProvider.notifier)
        .createAlbum(name.trim());
  }

  void _select(GalleryAlbum album) {
    Navigator.of(
      context,
    ).pop(AlbumSelectResult(albumId: album.id, albumName: album.name));
  }

  List<GalleryAlbum> _filtered(List<GalleryAlbum> albums) {
    if (_filterQuery.isEmpty) return albums;
    return albums
        .where((album) => album.name.toLowerCase().contains(_filterQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final albumState = ref.watch(galleryAlbumNotifierProvider);

    return CustomScrollView(
      key: const Key('album-select-scroll'),
      controller: widget.scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: ThemedInput(
              controller: _filterController,
              decoration: InputDecoration(
                hintText: l10n.collectionSelect_filterHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filterQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _filterController.clear,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        _buildList(theme, albumState),
        SliverSafeArea(
          top: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _createAlbum,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.localGallery_createAlbum),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.common_cancel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(ThemeData theme, GalleryAlbumState albumState) {
    if (albumState.isLoading) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 96,
          child: Center(
            child: CircularProgressIndicator(
              value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
            ),
          ),
        ),
      );
    }

    final albums = albumState.albums;
    if (albums.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          child: Column(
            children: [
              Icon(
                Icons.photo_album_outlined,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.localGallery_albumEmptyHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filtered(albums);
    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 96,
          child: Center(
            child: Icon(
              Icons.search_off_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }

    return SliverList.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final album = filtered[index];
        final pathLabel = album.parentId == null
            ? album.name
            : albums.getPathString(album.id);
        return ListTile(
          leading: Icon(
            Icons.photo_album_outlined,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            pathLabel,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            context.l10n.localGallery_imageCount(album.imageCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          trailing: Icon(
            Icons.add_circle_outline,
            color: theme.colorScheme.primary,
          ),
          onTap: () => _select(album),
        );
      },
    );
  }
}
