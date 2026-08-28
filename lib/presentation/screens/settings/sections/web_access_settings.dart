import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/web_access/web_access_models.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../prompt_assistant/providers/web_access_provider.dart';

class WebAccessSettings extends ConsumerStatefulWidget {
  const WebAccessSettings({super.key});

  @override
  ConsumerState<WebAccessSettings> createState() => _WebAccessSettingsState();
}

class _WebAccessSettingsState extends ConsumerState<WebAccessSettings> {
  late final TextEditingController _searxngController;
  final FocusNode _searxngFocus = FocusNode();
  Timer? _saveDebounce;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _searxngController = TextEditingController(
      text: ref.read(webAccessConfigProvider).config.searxngBaseUrl,
    );
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _searxngController.dispose();
    _searxngFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(webAccessConfigProvider);
    final config = state.config;
    final notifier = ref.read(webAccessConfigProvider.notifier);
    ref.listen<WebAccessConfigState>(webAccessConfigProvider, (previous, next) {
      if (_searxngFocus.hasFocus) return;
      final nextUrl = next.config.searxngBaseUrl;
      if (_searxngController.text != nextUrl) {
        _searxngController.text = nextUrl;
      }
    });

    final counts = <int>{3, 5, 8, 10, config.defaultResultCount}.toList()
      ..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const Icon(Icons.public_outlined),
          title: Text(context.l10n.promptAssistant_webAccessTitle),
          subtitle: Text(context.l10n.promptAssistant_webAccessSubtitle),
        ),
        SwitchListTile(
          value: config.enabled,
          title: Text(context.l10n.promptAssistant_webAccessEnable),
          subtitle: Text(context.l10n.promptAssistant_webAccessEnableSubtitle),
          onChanged: notifier.setEnabled,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: config.enabled
              ? Padding(
                  key: const ValueKey('web-access-settings-enabled'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final modeField =
                              DropdownButtonFormField<WebSearchMode>(
                                initialValue: config.mode,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: context
                                      .l10n
                                      .promptAssistant_webAccessBackend,
                                ),
                                items: [
                                  for (final mode in WebSearchMode.values)
                                    DropdownMenuItem(
                                      value: mode,
                                      child: Text(_modeLabel(context, mode)),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value != null) notifier.setMode(value);
                                },
                              );
                          final countField = DropdownButtonFormField<int>(
                            initialValue: config.defaultResultCount,
                            decoration: InputDecoration(
                              labelText: context
                                  .l10n
                                  .promptAssistant_webAccessResultCount,
                            ),
                            items: [
                              for (final count in counts)
                                DropdownMenuItem(
                                  value: count,
                                  child: Text('$count'),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                notifier.setDefaultResultCount(value);
                              }
                            },
                          );
                          if (constraints.maxWidth < 620) {
                            return Column(
                              children: [
                                modeField,
                                const SizedBox(height: 12),
                                countField,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: modeField),
                              const SizedBox(width: 12),
                              Expanded(child: countField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _modeDescription(context, config.mode),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (config.mode == WebSearchMode.auto ||
                          config.mode == WebSearchMode.searxng) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searxngController,
                          focusNode: _searxngFocus,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            labelText: context
                                .l10n
                                .promptAssistant_webAccessSearxngUrl,
                            hintText: 'http://127.0.0.1:8080',
                            prefixIcon: const Icon(Icons.dns_outlined),
                          ),
                          onChanged: (value) {
                            _saveDebounce?.cancel();
                            _saveDebounce = Timer(
                              const Duration(milliseconds: 500),
                              () => notifier.setSearxngBaseUrl(value),
                            );
                          },
                          onSubmitted: notifier.setSearxngBaseUrl,
                        ),
                      ],
                      if (config.mode == WebSearchMode.exaApi) ...[
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            state.hasExaApiKey
                                ? Icons.key_outlined
                                : Icons.key_off_outlined,
                          ),
                          title: Text(
                            context.l10n.promptAssistant_webAccessExaApiKey,
                          ),
                          subtitle: Text(
                            state.hasExaApiKey
                                ? context
                                      .l10n
                                      .promptAssistant_webAccessApiKeyConfigured
                                : context
                                      .l10n
                                      .promptAssistant_webAccessApiKeyMissing,
                          ),
                          trailing: TextButton.icon(
                            onPressed: () => _showApiKeyDialog(
                              notifier,
                              hasKey: state.hasExaApiKey,
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(
                              context
                                  .l10n
                                  .promptAssistant_webAccessConfigureKey,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: _testing ? null : _testConnection,
                          icon: _testing
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.network_check, size: 18),
                          label: Text(
                            _testing
                                ? context.l10n.promptAssistant_webAccessTesting
                                : context
                                      .l10n
                                      .promptAssistant_webAccessTestConnection,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(
                  key: ValueKey('web-access-settings-disabled'),
                ),
        ),
      ],
    );
  }

  Future<void> _testConnection() async {
    _saveDebounce?.cancel();
    await ref
        .read(webAccessConfigProvider.notifier)
        .setSearxngBaseUrl(_searxngController.text);
    if (!mounted) return;
    setState(() => _testing = true);
    try {
      final config = ref.read(webAccessConfigProvider).config;
      final result = await ref
          .read(webAccessGatewayProvider)
          .testConnection(config);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.promptAssistant_webAccessTestSucceeded(
              _backendLabel(context, result.backend),
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.promptAssistant_webAccessTestFailed('$error'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _showApiKeyDialog(
    WebAccessConfigNotifier notifier, {
    required bool hasKey,
  }) async {
    final controller = TextEditingController();
    final action = await showDialog<_ApiKeyAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.promptAssistant_webAccessExaApiKey),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              labelText: context.l10n.promptAssistant_webAccessExaApiKey,
              hintText: hasKey
                  ? context.l10n.promptAssistant_apiKeyLeaveEmpty
                  : null,
            ),
          ),
        ),
        actions: [
          if (hasKey)
            TextButton(
              onPressed: () => Navigator.pop(context, _ApiKeyAction.clear),
              child: Text(context.l10n.promptAssistant_webAccessClearKey),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _ApiKeyAction.save),
            child: Text(context.l10n.common_save),
          ),
        ],
      ),
    );
    try {
      if (action == _ApiKeyAction.clear) {
        await notifier.setExaApiKey('');
      } else if (action == _ApiKeyAction.save &&
          controller.text.trim().isNotEmpty) {
        await notifier.setExaApiKey(controller.text);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('${context.l10n.common_error}: $error')),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  String _modeLabel(BuildContext context, WebSearchMode mode) => switch (mode) {
    WebSearchMode.auto => context.l10n.promptAssistant_webAccessBackendAuto,
    WebSearchMode.searxng =>
      context.l10n.promptAssistant_webAccessBackendSearxng,
    WebSearchMode.exaMcp => context.l10n.promptAssistant_webAccessBackendExaMcp,
    WebSearchMode.exaApi => context.l10n.promptAssistant_webAccessBackendExaApi,
  };

  String _modeDescription(BuildContext context, WebSearchMode mode) =>
      switch (mode) {
        WebSearchMode.auto =>
          context.l10n.promptAssistant_webAccessBackendAutoDescription,
        WebSearchMode.searxng =>
          context.l10n.promptAssistant_webAccessBackendSearxngDescription,
        WebSearchMode.exaMcp =>
          context.l10n.promptAssistant_webAccessBackendExaMcpDescription,
        WebSearchMode.exaApi =>
          context.l10n.promptAssistant_webAccessBackendExaApiDescription,
      };

  String _backendLabel(BuildContext context, WebSearchBackend backend) =>
      switch (backend) {
        WebSearchBackend.searxng =>
          context.l10n.promptAssistant_webAccessBackendSearxng,
        WebSearchBackend.exaMcp =>
          context.l10n.promptAssistant_webAccessBackendExaMcp,
        WebSearchBackend.exaApi =>
          context.l10n.promptAssistant_webAccessBackendExaApi,
        WebSearchBackend.localReader => 'Local reader',
      };
}

enum _ApiKeyAction { save, clear }
