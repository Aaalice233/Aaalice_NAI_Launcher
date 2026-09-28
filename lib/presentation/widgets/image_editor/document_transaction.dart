import 'dart:typed_data';

/// A complete immutable snapshot of the document values touched by an operation.
/// Byte buffers are copied so rollback never observes later mutations.
class DocumentSnapshot {
  DocumentSnapshot({
    required Map<String, Uint8List?> bytes,
    required Map<String, Object?> values,
  }) : bytes = Map.unmodifiable(
         bytes.map(
           (key, value) =>
               MapEntry(key, value == null ? null : Uint8List.fromList(value)),
         ),
       ),
       values = Map.unmodifiable(values);

  final Map<String, Uint8List?> bytes;
  final Map<String, Object?> values;
}

/// Runs a document mutation atomically and restores its complete snapshot on
/// failure. The owner supplies restoration because native image ownership must
/// stay with the layer/document implementation that created the resources.
class DocumentTransaction {
  DocumentTransaction({
    required this.snapshot,
    required Future<void> Function(DocumentSnapshot snapshot) restore,
  }) : _restore = restore;

  final DocumentSnapshot snapshot;
  final Future<void> Function(DocumentSnapshot snapshot) _restore;
  bool _completed = false;

  Future<T> run<T>(Future<T> Function() mutation) async {
    if (_completed) throw StateError('Document transaction is already closed.');
    try {
      final result = await mutation();
      _completed = true;
      return result;
    } catch (_) {
      await rollback();
      rethrow;
    }
  }

  Future<void> rollback() async {
    if (_completed) return;
    _completed = true;
    await _restore(snapshot);
  }
}
