import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../base_data_source.dart';

/// Database execution boundary used by gallery stores.
///
/// Implementations keep connection leasing, retry, and timeout policy outside
/// repositories, while tests can mock the complete contract. Atomic writes go
/// through `applyAtomically` so no transaction spans several isolate messages.
abstract interface class GalleryDatabaseGateway {
  Future<T> execute<T>(
    String operationName,
    Future<T> Function(Database db) operation, {
    Duration? timeout,
    int? maxRetries,
  });
}

class EnhancedGalleryDatabaseGateway implements GalleryDatabaseGateway {
  EnhancedGalleryDatabaseGateway(this.dataSource);

  final EnhancedBaseDataSource dataSource;

  @override
  Future<T> execute<T>(
    String operationName,
    Future<T> Function(Database db) operation, {
    Duration? timeout,
    int? maxRetries,
  }) {
    return dataSource.execute<T>(
      operationName,
      operation,
      timeout: timeout,
      maxRetries: maxRetries,
    );
  }
}
