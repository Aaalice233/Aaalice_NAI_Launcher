import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/online_gallery_provider.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../providers/generation/preview_selection_provider.dart';
import '../../router/app_router_config.dart';
import '../../router/app_routes.dart';
import '../../router/shell_panels_overlay.dart';
import 'defined_agent_tool.dart';
import 'toolbox_json.dart';

typedef AgentDraftSnapshotLoader =
    Future<List<Map<String, dynamic>>> Function();

/// Read-only application state and authoritative navigation commands.
class ApplicationContextToolbox {
  ApplicationContextToolbox(this._ref, {this.loadDrafts});

  final Ref _ref;
  final AgentDraftSnapshotLoader? loadDrafts;

  List<AgentTool> tools() => [_readContext(), _navigate()];

  DefinedAgentTool _readContext() => DefinedAgentTool(
    name: 'get_application_context',
    label: 'Get Application Context',
    description:
        'Read the current destination, gallery filters, selected generated image, local drafts, and queue state.',
    parameters: toolboxObject(),
    executeFn: (_, __) async {
      final uri = _ref
          .read(appRouterProvider)
          .routeInformationProvider
          .value
          .uri;
      final online = _ref.read(onlineGalleryNotifierProvider);
      final local = _ref.read(localGalleryNotifierProvider);
      final queue = _ref.read(replicationQueueNotifierProvider);
      final execution = _ref.read(queueExecutionNotifierProvider);
      final selectedGeneratedId = _ref.read(generationPreviewSelectionProvider);
      final generation = _ref.read(imageGenerationNotifierProvider);
      final selectedGenerated = selectedGeneratedId == null
          ? null
          : generation.findImageById(selectedGeneratedId);
      return agentToolJsonResult({
        'ok': true,
        'route': {
          'uri': uri.toString(),
          'path': uri.path,
          'query': uri.queryParameters,
          'destination': _destinationForPath(uri.path),
        },
        'platform': {
          'target': defaultTargetPlatform.name,
          'desktop': switch (defaultTargetPlatform) {
            TargetPlatform.windows ||
            TargetPlatform.macOS ||
            TargetPlatform.linux => true,
            _ => false,
          },
        },
        'online_gallery': {
          'source': online.activeSourceId.key,
          'mode': online.viewMode.name,
          'query': online.viewMode == GalleryViewMode.favorites
              ? online.favoriteSearchQuery
              : online.viewMode == GalleryViewMode.popular
              ? online.popularQuery
              : online.searchQuery,
          'prompt_query': online.viewMode == GalleryViewMode.popular
              ? online.popularPromptQuery
              : online.promptQuery,
          'ratings': online.selectedRatings.toList()..sort(),
          'fuzzy': online.fuzzySearchEnabled,
          'random': online.randomEnabled,
          'visible_count': online.posts.length,
          'page': online.page,
          'has_more': online.hasMore,
        },
        'local_gallery': {
          'visible_count': local.currentImages.length,
          'filtered_count': local.filteredCount,
          'total_count': local.totalCount,
          'page': local.currentPage,
          'page_size': local.pageSize,
          'loading': local.isLoading || local.isPageLoading,
        },
        'selected_image': selectedGenerated == null
            ? null
            : {
                'kind': 'generated_image',
                'id': selectedGenerated.id,
                'width': selectedGenerated.width,
                'height': selectedGenerated.height,
              },
        'detail': null,
        'drafts': loadDrafts == null ? const [] : await loadDrafts!(),
        'queue': {
          'panel_visible': _ref.read(shellPanelProvider) == ShellPanel.queue,
          'status': execution.status.name,
          'current_task_id': execution.currentTaskId,
          'pending_count': queue.tasks.length,
          'failed_count': queue.failedTasks.length,
          'completed_count': queue.completedTasks.length,
          'remaining_capacity': queue.remainingCapacity,
        },
        'destinations': _destinations.keys.toList(growable: false),
      });
    },
  );

  DefinedAgentTool _navigate() => DefinedAgentTool(
    name: 'navigate_application',
    label: 'Navigate Application',
    description:
        'Navigate the owning main application or open its queue management surface.',
    parameters: toolboxObject(
      properties: {
        'destination': {'type': 'string', 'enum': _destinations.keys.toList()},
        'settings_section': {'type': 'string', 'enum': _settingsSections},
      },
      required: const ['destination'],
    ),
    executeFn: (_, params) async {
      final destination = params['destination'] as String;
      if (destination == 'queue') {
        _ref.read(shellPanelProvider.notifier).state = ShellPanel.queue;
        return agentToolJsonResult({
          'ok': true,
          'destination': destination,
          'queue_visible': true,
        });
      }
      final path = _destinations[destination];
      if (path == null) {
        return agentToolError('unknown_destination', destination);
      }
      final section = params['settings_section'] as String?;
      if (section != null && destination != 'settings') {
        return agentToolError(
          'invalid_settings_section',
          'settings_section is valid only for the settings destination.',
        );
      }
      final target = section == null
          ? path
          : '$path?section=${Uri.encodeQueryComponent(section)}';
      final router = _ref.read(appRouterProvider);
      router.go(target);
      return agentToolJsonResult({
        'ok': true,
        'destination': destination,
        'target_uri': target,
      });
    },
  );
}

const _settingsSections = [
  'account',
  'appearance',
  'generation',
  'storage',
  'privacy',
  'network',
  'shortcuts',
  'integrations',
  'about',
];

const _destinations = <String, String>{
  'home': AppRoutes.home,
  'generation': AppRoutes.generation,
  'local_gallery': AppRoutes.localGallery,
  'online_gallery': AppRoutes.onlineGallery,
  'settings': AppRoutes.settings,
  'prompt_config': AppRoutes.promptConfig,
  'statistics': AppRoutes.statistics,
  'tag_library': AppRoutes.tagLibraryPage,
  'vibe_library': AppRoutes.vibeLibrary,
  'precise_reference_library': AppRoutes.preciseRefLibrary,
  'queue': AppRoutes.generation,
};

String? _destinationForPath(String path) {
  for (final entry in _destinations.entries) {
    if (entry.key != 'queue' && entry.value == path) return entry.key;
  }
  return null;
}
