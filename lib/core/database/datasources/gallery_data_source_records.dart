part of 'gallery_data_source.dart';

/// 画廊图片记录
///
/// 数据库实体模型，用于 SQLite 存储。
/// 注意：与 [LocalImageRecord] 不同，此模型专注于数据库持久化。
class GalleryImageRecord {
  final int? id;
  final String filePath;
  final String fileName;
  final int fileSize;
  final int? width;
  final int? height;
  final double? aspectRatio;
  final DateTime modifiedAt;
  final DateTime createdAt;
  final DateTime indexedAt;
  final DateTime? lastScannedAt;
  final int dateYmd;
  final String? resolutionKey;
  final MetadataStatus metadataStatus;
  final bool isFavorite;
  final bool isDeleted;

  const GalleryImageRecord({
    this.id,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    this.width,
    this.height,
    this.aspectRatio,
    required this.modifiedAt,
    required this.createdAt,
    required this.indexedAt,
    this.lastScannedAt,
    required this.dateYmd,
    this.resolutionKey,
    this.metadataStatus = MetadataStatus.none,
    this.isFavorite = false,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'file_path': filePath,
    'file_name': fileName,
    'file_size': fileSize,
    'width': width,
    'height': height,
    'aspect_ratio': aspectRatio,
    'modified_at': modifiedAt.millisecondsSinceEpoch,
    'created_at': createdAt.millisecondsSinceEpoch,
    'indexed_at': indexedAt.millisecondsSinceEpoch,
    'last_scanned_at': lastScannedAt?.millisecondsSinceEpoch,
    'date_ymd': dateYmd,
    'resolution_key': resolutionKey,
    'metadata_status': metadataStatus.index,
    'is_favorite': isFavorite ? 1 : 0,
    'is_deleted': isDeleted ? 1 : 0,
  };

  factory GalleryImageRecord.fromMap(Map<String, dynamic> map) {
    final metadataStatusIndex = (map['metadata_status'] as num?)?.toInt() ?? 2;
    final safeMetadataStatus =
        metadataStatusIndex >= 0 &&
            metadataStatusIndex < MetadataStatus.values.length
        ? MetadataStatus.values[metadataStatusIndex]
        : MetadataStatus.none;

    return GalleryImageRecord(
      id: (map['id'] as num?)?.toInt(),
      filePath: map['file_path'] as String? ?? map['path'] as String? ?? '',
      fileName: map['file_name'] as String? ?? '',
      fileSize:
          (map['file_size'] as num?)?.toInt() ??
          (map['size'] as num?)?.toInt() ??
          0,
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      aspectRatio: (map['aspect_ratio'] as num?)?.toDouble(),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['modified_at'] as num?)?.toInt() ?? 0,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
      indexedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['indexed_at'] as num?)?.toInt() ?? 0,
      ),
      lastScannedAt: map['last_scanned_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['last_scanned_at'] as num).toInt(),
            )
          : null,
      dateYmd: (map['date_ymd'] as num?)?.toInt() ?? 0,
      resolutionKey: map['resolution_key'] as String?,
      metadataStatus: safeMetadataStatus,
      isFavorite: (map['is_favorite'] as num?)?.toInt() == 1,
      isDeleted: (map['is_deleted'] as num?)?.toInt() == 1,
    );
  }

  GalleryImageRecord copyWith({
    int? id,
    String? filePath,
    String? fileName,
    int? fileSize,
    int? width,
    int? height,
    double? aspectRatio,
    DateTime? modifiedAt,
    DateTime? createdAt,
    DateTime? indexedAt,
    DateTime? lastScannedAt,
    int? dateYmd,
    String? resolutionKey,
    MetadataStatus? metadataStatus,
    bool? isFavorite,
    bool? isDeleted,
  }) {
    return GalleryImageRecord(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      width: width ?? this.width,
      height: height ?? this.height,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      createdAt: createdAt ?? this.createdAt,
      indexedAt: indexedAt ?? this.indexedAt,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      dateYmd: dateYmd ?? this.dateYmd,
      resolutionKey: resolutionKey ?? this.resolutionKey,
      metadataStatus: metadataStatus ?? this.metadataStatus,
      isFavorite: isFavorite ?? this.isFavorite,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  String toString() {
    return 'GalleryImageRecord(id: $id, path: $filePath, name: $fileName, '
        'size: $fileSize, modifiedAt: $modifiedAt, metadataStatus: $metadataStatus, '
        'lastScannedAt: $lastScannedAt)';
  }
}

/// 画廊元数据记录
class GalleryMetadataRecord {
  final int imageId;
  final String prompt;
  final String negativePrompt;
  final int? seed;
  final String? sampler;
  final int? steps;
  final double? scale;
  final int? width;
  final int? height;
  final String? model;
  final bool smea;
  final bool smeaDyn;
  final String? noiseSchedule;
  final double? cfgRescale;
  final int? ucPreset;
  final bool qualityToggle;
  final bool isImg2Img;
  final double? strength;
  final double? noise;
  final String? software;
  final String? source;
  final String? version;
  final String? rawJson;
  final String fullPromptText;

  const GalleryMetadataRecord({
    required this.imageId,
    required this.prompt,
    this.negativePrompt = '',
    this.seed,
    this.sampler,
    this.steps,
    this.scale,
    this.width,
    this.height,
    this.model,
    this.smea = false,
    this.smeaDyn = false,
    this.noiseSchedule,
    this.cfgRescale,
    this.ucPreset,
    this.qualityToggle = false,
    this.isImg2Img = false,
    this.strength,
    this.noise,
    this.software,
    this.source,
    this.version,
    this.rawJson,
    required this.fullPromptText,
  });

  Map<String, dynamic> toMap() => {
    'image_id': imageId,
    'prompt': prompt,
    'negative_prompt': negativePrompt,
    'seed': seed,
    'sampler': sampler,
    'steps': steps,
    'cfg_scale': scale,
    'width': width,
    'height': height,
    'model': model,
    'smea': smea ? 1 : 0,
    'smea_dyn': smeaDyn ? 1 : 0,
    'noise_schedule': noiseSchedule,
    'cfg_rescale': cfgRescale,
    'uc_preset': ucPreset,
    'quality_toggle': qualityToggle ? 1 : 0,
    'is_img2img': isImg2Img ? 1 : 0,
    'strength': strength,
    'noise': noise,
    'software': software,
    'source': source,
    'version': version,
    'raw_json': rawJson,
    'full_prompt_text': fullPromptText,
  };

  factory GalleryMetadataRecord.fromMap(Map<String, dynamic> map) {
    return GalleryMetadataRecord(
      imageId: (map['image_id'] as num).toInt(),
      prompt: map['prompt'] as String? ?? '',
      negativePrompt: map['negative_prompt'] as String? ?? '',
      seed: map['seed'] as int?,
      sampler: map['sampler'] as String?,
      steps: map['steps'] as int?,
      scale: (map['cfg_scale'] as num?)?.toDouble(),
      width: map['width'] as int?,
      height: map['height'] as int?,
      model: map['model'] as String?,
      smea: (map['smea'] as num?)?.toInt() == 1,
      smeaDyn: (map['smea_dyn'] as num?)?.toInt() == 1,
      noiseSchedule: map['noise_schedule'] as String?,
      cfgRescale: (map['cfg_rescale'] as num?)?.toDouble(),
      ucPreset: map['uc_preset'] as int?,
      qualityToggle: (map['quality_toggle'] as num?)?.toInt() == 1,
      isImg2Img: (map['is_img2img'] as num?)?.toInt() == 1,
      strength: (map['strength'] as num?)?.toDouble(),
      noise: (map['noise'] as num?)?.toDouble(),
      software: map['software'] as String?,
      source: map['source'] as String?,
      version: map['version'] as String?,
      rawJson: map['raw_json'] as String?,
      fullPromptText: map['full_prompt_text'] as String? ?? '',
    );
  }

  factory GalleryMetadataRecord.fromNaiMetadata(
    int imageId,
    NaiImageMetadata metadata,
  ) {
    return GalleryMetadataRecord(
      imageId: imageId,
      prompt: metadata.prompt,
      negativePrompt: metadata.negativePrompt,
      seed: metadata.seed,
      sampler: metadata.sampler,
      steps: metadata.steps,
      scale: metadata.scale,
      width: metadata.width,
      height: metadata.height,
      model: metadata.model,
      smea: metadata.smea ?? false,
      smeaDyn: metadata.smeaDyn ?? false,
      noiseSchedule: metadata.noiseSchedule,
      cfgRescale: metadata.cfgRescale,
      ucPreset: metadata.ucPreset,
      qualityToggle: metadata.qualityToggle ?? false,
      isImg2Img: metadata.isImg2Img,
      strength: metadata.strength,
      noise: metadata.noise,
      software: metadata.software,
      source: metadata.source,
      version: metadata.version,
      rawJson: metadata.rawJson,
      fullPromptText: metadata.fullPrompt,
    );
  }
}

/// 画廊标签记录
class GalleryTagRecord {
  final String id;
  final String name;
  final String? category;
  final int usageCount;

  const GalleryTagRecord({
    required this.id,
    required this.name,
    this.category,
    this.usageCount = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'usage_count': usageCount,
  };

  factory GalleryTagRecord.fromMap(Map<String, dynamic> map) {
    return GalleryTagRecord(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String?,
      usageCount: (map['usage_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 扫描日志记录
class ScanLogRecord {
  final String id;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int totalFiles;
  final int processedFiles;
  final int newFiles;
  final int updatedFiles;
  final int failedFiles;
  final String? errorMessage;
  final String? scanPath;

  const ScanLogRecord({
    required this.id,
    required this.startedAt,
    this.completedAt,
    this.totalFiles = 0,
    this.processedFiles = 0,
    this.newFiles = 0,
    this.updatedFiles = 0,
    this.failedFiles = 0,
    this.errorMessage,
    this.scanPath,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'started_at': startedAt.millisecondsSinceEpoch,
    'completed_at': completedAt?.millisecondsSinceEpoch,
    'total_files': totalFiles,
    'processed_files': processedFiles,
    'new_files': newFiles,
    'updated_files': updatedFiles,
    'failed_files': failedFiles,
    'error_message': errorMessage,
    'scan_path': scanPath,
  };

  factory ScanLogRecord.fromMap(Map<String, dynamic> map) {
    return ScanLogRecord(
      id: map['id'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['started_at'] as num?)?.toInt() ?? 0,
      ),
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['completed_at'] as num).toInt(),
            )
          : null,
      totalFiles: (map['total_files'] as num?)?.toInt() ?? 0,
      processedFiles: (map['processed_files'] as num?)?.toInt() ?? 0,
      newFiles: (map['new_files'] as num?)?.toInt() ?? 0,
      updatedFiles: (map['updated_files'] as num?)?.toInt() ?? 0,
      failedFiles: (map['failed_files'] as num?)?.toInt() ?? 0,
      errorMessage: map['error_message'] as String?,
      scanPath: map['scan_path'] as String?,
    );
  }
}

/// 慢查询日志记录
class SlowQueryLog {
  final String operation;
  final int durationMs;
  final DateTime timestamp;
  final String? details;

  const SlowQueryLog({
    required this.operation,
    required this.durationMs,
    required this.timestamp,
    this.details,
  });
}

/// 查询缓存键
class _QueryCacheKey {
  final String queryType;
  final Map<String, dynamic> params;

  const _QueryCacheKey(this.queryType, this.params);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _QueryCacheKey &&
        other.queryType == queryType &&
        _mapEquals(other.params, params);
  }

  @override
  int get hashCode => Object.hash(queryType, _mapHash(params));

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static int _mapHash(Map<String, dynamic> map) {
    return Object.hashAll(map.entries.map((e) => Object.hash(e.key, e.value)));
  }
}
