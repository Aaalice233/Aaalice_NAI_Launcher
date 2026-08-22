import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'autocomplete_settings.dart';
import 'cooccurrence_data_pack_service.dart';

final cooccurrenceDataPackServiceProvider =
    StateNotifierProvider<
      CooccurrenceDataPackService,
      CooccurrenceDataPackState
    >((ref) => CooccurrenceDataPackService());

/// Mounted only after the main application appears. It reacts to explicit
/// settings changes but not transfer state changes, so a failed startup attempt
/// is retained for manual retry instead of hammering the server.
final cooccurrenceDataPackStartupProvider = Provider<void>((ref) {
  final shouldAutoInstall = ref.watch(
    autocompleteSettingsProvider.select(
      (settings) =>
          settings.relatedTagsEnabled && settings.autoDownloadRelatedData,
    ),
  );
  final service = ref.watch(cooccurrenceDataPackServiceProvider.notifier);
  unawaited(
    Future<void>(() async {
      await service.initialize();
      if (shouldAutoInstall) {
        await service.install();
      } else {
        service.cancelDownload();
      }
    }),
  );
});
