import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/gallery_category.dart';

/// 本地图库批量移动的可选分类目标。
class LocalGalleryMoveTarget {
  const LocalGalleryMoveTarget({required this.category, required this.label});

  final GalleryCategory category;

  /// 含父级链路的展示名称，例如「角色 / 猫娘」。
  final String label;
}

/// 把分类树按展示顺序平铺为批量移动目标列表。
///
/// 根分类在前、同级按 [GalleryCategory.sortOrder] 排列，
/// 子分类跟随其父分类之后，与分类面板的树形展示顺序一致。
List<LocalGalleryMoveTarget> buildLocalGalleryMoveTargets(
  List<GalleryCategory> categories,
) {
  final tree = categories.buildTree();
  final targets = <LocalGalleryMoveTarget>[];

  void visit(String? parentId, List<String> ancestorNames) {
    for (final category in tree[parentId] ?? const <GalleryCategory>[]) {
      final label = [...ancestorNames, category.displayName].join(' / ');
      targets.add(LocalGalleryMoveTarget(category: category, label: label));
      visit(category.id, [...ancestorNames, category.displayName]);
    }
  }

  visit(null, const <String>[]);
  return targets;
}

/// 弹出分类选择对话框，返回选中的分类 ID；取消时返回 null。
Future<String?> showLocalGalleryMoveTargetDialog({
  required BuildContext context,
  required List<LocalGalleryMoveTarget> targets,
}) {
  final l10n = context.l10n;
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.localGallery_moveToCategory),
      content: SizedBox(
        width: 300,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: targets.length,
          itemBuilder: (context, index) {
            final target = targets[index];
            return ListTile(
              leading: const Icon(Icons.folder),
              title: Text(target.label),
              subtitle: Text(
                l10n.localGallery_imageCount(target.category.imageCount),
              ),
              onTap: () => Navigator.of(dialogContext).pop(target.category.id),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.common_cancel),
        ),
      ],
    ),
  );
}
