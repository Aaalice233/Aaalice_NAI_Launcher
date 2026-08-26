import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../services/provider_adapters/prompt_assistant_adapter.dart';

class PromptAssistantCustomDialogResult {
  const PromptAssistantCustomDialogResult({
    required this.userRequest,
    required this.images,
  });

  final String userRequest;
  final List<PromptAssistantImageInput> images;
}

class PromptAssistantCustomDialog extends StatefulWidget {
  const PromptAssistantCustomDialog({
    super.key,
    required this.currentPrompt,
    required this.allowImages,
  });

  final String currentPrompt;
  final bool allowImages;

  @override
  State<PromptAssistantCustomDialog> createState() =>
      _PromptAssistantCustomDialogState();
}

class _PromptAssistantCustomDialogState
    extends State<PromptAssistantCustomDialog> {
  static const int _maxImages = 4;

  final TextEditingController _requestController = TextEditingController();
  final List<PromptAssistantImageInput> _images = [];
  String? _error;

  @override
  void dispose() {
    _requestController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (!widget.allowImages) {
      setState(() => _error = context.l10n.promptAssistant_imageInputDisabled);
      return;
    }
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) {
      setState(
        () => _error = context.l10n.promptAssistant_maxReferenceImages(
          _maxImages,
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;

    final next = <PromptAssistantImageInput>[];
    for (final file in result.files.take(remaining)) {
      final bytes = await _readBytes(file);
      if (bytes == null) continue;
      final mimeType = detectImageMime(bytes);
      if (mimeType == null) {
        setState(
          () => _error = context.l10n.promptAssistant_unsupportedImageFormat(
            file.name,
          ),
        );
        continue;
      }
      next.add(
        PromptAssistantImageInput(
          name: file.name,
          bytes: bytes,
          mimeType: mimeType,
        ),
      );
    }

    if (next.isNotEmpty) {
      setState(() {
        _images.addAll(next);
        _error = null;
      });
    }
  }

  Future<Uint8List?> _readBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes;
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    return File(path).readAsBytes();
  }

  void _submit() {
    final request = _requestController.text.trim();
    if (request.isEmpty && _images.isEmpty) {
      setState(
        () => _error = context.l10n.promptAssistant_needCustomRequestOrImage,
      );
      return;
    }
    Navigator.pop(
      context,
      PromptAssistantCustomDialogResult(
        userRequest: request,
        images: List.unmodifiable(_images),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.promptAssistant_customDialogTitle),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.promptAssistant_currentPrompt,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 100),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.currentPrompt.trim().isEmpty
                        ? context.l10n.promptAssistant_currentPromptEmpty
                        : widget.currentPrompt.trim(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _requestController,
                maxLines: 6,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.promptAssistant_customRequestLabel,
                  hintText: context.l10n.promptAssistant_customRequestHint,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: widget.allowImages ? _pickImages : null,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(context.l10n.promptAssistant_addReferenceImage),
                  ),
                  const SizedBox(width: 8),
                  Text('${_images.length}/$_maxImages'),
                  if (!widget.allowImages) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.promptAssistant_imageInputDisabled,
                      ),
                    ),
                  ],
                ],
              ),
              if (_images.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _images.length; i++)
                      _ImageChip(
                        image: _images[i],
                        onRemove: () {
                          setState(() => _images.removeAt(i));
                        },
                      ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(context.l10n.promptAssistant_execute),
        ),
      ],
    );
  }
}

class _ImageChip extends StatelessWidget {
  const _ImageChip({required this.image, required this.onRemove});

  final PromptAssistantImageInput image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            image.bytes,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Tooltip(
            message: context.l10n.common_delete,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(24),
                child: SizedBox.square(
                  dimension: 48,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
