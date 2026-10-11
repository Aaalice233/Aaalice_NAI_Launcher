import 'package:archive/archive.dart';

// ZIP 目录项以分隔符结尾；Unix 归档缺少 mode 位时会被解码成文件，以名字为准。
bool zipEntryNameMarksDirectory(String name) =>
    name.endsWith('/') || name.endsWith('\\');

bool isZipDirectoryEntry(ArchiveFile entry) =>
    !entry.isFile || zipEntryNameMarksDirectory(entry.name);
