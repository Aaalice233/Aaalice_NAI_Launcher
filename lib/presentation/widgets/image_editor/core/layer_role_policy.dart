import 'dart:ui';

import '../layers/layer.dart';
import '../layers/layer_manager.dart';
import '../layers/layer_role.dart';

/// 图层结构约束。重绘会话里蒙版层始终压在全部图片层之上，原图层不可删除、不可被合并掉；
/// 编辑会话不启用角色，只要求至少保留一个图层。
class LayerRolePolicy {
  const LayerRolePolicy.disabled()
    : rolesEnabled = false,
      protectedLayerId = null;

  const LayerRolePolicy.inpaint({required this.protectedLayerId})
    : rolesEnabled = true;

  final bool rolesEnabled;

  /// 原图层：它的底图范围就是取景框计算所用的原图区域
  final String? protectedLayerId;

  bool isProtected(Layer layer) =>
      rolesEnabled && layer.id == protectedLayerId;

  /// 原图层烘焙时输出范围必须保持为原图区域，其余图层不锁定
  Rect? extentLockFor(Layer layer) {
    if (!isProtected(layer)) return null;
    final image = layer.baseImage;
    if (image == null) return null;
    return layer.baseImageOffset &
        Size(image.width.toDouble(), image.height.toDouble());
  }

  /// 新图层的插入位置：紧贴当前图层上方，重绘会话里再按角色落到各自的分组
  int insertIndexFor(LayerManager layers, LayerRole role) {
    final all = layers.layers;
    final active = layers.activeLayer;
    final activeIndex = active == null ? -1 : all.indexOf(active);
    if (!rolesEnabled) {
      return activeIndex < 0 ? 0 : activeIndex;
    }
    final maskCount = all.where((layer) => layer.isMask).length;
    if (active != null && active.role == role && activeIndex >= 0) {
      return activeIndex;
    }
    return role == LayerRole.mask ? 0 : maskCount;
  }

  /// 蒙版层必须全部排在图片层前面（上方）
  bool isValidOrder(List<Layer> layers) {
    if (!rolesEnabled) return true;
    var seenImage = false;
    for (final layer in layers) {
      if (!layer.isMask) {
        seenImage = true;
      } else if (seenImage) {
        return false;
      }
    }
    return true;
  }

  bool canReorder(LayerManager layers, int oldIndex, int newIndex) {
    final all = layers.layers;
    if (oldIndex < 0 || oldIndex >= all.length) return false;
    if (newIndex < 0 || newIndex >= all.length || oldIndex == newIndex) {
      return false;
    }
    final reordered = List<Layer>.of(all);
    reordered.insert(newIndex, reordered.removeAt(oldIndex));
    return isValidOrder(reordered);
  }

  bool canDelete(LayerManager layers, Layer layer) {
    if (layer.locked || layers.layerCount <= 1) return false;
    if (!rolesEnabled) return true;
    if (isProtected(layer)) return false;
    // 至少留一个蒙版层承接蒙版笔
    return !layer.isMask || layers.maskLayers.length > 1;
  }

  /// 下方图层存在、同一角色、双方可见且未锁定，原图层不能被合并进别的图层
  Layer? mergeTargetFor(LayerManager layers, Layer layer) {
    final all = layers.layers;
    final index = all.indexOf(layer);
    if (index < 0 || index + 1 >= all.length) return null;
    final below = all[index + 1];
    if (layer.locked || below.locked) return null;
    if (!layer.visible || !below.visible) return null;
    if (!layer.hasContent) return null;
    if (rolesEnabled && (below.role != layer.role || isProtected(layer))) {
      return null;
    }
    return below;
  }

  /// 原图层清空后原图区域随之消失，取景框计算无从进行
  bool canClear(Layer layer) =>
      !layer.locked && layer.hasContent && !isProtected(layer);
}
