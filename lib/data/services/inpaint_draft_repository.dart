import 'dart:typed_data';

import '../models/inpaint/inpaint_draft.dart';

abstract interface class InpaintDraftRepository {
  Future<InpaintDraft> prepare({
    required Uint8List sourceBytes,
    required Map<String, dynamic> parameterSnapshot,
    required num estimatedAnlas,
  });

  Future<InpaintDraft?> get(String id);

  Future<List<InpaintDraft>> list();

  Future<Uint8List> readSource(String id);

  Future<Uint8List?> readMask(String id);

  Future<InpaintDraft> beginEditing(String id);

  Future<InpaintDraft> complete(
    String id, {
    required Uint8List sourceBytes,
    required Uint8List maskBytes,
    required Map<String, dynamic> parameterSnapshot,
    required num estimatedAnlas,
  });

  Future<InpaintDraft> cancel(String id);

  Future<InpaintDraft> reEdit(String id);

  Future<InpaintDraft> beginSubmission(String id);

  Future<InpaintDraft> restoreReady(String id, {required String message});

  Future<InpaintDraft> markSubmitted(String id);

  Future<InpaintDraft> markFailed(String id, {required String message});
}

class InpaintDraftNotFoundException implements Exception {
  const InpaintDraftNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'Inpaint draft not found: $id';
}

class InpaintDraftTransitionException implements Exception {
  const InpaintDraftTransitionException(this.from, this.operation);

  final String from;
  final String operation;

  @override
  String toString() => 'Cannot $operation an inpaint draft in state $from';
}

class InpaintDraftIntegrityException implements Exception {
  const InpaintDraftIntegrityException(this.message);

  final String message;

  @override
  String toString() => 'Inpaint draft integrity error: $message';
}
