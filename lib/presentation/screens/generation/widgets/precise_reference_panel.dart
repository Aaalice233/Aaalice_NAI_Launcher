import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../../core/constants/model_capabilities.dart';
import '../../../../core/enums/precise_ref_type.dart';
import '../../../../core/network/request_builders/precise_reference_limit_exception.dart';
import '../../../../core/network/request_builders/precise_reference_send_filter.dart';
import '../../../../core/platform/image_file_picker.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../../data/services/precise_ref_library_storage_service.dart';
import '../../../providers/generation/generation_panel_expansion_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/precise_ref_library_provider.dart';
import '../../../utils/card_drop_reader.dart';
import '../../../utils/native_drop_callback.dart';
import '../../../utils/precise_ref_library_import_helper.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/collapsible_image_panel.dart';
import '../../../widgets/common/decoded_memory_image.dart';
import '../../../widgets/common/image_card_action.dart';
import '../../../widgets/common/precise_reference_type_dialog.dart';
import '../../../widgets/common/themed_divider.dart';
import '../../precise_ref_library/widgets/precise_ref_selector_dialog.dart';
import 'precise_reference/precise_reference_image_card.dart';
import 'precise_reference/precise_reference_warning.dart';

class PreciseReferencePanel extends ConsumerStatefulWidget {
  const PreciseReferencePanel({super.key});

  @override
  ConsumerState<PreciseReferencePanel> createState() =>
      _PreciseReferencePanelState();
}

class _PreciseReferencePanelState extends ConsumerState<PreciseReferencePanel> {
  static const _panel = GenerationWorkbenchPanel.preciseReference;

  bool _isFileDraggingOver = false;
  bool _isProcessingDroppedFiles = false;
  List<PreciseReference> _previousReferences = const [];
  List<Key> _cardKeys = [];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final view = ref.watch(
      generationParamsNotifierProvider.select(
        (params) => (
          references: params.preciseReferences,
          capabilities: params.capabilities.preciseReference,
          requestCapabilities: params.requestPreciseReferenceCapabilities,
          action: params.action,
          sendCount: resolveSendablePreciseReferences(params).length,
        ),
      ),
    );
    final references = view.references;
    _syncCardKeys(references);
    final isExpanded = ref.watch(
      generationPanelExpansionProvider.select(
        (value) => value.isExpanded(_panel),
      ),
    );
    final showBackground = references.isNotEmpty && !isExpanded;
    final limitExceeded =
        view.sendCount > PreciseReferenceLimitException.maxReferences;
    final showCost = view.sendCount > 0 && !limitExceeded;
    final inlineCost =
        view.capabilities.supportsOutfit ||
        MediaQuery.textScalerOf(context).scale(10) > 15;
    final canAdd = view.capabilities.supported;
    final requestCapabilities = view.requestCapabilities;

    return CollapsibleImagePanel(
      title: l10n.preciseRef_title,
      icon: Icons.person_pin,
      isExpanded: isExpanded,
      onToggle: () => unawaited(
        ref.read(generationPanelExpansionProvider.notifier).toggle(_panel),
      ),
      hasData: references.isNotEmpty,
      backgroundImage: showBackground ? _buildBackground(references) : null,
      badge: _buildCountBadge(references.length, showBackground),
      trailing: showCost && !inlineCost
          ? _buildCostBadge(showBackground)
          : null,
      childBuilder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ThemedDivider(),
            if (showCost && inlineCost) ...[
              Text(
                l10n.preciseRef_costHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            if (!canAdd)
              PreciseReferenceWarning(message: l10n.preciseRef_supportedModels),
            if (view.action == ImageGenerationAction.infill &&
                requestCapabilities.supported &&
                !requestCapabilities.availableInInpainting &&
                references.any((reference) => reference.enabled))
              PreciseReferenceWarning(
                message: l10n.preciseRef_inpaintUnsupported,
              ),
            if (limitExceeded)
              PreciseReferenceWarning(
                message: l10n.preciseRef_limitExceeded(
                  PreciseReferenceLimitException.maxReferences,
                ),
              ),
            Text(
              l10n.preciseRef_description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            for (final (index, reference) in references.indexed)
              _buildCard(
                index,
                reference,
                view.capabilities,
                requestCapabilities,
              ),
            _buildPanelActions(
              canAdd: canAdd,
              hasReferences: references.isNotEmpty,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    int index,
    PreciseReference reference,
    PreciseReferenceCapabilities capabilities,
    PreciseReferenceCapabilities requestCapabilities,
  ) {
    return PreciseReferenceImageCard(
      key: _cardKeys[index],
      index: index,
      reference: reference,
      capabilities: capabilities,
      outfitWillBeSkipped: !requestCapabilities.supportsOutfit,
      onRemove: () => _removeReference(index),
      onSaveToLibrary: () => _saveSingleReferenceToLibrary(reference),
      onEnabledChanged: (value) => _updateReferenceEnabled(index, value),
      onTypeChanged: (type) => _updateReferenceType(index, type),
      onPreferSameOutfitChanged: (value) => ref
          .read(generationParamsNotifierProvider.notifier)
          .updatePreciseReferencePreferSameOutfit(index, value),
      onStrengthChanged: (value) => _updateReferenceStrength(index, value),
      onFidelityChanged: (value) => _updateReferenceFidelity(index, value),
    );
  }

  void _syncCardKeys(List<PreciseReference> references) {
    if (_previousReferences.length != references.length) {
      final previous = _previousReferences.indexed.toList();
      _cardKeys = [
        for (final reference in references) _matchCardKey(reference, previous),
      ];
    }
    _previousReferences = references;
  }

  Key _matchCardKey(
    PreciseReference reference,
    List<(int, PreciseReference)> previous,
  ) {
    final match = previous.indexWhere((item) => identical(item.$2, reference));
    return match < 0 ? UniqueKey() : _cardKeys[previous.removeAt(match).$1];
  }

  Widget _buildBackground(List<PreciseReference> references) {
    Widget preview(PreciseReference reference) => DecodedMemoryImage(
      bytes: reference.image,
      fit: BoxFit.cover,
      decodeScale: 0.75,
    );

    if (references.length == 1) return preview(references.single);
    return Row(
      children: [
        for (final reference in references) Expanded(child: preview(reference)),
      ],
    );
  }

  Widget _buildCountBadge(int count, bool overImage) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: overImage
            ? Colors.white.withValues(alpha: 0.2)
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: overImage
              ? Colors.white
              : theme.colorScheme.onSecondaryContainer,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildCostBadge(bool overImage) {
    final l10n = context.l10n;
    final color = overImage ? Colors.white : Colors.orange.shade700;
    return Tooltip(
      message: l10n.preciseRef_costHint,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: overImage ? 0.9 : 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 12, color: color),
            const SizedBox(width: 2),
            Text(
              l10n.preciseRef_costBadge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelActions({
    required bool canAdd,
    required bool hasReferences,
  }) {
    final l10n = context.l10n;
    const minimumSize = Size(44, 44);
    final libraryButtonStyle = TextButton.styleFrom(minimumSize: minimumSize);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAddReferenceDropTarget(
          supportsPreciseReference: canAdd,
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(minimumSize: minimumSize),
            onPressed: canAdd ? _addReference : null,
            icon: Icon(
              _isFileDraggingOver ? Icons.file_download_rounded : Icons.add,
              size: 18,
            ),
            label: Text(
              _isFileDraggingOver
                  ? l10n.preciseRef_dropToAdd
                  : l10n.preciseRef_addReference,
            ),
          ),
        ),
        const SizedBox(height: 8),
        OverflowBar(
          spacing: 8,
          overflowSpacing: 4,
          alignment: MainAxisAlignment.center,
          overflowAlignment: OverflowBarAlignment.center,
          children: [
            TextButton.icon(
              key: const Key('precise-ref-panel-from-library'),
              style: libraryButtonStyle,
              onPressed: canAdd ? _importFromLibrary : null,
              icon: const Icon(Icons.photo_library_outlined, size: 16),
              label: Text(l10n.preciseRefLib_fromLibrary),
            ),
            TextButton.icon(
              key: const Key('precise-ref-panel-save-to-library'),
              style: libraryButtonStyle,
              onPressed: hasReferences ? _saveReferencesToLibrary : null,
              icon: const Icon(Icons.bookmark_add_outlined, size: 16),
              label: Text(l10n.preciseRefLib_saveCurrentToLibrary),
            ),
          ],
        ),
        if (hasReferences)
          TextButton.icon(
            onPressed: _clearAllReferences,
            icon: const Icon(Icons.clear_all, size: 18),
            label: Text(l10n.preciseRef_clearAll),
            style: TextButton.styleFrom(
              minimumSize: minimumSize,
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
  }

  Widget _buildAddReferenceDropTarget({
    required bool supportsPreciseReference,
    required Widget child,
  }) {
    if (!supportsPreciseReference) {
      return child;
    }

    return DropRegion(
      formats: cardDropFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        if (_isProcessingDroppedFiles) {
          return DropOperation.none;
        }
        if (event.session.allowedOperations.contains(DropOperation.copy) &&
            const CardDropPolicy().accepts(event.session.items)) {
          if (!_isFileDraggingOver) {
            setState(() => _isFileDraggingOver = true);
          }
          return DropOperation.copy;
        }
        return DropOperation.none;
      },
      onDropLeave: (_) {
        if (_isFileDraggingOver) {
          setState(() => _isFileDraggingOver = false);
        }
      },
      onPerformDrop: (event) {
        setState(() => _isFileDraggingOver = false);
        return releaseNativeDropCallback(
          () => _handleDroppedReferences(event),
          library: 'PreciseReferencePanel',
        );
      },
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: _isFileDraggingOver
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : null,
        ),
        child: child,
      ),
    );
  }

  /// 从精准参考库导入条目（套用条目记住的类型与参数）
  Future<void> _importFromLibrary() async {
    final selected = await PreciseRefSelectorDialog.show(context);
    if (selected == null || selected.isEmpty || !mounted) return;

    final storage = ref.read(preciseRefLibraryStorageServiceProvider);
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final libraryNotifier = ref.read(
      preciseRefLibraryNotifierProvider.notifier,
    );

    final futures = <Future<void>>[];
    var added = 0;
    for (final entry in selected) {
      final bytes = await storage.readImageBytes(entry.id);
      if (bytes == null) continue;
      futures.add(
        notifier.addPreciseReferenceFromImage(
          bytes,
          type: entry.type,
          preferSameOutfit: entry.preferSameOutfit,
          strength: entry.strength,
          fidelity: entry.fidelity,
        ),
      );
      unawaited(libraryNotifier.recordUsage(entry.id));
      added++;
    }
    await Future.wait(futures);

    if (!mounted) return;
    if (added > 0) {
      AppToast.success(context, context.l10n.preciseRef_addedCount(added));
    }
    if (added < selected.length) {
      AppToast.warning(context, context.l10n.preciseRefLib_imageMissing);
    }
  }

  /// 把单张参考图（含类型与参数）保存到精准参考库
  Future<void> _saveSingleReferenceToLibrary(PreciseReference reference) async {
    try {
      final entry = await ref
          .read(preciseRefLibraryNotifierProvider.notifier)
          .importFromBytes(
            reference.image,
            name: defaultPreciseRefName(),
            type: reference.type,
            preferSameOutfit: reference.preferSameOutfit,
            strength: reference.strength,
            fidelity: reference.fidelity,
          );
      if (!mounted) return;
      AppToast.success(context, context.l10n.preciseRefLib_saved(entry.name));
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, preciseRefImportErrorMessage(context, e));
    }
  }

  /// 把当前参考图（含各自类型与参数）保存到精准参考库
  Future<void> _saveReferencesToLibrary() async {
    final references = ref
        .read(generationParamsNotifierProvider)
        .preciseReferences;
    if (references.isEmpty) return;

    final PreciseRefLibraryBatchImportResult batch;
    try {
      batch = await ref
          .read(preciseRefLibraryNotifierProvider.notifier)
          .importMany([
            for (final reference in references)
              PreciseRefLibraryImportSource(
                loadBytes: () async => reference.image,
                name: defaultPreciseRefName(),
                type: reference.type,
                preferSameOutfit: reference.preferSameOutfit,
                strength: reference.strength,
                fidelity: reference.fidelity,
              ),
          ]);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, preciseRefImportErrorMessage(context, e));
      return;
    }

    if (!mounted) return;
    if (batch.importedCount > 0) {
      AppToast.success(
        context,
        context.l10n.preciseRefLib_saveCurrentCount(batch.importedCount),
      );
    }
    if (batch.failedCount > 0) {
      AppToast.error(
        context,
        context.l10n.preciseRefLib_importFailedCount(batch.failedCount),
      );
    }
  }

  Future<void> _addReference() async {
    // 先选择类型
    final selectedType = await PreciseReferenceTypeDialog.show(
      context,
      outfit: ref
          .read(generationParamsNotifierProvider)
          .capabilities
          .preciseReference
          .supportsOutfit,
    );
    if (selectedType == null) return; // 用户取消了类型选择

    try {
      final result = await pickImageFiles(allowMultiple: true);

      if (result != null && result.files.isNotEmpty) {
        final notifier = ref.read(generationParamsNotifierProvider.notifier);
        final addOperations = <Future<void>>[];

        for (final file in result.files) {
          final bytes = await _readPickedImageBytes(file);
          if (bytes == null) {
            continue;
          }

          addOperations.add(
            notifier.addPreciseReferenceFromImage(
              bytes,
              type: selectedType,
              strength: 1.0,
              fidelity: 1.0,
            ),
          );
        }

        await Future.wait(addOperations);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.img2img_selectFailed(e.toString()),
        );
      }
    }
  }

  Future<void> _handleDroppedReferences(PerformDropEvent event) async {
    if (_isProcessingDroppedFiles) return;
    setState(() => _isProcessingDroppedFiles = true);
    try {
      final resources = await readCardDrop(context, event.session.items);
      await _applyDroppedReferences(resources);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isProcessingDroppedFiles = false);
      AppToast.error(context, context.l10n.img2img_selectFailed('$error'));
    }
  }

  Future<void> _applyDroppedReferences(
    List<CardDroppedResource> resources,
  ) async {
    if (!mounted) return;
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final library = ref.read(preciseRefLibraryNotifierProvider.notifier);
    try {
      final needsType = resources.any(
        (resource) => resource.preciseReference == null,
      );
      final type = needsType
          ? await PreciseReferenceTypeDialog.show(
              context,
              outfit: ref
                  .read(generationParamsNotifierProvider)
                  .capabilities
                  .preciseReference
                  .supportsOutfit,
            )
          : null;
      if (!mounted || needsType && type == null) return;
      final result = await ImageCardBatchResult.execute(resources, (
        resource,
      ) async {
        final entry = resource.preciseReference;
        await notifier.addPreciseReferenceFromImage(
          resource.image.bytes,
          type: entry?.type ?? type!,
          preferSameOutfit: entry?.preferSameOutfit,
          strength: entry?.strength ?? 1,
          fidelity: entry?.fidelity ?? 1,
        );
        if (entry != null) await library.recordUsage(entry.id);
      });
      if (!mounted) return;
      if (result.failures.isNotEmpty) {
        throw StateError(
          '${result.failures.length}/${resources.length}: ${result.failures.values.map((failure) => failure.error).join('; ')}',
        );
      }
      AppToast.success(
        context,
        context.l10n.preciseRef_addedCount(result.succeeded.length),
      );
    } catch (error) {
      if (mounted) {
        AppToast.error(context, context.l10n.img2img_selectFailed('$error'));
      }
    } finally {
      if (mounted) setState(() => _isProcessingDroppedFiles = false);
    }
  }

  Future<Uint8List?> _readPickedImageBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes;
    }

    final path = file.path;
    if (path == null) {
      return null;
    }

    return File(path).readAsBytes();
  }

  void _removeReference(int index) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .removePreciseReference(index);
  }

  void _updateReferenceType(int index, PreciseRefType type) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updatePreciseReferenceType(index, type);
  }

  void _updateReferenceEnabled(int index, bool value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updatePreciseReference(index, enabled: value);
  }

  void _updateReferenceStrength(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updatePreciseReference(index, strength: value);
  }

  void _updateReferenceFidelity(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updatePreciseReference(index, fidelity: value);
  }

  void _clearAllReferences() {
    final params = ref.read(generationParamsNotifierProvider);
    final count = params.preciseReferences.length;

    ref
        .read(generationParamsNotifierProvider.notifier)
        .clearPreciseReferences();

    if (mounted && count > 0) {
      AppToast.success(context, context.l10n.preciseRef_removedCount(count));
    }
  }
}
