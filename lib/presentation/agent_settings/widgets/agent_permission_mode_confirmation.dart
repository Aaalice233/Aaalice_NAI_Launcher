import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../providers/share_image_settings_provider.dart';
import '../../widgets/common/themed_confirm_dialog.dart';

/// 智能体与 MCP 的权限切换入口共用；只有切入全自动需要确认。
Future<bool> confirmAgentPermissionModeChange({
  required BuildContext context,
  required WidgetRef ref,
  required AgentPermissionMode from,
  required AgentPermissionMode to,
}) {
  if (!to.autoApprovesCharges || from.autoApprovesCharges) {
    return Future.value(true);
  }
  final l10n = context.l10n;
  final threshold = ref
      .read(shareImageSettingsProvider)
      .effectiveHighAnlasCostThreshold;
  return ThemedConfirmDialog.show(
    context: context,
    title: l10n.agentSettings_autopilotConfirmTitle,
    content: threshold == null
        ? l10n.agentSettings_autopilotConfirmUnlimited
        : l10n.agentSettings_autopilotConfirmThreshold(threshold),
    confirmText: l10n.agentSettings_autopilotConfirmAction,
    cancelText: l10n.common_cancel,
    type: ThemedConfirmDialogType.warning,
    icon: Icons.toll_outlined,
  );
}
