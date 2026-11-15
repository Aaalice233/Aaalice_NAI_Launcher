import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../themes/theme_extension.dart';
import '../../utils/image_detail_opener.dart';
import '../../widgets/common/decoded_memory_image.dart';
import '../../widgets/common/image_card_hover_motion.dart';
import '../../widgets/common/image_detail/image_detail_data.dart';
import '../../widgets/common/image_viewport_surface.dart';

class ToolResultInlineImage extends StatelessWidget {
  const ToolResultInlineImage({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => ToolResultInteractiveImageCard(
    onTap: () => ImageDetailOpener.showSingleImmediate(
      context,
      image: GeneratedImageDetailData(imageBytes: bytes),
      showMetadataPanel: true,
    ),
    child: DecodedMemoryImage(
      bytes: bytes,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    ),
  );
}

class ToolResultNetworkImage extends StatelessWidget {
  const ToolResultNetworkImage({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => ToolResultInteractiveImageCard(
    onTap: () => _showNetworkImagePreview(context, url),
    child: Image.network(
      url,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    ),
  );
}

class ToolResultInteractiveImageCard extends StatefulWidget {
  const ToolResultInteractiveImageCard({
    super.key,
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  State<ToolResultInteractiveImageCard> createState() =>
      _ToolResultInteractiveImageCardState();
}

class _ToolResultInteractiveImageCardState
    extends State<ToolResultInteractiveImageCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: context.l10n.detail_imageDetails,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                child: ImageCardHoverMotion(
                  hovered: _hovered,
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    foregroundDecoration: BoxDecoration(
                      color: _hovered
                          ? theme.colorScheme.primary.withValues(alpha: 0.07)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ImageViewportSurface(child: widget.child),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showNetworkImagePreview(BuildContext context, String url) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  final motion = Theme.of(context).appTheme;
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      transitionDuration: reduceMotion ? Duration.zero : motion.normalDuration,
      reverseTransitionDuration: reduceMotion
          ? Duration.zero
          : motion.fastDuration,
      pageBuilder: (routeContext, _, _) => _NetworkImagePreviewPage(url: url),
      transitionsBuilder: (_, animation, _, child) => reduceMotion
          ? child
          : FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _NetworkImagePreviewPage extends StatelessWidget {
  const _NetworkImagePreviewPage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Material(
      color: ImageViewportSurface.background,
      child: AnimatedPadding(
        duration: reduceMotion
            ? Duration.zero
            : Theme.of(context).appTheme.fastDuration,
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: SizedBox.expand(
            key: const ValueKey('agent-network-image-preview'),
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 8,
                    child: Center(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    key: const ValueKey('agent-network-image-preview-close'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
