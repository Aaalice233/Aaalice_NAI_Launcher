import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_tool_widgets.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_tool_result_summary.dart';

ToolResultMessage result(
  String name,
  Map<String, Object?> value, {
  bool failed = false,
  bool detailsOnly = false,
}) => ToolResultMessage(
  toolCallId: name,
  toolName: name,
  content: detailsOnly ? [] : [ToolResultTextContent(jsonEncode(value))],
  details: detailsOnly ? value : null,
  isError: failed,
);

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final search = result('web_search', {
    'ok': true,
    'result_count': 99,
    'results': [
      {'url': 'https://example.com/a'},
      {'url': 'https://example.com/b'},
      {'url': 'https://other.example/a'},
    ],
  });
  test('search counts returned rows and distinct hosts', () {
    expect(
      structuredAgentToolResultSummary(en, search),
      'Returned 3 results · From 2 sites',
    );
    expect(
      structuredAgentToolResultSummary(
        en,
        result('web_search', {'results': []}),
      ),
      'Returned 0 results',
    );
    expect(
      structuredAgentToolResultSummary(
        en,
        result('web_search', {'result_count': 99}),
      ),
      isNull,
    );
  });
  test('errors and explicit summaries retain existing handling', () {
    for (final failed in [true, false]) {
      expect(
        structuredAgentToolResultSummary(
          en,
          result('web_search', {
            'ok': false,
            'error': 'network failed',
            'results': [],
          }, failed: failed),
        ),
        isNull,
      );
    }
    expect(
      structuredAgentToolResultSummary(
        en,
        result('search_tags', {
          'message': 'Dictionary unavailable',
          'results': [],
        }),
      ),
      'Dictionary unavailable',
    );
  });
  test('web reads preserve truncation and count Unicode characters', () {
    expect(
      structuredAgentToolResultSummary(
        en,
        result('web_read', {
          'content': '猫🐈',
          'truncated': true,
          'title': 'Example',
        }),
      ),
      'Read 2 characters · Content truncated · Example',
    );
  });
  test('collections report returned size rather than total', () {
    for (final spec in [
      ('search_tags', 'results', 'tags'),
      ('search_local_gallery', 'items', 'images'),
      ('browse_online_gallery', 'items', 'images'),
      ('list_tag_library_entries', 'entries', 'entries'),
      ('list_fixed_tags', 'entries', 'entries'),
      ('list_vibe_library', 'entries', 'entries'),
      ('list_precise_reference_library', 'entries', 'entries'),
      ('list_tag_library_categories', 'categories', 'categories'),
      ('list_online_gallery_sources', 'sources', 'sources'),
      ('get_prompt_state', 'characters', 'characters'),
      ('get_skill_diagnostics', 'diagnostics', 'diagnostics'),
    ]) {
      expect(
        structuredAgentToolResultSummary(
          en,
          result(spec.$1, {
            spec.$2: [{}, {}],
            'total': 800,
            'note': 'Partial results',
          }, detailsOnly: true),
        ),
        'Returned 2 ${spec.$3} · Partial results',
      );
    }
  });
  test('image and queue outcomes distinguish inspection and preparation', () {
    expect(
      structuredAgentToolResultSummary(
        en,
        result('inspect_images', {'inspected_count': 2}),
      ),
      'Inspected 2 images',
    );
    expect(
      structuredAgentToolResultSummary(
        en,
        result('display_images', {'displayed_count': 1}),
      ),
      'Displayed 1 images',
    );
    expect(
      structuredAgentToolResultSummary(
        en,
        result('prepare_generation_queue_execution', {'task_count': 4}),
      ),
      'Prepared 4 tasks; awaiting confirmation',
    );
    expect(
      structuredAgentToolResultSummary(
        en,
        result('inspect_generation_queue', {
          'pending': [{}],
          'failed': [],
          'execution': {'total_tasks_in_session': 99},
        }),
      ),
      'Returned 1 pending tasks · Returned 0 failed tasks',
    );
  });
  test('favorite mutation and ordinary detail have distinct summaries', () {
    final data = {
      'entry': {'name': 'Example', 'favorite': false},
    };
    expect(
      structuredAgentToolResultSummary(
        en,
        result('get_tag_library_entry', data),
      ),
      'Example',
    );
    expect(
      structuredAgentToolResultSummary(
        en,
        result('toggle_tag_library_favorite', data),
      ),
      'Unfavorited · Example',
    );
  });
  test('all supported languages have localized summaries', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final summary = structuredAgentToolResultSummary(
        lookupAppLocalizations(locale),
        search,
      );
      expect(summary, contains('3'));
      expect(summary, contains('2'));
      if (locale.languageCode != 'en') {
        expect(summary, isNot(contains('Returned')));
      }
    }
  });
  testWidgets(
    'grouped search summaries are visible without raw JSON across widths',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
        await tester.binding.setSurfaceSize(Size(width, 500));
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 500),
                textScaler: const TextScaler.linear(3),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: AgentChatToolResultGroup(results: [search]),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final groupTitle = find.text(en.agentChat_toolGroupCount(1));
        await tester.tap(groupTitle);
        await tester.pumpAndSettle();
        expect(find.textContaining('Returned 3 results'), findsOneWidget);
        expect(find.textContaining('"result_count"'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
