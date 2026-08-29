import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/comfyui/comfyui_models.dart';
import '../../../../core/comfyui/workflow_template.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../utils/comfyui_workflow_l10n.dart';
import '../../../providers/comfyui/comfyui_provider.dart';
import '../../../providers/generation/image_workflow_controller.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/themed_input.dart';
import '../widgets/settings_card.dart';
import '../widgets/workflow_import_wizard.dart';

/// ComfyUI 设置板块
class ComfyUISettingsSection extends ConsumerStatefulWidget {
  const ComfyUISettingsSection({super.key});

  @override
  ConsumerState<ComfyUISettingsSection> createState() =>
      _ComfyUISettingsSectionState();
}

class _ComfyUISettingsSectionState
    extends ConsumerState<ComfyUISettingsSection> {
  final _urlController = TextEditingController();
  bool _isTesting = false;
  String? _testResult;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(comfyUISettingsProvider);
    final connStatus = ref.watch(comfyUIConnectionProvider);
    final workflows = ref.watch(comfyUIWorkflowsProvider);
    final seedvr2EmbedNaiMetadata = ref.watch(
      imageWorkflowControllerProvider.select(
        (state) => state.upscale.seedvr2EmbedNaiMetadata,
      ),
    );

    if (_urlController.text.isEmpty ||
        _urlController.text != settings.serverUrl) {
      _urlController.text = settings.serverUrl;
    }

    final customWorkflows = workflows.where((t) => !t.isBuiltin).toList();
    final builtinWorkflows = workflows.where((t) => t.isBuiltin).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCard(
          title: context.l10n.settings_integrationConnectionSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.power),
                title: Text(context.l10n.settings_comfyUiEnable),
                subtitle: Text(
                  settings.enabled
                      ? _connectionStatusText(context, connStatus)
                      : context.l10n.settings_comfyUiDisabledSubtitle,
                ),
                value: settings.enabled,
                onChanged: (value) {
                  ref.read(comfyUISettingsProvider.notifier).setEnabled(value);
                  if (!value) {
                    ref.read(comfyUIConnectionProvider.notifier).disconnect();
                  }
                },
              ),
              if (settings.enabled) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final urlField = ThemedInput(
                        controller: _urlController,
                        decoration: InputDecoration(
                          labelText: context.l10n.settings_comfyUiServerUrl,
                          hintText: 'http://127.0.0.1:8188',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: const Icon(Icons.dns_outlined),
                        ),
                        onChanged: (value) {
                          ref
                              .read(comfyUISettingsProvider.notifier)
                              .setServerUrl(value);
                        },
                      );
                      final testButton = FilledButton.tonal(
                        onPressed: _isTesting ? null : _testConnection,
                        child: _isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(context.l10n.settings_testConnection),
                      );
                      if (constraints.maxWidth < 520) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            urlField,
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: testButton,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: urlField),
                          const SizedBox(width: 12),
                          testButton,
                        ],
                      );
                    },
                  ),
                ),
                if (_testResult != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _testResult == 'ok'
                              ? Icons.check_circle
                              : Icons.error_outline,
                          size: 16,
                          color: _testResult == 'ok'
                              ? Colors.green
                              : theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _testResult == 'ok'
                              ? context.l10n.settings_comfyUiConnectionSuccess
                              : context.l10n.settings_comfyUiConnectionFailed(
                                  _testResult!,
                                ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _testResult == 'ok'
                                ? Colors.green
                                : theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (connStatus == ComfyUIConnectionStatus.connected)
                  ListTile(
                    leading: const Icon(
                      Icons.circle,
                      color: Colors.green,
                      size: 12,
                    ),
                    title: Text(context.l10n.settings_comfyUiConnected),
                    subtitle: Text(settings.serverUrl),
                    trailing: TextButton(
                      onPressed: () {
                        ref
                            .read(comfyUIConnectionProvider.notifier)
                            .disconnect();
                      },
                      child: Text(context.l10n.settings_comfyUiDisconnect),
                    ),
                  ),
                SwitchListTile(
                  secondary: const Icon(Icons.description_outlined),
                  title: Text(
                    context.l10n.settings_comfyUiSeedvr2EmbedNaiMetadata,
                  ),
                  subtitle: Text(
                    context.l10n.settings_comfyUiSeedvr2EmbedNaiMetadataHint,
                  ),
                  value: seedvr2EmbedNaiMetadata,
                  onChanged: ref
                      .read(imageWorkflowControllerProvider.notifier)
                      .updateSeedvr2EmbedNaiMetadata,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),

        // 工作流管理
        if (settings.enabled) ...[
          const SizedBox(height: 16),
          SettingsCard(
            title: context.l10n.settings_comfyUiWorkflowManagement,
            icon: Icons.account_tree,
            child: Column(
              children: [
                // 内置工作流列表
                if (builtinWorkflows.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 16,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.settings_comfyUiBuiltinWorkflows,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...builtinWorkflows.map((t) => _buildWorkflowTile(theme, t)),
                ],

                // 用户自定义工作流
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.settings_comfyUiCustomWorkflows,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => WorkflowImportWizard.show(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(context.l10n.common_import),
                      ),
                    ],
                  ),
                ),
                if (customWorkflows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      context.l10n.settings_comfyUiNoCustomWorkflows,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  )
                else
                  ...customWorkflows.map((t) => _buildWorkflowTile(theme, t)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWorkflowTile(ThemeData theme, WorkflowTemplate template) {
    final categoryLabel = template.category.localizedLabel(context);
    final description = template.localizedDescription(context);

    return ListTile(
      leading: Icon(
        template.isBuiltin ? Icons.inventory_2 : Icons.account_tree,
        color: template.isBuiltin
            ? theme.colorScheme.primary
            : theme.colorScheme.tertiary,
      ),
      title: Text(template.localizedName(context)),
      subtitle: Text(
        '$categoryLabel · '
        '${context.l10n.settings_comfyUiSlotCount(template.slots.length)}'
        '${description.isNotEmpty ? " · $description" : ""}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: template.isBuiltin
          ? Chip(
              label: Text(context.l10n.settings_comfyUiBuiltin),
              labelStyle: theme.textTheme.bodySmall,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            )
          : IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
                size: 20,
              ),
              onPressed: () => _confirmDeleteWorkflow(template),
            ),
    );
  }

  Future<void> _confirmDeleteWorkflow(WorkflowTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.settings_comfyUiDeleteWorkflowTitle),
        content: Text(
          context.l10n.settings_comfyUiDeleteWorkflowContent(
            template.localizedName(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(comfyUIWorkflowsProvider.notifier)
          .removeCustomTemplate(template.id);
      if (mounted) {
        AppToast.success(
          context,
          context.l10n.settings_comfyUiDeleted(template.localizedName(context)),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final ok = await ref
          .read(comfyUIConnectionProvider.notifier)
          .testConnection();
      if (mounted) {
        setState(() {
          _testResult = ok ? 'ok' : context.l10n.settings_comfyUiNoResponse;
          _isTesting = false;
        });
        if (ok) {
          AppToast.success(
            context,
            context.l10n.settings_comfyUiConnectionSuccessFull,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testResult = context.l10n.settings_comfyUiConnectionFailed(
            e.toString(),
          );
          _isTesting = false;
        });
      }
    }
  }

  String _connectionStatusText(
    BuildContext context,
    ComfyUIConnectionStatus status,
  ) {
    switch (status) {
      case ComfyUIConnectionStatus.disconnected:
        return context.l10n.settings_comfyUiStatusDisconnected;
      case ComfyUIConnectionStatus.connecting:
        return context.l10n.settings_comfyUiStatusConnecting;
      case ComfyUIConnectionStatus.connected:
        return context.l10n.settings_comfyUiStatusConnected;
      case ComfyUIConnectionStatus.error:
        return context.l10n.settings_comfyUiStatusError;
    }
  }
}
