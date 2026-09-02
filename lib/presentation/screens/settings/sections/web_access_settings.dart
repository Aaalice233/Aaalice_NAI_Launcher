import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/web_access/web_access_models.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../prompt_assistant/providers/web_access_provider.dart';

class WebAccessSettings extends ConsumerStatefulWidget {
  const WebAccessSettings({
    super.key,
    this.showEnableControl = true,
    this.enabled,
  });

  final bool showEnableControl;
  final bool? enabled;

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
    final enabled = widget.enabled ?? config.enabled;
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
        if (widget.showEnableControl) ...[
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.public_outlined),
            title: Text(context.l10n.promptAssistant_webAccessTitle),
            subtitle: Text(context.l10n.promptAssistant_webAccessSubtitle),
          ),
          SwitchListTile(
            value: enabled,
            title: Text(context.l10n.promptAssistant_webAccessEnable),
            subtitle: Text(
              context.l10n.promptAssistant_webAccessEnableSubtitle,
            ),
            onChanged: notifier.setEnabled,
          ),
        ],
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: enabled
              ? Padding(
                  key: const ValueKey('web-access-settings-enabled'),
                  padding: EdgeInsets.fromLTRB(
                    widget.showEnableControl ? 16 : 0,
                    8,
                    widget.showEnableControl ? 16 : 0,
                    0,
                  ),
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
                        _buildApiKeyEditorEntry(
                          notifier,
                          hasKey: state.hasExaApiKey,
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

  Widget _buildApiKeyEditorEntry(
    WebAccessConfigNotifier notifier, {
    required bool hasKey,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final button = TextButton.icon(
          onPressed: () => _showApiKeyDialog(notifier, hasKey: hasKey),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(context.l10n.promptAssistant_webAccessConfigureKey),
        );
        final tile = ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(hasKey ? Icons.key_outlined : Icons.key_off_outlined),
          title: Text(context.l10n.promptAssistant_webAccessExaApiKey),
          subtitle: Text(
            hasKey
                ? context.l10n.promptAssistant_webAccessApiKeyConfigured
                : context.l10n.promptAssistant_webAccessApiKeyMissing,
          ),
          trailing: constraints.maxWidth >= 420 ? button : null,
        );
        if (constraints.maxWidth >= 420) return tile;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tile,
            Align(alignment: AlignmentDirectional.centerEnd, child: button),
          ],
        );
      },
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
    final result = await AdaptivePresenter.showForm<_ApiKeyEditorResult>(
      context: context,
      titleBuilder: (panelContext) => Text(
        panelContext.l10n.promptAssistant_webAccessExaApiKey,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(panelContext).textTheme.titleMedium,
      ),
      sideSheetWidth: 420,
      builder: (panelContext, scrollController) =>
          _ApiKeyEditorForm(hasKey: hasKey, scrollController: scrollController),
    );
    try {
      if (result?.action == _ApiKeyAction.clear) {
        await notifier.setExaApiKey('');
      } else if (result?.action == _ApiKeyAction.save &&
          result!.value.trim().isNotEmpty) {
        await notifier.setExaApiKey(result.value);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('${context.l10n.common_error}: $error')),
        );
      }
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

class _ApiKeyEditorResult {
  const _ApiKeyEditorResult(this.action, this.value);

  final _ApiKeyAction action;
  final String value;
}

class _ApiKeyEditorForm extends StatefulWidget {
  const _ApiKeyEditorForm({
    required this.hasKey,
    required this.scrollController,
  });

  final bool hasKey;
  final ScrollController scrollController;

  @override
  State<_ApiKeyEditorForm> createState() => _ApiKeyEditorFormState();
}

class _ApiKeyEditorFormState extends State<_ApiKeyEditorForm> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _complete(_ApiKeyAction action) {
    Navigator.of(context).pop(_ApiKeyEditorResult(action, _controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _controller,
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.l10n.promptAssistant_webAccessExaApiKey,
                hintText: widget.hasKey
                    ? context.l10n.promptAssistant_apiKeyLeaveEmpty
                    : null,
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.hasKey)
                  TextButton(
                    onPressed: () => _complete(_ApiKeyAction.clear),
                    child: Text(context.l10n.promptAssistant_webAccessClearKey),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.common_cancel),
                ),
                FilledButton(
                  onPressed: () => _complete(_ApiKeyAction.save),
                  child: Text(context.l10n.common_save),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
