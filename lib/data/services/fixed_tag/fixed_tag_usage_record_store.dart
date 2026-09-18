import 'dart:convert';
import 'dart:typed_data';

import 'package:hive/hive.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/fixed_tag/fixed_tag_usage_snapshot.dart';
import '../metadata/hash_calculator.dart';

/// 图片内容哈希到固定词使用快照的旁路记录库。
///
/// 结果图字节保持 NovelAI 原样，快照只存在这里；快照按指纹去重。
class FixedTagUsageRecordStore {
  FixedTagUsageRecordStore._internal();

  static final FixedTagUsageRecordStore _instance =
      FixedTagUsageRecordStore._internal();

  factory FixedTagUsageRecordStore() => _instance;

  static final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

  Box<String>? _usageBox;
  Box<String>? _snapshotBox;

  bool get isReady =>
      (_usageBox?.isOpen ?? false) && (_snapshotBox?.isOpen ?? false);

  Future<void> initialize() async {
    if (isReady) return;
    _usageBox = await _openBox(StorageKeys.fixedTagUsageRecordsBox);
    _snapshotBox = await _openBox(StorageKeys.fixedTagUsageSnapshotsBox);
  }

  /// 记录一张图片实际使用的固定词；空 entries 快照同样是权威信号。
  Future<void> record({
    required String contentHash,
    required FixedTagUsageSnapshot snapshot,
    DateTime? recordedAt,
  }) async {
    _requireHash(contentHash, 'contentHash');
    await initialize();
    final fingerprint = snapshot.fingerprint;
    await _writeSnapshot(fingerprint, snapshot.toJson());
    await _writeUsageIfNewer(
      FixedTagUsageRecord(
        contentHash: contentHash,
        fingerprint: fingerprint,
        recordedAt: recordedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  FixedTagUsageSnapshot? lookup(String contentHash) {
    if (!isReady || !_hex64.hasMatch(contentHash)) return null;
    final usage = _decodeUsage(contentHash, _usageBox!.get(contentHash));
    if (usage == null) return null;
    return snapshotOf(usage.fingerprint);
  }

  /// 派生副本传播：源图没有记录时不写入。
  Future<void> copy({required String fromHash, required String toHash}) async {
    _requireHash(fromHash, 'fromHash');
    _requireHash(toHash, 'toHash');
    if (fromHash == toHash) return;
    await initialize();
    final usage = _decodeUsage(fromHash, _usageBox!.get(fromHash));
    if (usage == null) return;
    if (!_snapshotBox!.containsKey(usage.fingerprint)) return;
    await _writeUsageIfNewer(
      FixedTagUsageRecord(
        contentHash: toHash,
        fingerprint: usage.fingerprint,
        recordedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// 水印、马赛克、DLSS 等重编码副本的传播入口。
  ///
  /// 副本此时已经落盘，记录库未就绪或写入失败都不把这次保存报成失败。
  Future<void> copyForDerivative({
    required Uint8List sourceBytes,
    required Uint8List outputBytes,
  }) async {
    if (!isReady) return;
    final calculator = FileHashCalculator();
    try {
      await copy(
        fromHash: calculator.calculateFromBytes(sourceBytes),
        toHash: calculator.calculateFromBytes(outputBytes),
      );
    } catch (error, stack) {
      AppLogger.e(
        'Failed to propagate fixed-tag usage to a derivative copy',
        error,
        stack,
        'FixedTagUsageRecordStore',
      );
    }
  }

  FixedTagUsageSnapshot? snapshotOf(String fingerprint) {
    if (!isReady || !_hex64.hasMatch(fingerprint)) return null;
    final raw = _snapshotBox!.get(fingerprint);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return FixedTagUsageSnapshot.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      return null;
    }
  }

  List<FixedTagUsageRecord> exportUsage() {
    if (!isReady) return const [];
    final records = <FixedTagUsageRecord>[];
    for (final key in _usageBox!.keys) {
      if (key is! String) continue;
      final usage = _decodeUsage(key, _usageBox!.get(key));
      if (usage == null) continue;
      if (!_snapshotBox!.containsKey(usage.fingerprint)) continue;
      records.add(usage);
    }
    records.sort((a, b) => a.contentHash.compareTo(b.contentHash));
    return records;
  }

  Map<String, Map<String, dynamic>> exportSnapshots() {
    if (!isReady) return const {};
    final snapshots = <String, Map<String, dynamic>>{};
    for (final key in _snapshotBox!.keys) {
      if (key is! String) continue;
      final snapshot = snapshotOf(key);
      if (snapshot == null) continue;
      snapshots[key] = snapshot.toJson();
    }
    return snapshots;
  }

  /// 云同步落实目标快照：同一哈希无条件覆盖，让本地等于所选备份。
  Future<void> applySync({
    Map<String, Map<String, dynamic>> snapshots = const {},
    Iterable<FixedTagUsageRecord> usage = const [],
  }) async {
    await initialize();
    for (final entry in snapshots.entries) {
      _requireHash(entry.key, 'fingerprint');
      await _writeSnapshot(entry.key, entry.value);
    }
    for (final record in usage) {
      _requireHash(record.contentHash, 'contentHash');
      _requireHash(record.fingerprint, 'fingerprint');
      if (!_snapshotBox!.containsKey(record.fingerprint)) {
        throw ArgumentError.value(
          record.fingerprint,
          'fingerprint',
          'Fixed-tag snapshot is missing for this usage record',
        );
      }
      await _writeUsage(record);
    }
  }

  Future<void> removeUsage(String contentHash) async {
    _requireHash(contentHash, 'contentHash');
    await initialize();
    await _usageBox!.delete(contentHash);
  }

  Future<void> _writeSnapshot(
    String fingerprint,
    Map<String, dynamic> snapshot,
  ) async {
    if (_snapshotBox!.containsKey(fingerprint)) return;
    await _snapshotBox!.put(fingerprint, jsonEncode(snapshot));
  }

  Future<void> _writeUsageIfNewer(FixedTagUsageRecord record) async {
    final existing = _decodeUsage(
      record.contentHash,
      _usageBox!.get(record.contentHash),
    );
    if (existing != null && existing.recordedAt.isAfter(record.recordedAt)) {
      return;
    }
    await _writeUsage(record);
  }

  Future<void> _writeUsage(FixedTagUsageRecord record) async {
    await _usageBox!.put(
      record.contentHash,
      jsonEncode({
        'fingerprint': record.fingerprint,
        'recordedAt': record.recordedAt.toUtc().millisecondsSinceEpoch,
      }),
    );
  }

  FixedTagUsageRecord? _decodeUsage(String contentHash, String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final fingerprint = decoded['fingerprint'];
      final recordedAt = decoded['recordedAt'];
      if (fingerprint is! String ||
          !_hex64.hasMatch(fingerprint) ||
          recordedAt is! int) {
        return null;
      }
      return FixedTagUsageRecord(
        contentHash: contentHash,
        fingerprint: fingerprint,
        recordedAt: DateTime.fromMillisecondsSinceEpoch(
          recordedAt,
          isUtc: true,
        ),
      );
    } on FormatException {
      return null;
    }
  }

  Future<Box<String>> _openBox(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box<String>(name);
    try {
      return await Hive.openBox<String>(name);
    } catch (error, stack) {
      AppLogger.e(
        'Failed to open fixed-tag usage box $name',
        error,
        stack,
        'FixedTagUsageRecordStore',
      );
      rethrow;
    }
  }

  void _requireHash(String value, String name) {
    if (!_hex64.hasMatch(value)) {
      throw ArgumentError.value(
        value,
        name,
        'Expected a lowercase 64-character SHA-256 hex digest',
      );
    }
  }
}

class FixedTagUsageRecord {
  const FixedTagUsageRecord({
    required this.contentHash,
    required this.fingerprint,
    required this.recordedAt,
  });

  final String contentHash;
  final String fingerprint;
  final DateTime recordedAt;
}
