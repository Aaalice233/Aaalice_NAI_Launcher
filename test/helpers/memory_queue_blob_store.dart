import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:nai_launcher/core/storage/replication_queue_blob_store.dart';
import 'package:nai_launcher/core/storage/storage_file_system.dart';
import 'package:path/path.dart' as p;

/// 只存在于内存的文件系统，供队列图片存储的 provider 测试使用。
class MemoryStorageFileSystem extends StorageFileSystem {
  final Map<String, Uint8List> files = {};
  int writes = 0;
  int deletes = 0;
  bool failWrites = false;

  /// 列目录时在交出全部条目之后、结束之前等待，用来卡住清扫的时序。
  Completer<void>? listGate;

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    if (failWrites) throw FileSystemException('injected write failure', path);
    writes++;
    files[path] = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List> readBytes(String path) async =>
      files[path] ?? (throw PathNotFoundException(path, const OSError()));

  @override
  Future<int> length(String path) async => (await readBytes(path)).length;

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<void> delete(String path) async {
    if (files.remove(path) == null) {
      throw PathNotFoundException(path, const OSError());
    }
    deletes++;
  }

  @override
  Future<void> rename(String from, String to) async {
    files[to] =
        files.remove(from) ??
        (throw PathNotFoundException(from, const OSError()));
  }

  @override
  Stream<FileSystemEntity> list(String directory) async* {
    final paths = [
      for (final path in files.keys)
        if (p.dirname(path) == directory) path,
    ];
    for (final path in paths) {
      yield File(path);
    }
    await listGate?.future;
  }
}

const String memoryQueueBlobDirectory = '/queue-blobs';

ReplicationQueueBlobStore memoryQueueBlobStore([
  MemoryStorageFileSystem? fileSystem,
]) => ReplicationQueueBlobStore(
  resolveDirectory: () async => memoryQueueBlobDirectory,
  fileSystem: fileSystem ?? MemoryStorageFileSystem(),
  worker: <T>(FutureOr<T> Function() task, {String? debugName}) async => task(),
);
