import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import 'agent_resource_resolver.dart';
import 'application_context_toolbox.dart';
import 'fixed_tags_toolbox.dart';
import 'tag_library_toolbox.dart';

/// Backward-compatible registration facade for application-owned tools.
class ApplicationToolbox {
  ApplicationToolbox(this._ref, {this.loadDrafts, this.resourceResolver});

  final Ref _ref;
  final AgentDraftSnapshotLoader? loadDrafts;
  final AgentResourceResolver? resourceResolver;

  List<AgentTool> tools() => [
    ...ApplicationContextToolbox(_ref, loadDrafts: loadDrafts).tools(),
    ...TagLibraryToolbox(_ref, resourceResolver: resourceResolver).tools(),
    ...FixedTagsToolbox(_ref).tools(),
  ];
}
