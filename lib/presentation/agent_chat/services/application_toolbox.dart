import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import 'application_context_toolbox.dart';
import 'fixed_tags_toolbox.dart';
import 'tag_library_toolbox.dart';

/// Backward-compatible registration facade for application-owned tools.
class ApplicationToolbox {
  ApplicationToolbox(this._ref, {this.loadDrafts});

  final Ref _ref;
  final AgentDraftSnapshotLoader? loadDrafts;

  List<AgentTool> tools() => [
    ...ApplicationContextToolbox(_ref, loadDrafts: loadDrafts).tools(),
    ...TagLibraryToolbox(_ref).tools(),
    ...FixedTagsToolbox(_ref).tools(),
  ];
}
