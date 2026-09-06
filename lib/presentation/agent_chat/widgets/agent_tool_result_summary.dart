import 'dart:convert';

import '../../../core/agent/agent_tool_presentation.dart';
import '../../../core/agent/agent_types.dart';
import '../../../l10n/app_localizations.dart';

/// Projects returned evidence only; pagination totals and requested limits are
/// not counts of the results the agent actually received.
String? structuredAgentToolResultSummary(
  AppLocalizations l10n,
  ToolResultMessage result,
) {
  if (result.isError) return null;
  final text = result.text.trim();
  Object? decoded;
  if (text.isNotEmpty) {
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
  } else {
    decoded = result.details;
  }
  if (decoded is! Map || decoded['ok'] == false || decoded['error'] != null) {
    return null;
  }
  for (final key in const [
    'summary',
    'message',
    'status_message',
    'statusMessage',
  ]) {
    if (decoded[key] case final String value when value.trim().isNotEmpty) {
      return AgentToolPresentation.summary(value, fallback: '');
    }
  }

  var summary = _outcome(l10n, decoded, result.toolName);
  if (summary == null) return null;
  // A useful count must not erase an explicit partial-result warning.
  if (decoded['note'] case final String note when note.trim().isNotEmpty) {
    summary = '$summary · $note';
  }
  return AgentToolPresentation.summary(summary, fallback: '');
}

String? _outcome(AppLocalizations l10n, Map decoded, String toolName) {
  String count(String kind, int value) =>
      l10n.agentTool_resultCount(kind, value);
  String? summary;
  switch (toolName) {
    case 'web_search':
      if (decoded['results'] case final List results) {
        final hosts = <String>{};
        for (final item in results.whereType<Map>()) {
          final url = item['url'];
          final uri = url is String ? Uri.tryParse(url) : null;
          if (uri != null && uri.host.isNotEmpty) hosts.add(uri.host);
        }
        summary = count('results', results.length);
        if (hosts.isNotEmpty) summary += ' · ${count('sites', hosts.length)}';
      }
    case 'web_read':
      if (decoded['content'] case final String content) {
        summary = count('read', content.runes.length);
        if (decoded['truncated'] == true) {
          summary += ' · ${l10n.agentTool_resultTruncated}';
        }
        if (decoded['title'] case final String title when title.isNotEmpty) {
          summary += ' · $title';
        }
      }
    case 'inspect_images' || 'display_images':
      final display = toolName == 'display_images';
      final value = decoded[display ? 'displayed_count' : 'inspected_count'];
      if (value is int && value >= 0) {
        summary = count(display ? 'displayed' : 'inspected', value);
      }
    case 'inspect_generation_queue':
      final pending = decoded['pending'];
      final failed = decoded['failed'];
      if (pending is List && failed is List) {
        summary =
            '${count('pendingPreview', pending.length)} · '
            '${count('failedPreview', failed.length)}';
      }
    case 'prepare_generation_queue_execution':
      if (decoded['task_count'] case final int value when value >= 0) {
        summary = count('prepared', value);
      }
    case 'retry_all_failed_generation_queue_tasks':
      if (decoded['retried'] case final int value when value >= 0) {
        summary = count('retried', value);
      }
    case 'set_positive_prompt' || 'set_negative_prompt':
      final value =
          decoded[toolName == 'set_positive_prompt'
              ? 'positive_prompt'
              : 'negative_prompt'];
      if (value is String) summary = count('updatedText', value.runes.length);
    default:
      final collection = switch (toolName) {
        'search_tags' => ('results', 'tags'),
        'list_tag_library_entries' ||
        'list_fixed_tags' ||
        'list_vibe_library' ||
        'list_precise_reference_library' => ('entries', 'entries'),
        'list_tag_library_categories' => ('categories', 'categories'),
        'list_online_gallery_sources' => ('sources', 'sources'),
        'search_local_gallery' ||
        'search_online_gallery' ||
        'browse_online_gallery' => ('items', 'images'),
        'get_prompt_state' ||
        'set_character_layout_mode' ||
        'reorder_characters' => ('characters', 'characters'),
        'reload_skills' => ('skills', 'skills'),
        'get_skill_diagnostics' => ('diagnostics', 'diagnostics'),
        _ => null,
      };
      if (collection != null && decoded[collection.$1] is List) {
        summary = count(collection.$2, (decoded[collection.$1] as List).length);
      }
  }
  return summary ?? _entityOutcome(l10n, decoded, toolName);
}

String? _entityOutcome(AppLocalizations l10n, Map decoded, String toolName) {
  String? summary;
  final entry = decoded['entry'];
  final favorite =
      decoded['favorite'] ?? (entry is Map ? entry['favorite'] : null);
  if (favorite is bool &&
      const {
        'toggle_local_gallery_favorite',
        'toggle_online_gallery_favorite',
        'toggle_tag_library_favorite',
        'set_generated_image_favorite',
      }.contains(toolName)) {
    summary = favorite
        ? l10n.onlineGallery_favorited
        : l10n.onlineGallery_unfavorited;
  } else if (toolName == 'toggle_fixed_tag_enabled' && entry is Map) {
    final enabled = entry['enabled'];
    if (enabled is bool) {
      summary = enabled ? l10n.common_enabled : l10n.common_disabled;
    }
  }
  for (final key in const ['entry', 'item', 'category', 'character']) {
    if (decoded[key] case final Map entity) {
      final name = entity['name'] ?? entity['title'];
      if (name is String && name.trim().isNotEmpty) {
        summary = summary == null ? name : '$summary · $name';
        break;
      }
    }
  }
  return summary;
}
