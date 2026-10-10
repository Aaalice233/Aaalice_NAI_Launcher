import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../../adaptive/content_sized_adaptive_form.dart';
import '../../../../prompt_assistant/models/assistant_model_capability.dart';
import '../../widgets/settings_form_footer.dart';

typedef ProviderModelFormResult = ({String id, String displayName});

/// 传入 [model] 时只改显示名；模型 ID 是路由和请求的依据，编辑时不可改。
class ProviderModelForm extends StatefulWidget {
  const ProviderModelForm({
    super.key,
    required this.provider,
    required this.existingIds,
    required this.scrollController,
    this.model,
  });

  final ProviderConfig provider;
  final Set<String> existingIds;
  final ScrollController scrollController;
  final ModelConfig? model;

  @override
  State<ProviderModelForm> createState() => _ProviderModelFormState();
}

class _ProviderModelFormState extends State<ProviderModelForm> {
  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  String? _idError;

  bool get _editing => widget.model != null;

  @override
  void initState() {
    super.initState();
    final model = widget.model;
    _idController = TextEditingController(text: model?.name ?? '');
    final custom = model?.displayName.trim() ?? '';
    _nameController = TextEditingController(
      text: custom == model?.name ? '' : custom,
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _fallbackName(String id) =>
      AssistantModelCatalog.catalogDisplayName(
        provider: widget.provider,
        model: id,
      ) ??
      id;

  void _save() {
    final l10n = context.l10n;
    final id = _idController.text.trim();
    final error = id.isEmpty
        ? l10n.modelServices_modelIdRequired
        : !_editing && widget.existingIds.contains(id)
        ? l10n.modelServices_modelExists
        : null;
    if (error != null) {
      setState(() => _idError = error);
      return;
    }
    Navigator.pop<ProviderModelFormResult>(context, (
      id: id,
      displayName: _nameController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final id = _idController.text.trim();
    return ContentSizedAdaptiveForm(
      key: const ValueKey('model-services-model-form'),
      scrollController: widget.scrollController,
      content: [
        TextField(
          key: const ValueKey('model-services-model-id'),
          controller: _idController,
          enabled: !_editing,
          autofocus: !_editing,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.modelServices_modelId,
            hintText: 'deepseek-flash',
            errorText: _idError,
          ),
          onChanged: (_) => setState(() => _idError = null),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('model-services-model-display-name'),
          controller: _nameController,
          autofocus: _editing,
          decoration: InputDecoration(
            labelText: l10n.modelServices_displayName,
            hintText: id.isEmpty
                ? null
                : l10n.modelServices_displayNameHint(_fallbackName(id)),
          ),
          onSubmitted: (_) => _save(),
        ),
      ],
      footer: SettingsFormFooter(onSave: _save),
    );
  }
}
