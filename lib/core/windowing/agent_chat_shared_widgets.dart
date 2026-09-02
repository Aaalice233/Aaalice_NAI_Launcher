import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart' as md;

import '../../presentation/adaptive/interaction_policy.dart';

/// Shared sizing contract for the embedded and detached composer editors.
abstract final class AgentChatComposerLayout {
  static const defaultMinLines = 2;
  static const defaultMobileMaxLines = 6;
  static const defaultDesktopMaxLines = 8;

  static int collapsedEditorMinLines({
    required double availableHeight,
    required double textScale,
    required bool touchOptimized,
  }) =>
      touchOptimized &&
          (availableHeight < 400 || (availableHeight < 500 && textScale > 1.4))
      ? 1
      : defaultMinLines;

  static int collapsedEditorMaxLines({
    required double availableHeight,
    required double textScale,
    required bool touchOptimized,
  }) {
    if (touchOptimized &&
        (availableHeight < 400 || (availableHeight < 500 && textScale > 1.4))) {
      return 1;
    }
    return touchOptimized ? defaultMobileMaxLines : defaultDesktopMaxLines;
  }

  static double expandedEditorHeight({
    required double availableHeight,
    required bool touchOptimized,
  }) {
    final fraction = touchOptimized ? 0.34 : 0.38;
    final preferredMinimum = touchOptimized ? 128.0 : 144.0;
    final maximum = touchOptimized ? 280.0 : 360.0;
    final controlsReserve = touchOptimized ? 112.0 : 104.0;
    final safeMaximum = (availableHeight - controlsReserve)
        .clamp(96.0, maximum)
        .toDouble();
    final safeMinimum = preferredMinimum.clamp(96.0, safeMaximum).toDouble();
    return (availableHeight * fraction)
        .clamp(safeMinimum, safeMaximum)
        .toDouble();
  }

  static double availableViewportHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    return (media.size.height - media.viewInsets.bottom).clamp(
      0,
      double.infinity,
    );
  }
}

/// Immediate, accessible expand/collapse affordance shared by both composers.
class AgentChatComposerExpandButton extends StatelessWidget {
  const AgentChatComposerExpandButton({
    super.key,
    required this.expanded,
    required this.touchOptimized,
    required this.expandLabel,
    required this.collapseLabel,
    required this.onPressed,
  });

  final bool expanded;
  final bool touchOptimized;
  final String expandLabel;
  final String collapseLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = expanded ? collapseLabel : expandLabel;
    final policyExtent = context.interactionPolicy.minimumControlExtent;
    final size = touchOptimized
        ? policyExtent.clamp(48.0, double.infinity).toDouble()
        : policyExtent;
    return Semantics(
      button: true,
      toggled: expanded,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              expanded
                  ? Icons.close_fullscreen_rounded
                  : Icons.open_in_full_rounded,
            ),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            iconSize: touchOptimized ? 20 : 18,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(width: size, height: size),
          ),
        ),
      ),
    );
  }
}

/// Markdown presentation shared by the authoritative panel and IPC client.
class AgentChatMarkdownContent extends StatelessWidget {
  const AgentChatMarkdownContent({
    super.key,
    required this.text,
    required this.touchOptimized,
    this.imageBuilder,
  });

  final String text;
  final bool touchOptimized;
  final Widget Function(Uri uri, String? title, String? alt)? imageBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium;
    return md.MarkdownBody(
      data: text,
      selectable: true,
      imageBuilder: imageBuilder,
      styleSheet: md.MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: bodyStyle?.copyWith(height: 1.55),
        code: bodyStyle?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.6,
          ),
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.6,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// Resolves the same Markdown image schemes in every Agent chat surface.
class AgentChatMarkdownImage extends StatelessWidget {
  const AgentChatMarkdownImage({
    super.key,
    required this.uri,
    required this.alt,
    this.dataBytes,
  });

  final Uri uri;
  final String? alt;
  final Uint8List? dataBytes;

  @override
  Widget build(BuildContext context) {
    final scheme = uri.scheme.toLowerCase();
    final image = switch (scheme) {
      'http' || 'https' => Image.network(
        uri.toString(),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _brokenImage(context),
      ),
      'resource' => Image.asset(
        uri.path,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _brokenImage(context),
      ),
      'data' => _dataImage(context),
      _ => _fileImage(context, scheme),
    };
    return Semantics(
      label: alt,
      image: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320, maxHeight: 220),
        child: AspectRatio(
          aspectRatio: 320 / 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image,
          ),
        ),
      ),
    );
  }

  Widget _dataImage(BuildContext context) {
    try {
      return Image.memory(
        dataBytes ?? uri.data!.contentAsBytes(),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _brokenImage(context),
      );
    } catch (_) {
      return _brokenImage(context);
    }
  }

  Widget _fileImage(BuildContext context, String scheme) {
    try {
      final file = scheme == 'file'
          ? File.fromUri(uri)
          : File(uri.toFilePath(windows: Platform.isWindows));
      return Image.file(
        file,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _brokenImage(context),
      );
    } catch (_) {
      return _brokenImage(context);
    }
  }

  Widget _brokenImage(BuildContext context) => ColoredBox(
    color: Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
    child: const Center(child: Icon(Icons.broken_image_outlined)),
  );
}

/// Bounded, selectable and copyable detail surface for tool protocol data.
class AgentToolDetailSurface extends StatefulWidget {
  const AgentToolDetailSurface({
    super.key,
    required this.text,
    this.copyTooltip,
    this.onCopy,
    this.maxHeight = 240,
    this.margin = const EdgeInsets.fromLTRB(24, 2, 4, 6),
  });

  final String text;
  final String? copyTooltip;
  final VoidCallback? onCopy;
  final double maxHeight;
  final EdgeInsets margin;

  @override
  State<AgentToolDetailSurface> createState() => _AgentToolDetailSurfaceState();
}

class _AgentToolDetailSurfaceState extends State<AgentToolDetailSurface> {
  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );
  final PageStorageBucket _detailPageStorage = PageStorageBucket();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final interactionPolicy = context.interactionPolicy;
    final copyButtonExtent = interactionPolicy.touchAvailable
        ? interactionPolicy.minimumControlExtent
        : 40.0;
    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            child: Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                primary: false,
                padding: EdgeInsets.fromLTRB(
                  10,
                  9,
                  widget.onCopy == null ? 10 : 42,
                  10,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: PageStorage(
                    bucket: _detailPageStorage,
                    child: SelectableText(
                      widget.text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.onCopy != null)
            Positioned(
              top: 2,
              right: 2,
              child: IconButton(
                key: const ValueKey('agent-tool-detail-copy'),
                tooltip: widget.copyTooltip,
                visualDensity: VisualDensity.compact,
                constraints: BoxConstraints.tightFor(
                  width: copyButtonExtent,
                  height: copyButtonExtent,
                ),
                iconSize: 16,
                onPressed: widget.onCopy,
                icon: const Icon(Icons.copy_all_outlined),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shared approval surface for mutations and separately-confirmed Anlas costs.
class AgentChatApprovalSurface extends StatelessWidget {
  const AgentChatApprovalSurface({
    super.key,
    required this.title,
    required this.description,
    required this.details,
    required this.denyLabel,
    required this.allowLabel,
    required this.onDeny,
    required this.onAllow,
    this.costLabel,
    this.touchOptimized = false,
  });

  final String title;
  final String description;
  final String details;
  final String? costLabel;
  final String denyLabel;
  final String allowLabel;
  final VoidCallback onDeny;
  final VoidCallback onAllow;
  final bool touchOptimized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onTertiaryContainer;
    return Container(
      key: const ValueKey('agent-chat-approval-surface'),
      margin: EdgeInsets.fromLTRB(
        touchOptimized ? 12 : 10,
        5,
        touchOptimized ? 12 : 10,
        5,
      ),
      padding: EdgeInsets.all(touchOptimized ? 14 : 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.gpp_maybe_outlined,
                  size: 19,
                  color: foreground,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.76),
                      ),
                    ),
                    if (costLabel case final label?) ...[
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.tertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const ValueKey('agent-chat-approval-details'),
                  minTileHeight: touchOptimized ? 44 : 34,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    details.split('\n').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foreground.withValues(alpha: 0.74),
                      fontFamily: 'monospace',
                    ),
                  ),
                  children: [
                    AgentToolDetailSurface(
                      text: details,
                      maxHeight: touchOptimized ? 132 : 104,
                      margin: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDeny,
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.fromHeight(touchOptimized ? 48 : 38),
                  ),
                  child: Text(denyLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onAllow,
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(touchOptimized ? 48 : 38),
                  ),
                  child: Text(allowLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
