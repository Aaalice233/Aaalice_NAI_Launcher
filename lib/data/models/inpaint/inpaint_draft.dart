import 'inpaint_draft_status.dart';

class InpaintDraftAsset {
  const InpaintDraftAsset({
    required this.sha256,
    required this.sizeBytes,
    required this.width,
    required this.height,
  });

  final String sha256;
  final int sizeBytes;
  final int width;
  final int height;

  Map<String, dynamic> toJson() => {
    'sha256': sha256,
    'sizeBytes': sizeBytes,
    'width': width,
    'height': height,
  };

  factory InpaintDraftAsset.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid inpaint draft asset');
    }
    final sha256 = value['sha256'];
    final sizeBytes = value['sizeBytes'];
    final width = value['width'];
    final height = value['height'];
    if (sha256 is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256) ||
        sizeBytes is! int ||
        sizeBytes < 1 ||
        width is! int ||
        width < 1 ||
        height is! int ||
        height < 1) {
      throw const FormatException('Invalid inpaint draft asset fields');
    }
    return InpaintDraftAsset(
      sha256: sha256,
      sizeBytes: sizeBytes,
      width: width,
      height: height,
    );
  }
}

class InpaintDraft {
  const InpaintDraft({
    required this.id,
    required this.status,
    required this.source,
    required this.parameterSnapshot,
    required this.estimatedAnlas,
    required this.createdAt,
    required this.updatedAt,
    this.mask,
    this.failureMessage,
    this.reEditOfDraftId,
  });

  static const schemaVersion = 1;

  final String id;
  final InpaintDraftStatus status;
  final InpaintDraftAsset source;
  final InpaintDraftAsset? mask;
  final Map<String, dynamic> parameterSnapshot;
  final num estimatedAnlas;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? failureMessage;
  final String? reEditOfDraftId;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'status': status.name,
    'source': source.toJson(),
    if (mask != null) 'mask': mask!.toJson(),
    'parameterSnapshot': parameterSnapshot,
    'estimatedAnlas': estimatedAnlas,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (failureMessage != null) 'failureMessage': failureMessage,
    if (reEditOfDraftId != null) 'reEditOfDraftId': reEditOfDraftId,
  };

  factory InpaintDraft.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw FormatException(
        'Unsupported inpaint draft schema: ${json['schemaVersion']}',
      );
    }
    final id = json['id'];
    final snapshot = json['parameterSnapshot'];
    final estimatedAnlas = json['estimatedAnlas'];
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    if (id is! String ||
        snapshot is! Map<String, dynamic> ||
        estimatedAnlas is! num ||
        !estimatedAnlas.isFinite ||
        estimatedAnlas < 0 ||
        createdAt == null ||
        updatedAt == null ||
        (json['failureMessage'] != null && json['failureMessage'] is! String) ||
        (json['reEditOfDraftId'] != null &&
            json['reEditOfDraftId'] is! String)) {
      throw const FormatException('Invalid inpaint draft metadata');
    }
    return InpaintDraft(
      id: id,
      status: InpaintDraftStatus.fromJson(json['status']),
      source: InpaintDraftAsset.fromJson(json['source']),
      mask: json['mask'] == null
          ? null
          : InpaintDraftAsset.fromJson(json['mask']),
      parameterSnapshot: snapshot,
      estimatedAnlas: estimatedAnlas,
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
      failureMessage: json['failureMessage'] as String?,
      reEditOfDraftId: json['reEditOfDraftId'] as String?,
    );
  }

  InpaintDraft copyWith({
    InpaintDraftStatus? status,
    InpaintDraftAsset? source,
    InpaintDraftAsset? mask,
    bool clearMask = false,
    Map<String, dynamic>? parameterSnapshot,
    num? estimatedAnlas,
    DateTime? updatedAt,
    String? failureMessage,
    bool clearFailureMessage = false,
  }) {
    return InpaintDraft(
      id: id,
      status: status ?? this.status,
      source: source ?? this.source,
      mask: clearMask ? null : mask ?? this.mask,
      parameterSnapshot: parameterSnapshot ?? this.parameterSnapshot,
      estimatedAnlas: estimatedAnlas ?? this.estimatedAnlas,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      failureMessage: clearFailureMessage
          ? null
          : failureMessage ?? this.failureMessage,
      reEditOfDraftId: reEditOfDraftId,
    );
  }
}
