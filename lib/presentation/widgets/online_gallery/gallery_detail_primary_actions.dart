import 'package:flutter/material.dart';

import 'gallery_detail_models.dart';

class GalleryDetailPrimaryActions extends StatelessWidget {
  const GalleryDetailPrimaryActions({
    super.key,
    required this.viewModel,
    required this.actions,
  });

  final GalleryDetailViewModel viewModel;
  final GalleryDetailActions actions;

  @override
  Widget build(BuildContext context) {
    const style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size.fromHeight(48)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
    final media = viewModel.currentMedia;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scaledLabelHeight = MediaQuery.textScalerOf(context).scale(14);
          final stackActions =
              constraints.maxWidth < 420 || scaledLabelHeight > 20;
          final generate = FilledButton(
            key: const ValueKey('gallery-detail-generate'),
            style: style,
            onPressed: viewModel.canUseGenerationActions
                ? () => actions.sendToGenerate(media)
                : null,
            child: _ActionLabel(
              icon: Icons.auto_awesome,
              label: viewModel.labels.sendToGenerate,
            ),
          );
          final queue = OutlinedButton(
            key: const ValueKey('gallery-detail-queue'),
            style: style,
            onPressed:
                viewModel.canUseGenerationActions &&
                    !viewModel.queueActionPending
                ? () => actions.addToQueue(media)
                : null,
            child: _ActionLabel(
              icon: Icons.playlist_add,
              label: viewModel.labels.addToQueue,
              loading: viewModel.queueActionPending,
            ),
          );

          if (stackActions) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [generate, const SizedBox(height: 8), queue],
            );
          }
          return Row(
            children: [
              Expanded(child: generate),
              const SizedBox(width: 8),
              Expanded(child: queue),
            ],
          );
        },
      ),
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel({
    required this.icon,
    required this.label,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 18,
          child: loading
              ? const CircularProgressIndicator(strokeWidth: 2)
              : Icon(icon, size: 18),
        ),
        const SizedBox(width: 8),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
  }
}
