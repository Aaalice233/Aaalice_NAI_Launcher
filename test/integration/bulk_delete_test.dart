import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/presentation/providers/bulk_operation_provider.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';

void main() {
  group('Bulk Delete Integration Tests', () {
    late ProviderContainer container;
    late Directory tempDir;
    late List<File> testFiles;

    setUp(() async {
      // Initialize Hive for testing
      Hive.init('./test_hive_bulk_delete');

      // Open required boxes
      await Hive.openBox(StorageKeys.localFavoritesBox);
      await Hive.openBox(StorageKeys.tagsBox);

      // Create temporary directory for test files
      tempDir = await Directory.systemTemp.createTemp('bulk_delete_test_');

      // Create test image files
      testFiles = [];
      for (var i = 0; i < 10; i++) {
        final file = File('${tempDir.path}/test_image_$i.png');
        await file.writeAsBytes(List.generate(1024, (index) => 0));
        testFiles.add(file);
      }

      // Create provider container
      container = ProviderContainer();
    });

    tearDown(() async {
      // Clean up test files
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }

      // Close Hive
      await Hive.close();

      // Dispose provider container
      container.dispose();
    });

    group('Bulk Delete with Undo', () {
      test('should delete all files successfully and update state', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);
        final paths = testFiles.map((f) => f.path).toList();

        final result = await notifier.bulkDelete(paths);

        expect(result.success, 10);
        expect(result.failed, 0);
        expect(result.errors, isEmpty);

        // Verify state is updated
        final state = container.read(bulkOperationNotifierProvider);
        expect(state.isOperationInProgress, false);
        expect(state.isCompleted, true);
        expect(state.canUndo, true);

        // Verify all files are deleted
        await Future.delayed(const Duration(milliseconds: 100));
        for (final path in paths) {
          final file = File(path);
          expect(
            await file.exists(),
            false,
            reason: 'File should be deleted: $path',
          );
        }
      });

      test('should handle empty file list', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        final result = await notifier.bulkDelete([]);

        expect(result.success, 0);
        expect(result.failed, 0);
        expect(result.errors, isEmpty);

        // Verify state - empty list returns early without updating state
        final state = container.read(bulkOperationNotifierProvider);
        expect(state.isOperationInProgress, false);
        // isCompleted is not set for empty operations (returns early)
        expect(state.canUndo, false); // No command added to history
      });

      test('should handle non-existent files gracefully', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);
        final paths = [
          testFiles[0].path,
          '/non/existent/path.png',
          testFiles[1].path,
          '/another/nonexistent.png',
        ];

        final result = await notifier.bulkDelete(paths);

        expect(result.success, 2);
        expect(result.failed, 2);
        expect(result.errors.length, 2);

        // Verify existing files are deleted
        await Future.delayed(const Duration(milliseconds: 100));
        expect(await File(testFiles[0].path).exists(), false);
        expect(await File(testFiles[1].path).exists(), false);
      });

      test('should track progress during bulk delete', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);
        final paths = testFiles.map((f) => f.path).toList();

        final progressUpdates = <Map<String, dynamic>>[];
        final subscription = container.listen<BulkOperationState>(
          bulkOperationNotifierProvider,
          (previous, next) {
            if (next.isOperationInProgress) {
              progressUpdates.add({
                'current': next.currentProgress,
                'total': next.totalItems,
                'currentItem': next.currentItem,
              });
            }
          },
        );

        await notifier.bulkDelete(paths);

        subscription.close();

        // Verify progress was tracked
        expect(progressUpdates.length, greaterThan(0));
        expect(progressUpdates.last['total'], 10);
      });

      test('should update canUndo after delete operation', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);
        final state = container.read(bulkOperationNotifierProvider);

        // Initial state - cannot undo
        expect(state.canUndo, false);
        expect(state.canRedo, false);

        // Perform delete
        final paths = testFiles.take(3).map((f) => f.path).toList();
        await notifier.bulkDelete(paths);

        // Should be able to undo now
        final newState = container.read(bulkOperationNotifierProvider);
        expect(newState.canUndo, true);
        expect(newState.canRedo, false);
      });

      test('should handle undo operation (with limitations)', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);
        final paths = testFiles.take(3).map((f) => f.path).toList();

        // Perform delete
        await notifier.bulkDelete(paths);

        // Verify files are deleted
        await Future.delayed(const Duration(milliseconds: 100));
        expect(await File(testFiles[0].path).exists(), false);

        // Attempt undo (files are permanently deleted, so this is limited)
        await notifier.undo();

        // Verify undo state is updated
        final state = container.read(bulkOperationNotifierProvider);
        expect(state.canUndo, false);

        // Note: Files remain deleted because file deletion cannot be undone
        // This is a known limitation of the current implementation
        expect(await File(testFiles[0].path).exists(), false);
      });

      test('should clear history when requested', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);
        final paths = testFiles.take(2).map((f) => f.path).toList();

        // Perform delete
        await notifier.bulkDelete(paths);

        // Verify can undo
        expect(container.read(bulkOperationNotifierProvider).canUndo, true);

        // Clear history
        notifier.clearHistory();

        // Verify cannot undo anymore
        final state = container.read(bulkOperationNotifierProvider);
        expect(state.canUndo, false);
        expect(state.canRedo, false);
      });

      test('should reset state to idle', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);
        final paths = testFiles.take(2).map((f) => f.path).toList();

        // Perform delete
        await notifier.bulkDelete(paths);

        // Verify state has data
        var state = container.read(bulkOperationNotifierProvider);
        expect(state.isCompleted, true);
        expect(state.canUndo, true);

        // Reset state
        notifier.reset();

        // Verify state is cleared
        state = container.read(bulkOperationNotifierProvider);
        expect(state.isCompleted, false);
        expect(state.canUndo, false);
        expect(state.canRedo, false);
        expect(state.currentOperation, isNull);
      });

      test('should handle multiple delete operations', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        // First delete
        final paths1 = testFiles.take(3).map((f) => f.path).toList();
        await notifier.bulkDelete(paths1);

        var state = container.read(bulkOperationNotifierProvider);
        expect(state.lastResult?.success, 3);

        // Second delete
        final paths2 = testFiles.skip(3).take(3).map((f) => f.path).toList();
        await notifier.bulkDelete(paths2);

        state = container.read(bulkOperationNotifierProvider);
        expect(state.lastResult?.success, 3);
        expect(state.canUndo, true);
      });

      test('should provide correct progress percentage', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);
        final paths = testFiles.map((f) => f.path).toList();

        final progressPercentages = <double>[];
        final subscription = container.listen<BulkOperationState>(
          bulkOperationNotifierProvider,
          (previous, next) {
            if (next.isOperationInProgress) {
              progressPercentages.add(next.progressPercentage);
            }
          },
        );

        await notifier.bulkDelete(paths);

        subscription.close();

        // Verify progress percentages are between 0 and 100
        for (final percentage in progressPercentages) {
          expect(percentage, greaterThanOrEqualTo(0));
          expect(percentage, lessThanOrEqualTo(100));
        }

        // Final percentage should be 100
        final finalState = container.read(bulkOperationNotifierProvider);
        expect(finalState.progressPercentage, 100);
      });

      test('should handle error during delete operation', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        // Mix of valid and invalid paths
        final paths = [
          testFiles[0].path,
          '/nonexistent/file1.png',
          testFiles[1].path,
          '/nonexistent/file2.png',
        ];

        final result = await notifier.bulkDelete(paths);

        // Some should succeed, some should fail
        expect(result.success + result.failed, 4);
        expect(result.errors, isNotEmpty);

        // State should show completion
        final state = container.read(bulkOperationNotifierProvider);
        expect(state.isCompleted, true);
        expect(
          state.hasError,
          false,
        ); // Individual errors don't set state error
      });

      test('should clear error when requested', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        // Try to undo when there's nothing to undo
        await notifier.undo();

        var state = container.read(bulkOperationNotifierProvider);
        expect(state.error, isNotNull);

        // Clear error
        notifier.clearError();

        state = container.read(bulkOperationNotifierProvider);
        expect(state.error, isNull);
      });

      test('should persist last operation result', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);
        final paths = testFiles.take(5).map((f) => f.path).toList();

        await notifier.bulkDelete(paths);

        final state = container.read(bulkOperationNotifierProvider);
        expect(state.lastResult, isNotNull);
        expect(state.lastResult?.success, 5);
        expect(state.lastResult?.failed, 0);
      });

      test('should handle rapid consecutive delete operations', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        // Perform multiple deletes in quick succession
        for (var i = 0; i < 3; i++) {
          final start = i * 3;
          final end = start + 3;
          if (end <= testFiles.length) {
            final paths = testFiles
                .skip(start)
                .take(end - start)
                .map((f) => f.path)
                .toList();
            await notifier.bulkDelete(paths);
          }
        }

        // Verify final state
        final state = container.read(bulkOperationNotifierProvider);
        expect(state.isCompleted, true);
        expect(state.lastResult?.success, greaterThan(0));
      });

      test('should maintain correct operation type during delete', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);
        final paths = testFiles.take(2).map((f) => f.path).toList();

        final operationTypes = <BulkOperationType?>[];
        final subscription = container.listen<BulkOperationState>(
          bulkOperationNotifierProvider,
          (previous, next) {
            if (next.currentOperation != null) {
              operationTypes.add(next.currentOperation);
            }
          },
        );

        await notifier.bulkDelete(paths);

        subscription.close();

        // All operation types should be delete
        for (final type in operationTypes) {
          expect(type, BulkOperationType.delete);
        }
      });
    });

    group('Undo/Redo Edge Cases', () {
      test('should handle undo when no operation to undo', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        // Try to undo without any operation
        await notifier.undo();

        final state = container.read(bulkOperationNotifierProvider);
        expect(state.error, contains('Cannot undo'));
      });

      test('should handle redo when no operation to redo', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        // Try to redo without any undo
        await notifier.redo();

        final state = container.read(bulkOperationNotifierProvider);
        expect(state.error, contains('Cannot redo'));
      });

      test('should handle undo and redo sequence', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);
        final paths = testFiles.take(2).map((f) => f.path).toList();

        // Perform delete
        await notifier.bulkDelete(paths);

        var state = container.read(bulkOperationNotifierProvider);
        expect(state.canUndo, true);
        expect(state.canRedo, false);

        // Undo (limited - files remain deleted)
        await notifier.undo();

        state = container.read(bulkOperationNotifierProvider);
        expect(state.canUndo, false);
        expect(state.canRedo, true);

        // Redo
        await notifier.redo();

        state = container.read(bulkOperationNotifierProvider);
        expect(state.canUndo, true);
        expect(state.canRedo, false);
      });

      test('should handle multiple undo operations', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);

        // Perform multiple deletes
        await notifier
            .bulkDelete(testFiles.take(2).map((f) => f.path).toList());
        await notifier
            .bulkDelete(testFiles.skip(2).take(2).map((f) => f.path).toList());

        var state = container.read(bulkOperationNotifierProvider);
        expect(state.canUndo, true);

        // Undo twice
        await notifier.undo();
        state = container.read(bulkOperationNotifierProvider);
        expect(state.canUndo, true);

        await notifier.undo();
        state = container.read(bulkOperationNotifierProvider);
        expect(state.canUndo, false);
        expect(state.canRedo, true);
      });
    });

    group('State Management', () {
      test('should update operationInProgress flag correctly', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);
        final paths = testFiles.take(5).map((f) => f.path).toList();

        final inProgressStates = <bool>[];
        final subscription = container.listen<BulkOperationState>(
          bulkOperationNotifierProvider,
          (previous, next) {
            inProgressStates.add(next.isOperationInProgress);
          },
        );

        await notifier.bulkDelete(paths);

        subscription.close();

        // Should have true at start, false at end
        expect(inProgressStates, contains(true));
        expect(inProgressStates.last, false);
      });

      test('should update current item during operation', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);
        final paths = testFiles.take(3).map((f) => f.path).toList();

        final currentItems = <String?>[];
        final subscription = container.listen<BulkOperationState>(
          bulkOperationNotifierProvider,
          (previous, next) {
            if (next.isOperationInProgress) {
              currentItems.add(next.currentItem);
            }
          },
        );

        await notifier.bulkDelete(paths);

        subscription.close();

        // Should have tracked current items
        expect(currentItems.length, greaterThan(0));
        expect(
          currentItems.any((item) => item != null && item.isNotEmpty),
          true,
        );
      });

      test('should compute correct progress percentage', () async {
        final notifier = container.read(bulkOperationNotifierProvider.notifier);
        final paths = testFiles.take(5).map((f) => f.path).toList();

        final percentages = <double>[];
        final subscription = container.listen<BulkOperationState>(
          bulkOperationNotifierProvider,
          (previous, next) {
            if (next.isOperationInProgress || next.isCompleted) {
              percentages.add(next.progressPercentage);
            }
          },
        );

        await notifier.bulkDelete(paths);

        subscription.close();

        // Progress should increase
        expect(percentages, isNotEmpty);

        // Check that percentage generally increases (allowing for some fluctuation)
        if (percentages.length > 1) {
          final firstPercentage = percentages.first;
          final lastPercentage = percentages.last;
          expect(lastPercentage, greaterThanOrEqualTo(firstPercentage));
        }
      });
    });
  });
}
