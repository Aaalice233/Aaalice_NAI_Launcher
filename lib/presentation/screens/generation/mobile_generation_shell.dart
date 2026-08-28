import 'package:flutter/material.dart';

import '../../agent_chat/widgets/agent_chat_panel.dart';
import 'mobile_generation_chrome.dart';
import 'mobile_generation_controller.dart';
import 'mobile_generation_gestures.dart';
import 'mobile_generation_view_data.dart';
import 'mobile_generation_workspace.dart';

class MobileGenerationShell extends StatelessWidget {
  const MobileGenerationShell({
    super.key,
    required this.controller,
    required this.data,
  });

  final MobileGenerationController controller;
  final MobileGenerationViewData data;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !data.isPromptMaximized && !controller.agentFullScreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.handleBack(data.isPromptMaximized);
      },
      child: MobileGenerationChrome(
        controller: controller,
        data: data,
        body: Stack(
          key: const ValueKey('generation-mobile-primary-workspaces'),
          children: [
            MobileGenerationWorkspace(controller: controller, data: data),
            MobileWorkspaceMotion(
              active: controller.agentFullScreen,
              hiddenOffset: const Offset(0, 0.08),
              child: TickerMode(
                enabled: controller.agentFullScreen,
                child: controller.agentHasOpened
                    ? SafeArea(
                        key: const ValueKey('generation-agent-fullscreen'),
                        child: AgentChatPanel(
                          mobile: true,
                          fullScreen: true,
                          onClose: controller.closeAgentChat,
                          onOpenSettings: () =>
                              controller.openAgentSettings(context),
                          mobileHeaderWrapper: (child) =>
                              MobileVerticalCloseGesture(
                                key: const ValueKey(
                                  'generation-agent-close-drag-handle',
                                ),
                                closeDirection: AxisDirection.down,
                                onClose: controller.closeAgentChat,
                                child: child,
                              ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
