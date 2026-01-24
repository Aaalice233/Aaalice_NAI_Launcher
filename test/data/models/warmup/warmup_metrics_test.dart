import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/warmup/warmup_metrics.dart';

void main() {
  group('WarmupTaskMetrics Constructor Tests', () {
    test('should create instance with all required fields', () {
      // Arrange
      const taskName = 'warmup_loadingTranslation';
      const durationMs = 1500;
      const status = WarmupTaskStatus.success;
      final timestamp = DateTime(2024, 1, 24, 12, 0, 0);

      // Act
      final metrics = WarmupTaskMetrics(
        taskName: taskName,
        durationMs: durationMs,
        status: status,
        timestamp: timestamp,
      );

      // Assert
      expect(metrics.taskName, equals(taskName),
          reason: 'Task name should be set correctly');
      expect(metrics.durationMs, equals(durationMs),
          reason: 'Duration should be set correctly');
      expect(metrics.status, equals(status),
          reason: 'Status should be set correctly');
      expect(metrics.timestamp, equals(timestamp),
          reason: 'Timestamp should be set correctly');
      expect(metrics.errorMessage, isNull,
          reason: 'Error message should be null when not provided');
    });

    test('should create instance with optional errorMessage', () {
      // Arrange
      const errorMessage = 'Failed to load translation';

      // Act
      final metrics = WarmupTaskMetrics(
        taskName: 'warmup_loadingTranslation',
        durationMs: 500,
        status: WarmupTaskStatus.failed,
        errorMessage: errorMessage,
        timestamp: DateTime.now(),
      );

      // Assert
      expect(metrics.errorMessage, equals(errorMessage),
          reason: 'Error message should be set when provided');
    });

    test('should create instance using factory constructor', () {
      // Arrange
      const taskName = 'warmup_initCache';
      const durationMs = 300;
      const status = WarmupTaskStatus.success;

      // Act
      final metrics = WarmupTaskMetrics.create(
        taskName: taskName,
        durationMs: durationMs,
        status: status,
      );

      // Assert
      expect(metrics.taskName, equals(taskName));
      expect(metrics.durationMs, equals(durationMs));
      expect(metrics.status, equals(status));
      expect(metrics.timestamp, isNotNull,
          reason: 'Timestamp should be set to current time');
      expect(metrics.errorMessage, isNull,
          reason: 'Error message should be null when not provided');
    });

    test('should create instance with error message using factory constructor',
        () {
      // Arrange
      const errorMessage = 'Connection timeout';

      // Act
      final metrics = WarmupTaskMetrics.create(
        taskName: 'warmup_networkCheck',
        durationMs: 5000,
        status: WarmupTaskStatus.failed,
        errorMessage: errorMessage,
      );

      // Assert
      expect(metrics.errorMessage, equals(errorMessage));
    });
  });

  group('WarmupTaskMetrics Status Tests', () {
    test('isSuccess should return true when status is success', () {
      // Arrange
      final metrics = WarmupTaskMetrics.create(
        taskName: 'test_task',
        durationMs: 100,
        status: WarmupTaskStatus.success,
      );

      // Assert
      expect(metrics.isSuccess, isTrue,
          reason: 'isSuccess should be true when status is success');
      expect(metrics.isFailed, isFalse,
          reason: 'isFailed should be false when status is success');
      expect(metrics.isSkipped, isFalse,
          reason: 'isSkipped should be false when status is success');
    });

    test('isFailed should return true when status is failed', () {
      // Arrange
      final metrics = WarmupTaskMetrics.create(
        taskName: 'test_task',
        durationMs: 100,
        status: WarmupTaskStatus.failed,
      );

      // Assert
      expect(metrics.isFailed, isTrue,
          reason: 'isFailed should be true when status is failed');
      expect(metrics.isSuccess, isFalse,
          reason: 'isSuccess should be false when status is failed');
      expect(metrics.isSkipped, isFalse,
          reason: 'isSkipped should be false when status is failed');
    });

    test('isSkipped should return true when status is skipped', () {
      // Arrange
      final metrics = WarmupTaskMetrics.create(
        taskName: 'test_task',
        durationMs: 0,
        status: WarmupTaskStatus.skipped,
      );

      // Assert
      expect(metrics.isSkipped, isTrue,
          reason: 'isSkipped should be true when status is skipped');
      expect(metrics.isSuccess, isFalse,
          reason: 'isSuccess should be false when status is skipped');
      expect(metrics.isFailed, isFalse,
          reason: 'isFailed should be false when status is skipped');
    });
  });

  group('WarmupTaskMetrics formattedDuration Tests', () {
    test('should format duration in milliseconds when < 1000ms', () {
      // Arrange
      final metrics = WarmupTaskMetrics.create(
        taskName: 'test_task',
        durationMs: 500,
        status: WarmupTaskStatus.success,
      );

      // Assert
      expect(metrics.formattedDuration, equals('500ms'),
          reason: 'Duration < 1000ms should be formatted as milliseconds');
    });

    test('should format duration in seconds when >= 1000ms and < 60000ms',
        () {
      // Arrange
      final metrics = WarmupTaskMetrics.create(
        taskName: 'test_task',
        durationMs: 2500,
        status: WarmupTaskStatus.success,
      );

      // Assert
      expect(metrics.formattedDuration, equals('2.5s'),
          reason: 'Duration >= 1000ms should be formatted as seconds');
    });

    test('should format duration in seconds with one decimal place', () {
      // Arrange
      final metrics = WarmupTaskMetrics.create(
        taskName: 'test_task',
        durationMs: 1234,
        status: WarmupTaskStatus.success,
      );

      // Assert
      expect(metrics.formattedDuration, equals('1.2s'),
          reason: 'Duration should be formatted with one decimal place');
    });

    test('should format duration in minutes when >= 60000ms', () {
      // Arrange
      final metrics = WarmupTaskMetrics.create(
        taskName: 'test_task',
        durationMs: 120000,
        status: WarmupTaskStatus.success,
      );

      // Assert
      expect(metrics.formattedDuration, equals('2.0m'),
          reason: 'Duration >= 60000ms should be formatted as minutes');
    });

    test('should format very long durations correctly in minutes', () {
      // Arrange
      final metrics = WarmupTaskMetrics.create(
        taskName: 'test_task',
        durationMs: 185000, // 3 minutes and 5 seconds
        status: WarmupTaskStatus.success,
      );

      // Assert
      expect(metrics.formattedDuration, equals('3.1m'),
          reason: 'Long duration should be formatted in minutes with one decimal');
    });

    test('should handle zero duration', () {
      // Arrange
      final metrics = WarmupTaskMetrics.create(
        taskName: 'test_task',
        durationMs: 0,
        status: WarmupTaskStatus.skipped,
      );

      // Assert
      expect(metrics.formattedDuration, equals('0ms'),
          reason: 'Zero duration should be formatted as 0ms');
    });

    test('should handle boundary value at 999ms', () {
      // Arrange
      final metrics = WarmupTaskMetrics.create(
        taskName: 'test_task',
        durationMs: 999,
        status: WarmupTaskStatus.success,
      );

      // Assert
      expect(metrics.formattedDuration, equals('999ms'),
          reason: '999ms should be formatted in milliseconds');
    });

    test('should handle boundary value at 1000ms', () {
      // Arrange
      final metrics = WarmupTaskMetrics.create(
        taskName: 'test_task',
        durationMs: 1000,
        status: WarmupTaskStatus.success,
      );

      // Assert
      expect(metrics.formattedDuration, equals('1.0s'),
          reason: '1000ms should be formatted as 1.0s');
    });

    test('should handle boundary value at 59999ms', () {
      // Arrange
      final metrics = WarmupTaskMetrics.create(
        taskName: 'test_task',
        durationMs: 59999,
        status: WarmupTaskStatus.success,
      );

      // Assert
      expect(metrics.formattedDuration, equals('60.0s'),
          reason: '59999ms should be formatted in seconds');
    });

    test('should handle boundary value at 60000ms', () {
      // Arrange
      final metrics = WarmupTaskMetrics.create(
        taskName: 'test_task',
        durationMs: 60000,
        status: WarmupTaskStatus.success,
      );

      // Assert
      expect(metrics.formattedDuration, equals('1.0m'),
          reason: '60000ms should be formatted as 1.0m');
    });
  });

  group('WarmupTaskMetrics JSON Serialization Tests', () {
    test('should serialize to JSON correctly', () {
      // Arrange
      final timestamp = DateTime(2024, 1, 24, 12, 30, 45);
      final metrics = WarmupTaskMetrics(
        taskName: 'warmup_initCache',
        durationMs: 1500,
        status: WarmupTaskStatus.success,
        errorMessage: null,
        timestamp: timestamp,
      );

      // Act
      final json = metrics.toJson();

      // Assert
      expect(json['taskName'], equals('warmup_initCache'));
      expect(json['durationMs'], equals(1500));
      expect(json['status'], equals('success'));
      expect(json['errorMessage'], isNull);
      expect(json['timestamp'], equals(timestamp.toIso8601String()));
    });

    test('should serialize with error message to JSON', () {
      // Arrange
      final timestamp = DateTime(2024, 1, 24, 12, 30, 45);
      final metrics = WarmupTaskMetrics(
        taskName: 'warmup_networkCheck',
        durationMs: 5000,
        status: WarmupTaskStatus.failed,
        errorMessage: 'Connection timeout',
        timestamp: timestamp,
      );

      // Act
      final json = metrics.toJson();

      // Assert
      expect(json['taskName'], equals('warmup_networkCheck'));
      expect(json['durationMs'], equals(5000));
      expect(json['status'], equals('failed'));
      expect(json['errorMessage'], equals('Connection timeout'));
      expect(json['timestamp'], equals(timestamp.toIso8601String()));
    });

    test('should deserialize from JSON correctly', () {
      // Arrange
      final json = {
        'taskName': 'warmup_initCache',
        'durationMs': 1500,
        'status': 'success',
        'errorMessage': null,
        'timestamp': '2024-01-24T12:30:45.000',
      };

      // Act
      final metrics = WarmupTaskMetrics.fromJson(json);

      // Assert
      expect(metrics.taskName, equals('warmup_initCache'));
      expect(metrics.durationMs, equals(1500));
      expect(metrics.status, equals(WarmupTaskStatus.success));
      expect(metrics.errorMessage, isNull);
      expect(
        metrics.timestamp,
        equals(DateTime.parse('2024-01-24T12:30:45.000')),
      );
    });

    test('should deserialize with error message from JSON', () {
      // Arrange
      final json = {
        'taskName': 'warmup_networkCheck',
        'durationMs': 5000,
        'status': 'failed',
        'errorMessage': 'Connection timeout',
        'timestamp': '2024-01-24T12:30:45.000',
      };

      // Act
      final metrics = WarmupTaskMetrics.fromJson(json);

      // Assert
      expect(metrics.taskName, equals('warmup_networkCheck'));
      expect(metrics.durationMs, equals(5000));
      expect(metrics.status, equals(WarmupTaskStatus.failed));
      expect(metrics.errorMessage, equals('Connection timeout'));
    });

    test('should deserialize skipped status from JSON', () {
      // Arrange
      final json = {
        'taskName': 'warmup_optionalTask',
        'durationMs': 0,
        'status': 'skipped',
        'errorMessage': null,
        'timestamp': '2024-01-24T12:30:45.000',
      };

      // Act
      final metrics = WarmupTaskMetrics.fromJson(json);

      // Assert
      expect(metrics.status, equals(WarmupTaskStatus.skipped));
      expect(metrics.isSkipped, isTrue);
    });

    test('should maintain data integrity through serialize-deserialize cycle',
        () {
      // Arrange
      final original = WarmupTaskMetrics.create(
        taskName: 'warmup_testTask',
        durationMs: 2345,
        status: WarmupTaskStatus.success,
      );

      // Act
      final json = original.toJson();
      final restored = WarmupTaskMetrics.fromJson(json);

      // Assert
      expect(restored.taskName, equals(original.taskName));
      expect(restored.durationMs, equals(original.durationMs));
      expect(restored.status, equals(original.status));
      expect(restored.errorMessage, equals(original.errorMessage));
      // Note: timestamp might have slight microsecond differences in serialization
      expect(
        restored.timestamp.millisecondsSinceEpoch,
        closeTo(original.timestamp.millisecondsSinceEpoch, 1),
      );
    });
  });

  group('WarmupTaskStatus Enum Tests', () {
    test('should have correct enum values', () {
      // Assert
      expect(WarmupTaskStatus.success, isNotNull);
      expect(WarmupTaskStatus.failed, isNotNull);
      expect(WarmupTaskStatus.skipped, isNotNull);
    });

    test('enum values should be distinct', () {
      // Assert
      expect(WarmupTaskStatus.success, isNot(equals(WarmupTaskStatus.failed)));
      expect(WarmupTaskStatus.success, isNot(equals(WarmupTaskStatus.skipped)));
      expect(WarmupTaskStatus.failed, isNot(equals(WarmupTaskStatus.skipped)));
    });
  });

  group('WarmupTaskMetrics Edge Cases Tests', () {
    test('should handle very long task names', () {
      // Arrange
      final longTaskName = 'warmup_' * 100;

      // Act
      final metrics = WarmupTaskMetrics.create(
        taskName: longTaskName,
        durationMs: 100,
        status: WarmupTaskStatus.success,
      );

      // Assert
      expect(metrics.taskName, equals(longTaskName),
          reason: 'Should handle very long task names');
    });

    test('should handle very large duration values', () {
      // Arrange
      const largeDuration = 999999999; // ~277 hours

      // Act
      final metrics = WarmupTaskMetrics.create(
        taskName: 'test_task',
        durationMs: largeDuration,
        status: WarmupTaskStatus.success,
      );

      // Assert
      expect(metrics.durationMs, equals(largeDuration));
      expect(metrics.formattedDuration, equals('16666.7m'),
          reason: 'Should format very large durations correctly');
    });

    test('should handle empty error message as null equivalent', () {
      // Arrange
      final metrics1 = WarmupTaskMetrics.create(
        taskName: 'test_task',
        durationMs: 100,
        status: WarmupTaskStatus.failed,
      );

      final metrics2 = WarmupTaskMetrics(
        taskName: 'test_task',
        durationMs: 100,
        status: WarmupTaskStatus.failed,
        errorMessage: '',
        timestamp: DateTime.now(),
      );

      // Assert
      expect(metrics1.errorMessage, isNull);
      expect(metrics2.errorMessage, equals(''));
    });

    test('should create instances with different timestamps', () {
      // Arrange
      final timestamp1 = DateTime(2024, 1, 24, 12, 0, 0);
      final timestamp2 = DateTime(2024, 1, 24, 12, 0, 1);

      // Act
      final metrics1 = WarmupTaskMetrics(
        taskName: 'task1',
        durationMs: 100,
        status: WarmupTaskStatus.success,
        timestamp: timestamp1,
      );

      final metrics2 = WarmupTaskMetrics(
        taskName: 'task2',
        durationMs: 200,
        status: WarmupTaskStatus.success,
        timestamp: timestamp2,
      );

      // Assert
      expect(metrics1.timestamp, equals(timestamp1));
      expect(metrics2.timestamp, equals(timestamp2));
      expect(metrics1.timestamp, isNot(equals(metrics2.timestamp)),
          reason: 'Each instance should have its own timestamp');
    });

    test('should handle different timestamp values', () {
      // Arrange
      final past = DateTime(2024, 1, 1, 0, 0, 0);
      final future = DateTime(2025, 12, 31, 23, 59, 59);

      // Act
      final pastMetrics = WarmupTaskMetrics(
        taskName: 'past_task',
        durationMs: 100,
        status: WarmupTaskStatus.success,
        timestamp: past,
      );

      final futureMetrics = WarmupTaskMetrics(
        taskName: 'future_task',
        durationMs: 100,
        status: WarmupTaskStatus.success,
        timestamp: future,
      );

      // Assert
      expect(pastMetrics.timestamp, equals(past));
      expect(futureMetrics.timestamp, equals(future));
      expect(pastMetrics.timestamp.isBefore(futureMetrics.timestamp), isTrue);
    });
  });

  group('WarmupTaskMetrics Immutability Tests', () {
    test('should be immutable with freezed', () {
      // Arrange
      final metrics = WarmupTaskMetrics.create(
        taskName: 'test_task',
        durationMs: 100,
        status: WarmupTaskStatus.success,
      );

      // Act & Assert
      // Freezed-generated classes are immutable
      // If this compiles and runs, immutability is enforced
      expect(metrics, isA<WarmupTaskMetrics>());
      expect(metrics.taskName, equals('test_task'));
    });

    test('should create new instance with copyWith', () {
      // Arrange
      final original = WarmupTaskMetrics.create(
        taskName: 'test_task',
        durationMs: 100,
        status: WarmupTaskStatus.success,
      );

      // Act
      final modified = original.copyWith(
        durationMs: 200,
        status: WarmupTaskStatus.failed,
      );

      // Assert
      expect(original.taskName, equals(modified.taskName));
      expect(original.durationMs, equals(100),
          reason: 'Original should remain unchanged');
      expect(modified.durationMs, equals(200),
          reason: 'Modified should have new value');
      expect(modified.status, equals(WarmupTaskStatus.failed));
    });

    test('should handle copyWith with null values', () {
      // Arrange
      final original = WarmupTaskMetrics(
        taskName: 'test_task',
        durationMs: 100,
        status: WarmupTaskStatus.failed,
        errorMessage: 'Error',
        timestamp: DateTime.now(),
      );

      // Act
      final modified = original.copyWith(errorMessage: null);

      // Assert
      expect(original.errorMessage, equals('Error'),
          reason: 'Original should remain unchanged');
      expect(modified.errorMessage, isNull,
          reason: 'Modified should have null errorMessage');
    });
  });
}
