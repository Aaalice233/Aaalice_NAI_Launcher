import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../widgets/common/owned_scroll_controller.dart';

/// 固定词浏览位置的展示面。
enum FixedTagsSurface { dialog, sidebar }

/// 固定词对话框与侧栏在本次运行内的浏览视口，关闭再打开时回到原处。
///
/// 只记未筛选的完整列表；不落盘、不参与云同步。
class FixedTagsViewportMemory {
  final _browseViewports =
      <(FixedTagsSurface, FixedTagPromptType), OwnedViewportOffset>{};
  final _collapsedSidebarSections = <FixedTagPromptType, Set<String>>{};

  FixedTagPromptType dialogMobilePromptType = FixedTagPromptType.positive;

  OwnedViewportOffset browseViewport(
    FixedTagsSurface surface,
    FixedTagPromptType promptType,
  ) {
    final slot = (surface, promptType);
    return _browseViewports.putIfAbsent(slot, OwnedViewportOffset.new);
  }

  Set<String> collapsedSidebarSections(FixedTagPromptType promptType) =>
      _collapsedSidebarSections[promptType] ?? const {};

  void rememberCollapsedSidebarSections(
    FixedTagPromptType promptType,
    Set<String> sectionIds,
  ) {
    _collapsedSidebarSections[promptType] = Set.unmodifiable(sectionIds);
  }
}

final fixedTagsViewportMemoryProvider = Provider<FixedTagsViewportMemory>(
  (ref) => FixedTagsViewportMemory(),
);
