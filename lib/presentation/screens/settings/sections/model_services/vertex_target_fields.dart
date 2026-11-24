import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../../../data/models/prompt_assistant/vertex_target.dart';
import '../../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../../prompt_assistant/providers/provider_remote_models_provider.dart';

/// Vertex 的项目 ID 与区域；与连接卡片一致，在失焦、回车、切换服务商或离开页面时提交。
class VertexTargetFields extends ConsumerStatefulWidget {
  const VertexTargetFields({super.key, required this.provider});

  final ProviderConfig provider;

  @override
  ConsumerState<VertexTargetFields> createState() => _VertexTargetFieldsState();
}

class _VertexTargetFieldsState extends ConsumerState<VertexTargetFields> {
  final _projectController = TextEditingController();
  final _locationController = TextEditingController();
  final _projectFocus = FocusNode();
  final _locationFocus = FocusNode();
  late final PromptAssistantConfigNotifier _config;
  late final ProviderRemoteModelsNotifier _remote;
  late String _providerId;
  late VertexTarget _committed;
  var _invalidLocation = false;

  @override
  void initState() {
    super.initState();
    _config = ref.read(promptAssistantConfigProvider.notifier);
    _remote = ref.read(providerRemoteModelsProvider.notifier);
    _bind(widget.provider);
    for (final focus in [_projectFocus, _locationFocus]) {
      focus.addListener(() {
        if (!focus.hasFocus) _commit();
      });
    }
  }

  @override
  void didUpdateWidget(covariant VertexTargetFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider.id != widget.provider.id) {
      _commit(deferred: true);
      _bind(widget.provider);
      return;
    }
    // 导入凭据会补上项目 ID，外部写入时同步到未在编辑的输入框。
    final target = widget.provider.vertexTarget;
    if (target == _committed) return;
    _committed = target;
    if (!_projectFocus.hasFocus) _projectController.text = target.projectId;
    if (!_locationFocus.hasFocus) _locationController.text = target.location;
  }

  @override
  void dispose() {
    _commit(deferred: true);
    _projectController.dispose();
    _locationController.dispose();
    _projectFocus.dispose();
    _locationFocus.dispose();
    super.dispose();
  }

  void _bind(ProviderConfig provider) {
    _providerId = provider.id;
    _committed = provider.vertexTarget;
    _projectController.text = _committed.projectId;
    _locationController.text = _committed.location;
    _invalidLocation = false;
  }

  /// 区域非法时不提交，保留输入供用户修改。
  Future<void> _commit({bool deferred = false}) {
    final location = _locationController.text.trim();
    final validLocation =
        location.isEmpty || VertexTarget.isValidLocation(location);
    if (!deferred && mounted && validLocation == _invalidLocation) {
      setState(() => _invalidLocation = !validLocation);
    }
    final next = VertexTarget(
      projectId: _projectController.text.trim(),
      location: validLocation ? location : _committed.location,
    );
    if (next == _committed) return Future.value();
    _committed = next;
    final providerId = _providerId;
    final config = _config;
    final remote = _remote;
    Future<void> write() async {
      await config.setVertexTarget(providerId, next);
      remote.forget(providerId);
    }

    return deferred ? Future.microtask(write) : write();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('model-services-vertex-project'),
          controller: _projectController,
          focusNode: _projectFocus,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => _commit(),
          decoration: InputDecoration(
            labelText: l10n.modelServices_vertexProjectId,
            hintText: l10n.modelServices_vertexProjectIdHint,
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('model-services-vertex-location'),
          controller: _locationController,
          focusNode: _locationFocus,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => _commit(),
          decoration: InputDecoration(
            labelText: l10n.modelServices_vertexLocation,
            hintText: l10n.modelServices_vertexLocationHint,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            errorText: _invalidLocation
                ? l10n.modelServices_vertexLocationInvalid
                : null,
            errorMaxLines: 3,
          ),
        ),
      ],
    );
  }
}
