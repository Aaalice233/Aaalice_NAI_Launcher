import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../core/editor_state.dart';
import '../layers/layer.dart';
import 'project_data.dart';

/// 项目文件扩展名
const String projectExtension = '.naiedit';

/// 文件状态信息包装类
///
/// 用于包装FileStat或表示一个不存在的文件
class _FileStatInfo {
  final File file;
  final DateTime modified;
  final FileSystemEntityType type;

  const _FileStatInfo({
    required this.file,
    required this.modified,
    required this.type,
  });

  /// 从FileStat创建
  factory _FileStatInfo.fromStat(File file, FileStat stat) => _FileStatInfo(
        file: file,
        modified: stat.modified,
        type: stat.type,
      );

  /// 表示不存在的文件
  factory _FileStatInfo.notFound(File file) => _FileStatInfo(
        file: file,
        modified: DateTime(0),
        type: FileSystemEntityType.notFound,
      );

  bool get exists => type != FileSystemEntityType.notFound;
}

/// 项目管理器
class ProjectManager {
  /// 保存项目到文件
  static Future<void> saveProject(
    EditorState state,
    String filePath,
  ) async {
    final projectData = _createProjectData(state);
    final json = jsonEncode(projectData.toJson());

    final file = File(filePath);
    await file.writeAsString(json);
  }

  /// 从文件加载项目
  static Future<ProjectData> loadProject(String filePath) async {
    final file = File(filePath);
    final json = await file.readAsString();
    final data = jsonDecode(json) as Map<String, dynamic>;

    return ProjectData.fromJson(data);
  }

  /// 应用项目数据到编辑器状态
  static Future<void> applyProjectData(
    EditorState state,
    ProjectData project,
  ) async {
    // 重置状态
    state.reset();

    // 设置画布尺寸
    state.setCanvasSize(
      Size(
        project.width.toDouble(),
        project.height.toDouble(),
      ),
    );

    // 设置颜色
    state.setForegroundColor(Color(project.foregroundColor));
    state.setBackgroundColor(Color(project.backgroundColor));

    // 恢复图层
    for (final layerData in project.layers) {
      final layer = Layer(
        id: layerData.id,
        name: layerData.name,
        visible: layerData.visible,
        locked: layerData.locked,
        opacity: layerData.opacity,
        blendMode: _parseBlendMode(layerData.blendMode),
      );

      // 恢复笔画
      for (final strokeData in layerData.strokes) {
        layer.addStroke(strokeData.toStrokeData());
      }

      // 添加图层到管理器
      state.layerManager.insertLayerFromData(
        layer.toData(),
        state.layerManager.layerCount,
      );
    }

    // 设置活动图层
    if (project.activeLayerId != null) {
      state.layerManager.setActiveLayer(project.activeLayerId!);
    }
  }

  /// 创建项目数据
  static ProjectData _createProjectData(EditorState state) {
    final layers = <LayerProjectData>[];

    for (final layer in state.layerManager.layers) {
      final strokes = layer.strokes
          .map((s) => StrokeProjectData.fromStrokeData(s))
          .toList();

      layers.add(
        LayerProjectData(
          id: layer.id,
          name: layer.name,
          visible: layer.visible,
          locked: layer.locked,
          opacity: layer.opacity,
          blendMode: layer.blendMode.name,
          strokes: strokes,
        ),
      );
    }

    return ProjectData(
      width: state.canvasSize.width.toInt(),
      height: state.canvasSize.height.toInt(),
      layers: layers,
      activeLayerId: state.layerManager.activeLayerId,
      foregroundColor: state.foregroundColor.value,
      backgroundColor: state.backgroundColor.value,
    );
  }

  /// 解析混合模式
  static LayerBlendMode _parseBlendMode(String name) {
    return LayerBlendMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => LayerBlendMode.normal,
    );
  }

  /// 获取自动保存目录
  static Future<Directory> getAutoSaveDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final autoSaveDir =
        Directory(path.join(appDir.path, 'NAILauncher', 'autosave'));

    if (!await autoSaveDir.exists()) {
      await autoSaveDir.create(recursive: true);
    }

    return autoSaveDir;
  }

  /// 自动保存
  static Future<String> autoSave(EditorState state) async {
    final autoSaveDir = await getAutoSaveDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath =
        path.join(autoSaveDir.path, 'autosave_$timestamp$projectExtension');

    await saveProject(state, filePath);
    return filePath;
  }

  /// 获取最近的自动保存文件
  static Future<String?> getLatestAutoSave() async {
    final autoSaveDir = await getAutoSaveDirectory();

    if (!await autoSaveDir.exists()) {
      return null;
    }

    final files = await autoSaveDir
        .list()
        .where(
          (entity) => entity is File && entity.path.endsWith(projectExtension),
        )
        .cast<File>()
        .toList();

    if (files.isEmpty) {
      return null;
    }

    final validFiles = await _getFilesWithStats(files);
    if (validFiles.isEmpty) {
      return null;
    }

    validFiles.sort((a, b) => b.modified.compareTo(a.modified));
    return validFiles.first.file.path;
  }

  /// 清理旧的自动保存文件（保留最近N个）
  static Future<void> cleanupAutoSaves({int keepCount = 5}) async {
    final autoSaveDir = await getAutoSaveDirectory();

    if (!await autoSaveDir.exists()) {
      return;
    }

    final files = await autoSaveDir
        .list()
        .where(
          (entity) => entity is File && entity.path.endsWith(projectExtension),
        )
        .cast<File>()
        .toList();

    if (files.length <= keepCount) {
      return;
    }

    final validFiles = await _getFilesWithStats(files);
    if (validFiles.length <= keepCount) {
      return;
    }

    validFiles.sort((a, b) => b.modified.compareTo(a.modified));

    // 删除旧文件，忽略删除失败的文件
    for (final fileInfo in validFiles.skip(keepCount)) {
      try {
        await fileInfo.file.delete();
      } catch (_) {}
    }
  }

  /// 批量获取文件状态（每批20个，避免无界并发）
  static Future<List<_FileStatInfo>> _getFilesWithStats(List<File> files) async {
    const batchSize = 20;
    final result = <_FileStatInfo>[];

    for (var i = 0; i < files.length; i += batchSize) {
      final batch = files.sublist(i, min(i + batchSize, files.length));
      final batchStats = await Future.wait(
        batch.map((file) async {
          try {
            return _FileStatInfo.fromStat(file, await file.stat());
          } catch (_) {
            return _FileStatInfo.notFound(file);
          }
        }),
      );
      result.addAll(batchStats);
    }

    return result.where((info) => info.exists).toList();
  }
}
