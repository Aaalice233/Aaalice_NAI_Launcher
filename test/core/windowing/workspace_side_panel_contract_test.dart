import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/windowing/workspace_side_panel_contract.dart';

void main() {
  test('desktop side panels share stable and wide workspace bounds', () {
    expect(WorkspaceSidePanelContract.overlayWidth(840), 520);
    expect(WorkspaceSidePanelContract.overlayWidth(1179.9), 520);
    expect(WorkspaceSidePanelContract.overlayWidth(1180), 520);
    expect(WorkspaceSidePanelContract.overlayWidth(1600), 608);
    expect(WorkspaceSidePanelContract.overlayWidth(2000), 760);
    expect(WorkspaceSidePanelContract.overlayWidth(3840), 960);
  });

  test('explicit overlay preferences still obey the shared ceiling', () {
    expect(
      WorkspaceSidePanelContract.overlayWidth(840, preferredWidth: 680),
      520,
    );
    expect(
      WorkspaceSidePanelContract.overlayWidth(1600, preferredWidth: 440),
      440,
    );
    expect(
      WorkspaceSidePanelContract.overlayWidth(1600, preferredWidth: 720),
      608,
    );
  });

  test(
    'preferred generation panel width uses the shared responsive ceiling',
    () {
      expect(
        WorkspaceSidePanelContract.constrainedWorkspaceWidth(
          workspaceWidth: 1180,
          preferredWidth: 900,
        ),
        520,
      );
      expect(
        WorkspaceSidePanelContract.constrainedWorkspaceWidth(
          workspaceWidth: 2560,
          preferredWidth: 820,
        ),
        820,
      );
      expect(
        WorkspaceSidePanelContract.constrainedWorkspaceWidth(
          workspaceWidth: 3840,
          preferredWidth: 1200,
        ),
        960,
      );
    },
  );

  test(
    'workspace constraint deducts other panels and protects main content',
    () {
      expect(
        WorkspaceSidePanelContract.constrainedWorkspaceWidth(
          workspaceWidth: 1180,
          preferredWidth: 960,
          occupiedWidth: 724,
          minimumPrimaryWidth: 320,
        ),
        136,
      );
      expect(
        WorkspaceSidePanelContract.constrainedWorkspaceWidth(
          workspaceWidth: 1600,
          preferredWidth: 960,
          occupiedWidth: 874,
          minimumPrimaryWidth: 320,
        ),
        406,
      );
    },
  );
}
