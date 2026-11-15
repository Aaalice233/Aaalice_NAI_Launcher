import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/utils/localization_extension.dart';
import '../../screens/online_gallery/online_gallery_detail_launcher.dart';
import '../../utils/image_detail_opener.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/decoded_memory_image.dart';
import '../../widgets/common/image_card_hover_motion.dart';
import '../../widgets/common/image_detail/file_image_detail_data.dart';
import '../../widgets/common/image_detail/image_detail_data.dart';
import '../../widgets/common/surface_ink_well.dart';
import '../providers/agent_chat_notifier.dart';
import '../services/agent_resource_resolver.dart';
import 'agent_chat_tool_image_card.dart';

List<Widget> buildToolResultResourcePreviewWidgets({
  required List<AgentChatResourceReference> references,
  required List<Uint8List> inlineImages,
  required String keyPrefix,
  Future<ResolvedAgentResource?> Function(AgentChatResourceReference reference)?
  resolveResource,
}) {
  final online = <Widget>[];
  final other = <Widget>[];
  for (var index = 0; index < references.length; index++) {
    final reference = references[index];
    final preview = _ToolResultResourcePreview(
      key: ValueKey('$keyPrefix-$index'),
      reference: reference,
      thumbnailBytes: index < inlineImages.length ? inlineImages[index] : null,
      resolveResource: resolveResource,
    );
    if (reference.kind == AgentChatResourceKind.onlineGalleryMedia) {
      online.add(SizedBox(width: 200, child: preview));
    } else {
      other.add(preview);
    }
  }
  return [
    if (online.isNotEmpty)
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: online,
      ),
    ...other,
  ];
}

class _ToolResultResourcePreview extends ConsumerStatefulWidget {
  const _ToolResultResourcePreview({
    super.key,
    required this.reference,
    this.thumbnailBytes,
    this.resolveResource,
  });

  final AgentChatResourceReference reference;
  final Uint8List? thumbnailBytes;
  final Future<ResolvedAgentResource?> Function(
    AgentChatResourceReference reference,
  )?
  resolveResource;

  @override
  ConsumerState<_ToolResultResourcePreview> createState() =>
      _ToolResultResourcePreviewState();
}

class _ToolResultResourcePreviewState
    extends ConsumerState<_ToolResultResourcePreview> {
  Future<ResolvedAgentResource?>? _resolution;
  bool _opening = false;

  Future<ResolvedAgentResource?> _resolve() => _resolution ??=
      widget.resolveResource?.call(widget.reference) ??
      ref
          .read(agentChatNotifierProvider.notifier)
          .resolveResourcePreview(widget.reference);

  @override
  void didUpdateWidget(covariant _ToolResultResourcePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference) {
      _resolution = null;
      _opening = false;
    }
  }

  Future<void> _openOriginal() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final resolved = await _resolve();
      if (!mounted) return;
      if (resolved == null ||
          (resolved.filePath == null && resolved.bytes == null)) {
        AppToast.error(context, context.l10n.agentChat_resourceUnavailable);
        return;
      }
      if (resolved.onlineGalleryItem case final item?) {
        final detail = resolved.onlineGalleryDetail;
        if (detail == null) {
          AppToast.error(context, context.l10n.agentChat_resourceUnavailable);
          return;
        }
        await OnlineGalleryDetailLauncher(
          context: context,
          ref: ref,
        ).show(context, item, preloadedDetail: detail);
      } else if (resolved.filePath case final path?) {
        ImageDetailOpener.showSingleImmediate(
          context,
          image: FileImageDetailData(filePath: path),
          showMetadataPanel: true,
        );
      } else {
        ImageDetailOpener.showSingleImmediate(
          context,
          image: GeneratedImageDetailData(imageBytes: resolved.bytes!),
          showMetadataPanel: true,
        );
      }
    } on Object {
      if (mounted) {
        AppToast.error(context, context.l10n.agentChat_resourceUnavailable);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Widget _buildPreview(Uint8List bytes) {
    final isOnlineGallery =
        widget.reference.kind == AgentChatResourceKind.onlineGalleryMedia;
    final image = DecodedMemoryImage(
      bytes: bytes,
      fit: isOnlineGallery ? BoxFit.cover : BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const _AgentResourceUnavailableImage(),
    );
    if (isOnlineGallery) {
      return _OnlineGalleryResourceCard(
        reference: widget.reference,
        onTap: () => unawaited(_openOriginal()),
        image: image,
      );
    }
    return ToolResultInteractiveImageCard(
      onTap: () => unawaited(_openOriginal()),
      child: image,
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumbnail = widget.thumbnailBytes;
    if (thumbnail != null) return _buildPreview(thumbnail);
    return FutureBuilder<ResolvedAgentResource?>(
      future: _resolve(),
      builder: (context, snapshot) {
        final bytes = snapshot.data?.bytes;
        if (bytes == null) return const _AgentResourceUnavailableImage();
        return _buildPreview(bytes);
      },
    );
  }
}

class _OnlineGalleryResourceCard extends StatefulWidget {
  const _OnlineGalleryResourceCard({
    required this.reference,
    required this.onTap,
    required this.image,
  });

  final AgentChatResourceReference reference;
  final VoidCallback onTap;
  final Widget image;

  @override
  State<_OnlineGalleryResourceCard> createState() =>
      _OnlineGalleryResourceCardState();
}

class _OnlineGalleryResourceCardState
    extends State<_OnlineGalleryResourceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source =
        widget.reference.display['source_label'] ?? widget.reference.source;
    final title = widget.reference.display['title'];
    final author = widget.reference.display['author'];
    final hasDetails = title != null || author != null;
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: true,
      label: [source, title, author].whereType<String>().join(', '),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: ImageCardHoverMotion(
          hovered: _hovered,
          child: ClipRRect(
            borderRadius: radius,
            child: SurfaceInkWell(
              key: const ValueKey('online-gallery-resource-card'),
              borderRadius: radius,
              color: theme.colorScheme.surfaceContainerLow,
              inkAboveChild: true,
              // 悬停交给卡片自带的高亮蒙层
              hoverColor: Colors.transparent,
              onTap: widget.onTap,
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: widget.image,
                        ),
                      ),
                      if (hasDetails)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (title != null)
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge,
                                ),
                              if (author != null) ...[
                                if (title != null) const SizedBox(height: 1),
                                Text(
                                  author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 120),
                        curve: Curves.easeOut,
                        color: _hovered
                            ? theme.colorScheme.primary.withValues(alpha: 0.08)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentResourceUnavailableImage extends StatelessWidget {
  const _AgentResourceUnavailableImage();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    height: 120,
    child: Center(
      child: Text(
        context.l10n.agentChat_resourceUnavailable,
        textAlign: TextAlign.center,
      ),
    ),
  );
}
