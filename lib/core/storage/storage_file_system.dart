import 'dart:io';
import 'dart:typed_data';

/// 文件存储共用的读写接缝，测试通过子类注入故障。
class StorageFileSystem {
  const StorageFileSystem();

  Future<void> writeBytes(String path, Uint8List bytes) async {
    await File(path).writeAsBytes(bytes, flush: true);
  }

  Future<void> writeStream(String path, Stream<List<int>> bytes) async {
    final sink = File(path).openWrite(mode: FileMode.writeOnly);
    try {
      await sink.addStream(bytes);
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  Future<Uint8List> readBytes(String path) => File(path).readAsBytes();
  Stream<List<int>> openRead(String path) => File(path).openRead();
  Future<int> length(String path) => File(path).length();
  Future<bool> exists(String path) => File(path).exists();
  Future<void> delete(String path) => File(path).delete();

  Future<void> createDirectory(String path) async {
    await Directory(path).create(recursive: true);
  }

  Future<void> rename(String from, String to) async {
    await File(from).rename(to);
  }

  Stream<FileSystemEntity> list(String directory) =>
      Directory(directory).list();
}
