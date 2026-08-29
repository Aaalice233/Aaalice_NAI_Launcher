import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart' as md;

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
    final bodyStyle = touchOptimized
        ? theme.textTheme.bodyMedium
        : theme.textTheme.bodySmall;
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
    required this.copyTooltip,
    required this.onCopy,
    this.maxHeight = 240,
    this.margin = const EdgeInsets.fromLTRB(24, 2, 4, 6),
  });

  final String text;
  final String copyTooltip;
  final VoidCallback onCopy;
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
                padding: const EdgeInsets.fromLTRB(10, 9, 42, 10),
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
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              key: const ValueKey('agent-tool-detail-copy'),
              tooltip: widget.copyTooltip,
              visualDensity: VisualDensity.compact,
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
