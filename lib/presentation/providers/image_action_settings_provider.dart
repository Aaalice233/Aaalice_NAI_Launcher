import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../widgets/common/image_card_action.dart';

/// 承载图片操作按钮的四大业务场景
enum ImageActionScene {
  historyCard('historyCard', '历史记录卡片'),
  canvasPreview('canvasPreview', '画布中心预览图'),
  imageDetail('imageDetail', '图片详情顶栏'),
  localGallery('localGallery', '本地图库卡片');

  const ImageActionScene(this.key, this.displayName);
  final String key;
  final String displayName;

  String get storageKey => switch (this) {
    ImageActionScene.historyCard => StorageKeys.imageActionsConfigHistory,
    ImageActionScene.canvasPreview => StorageKeys.imageActionsConfigCanvas,
    ImageActionScene.imageDetail => StorageKeys.imageActionsConfigDetail,
    ImageActionScene.localGallery => StorageKeys.imageActionsConfigGallery,
  };
}

/// 动作元数据模型
@immutable
class ImageActionMeta {
  const ImageActionMeta({
    required this.id,
    required this.label,
    required this.icon,
    this.isDanger = false,
  });

  final ImageCardActionId id;
  final String label;
  final IconData icon;
  final bool isDanger;
}

/// 动作注册表与各场景默认配置
class ImageActionRegistry {
  const ImageActionRegistry._();

  static const Map<ImageCardActionId, ImageActionMeta> allActions = {
    ImageCardActionId.delete: ImageActionMeta(
      id: ImageCardActionId.delete,
      label: '删除',
      icon: Icons.delete_outline,
      isDanger: true,
    ),
    ImageCardActionId.inpaint: ImageActionMeta(
      id: ImageCardActionId.inpaint,
      label: '局部重绘',
      icon: Icons.brush_outlined,
    ),
    ImageCardActionId.copy: ImageActionMeta(
      id: ImageCardActionId.copy,
      label: '复用参数',
      icon: Icons.content_copy,
    ),
    ImageCardActionId.save: ImageActionMeta(
      id: ImageCardActionId.save,
      label: '下载/保存',
      icon: Icons.download,
    ),
    ImageCardActionId.imageToImage: ImageActionMeta(
      id: ImageCardActionId.imageToImage,
      label: '图生图',
      icon: Icons.image_outlined,
    ),
    ImageCardActionId.favorite: ImageActionMeta(
      id: ImageCardActionId.favorite,
      label: '收藏',
      icon: Icons.favorite_border,
    ),
    ImageCardActionId.saveAs: ImageActionMeta(
      id: ImageCardActionId.saveAs,
      label: '另存为',
      icon: Icons.save_as_outlined,
    ),
    ImageCardActionId.copyPrompt: ImageActionMeta(
      id: ImageCardActionId.copyPrompt,
      label: '复制提示词',
      icon: Icons.text_snippet_outlined,
    ),
    ImageCardActionId.copySeed: ImageActionMeta(
      id: ImageCardActionId.copySeed,
      label: '复制种子',
      icon: Icons.tag_outlined,
    ),
    ImageCardActionId.reversePrompt: ImageActionMeta(
      id: ImageCardActionId.reversePrompt,
      label: '反推Tag',
      icon: Icons.manage_search_rounded,
    ),
    ImageCardActionId.vibeTransfer: ImageActionMeta(
      id: ImageCardActionId.vibeTransfer,
      label: '风格迁移',
      icon: Icons.auto_fix_high,
    ),
    ImageCardActionId.preciseReference: ImageActionMeta(
      id: ImageCardActionId.preciseReference,
      label: '精准参考',
      icon: Icons.person_pin,
    ),
    ImageCardActionId.saveToPreciseRefLibrary: ImageActionMeta(
      id: ImageCardActionId.saveToPreciseRefLibrary,
      label: '存参考库',
      icon: Icons.bookmark_add_outlined,
    ),
    ImageCardActionId.sendToGeneration: ImageActionMeta(
      id: ImageCardActionId.sendToGeneration,
      label: '复刻文生图',
      icon: Icons.send_rounded,
    ),
    ImageCardActionId.generateVariations: ImageActionMeta(
      id: ImageCardActionId.generateVariations,
      label: '生成变体',
      icon: Icons.shuffle_rounded,
    ),
    ImageCardActionId.directorTools: ImageActionMeta(
      id: ImageCardActionId.directorTools,
      label: '导演工具',
      icon: Icons.movie_filter_outlined,
    ),
    ImageCardActionId.enhance: ImageActionMeta(
      id: ImageCardActionId.enhance,
      label: '图像增强',
      icon: Icons.auto_awesome,
    ),
    ImageCardActionId.upscale: ImageActionMeta(
      id: ImageCardActionId.upscale,
      label: '超分辨率',
      icon: Icons.zoom_in,
    ),
    ImageCardActionId.dlssEnhance: ImageActionMeta(
      id: ImageCardActionId.dlssEnhance,
      label: 'DLSS增强',
      icon: Icons.rocket_launch_outlined,
    ),
    ImageCardActionId.sendToKrita: ImageActionMeta(
      id: ImageCardActionId.sendToKrita,
      label: '送入Krita',
      icon: Icons.palette_outlined,
    ),
    ImageCardActionId.createWatermark: ImageActionMeta(
      id: ImageCardActionId.createWatermark,
      label: '水印处理',
      icon: Icons.branding_watermark_outlined,
    ),
    ImageCardActionId.createMosaic: ImageActionMeta(
      id: ImageCardActionId.createMosaic,
      label: '马赛克打码',
      icon: Icons.grid_on_rounded,
    ),
    ImageCardActionId.openFolder: ImageActionMeta(
      id: ImageCardActionId.openFolder,
      label: '定位文件',
      icon: Icons.folder_open_outlined,
    ),
    ImageCardActionId.shareDiscord: ImageActionMeta(
      id: ImageCardActionId.shareDiscord,
      label: '分享Discord',
      icon: Icons.chat_bubble_outline,
    ),
    ImageCardActionId.viewDetail: ImageActionMeta(
      id: ImageCardActionId.viewDetail,
      label: '查看详情',
      icon: Icons.visibility_outlined,
    ),
    ImageCardActionId.classify: ImageActionMeta(
      id: ImageCardActionId.classify,
      label: '相册分类',
      icon: Icons.folder_shared_outlined,
    ),
    ImageCardActionId.editImage: ImageActionMeta(
      id: ImageCardActionId.editImage,
      label: '图片编辑',
      icon: Icons.crop_rotate,
    ),
  };

  static ImageActionMeta getMeta(ImageCardActionId id) {
    return allActions[id] ??
        ImageActionMeta(
          id: id,
          label: id.name,
          icon: Icons.extension_outlined,
        );
  }

  /// 各场景支持的可选功能全集
  static List<ImageCardActionId> getPool(ImageActionScene scene) {
    return switch (scene) {
      ImageActionScene.historyCard => const [
        ImageCardActionId.delete,
        ImageCardActionId.inpaint,
        ImageCardActionId.copy,
        ImageCardActionId.save,
        ImageCardActionId.imageToImage,
        ImageCardActionId.favorite,
        ImageCardActionId.saveAs,
        ImageCardActionId.copyPrompt,
        ImageCardActionId.copySeed,
        ImageCardActionId.reversePrompt,
        ImageCardActionId.vibeTransfer,
        ImageCardActionId.preciseReference,
        ImageCardActionId.saveToPreciseRefLibrary,
        ImageCardActionId.sendToKrita,
        ImageCardActionId.upscale,
        ImageCardActionId.openFolder,
        ImageCardActionId.shareDiscord,
        ImageCardActionId.viewDetail,
      ],
      ImageActionScene.canvasPreview => const [
        ImageCardActionId.save,
        ImageCardActionId.saveAs,
        ImageCardActionId.viewDetail,
        ImageCardActionId.copy,
        ImageCardActionId.imageToImage,
        ImageCardActionId.inpaint,
        ImageCardActionId.generateVariations,
        ImageCardActionId.upscale,
        ImageCardActionId.shareDiscord,
        ImageCardActionId.copyPrompt,
        ImageCardActionId.copySeed,
        ImageCardActionId.directorTools,
        ImageCardActionId.enhance,
        ImageCardActionId.editImage,
        ImageCardActionId.reversePrompt,
        ImageCardActionId.vibeTransfer,
        ImageCardActionId.preciseReference,
        ImageCardActionId.sendToKrita,
        ImageCardActionId.openFolder,
      ],
      ImageActionScene.imageDetail => const [
        ImageCardActionId.save,
        ImageCardActionId.saveAs,
        ImageCardActionId.shareDiscord,
        ImageCardActionId.favorite,
        ImageCardActionId.viewDetail,
        ImageCardActionId.copy,
        ImageCardActionId.imageToImage,
        ImageCardActionId.inpaint,
        ImageCardActionId.reversePrompt,
        ImageCardActionId.copyPrompt,
        ImageCardActionId.copySeed,
        ImageCardActionId.createWatermark,
        ImageCardActionId.createMosaic,
        ImageCardActionId.openFolder,
      ],
      ImageActionScene.localGallery => const [
        ImageCardActionId.copyPrompt,
        ImageCardActionId.copy,
        ImageCardActionId.favorite,
        ImageCardActionId.sendToGeneration,
        ImageCardActionId.inpaint,
        ImageCardActionId.delete,
        ImageCardActionId.imageToImage,
        ImageCardActionId.reversePrompt,
        ImageCardActionId.vibeTransfer,
        ImageCardActionId.preciseReference,
        ImageCardActionId.saveToPreciseRefLibrary,
        ImageCardActionId.dlssEnhance,
        ImageCardActionId.upscale,
        ImageCardActionId.sendToKrita,
        ImageCardActionId.createWatermark,
        ImageCardActionId.createMosaic,
        ImageCardActionId.classify,
        ImageCardActionId.openFolder,
        ImageCardActionId.shareDiscord,
        ImageCardActionId.viewDetail,
      ],
    };
  }

  /// 各场景默认启用的功能及顺序
  static List<ImageCardActionId> getDefaultOrder(ImageActionScene scene) {
    return switch (scene) {
      // 历史记录卡片用户指定默认顺序（从右往左）：删除、局部重绘、复用参数、下载、图生图、收藏
      ImageActionScene.historyCard => const [
        ImageCardActionId.delete,
        ImageCardActionId.inpaint,
        ImageCardActionId.copy,
        ImageCardActionId.save,
        ImageCardActionId.imageToImage,
        ImageCardActionId.favorite,
      ],
      ImageActionScene.canvasPreview => const [
        ImageCardActionId.save,
        ImageCardActionId.saveAs,
        ImageCardActionId.viewDetail,
        ImageCardActionId.copy,
        ImageCardActionId.imageToImage,
        ImageCardActionId.inpaint,
        ImageCardActionId.generateVariations,
        ImageCardActionId.upscale,
        ImageCardActionId.shareDiscord,
      ],
      ImageActionScene.imageDetail => const [
        ImageCardActionId.save,
        ImageCardActionId.saveAs,
        ImageCardActionId.shareDiscord,
        ImageCardActionId.favorite,
        ImageCardActionId.viewDetail,
        ImageCardActionId.copy,
        ImageCardActionId.imageToImage,
        ImageCardActionId.inpaint,
        ImageCardActionId.reversePrompt,
        ImageCardActionId.copyPrompt,
        ImageCardActionId.createWatermark,
        ImageCardActionId.createMosaic,
      ],
      ImageActionScene.localGallery => const [
        ImageCardActionId.copyPrompt,
        ImageCardActionId.copy,
        ImageCardActionId.favorite,
        ImageCardActionId.sendToGeneration,
        ImageCardActionId.inpaint,
        ImageCardActionId.delete,
      ],
    };
  }
}

/// 状态存储类
class ImageActionSettingsState {
  const ImageActionSettingsState(this.actions);

  final Map<ImageActionScene, List<ImageCardActionId>> actions;

  List<ImageCardActionId> forScene(ImageActionScene scene) {
    return actions[scene] ?? ImageActionRegistry.getDefaultOrder(scene);
  }

  bool isEnabled(ImageActionScene scene, ImageCardActionId id) {
    return forScene(scene).contains(id);
  }

  ImageActionSettingsState copyWith({
    ImageActionScene? scene,
    List<ImageCardActionId>? sceneActions,
  }) {
    if (scene == null || sceneActions == null) return this;
    final next = Map<ImageActionScene, List<ImageCardActionId>>.from(actions);
    next[scene] = List.unmodifiable(sceneActions);
    return ImageActionSettingsState(Map.unmodifiable(next));
  }
}

/// Provider
final imageActionSettingsProvider =
    NotifierProvider<ImageActionSettingsNotifier, ImageActionSettingsState>(
      ImageActionSettingsNotifier.new,
    );

class ImageActionSettingsNotifier extends Notifier<ImageActionSettingsState> {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  ImageActionSettingsState build() {
    final map = <ImageActionScene, List<ImageCardActionId>>{};
    for (final scene in ImageActionScene.values) {
      map[scene] = _loadScene(scene);
    }
    return ImageActionSettingsState(Map.unmodifiable(map));
  }

  List<ImageCardActionId> _loadScene(ImageActionScene scene) {
    try {
      final raw = _storage.getSetting<dynamic>(scene.storageKey);
      if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final pool = ImageActionRegistry.getPool(scene);
          final result = <ImageCardActionId>[];
          for (final item in decoded) {
            if (item is String) {
              final id = ImageCardActionId.values.where((e) => e.name == item).firstOrNull;
              if (id != null && pool.contains(id) && !result.contains(id)) {
                result.add(id);
              }
            }
          }
          if (result.isNotEmpty) return result;
        }
      }
    } catch (e, st) {
      AppLogger.e('Failed to load image action config for ${scene.name}', e, st);
    }
    return List.from(ImageActionRegistry.getDefaultOrder(scene));
  }

  Future<void> _persistScene(ImageActionScene scene, List<ImageCardActionId> list) async {
    try {
      final encoded = jsonEncode(list.map((e) => e.name).toList());
      await _storage.setSetting(scene.storageKey, encoded);
    } catch (e, st) {
      AppLogger.e('Failed to persist image action config for ${scene.name}', e, st);
    }
  }

  /// 切换某功能的开启状态（开启时附加在末尾，关闭时移除）
  Future<void> toggleAction(
    ImageActionScene scene,
    ImageCardActionId id,
    bool enabled,
  ) async {
    final current = List<ImageCardActionId>.from(state.forScene(scene));
    if (enabled) {
      if (!current.contains(id)) {
        current.add(id);
      }
    } else {
      current.remove(id);
    }
    state = state.copyWith(scene: scene, sceneActions: current);
    await _persistScene(scene, current);
  }

  /// 在预览图上拖拽重排
  Future<void> reorderAction(
    ImageActionScene scene,
    int oldIndex,
    int newIndex,
  ) async {
    final current = List<ImageCardActionId>.from(state.forScene(scene));
    if (oldIndex < 0 || oldIndex >= current.length) return;
    if (newIndex < 0 || newIndex >= current.length) return;
    if (oldIndex == newIndex) return;

    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);

    state = state.copyWith(scene: scene, sceneActions: current);
    await _persistScene(scene, current);
  }

  /// 恢复当前场景为官方默认
  Future<void> resetToDefault(ImageActionScene scene) async {
    final defaultList = List<ImageCardActionId>.from(
      ImageActionRegistry.getDefaultOrder(scene),
    );
    state = state.copyWith(scene: scene, sceneActions: defaultList);
    await _persistScene(scene, defaultList);
  }
}
