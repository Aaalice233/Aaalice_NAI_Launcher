import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/windowing/agent_chat_dock_contract.dart';
import 'package:nai_launcher/core/windowing/workspace_side_panel_contract.dart';

void main() {
  group('AgentChatDockContract.sideBySideWidthFor', () {
    test('返回 null 表示两列最小宽度放不下，调用方退回上下分栏', () {
      expect(
        AgentChatDockContract.sideBySideWidthFor(
          workspaceWidth: 1000,
          occupiedWidth: 316,
          minimumPrimaryWidth: 320,
          preferredWidth: 648,
        ),
        isNull,
      );
      expect(
        AgentChatDockContract.sideBySideWidthFor(
          workspaceWidth: 0,
          occupiedWidth: 0,
          minimumPrimaryWidth: 320,
          preferredWidth: 648,
        ),
        isNull,
      );
    });

    test('放得下时按偏好宽度取值，并受剩余空间与两列上限约束', () {
      const available = 1540 - 316 - 320.0;
      expect(
        AgentChatDockContract.sideBySideWidthFor(
          workspaceWidth: 1540,
          occupiedWidth: 316,
          minimumPrimaryWidth: 320,
          preferredWidth: 648,
        ),
        648,
      );
      expect(
        AgentChatDockContract.sideBySideWidthFor(
          workspaceWidth: 1540,
          occupiedWidth: 316,
          minimumPrimaryWidth: 320,
          preferredWidth: 5000,
        ),
        available,
      );
      expect(
        AgentChatDockContract.sideBySideWidthFor(
          workspaceWidth: 1540,
          occupiedWidth: 316,
          minimumPrimaryWidth: 320,
          preferredWidth: 10,
        ),
        AgentChatDockContract.sideBySideMinimumWidth,
      );
      expect(
        AgentChatDockContract.sideBySideMaximumFor(3000),
        WorkspaceSidePanelContract.maximumWidth * 2 +
            AgentChatDockContract.splitHandleExtent,
      );
    });
  });

  test('持久化值的归一化拒绝非有限值并夹回允许范围', () {
    expect(
      AgentChatDockContract.normalizeStackedChatFraction(null),
      AgentChatDockContract.defaultStackedChatFraction,
    );
    expect(
      AgentChatDockContract.normalizeStackedChatFraction(double.nan),
      AgentChatDockContract.defaultStackedChatFraction,
    );
    expect(
      AgentChatDockContract.normalizeStackedChatFraction(0.01),
      AgentChatDockContract.minimumStackedChatFraction,
    );
    expect(
      AgentChatDockContract.normalizeStackedChatFraction(0.99),
      AgentChatDockContract.maximumStackedChatFraction,
    );
    expect(
      AgentChatDockContract.normalizeSideBySideChatWidth(-1),
      AgentChatDockContract.defaultSideBySideChatWidth,
    );
    expect(
      AgentChatDockContract.normalizeSideBySideChatWidth(10),
      AgentChatDockContract.minimumChatPaneWidth,
    );
    expect(
      AgentChatDockContract.normalizeSideBySideChatWidth(double.infinity),
      AgentChatDockContract.defaultSideBySideChatWidth,
    );
    expect(AgentChatDockContract.normalizeSideBySideChatWidth(420), 420);
  });
}
