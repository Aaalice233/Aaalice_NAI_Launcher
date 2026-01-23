import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PoolMapperPanel extends ConsumerStatefulWidget {
  final String poolId;
  final ValueChanged<String> onIdChanged;
  final VoidCallback onVerify;
  final bool isVerifying;
  final String? error;
  final List<String> previewTags;

  const PoolMapperPanel({
    super.key,
    required this.poolId,
    required this.onIdChanged,
    required this.onVerify,
    required this.isVerifying,
    this.error,
    this.previewTags = const [],
  });

  @override
  ConsumerState<PoolMapperPanel> createState() => _PoolMapperPanelState();
}

class _PoolMapperPanelState extends ConsumerState<PoolMapperPanel> {
  late TextEditingController _idController;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.poolId);
  }

  @override
  void didUpdateWidget(PoolMapperPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.poolId != oldWidget.poolId && widget.poolId != _idController.text) {
      _idController.text = widget.poolId;
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Input Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _idController,
                decoration: InputDecoration(
                  labelText: 'Danbooru Pool ID',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.photo_library),
                  helperText: 'Enter the numeric ID of the pool',
                  errorText: widget.error,
                ),
                keyboardType: TextInputType.number,
                onChanged: widget.onIdChanged,
                enabled: !widget.isVerifying,
              ),
            ),
            const SizedBox(width: 16),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
                child: OutlinedButton(
                onPressed: widget.isVerifying ? null : widget.onVerify,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  side: BorderSide(color: widget.isVerifying ? Colors.transparent : colorScheme.primary.withOpacity(0.5)),
                ),
                child: widget.isVerifying
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    : Tooltip(
                        message: 'Fetch tags from Danbooru using this Pool ID',
                        child: Text(
                          'Verify',
                          style: TextStyle(color: colorScheme.primary),
                        ),
                      ),
              ),
            ),
          ],
        ),

        // Custom Error Display (if needed for more prominence than input decoration)
        if (widget.error != null && widget.error!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.error_outline, size: 16, color: colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 24),

        // Preview Area
        Text(
          'Preview',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.2),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildPreviewContent(theme, colorScheme),
        ),
      ],
    );
  }

  Widget _buildPreviewContent(ThemeData theme, ColorScheme colorScheme) {
    if (widget.isVerifying) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Fetching preview...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.previewTags.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.preview_outlined,
              size: 48,
              color: colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No preview available',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.outline,
              ),
            ),
            Text(
              'Enter a Pool ID and click Verify',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header for results
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
          child: Text(
            'Found ${widget.previewTags.length} tags',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.previewTags.map((tag) {
                return Chip(
                  label: Text(tag),
                  backgroundColor: colorScheme.surface,
                  side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
                  labelStyle: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
