import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../../prompt_assistant/providers/provider_remote_models_provider.dart';
import '../../../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/settings_card.dart';

/// 地址与密钥在失焦、回车、切换服务商或离开页面时提交；密钥只写入安全存储，不回显。
class ProviderConnectionCard extends ConsumerStatefulWidget {
  const ProviderConnectionCard({super.key, required this.provider});

  final ProviderConfig provider;

  @override
  ConsumerState<ProviderConnectionCard> createState() =>
      _ProviderConnectionCardState();
}

class _ProviderConnectionCardState
    extends ConsumerState<ProviderConnectionCard> {
  final _keyController = TextEditingController();
  final _urlController = TextEditingController();
  final _keyFocus = FocusNode();
  final _urlFocus = FocusNode();
  // dispose 时不能再读 ref，提交所需句柄在 initState 先取好。
  late final PromptAssistantConfigNotifier _config;
  late final ProviderRemoteModelsNotifier _remote;
  late String _providerId;
  late String _committedUrl;
  var _obscureKey = true;
  var _checking = false;

  @override
  void initState() {
    super.initState();
    _config = ref.read(promptAssistantConfigProvider.notifier);
    _remote = ref.read(providerRemoteModelsProvider.notifier);
    _bind(widget.provider);
    _keyFocus.addListener(() {
      if (!_keyFocus.hasFocus) _commit();
    });
    _urlFocus.addListener(() {
      if (!_urlFocus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant ProviderConnectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider.id != widget.provider.id) {
      _commit(deferred: true);
      _bind(widget.provider);
    } else if (widget.provider.baseUrl != _committedUrl &&
        !_urlFocus.hasFocus) {
      _committedUrl = widget.provider.baseUrl;
      _urlController.text = _committedUrl;
    }
  }

  @override
  void dispose() {
    _commit(deferred: true);
    _keyController.dispose();
    _urlController.dispose();
    _keyFocus.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  void _bind(ProviderConfig provider) {
    _providerId = provider.id;
    _committedUrl = provider.baseUrl;
    _urlController.text = provider.baseUrl;
    _keyController.clear();
    _obscureKey = true;
  }

  /// 同步取出待提交的值；生命周期回调里改 provider 会触发 Riverpod 断言，那里推迟到本帧之后再写。
  Future<void> _commit({bool deferred = false}) {
    final providerId = _providerId;
    final key = _keyController.text.trim();
    final url = _urlController.text.trim();
    final urlChanged = url != _committedUrl;
    if (key.isEmpty && !urlChanged) return Future.value();
    _keyController.clear();
    _committedUrl = url;
    final config = _config;
    final remote = _remote;
    Future<void> write() async {
      if (key.isNotEmpty) await config.setProviderApiKey(providerId, key);
      if (urlChanged) await config.setProviderBaseUrl(providerId, url);
      remote.forget(providerId);
    }

    return deferred ? Future.microtask(write) : write();
  }

  Future<void> _clearKey() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await ThemedConfirmDialog.showDelete(
      context: context,
      itemName: l10n.modelServices_apiKey,
    );
    if (!confirmed) return;
    _keyController.clear();
    await _config.setProviderApiKey(_providerId, '');
    _remote.forget(_providerId);
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.modelServices_apiKeyCleared)),
    );
  }

  Future<void> _checkConnection() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final providerId = _providerId;
    setState(() => _checking = true);
    try {
      await _commit();
      final models = await _remote.fetch(providerId);
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.modelServices_connectionOk(models.length))),
      );
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.modelServices_connectionFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final provider = widget.provider;
    final hasKey = ref.watch(
      promptAssistantConfigProvider.select(
        (state) => state.providerHasApiKey[provider.id] ?? false,
      ),
    );
    final keyOptional = !(provider.preset?.requiresApiKey ?? true);

    return SettingsCard(
      key: const ValueKey('model-services-connection-card'),
      title: l10n.modelServices_connection,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('model-services-api-key'),
              controller: _keyController,
              focusNode: _keyFocus,
              obscureText: _obscureKey,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _commit(),
              decoration: InputDecoration(
                labelText: l10n.modelServices_apiKey,
                hintText: hasKey
                    ? l10n.modelServices_apiKeySavedHint
                    : keyOptional
                    ? l10n.modelServices_apiKeyOptional
                    : null,
                floatingLabelBehavior: hasKey || keyOptional
                    ? FloatingLabelBehavior.always
                    : null,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _obscureKey
                          ? l10n.modelServices_showApiKey
                          : l10n.modelServices_hideApiKey,
                      icon: Icon(
                        _obscureKey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                    ),
                    if (hasKey)
                      IconButton(
                        key: const ValueKey('model-services-clear-api-key'),
                        tooltip: l10n.modelServices_clearApiKey,
                        icon: const Icon(Icons.key_off_outlined),
                        onPressed: _clearKey,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('model-services-base-url'),
              controller: _urlController,
              focusNode: _urlFocus,
              keyboardType: TextInputType.url,
              autocorrect: false,
              onSubmitted: (_) => _commit(),
              decoration: InputDecoration(
                labelText: l10n.modelServices_baseUrl,
                hintText: l10n.promptAssistant_baseUrlHint,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  [
                    provider.protocol.label,
                    provider.allowImageInput
                        ? l10n.promptAssistant_supportsImageInput
                        : l10n.promptAssistant_textOnly,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('model-services-check-connection'),
                  onPressed: _checking ? null : _checkConnection,
                  icon: _checking
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check_rounded),
                  label: Text(l10n.modelServices_checkConnection),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
