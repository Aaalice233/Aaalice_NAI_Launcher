import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/image_save_utils.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../../data/services/dlss/dlss_options.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../providers/dlss_provider.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/image_comparison_view.dart';
import '../../adaptive/window_size_class.dart';
import 'dlss_error_view.dart';
import 'dlss_preset_editor.dart';
import '../settings/settings_screen.dart';
import '../settings/settings_section.dart';
import 'dlss_environment_card.dart';

Future<void> showDlssEnhancement(BuildContext context, Uint8List bytes) =>
    AdaptivePresenter.showForm<void>(
      context: context,
      title: context.l10n.dlss_title,
      dialogWidth: 1200,
      expandCompact: true,
      barrierDismissible: false,
      builder: (context, scrollController) => DlssEnhancementPanel(
        source: bytes,
        scrollController: scrollController,
      ),
    );

class DlssEnhancementPanel extends ConsumerStatefulWidget {
  const DlssEnhancementPanel({
    super.key,
    required this.source,
    required this.scrollController,
  });
  final Uint8List source;
  final ScrollController scrollController;
  @override
  ConsumerState<DlssEnhancementPanel> createState() =>
      _DlssEnhancementPanelState();
}

class _DlssEnhancementPanelState extends ConsumerState<DlssEnhancementPanel> {
  late DlssOptions _options;
  late final DlssController _controller;
  Uint8List? _result;
  bool _running = false;
  bool _finalizing = false;
  bool _saving = false;
  Object? _error;
  bool _saveError = false;
  final _comparisonKey = GlobalKey();
  Completer<void>? _cancelled;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(dlssProvider);
    _options = _controller.options;
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _cancel() {
    if (_cancelled != null && !_cancelled!.isCompleted) _cancelled!.complete();
  }

  Future<void> _run() async {
    _options = _controller.options;
    setState(() {
      _running = true;
      _finalizing = false;
      _saveError = false;
      _error = null;
    });
    _cancelled = Completer<void>();
    try {
      final result = await _controller.enhance(
        widget.source,
        _options,
        cancelled: _cancelled!.future,
        onFinalizing: () {
          if (mounted) setState(() => _finalizing = true);
        },
      );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _save() async {
    final bytes = _result;
    if (bytes == null) return;
    setState(() {
      _saving = true;
      _saveError = true;
      _error = null;
    });
    try {
      final root = await GalleryFolderRepository.instance.getRootPath();
      if (root == null || root.isEmpty) {
        throw StateError('Image save directory is not configured');
      }
      final path = await ImageSaveUtils.saveBytesToDatedPath(
        rootPath: root,
        bytes: bytes,
        seed: await ImageSaveUtils.resolveSeed(bytes: bytes),
      );
      if (mounted) {
        AppToast.success(context, '${context.l10n.common_success}\n$path');
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dlssProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= WindowSizeClass.expandedMinWidth;
        final preview = _preview();
        final controls = _controls(state);
        if (wide) {
          return SizedBox(
            height: constraints.maxHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: preview,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: SingleChildScrollView(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.all(20),
                      child: controls,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          controller: widget.scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _preview(
                viewportHeight: (MediaQuery.sizeOf(context).height * 0.42)
                    .clamp(200, 420),
              ),
              const SizedBox(height: 20),
              controls,
            ],
          ),
        );
      },
    );
  }

  Widget _preview({double? viewportHeight}) {
    final l10n = context.l10n;
    final result = _result;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ImageComparisonView(
        key: _comparisonKey,
        sourceImageBytes: widget.source,
        generatedImageBytes: result ?? widget.source,
        fit: BoxFit.contain,
        showPixelScaleControls: true,
        viewportHeight: viewportHeight,
      ),
    );
    return Column(
      mainAxisSize: viewportHeight == null
          ? MainAxisSize.max
          : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          children: [
            Visibility(
              visible: result != null,
              maintainSize: true,
              maintainState: true,
              maintainAnimation: true,
              child: Text(l10n.dlss_result),
            ),
            Text(l10n.dlss_original),
          ],
        ),
        const SizedBox(height: 12),
        if (viewportHeight == null) Expanded(child: image) else image,
        const SizedBox(height: 12),
        Text(
          l10n.dlss_compareHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _controls(DlssController state) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.dlss_previewHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (!state.enabled) ...[
          const SizedBox(height: 12),
          Text(
            state.ready
                ? l10n.dlss_disabled
                : dlssAvailabilityLabel(l10n, state.environment.availability),
          ),
        ],
        const SizedBox(height: 20),
        DlssPresetEditor(enabled: !_running),
        if (_error != null)
          DlssErrorView(
            error: _error!,
            summary: _saveError ? l10n.dlss_saveFailed : null,
          ),
        if (_running) ...[
          const LinearProgressIndicator(),
          Text(_finalizing ? l10n.dlss_finalizing : l10n.dlss_running),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('dlss-run'),
          onPressed: _running || !state.enabled ? null : _run,
          icon: const Icon(Icons.tonality_outlined),
          label: Text(l10n.dlss_run),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('dlss-save-copy'),
          onPressed: _result == null || _running || _saving ? null : _save,
          icon: const Icon(Icons.save_alt),
          label: Text(l10n.dlss_saveCopy),
        ),
        if (_running)
          TextButton(onPressed: _cancel, child: Text(l10n.common_cancel)),
        TextButton(
          onPressed: _running
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(
                      initialSection: SettingsSection.integrations,
                      initiallyShowDlss: true,
                    ),
                  ),
                ),
          child: Text(l10n.dlss_runtime),
        ),
      ],
    );
  }
}
