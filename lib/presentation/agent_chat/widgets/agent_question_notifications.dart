import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/agent_question_notification_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../router/shell_panels_overlay.dart';
import '../../widgets/common/app_toast.dart';
import '../models/agent_user_question_request.dart';
import '../providers/agent_chat_notifier.dart';

/// Mounted at the shell so hidden conversations still request attention once.
class AgentQuestionNotifications extends ConsumerStatefulWidget {
  const AgentQuestionNotifications({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AgentQuestionNotifications> createState() =>
      _AgentQuestionNotificationsState();
}

class _AgentQuestionNotificationsState
    extends ConsumerState<AgentQuestionNotifications> {
  late final AgentQuestionNotificationService _service;
  late final StreamSubscription<String> _opened;

  @override
  void initState() {
    super.initState();
    _service = ref.read(agentQuestionNotificationServiceProvider);
    _opened = _service.opened.listen((requestId) {
      if (!mounted) return;
      if (ref.read(agentChatNotifierProvider).questionRequest?.toolCallId ==
          requestId) {
        ref.read(shellPanelProvider.notifier).state = ShellPanel.agent;
      }
    });
  }

  Future<void> _update(AgentUserQuestionRequest? request) async {
    if (!mounted) return;
    final l10n = context.l10n;
    try {
      if (request == null) {
        await _service.cancel();
      } else {
        AppToast.info(context, l10n.userQuestion_notification);
        await _service.show(
          requestId: request.toolCallId,
          title: l10n.userQuestion_waiting,
          message: l10n.userQuestion_notification,
          expiresAt: request.expiresAt!,
        );
      }
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to update agent question notification',
        error,
        stackTrace,
        'AgentQuestionNotifications',
      );
      if (mounted && request != null) {
        AppToast.warning(context, l10n.userQuestion_notificationUnavailable);
      }
    }
  }

  @override
  void dispose() {
    unawaited(_opened.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AgentUserQuestionRequest?>(
      agentChatNotifierProvider.select((state) => state.questionRequest),
      (previous, next) {
        if (previous?.toolCallId == next?.toolCallId) return;
        unawaited(_update(next));
      },
    );
    return widget.child;
  }
}
