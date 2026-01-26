import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/presentation/providers/bulk_operation_provider.dart';

void main() {
  group('BulkOperationNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('Initial State', () {
      test('should initialize with empty idle state', () {
        final state = container.read(bulkOperationNotifierProvider);

        expect(
          state.currentOperation,
          isNull,
          reason: 'Current operation should be null initially',
        );
        expect(
          state.isOperationInProgress,
          isFalse,
          reason: 'Should not be in progress initially',
        );
        expect(
          state.currentProgress,
          0,
          reason: 'Current progress should be 0',
        );
        expect(
          state.totalItems,
          0,
          reason: 'Total items should be 0',
        );
        expect(
          state.currentItem,
          isNull,
          reason: 'Current item should be null',
        );
        expect(
          state.lastResult,
          isNull,
          reason: 'Last result should be null',
        );
        expect(
          state.isCompleted,
          isFalse,
          reason: 'Should not be completed initially',
        );
        expect(
          state.error,
          isNull,
          reason: 'Should have no error initially',
        );
        expect(
          state.canUndo,
          isFalse,
          reason: 'Should not be able to undo initially',
        );
        expect(
          state.canRedo,
          isFalse,
          reason: 'Should not be able to redo initially',
        );
        expect(
          state.progressPercentage,
          0,
          reason: 'Progress percentage should be 0',
        );
        expect(
          state.hasError,
          isFalse,
          reason: 'Should have no error',
        );
        expect(
          state.canPerformUndoRedo,
          isFalse,
          reason: 'Should not be able to perform undo/redo',
        );
      });
    });

    group('bulkDelete', () {
      test('should handle empty list gracefully', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        final result = await notifier.bulkDelete([]);

        expect(
          result.success,
          0,
          reason: 'Should return 0 success for empty list',
        );
        expect(
          result.failed,
          0,
          reason: 'Should return 0 failed for empty list',
        );
      });
    });

    group('bulkExport', () {
      test('should handle empty list gracefully', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        final result = await notifier.bulkExport([]);

        expect(
          result,
          isNull,
          reason: 'Should return null for empty list',
        );

        final state = container.read(bulkOperationNotifierProvider);
        expect(
          state.error,
          isNotNull,
          reason: 'Should have error for empty list',
        );
      });
    });

    group('bulkEditMetadata', () {
      test('should handle empty list gracefully', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        final result = await notifier.bulkEditMetadata([]);

        expect(
          result.success,
          0,
          reason: 'Should return 0 success for empty list',
        );
        expect(
          result.failed,
          0,
          reason: 'Should return 0 failed for empty list',
        );
      });

      test('should handle empty tag lists gracefully', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);
        final imagePaths = ['image1.png'];

        final result = await notifier.bulkEditMetadata(
          imagePaths,
          tagsToAdd: [],
          tagsToRemove: [],
        );

        expect(
          result.success,
          0,
          reason: 'Should return 0 success when no tags to change',
        );

        final state = container.read(bulkOperationNotifierProvider);
        expect(
          state.error,
          isNotNull,
          reason: 'Should have error when no tags to change',
        );
      });
    });

    group('bulkToggleFavorite', () {
      test('should handle empty list gracefully', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        final result = await notifier.bulkToggleFavorite([], isFavorite: true);

        expect(
          result.success,
          0,
          reason: 'Should return 0 success for empty list',
        );
        expect(
          result.failed,
          0,
          reason: 'Should return 0 failed for empty list',
        );
      });
    });

    group('bulkAddToCollection', () {
      test('should handle empty list gracefully', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        final result = await notifier.bulkAddToCollection('collection1', []);

        expect(
          result,
          0,
          reason: 'Should return 0 for empty list',
        );

        final state = container.read(bulkOperationNotifierProvider);
        expect(
          state.error,
          isNotNull,
          reason: 'Should have error for empty list',
        );
      });
    });

    group('undo/redo', () {
      test('should not allow undo when no operations', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        await notifier.undo();

        final state = container.read(bulkOperationNotifierProvider);
        expect(
          state.error,
          isNotNull,
          reason: 'Should have error when trying to undo with no operations',
        );
      });

      test('should not allow redo when no operations', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        await notifier.redo();

        final state = container.read(bulkOperationNotifierProvider);
        expect(
          state.error,
          isNotNull,
          reason: 'Should have error when trying to redo with no operations',
        );
      });
    });

    group('clearHistory', () {
      test('should clear operation history', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        notifier.clearHistory();

        final state = container.read(bulkOperationNotifierProvider);
        expect(
          state.canUndo,
          isFalse,
          reason: 'Should not be able to undo after clearing history',
        );
        expect(
          state.canRedo,
          isFalse,
          reason: 'Should not be able to redo after clearing history',
        );
      });
    });

    group('clearError', () {
      test('should clear error state', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        // Trigger an error
        await notifier.undo();

        expect(
          container.read(bulkOperationNotifierProvider).hasError,
          isTrue,
          reason: 'Should have error',
        );

        notifier.clearError();

        expect(
          container.read(bulkOperationNotifierProvider).error,
          isNull,
          reason: 'Error should be cleared',
        );
      });
    });

    group('reset', () {
      test('should reset state to initial idle state', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        notifier.reset();

        final state = container.read(bulkOperationNotifierProvider);
        expect(
          state.currentOperation,
          isNull,
          reason: 'Current operation should be null after reset',
        );
        expect(
          state.isOperationInProgress,
          isFalse,
          reason: 'Should not be in progress after reset',
        );
        expect(
          state.isCompleted,
          isFalse,
          reason: 'Should not be completed after reset',
        );
        expect(
          state.canUndo,
          isFalse,
          reason: 'Should not be able to undo after reset',
        );
        expect(
          state.canRedo,
          isFalse,
          reason: 'Should not be able to redo after reset',
        );
      });
    });

    group('progressPercentage calculation', () {
      test('should return 0% when total items is 0', () {
        final state = container.read(bulkOperationNotifierProvider);

        expect(
          state.progressPercentage,
          0,
          reason: 'Progress should be 0 when no items',
        );
      });
    });
  });
}
