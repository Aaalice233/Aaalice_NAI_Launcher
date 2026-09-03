import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../../core/platform/platform_capabilities.dart';
import '../../../../data/models/character/character_prompt.dart';
import '../../../../data/services/local_onnx_model_service.dart';
import '../../../providers/generation/generation_panel_expansion_provider.dart';
import '../../../providers/generation/generation_params_notifier.dart';
import '../../../providers/reverse_prompt_provider.dart';
import '../../../providers/tag_library_page_provider.dart';
import '../../../prompt_assistant/providers/prompt_assistant_history_provider.dart';
import '../../../utils/asset_protection_guard.dart';
import '../../../utils/dropped_file_reader.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/translated_tag_text.dart';
import '../../../widgets/common/collapsible_image_panel.dart';
import '../../../widgets/common/decoded_memory_image.dart';
import '../../../widgets/common/themed_divider.dart';
import '../../../widgets/tag_library/tag_library_picker_dialog.dart';

class ReversePromptPanel extends ConsumerStatefulWidget {
  const ReversePromptPanel({super.key});

  @override
  ConsumerState<ReversePromptPanel> createState() => _ReversePromptPanelState();
}

class _ReversePromptPanelState extends ConsumerState<ReversePromptPanel> {
  static const _panel = GenerationWorkbenchPanel.reversePrompt;

  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(reversePromptProvider);
    final isExpanded = ref.watch(
      generationPanelExpansionProvider.select(
        (value) => value.isExpanded(_panel),
      ),
    );
    final hasImages = state.images.isNotEmpty;
    final showBackground = hasImages && !isExpanded;

    return CollapsibleImagePanel(
      title: context.l10n.reversePrompt_title,
      icon: Icons.manage_search_rounded,
      isExpanded: isExpanded,
      onToggle: () => unawaited(
        ref.read(generationPanelExpansionProvider.notifier).toggle(_panel),
      ),
      hasData: hasImages || state.finalPrompt.isNotEmpty,
      backgroundImage: showBackground
          ? DecodedMemoryImage(
              bytes: state.images.first.bytes,
              fit: BoxFit.cover,
              decodeScale: 0.75,
            )
          : null,
      badge: hasImages ? _buildBadge(context, state, showBackground) : null,
      childBuilder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ThemedDivider(),
            _buildDropArea(state),
            if (hasImages) ...[
              const SizedBox(height: 10),
              _buildImageStrip(state),
            ],
            const SizedBox(height: 12),
            _buildChainToggles(state),
            if (state.useOnnxTagger) ...[
              const SizedBox(height: 8),
              _buildTaggerControls(state),
            ],
            if (state.useCharacterReplace) ...[
              const SizedBox(height: 8),
              _buildCharacterSelector(state),
            ],
            const SizedBox(height: 12),
            _buildActions(state),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                _localizedError(state.error!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (state.taggerPrompt.isNotEmpty) ...[
              const SizedBox(height: 12),
              _PromptOutputBlock(
                title: 'ONNX tagger',
                text: state.taggerPrompt,
              ),
            ],
            if (state.llmPrompt.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PromptOutputBlock(
                title: context.l10n.reversePrompt_llmReverse,
                text: state.llmPrompt,
              ),
            ],
            if (state.characterReplacePrompt.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PromptOutputBlock(
                title: context.l10n.reversePrompt_characterReplace,
                text: state.characterReplacePrompt,
              ),
            ],
            if (state.finalPrompt.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PromptOutputBlock(
                title: context.l10n.reversePrompt_finalResult,
                text: state.finalPrompt,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(
    BuildContext context,
    ReversePromptState state,
    bool showBackground,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: showBackground
            ? Colors.white.withValues(alpha: 0.2)
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        context.l10n.reversePrompt_imageCount(state.images.length),
        style: theme.textTheme.labelSmall?.copyWith(
          color: showBackground
              ? Colors.white
              : theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _buildDropArea(ReversePromptState state) {
    final button = FilledButton.tonalIcon(
      onPressed: state.isProcessing ? null : _pickImages,
      icon: Icon(
        _isDragging ? Icons.file_download_rounded : Icons.add_photo_alternate,
        size: 18,
      ),
      label: Text(
        _isDragging
            ? context.l10n.reversePrompt_dropToAdd
            : context.l10n.reversePrompt_addOrDropImages,
      ),
    );
    if (!PlatformCapabilities.current.supportsExternalFileDrop) return button;

    return DropRegion(
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        if (event.session.allowedOperations.contains(DropOperation.copy)) {
          if (!_isDragging) {
            setState(() => _isDragging = true);
          }
          return DropOperation.copy;
        }
        return DropOperation.none;
      },
      onDropLeave: (_) {
        if (_isDragging) {
          setState(() => _isDragging = false);
        }
      },
      onPerformDrop: (event) async {
        setState(() => _isDragging = false);
        unawaited(_handleDrop(event));
      },
      child: button,
    );
  }

  Widget _buildImageStrip(ReversePromptState state) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final image = state.images[index];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 74,
                  height: 74,
                  child: DecodedMemoryImage(
                    bytes: image.bytes,
                    fit: BoxFit.cover,
                    decodeScale: 0.75,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: InkWell(
                  onTap: () => ref
                      .read(reversePromptProvider.notifier)
                      .removeImage(image.id),
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox.square(
                    dimension: 48,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.all(2),
                        // 固定深色底必须搭配固定浅色图标，避免浅色主题下失去对比。
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChainToggles(ReversePromptState state) {
    final notifier = ref.read(reversePromptProvider.notifier);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        FilterChip(
          label: const Text('ONNX tagger'),
          selected: state.useOnnxTagger,
          onSelected: state.isProcessing ? null : notifier.setUseOnnxTagger,
        ),
        FilterChip(
          label: Text(context.l10n.reversePrompt_llmReverse),
          selected: state.useLlmReverse,
          onSelected: state.isProcessing ? null : notifier.setUseLlmReverse,
        ),
        FilterChip(
          label: Text(context.l10n.reversePrompt_characterReplace),
          selected: state.useCharacterReplace,
          onSelected: state.isProcessing
              ? null
              : notifier.setUseCharacterReplace,
        ),
      ],
    );
  }

  Widget _buildTaggerControls(ReversePromptState state) {
    return FutureBuilder<List<LocalOnnxModelDescriptor>>(
      future: ref.read(localOnnxModelServiceProvider).scanTaggerModels(),
      builder: (context, snapshot) {
        final models = snapshot.data ?? const <LocalOnnxModelDescriptor>[];
        final selected =
            models.any((m) => m.path == state.selectedTaggerModelPath)
            ? state.selectedTaggerModelPath
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selected,
              isExpanded: true,
              items: models
                  .map(
                    (model) => DropdownMenuItem(
                      value: model.path,
                      child: Text(model.name),
                    ),
                  )
                  .toList(),
              onChanged: state.isProcessing
                  ? null
                  : ref
                        .read(reversePromptProvider.notifier)
                        .setSelectedTaggerModelPath,
              decoration: InputDecoration(
                labelText: context.l10n.reversePrompt_localTaggerModel,
                hintText: context.l10n.reversePrompt_localTaggerModelHint,
                isDense: true,
              ),
            ),
            const SizedBox(height: 6),
            _ThresholdSlider(
              label: context.l10n.reversePrompt_generalThreshold,
              value: state.taggerGeneralThreshold,
              onChanged: state.isProcessing
                  ? null
                  : ref
                        .read(reversePromptProvider.notifier)
                        .setTaggerGeneralThreshold,
            ),
            _ThresholdSlider(
              label: context.l10n.reversePrompt_characterThreshold,
              value: state.taggerCharacterThreshold,
              onChanged: state.isProcessing
                  ? null
                  : ref
                        .read(reversePromptProvider.notifier)
                        .setTaggerCharacterThreshold,
            ),
            Text(
              context.l10n.reversePrompt_taggerFilterHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCharacterSelector(ReversePromptState state) {
    final selectedCharacter = ref
        .watch(reversePromptCharacterProvider)
        .characters
        .where((c) => c.enabled && c.prompt.trim().isNotEmpty)
        .cast<CharacterPrompt?>()
        .firstWhere((_) => true, orElse: () => null);
    if (selectedCharacter == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.reversePrompt_replacementEmptyHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: state.isProcessing
                  ? null
                  : _selectReverseCharacterFromLibrary,
              icon: const Icon(Icons.library_books_outlined, size: 18),
              label: Text(
                context.l10n.reversePrompt_selectReplacementCharacter,
              ),
            ),
          ),
        ],
      );
    }

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.person_search_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedCharacter.name,
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TranslatedPromptText(
            selectedCharacter.prompt,
            selectable: false,
            maxLines: 2,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: state.isProcessing
                    ? null
                    : _selectReverseCharacterFromLibrary,
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: Text(context.l10n.reversePrompt_change),
              ),
              TextButton.icon(
                onPressed: state.isProcessing
                    ? null
                    : ref
                          .read(reversePromptCharacterProvider.notifier)
                          .clearReplacementCharacter,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text(context.l10n.common_clear),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectReverseCharacterFromLibrary() async {
    final entry = await TagLibraryPickerDialog.show(
      context,
      title: context.l10n.reversePrompt_selectReplacementTargetTitle,
    );

    if (entry == null) {
      return;
    }

    ref.read(tagLibraryPageNotifierProvider.notifier).recordUsage(entry.id);
    ref
        .read(reversePromptCharacterProvider.notifier)
        .setReplacementCharacter(
          CharacterPrompt.create(
            name: entry.displayName,
            prompt: entry.content,
            thumbnailPath: entry.thumbnail,
          ),
        );
  }

  Widget _buildActions(ReversePromptState state) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: state.isProcessing || !state.canRun
                ? null
                : () => _runChainWithProtection(state),
            icon: state.isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(
              state.processingStage == null
                  ? context.l10n.reversePrompt_start
                  : _localizedProcessingStage(state.processingStage!),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: state.finalPrompt.trim().isEmpty
              ? null
              : () {
                  final prompt = state.finalPrompt.trim();
                  final currentPrompt = ref
                      .read(generationParamsNotifierProvider)
                      .prompt;
                  ref
                      .read(promptAssistantHistoryProvider.notifier)
                      .recordExternalChange(
                        PromptHistorySessionIds.generationPrompt,
                        before: currentPrompt,
                        after: prompt,
                      );
                  ref
                      .read(generationParamsNotifierProvider.notifier)
                      .updatePrompt(prompt);
                  AppToast.success(
                    context,
                    context.l10n.reversePrompt_sentToPrompt,
                  );
                },
          icon: const Icon(Icons.send_rounded, size: 18),
          label: Text(context.l10n.reversePrompt_sendToPrompt),
        ),
      ],
    );
  }

  Future<void> _runChainWithProtection(ReversePromptState state) async {
    if (state.useLlmReverse) {
      final confirmed = await AssetProtectionGuard.confirmExternalImageSend(
        context: context,
        ref: ref,
        targetName: context.l10n.reversePrompt_externalTarget,
        imageCount: state.images.length,
      );
      if (!confirmed || !mounted) {
        return;
      }
    }
    await ref.read(reversePromptProvider.notifier).runChain();
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: false,
    );
    if (result == null) {
      return;
    }
    for (final file in result.files) {
      final path = file.path;
      if (path == null) {
        continue;
      }
      final bytes = await File(path).readAsBytes();
      await ref
          .read(reversePromptProvider.notifier)
          .addImage(bytes, name: file.name);
    }
  }

  Future<void> _handleDrop(PerformDropEvent event) async {
    var handledAny = false;
    for (final item in event.session.items) {
      final reader = item.dataReader;
      if (reader == null) {
        continue;
      }
      final file = await DroppedFileReader.read(
        reader,
        logTag: 'ReversePromptDrop',
      );
      if (file != null) {
        handledAny = true;
        await ref
            .read(reversePromptProvider.notifier)
            .addImage(file.bytes, name: file.fileName);
      }
    }
    if (!handledAny && mounted) {
      AppToast.warning(context, context.l10n.reversePrompt_dropUnreadable);
    }
  }

  String _localizedProcessingStage(ReversePromptProcessingStage stage) {
    return switch (stage) {
      ReversePromptProcessingStage.preparing =>
        context.l10n.reversePrompt_stagePreparing,
      ReversePromptProcessingStage.onnxTagger =>
        context.l10n.reversePrompt_stageOnnxTagger,
      ReversePromptProcessingStage.llmReverse =>
        context.l10n.reversePrompt_stageLlmReverse,
      ReversePromptProcessingStage.characterReplace =>
        context.l10n.reversePrompt_stageCharacterReplace,
    };
  }

  String _localizedError(String error) {
    return switch (error) {
      'reversePrompt_needImageAndMethod' =>
        context.l10n.reversePrompt_needImageAndMethod,
      'reversePrompt_needReplacementCharacter' =>
        context.l10n.reversePrompt_needReplacementCharacter,
      'reversePrompt_needPromptForCharacterReplace' =>
        context.l10n.reversePrompt_needPromptForCharacterReplace,
      'reversePrompt_noOnnxModel' => context.l10n.reversePrompt_noOnnxModel,
      _ => error,
    };
  }
}

class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 104, child: Text('$label ${value.toStringAsFixed(2)}')),
        Expanded(
          child: Slider(
            value: value,
            min: 0.05,
            max: 0.95,
            divisions: 18,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _PromptOutputBlock extends StatelessWidget {
  const _PromptOutputBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          TranslatedPromptText(text, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
