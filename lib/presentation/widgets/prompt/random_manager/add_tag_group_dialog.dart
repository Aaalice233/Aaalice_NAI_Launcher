import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/adaptive_form_footer.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../adaptive/content_sized_adaptive_form.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/random_tag_group.dart';
import '../../../../data/models/prompt/weighted_tag.dart';
import '../../common/emoji_picker_dialog.dart';
import '../../common/hover_preview_card.dart';
import '../../common/surface_ink_well.dart';
import '../../common/tab_swipe_detector.dart';
import '../../common/themed_form_input.dart';
import '../../common/themed_input.dart';
import 'danbooru_preview_content.dart';
import 'random_config_l10n.dart';

/// 添加词组对话框
class AddTagGroupDialog extends ConsumerStatefulWidget {
  const AddTagGroupDialog({
    super.key,
    required this.category,
    required this.presetId,
    this.scrollController,
  });

  final RandomCategory category;
  final String presetId;
  final ScrollController? scrollController;

  static Future<void> show(
    BuildContext context, {
    required RandomCategory category,
    required String presetId,
  }) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      dialogWidth: 580,
      headerScrollsWithContent: true,
      titleBuilder: (panelContext) => Row(
        children: [
          Icon(
            Icons.add_rounded,
            color: Theme.of(panelContext).colorScheme.primary,
            size: 21,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  panelContext.l10n.randomManager_addTagGroup,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(panelContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      builder: (panelContext, scrollController) => AddTagGroupDialog(
        category: category,
        presetId: presetId,
        scrollController: scrollController,
      ),
    );
  }

  @override
  ConsumerState<AddTagGroupDialog> createState() => _AddTagGroupDialogState();
}

class _AddTagGroupDialogState extends ConsumerState<AddTagGroupDialog>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _tagsController = TextEditingController();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  String _selectedEmoji = '';
  int _sourceTabIndex = 0; // 0 = 自定义, 1 = Tag Group, 2 = Pool

  String? _selectedDanbooruGroup;
  int? _selectedPoolId;
  String _searchQuery = '';

  static const _tagGroups = [
    ('Hair Color', 'tag_group:hair_color'),
    ('Eye Color', 'tag_group:eye_color'),
    ('Hairstyles', 'tag_group:hairstyles'),
    ('Hair Length', 'tag_group:hair_lengths'),
    ('Attire', 'tag_group:attire'),
    ('Expressions', 'tag_group:facial_expressions'),
    ('Posture', 'tag_group:posture'),
    ('Gestures', 'tag_group:gestures'),
    ('Accessories', 'tag_group:accessories'),
    ('Backgrounds', 'tag_group:backgrounds'),
    ('Skin Color', 'tag_group:skin_color'),
    ('Body Types', 'tag_group:body_types'),
  ];

  static const _popularPools = [
    ('Genshin Characters', 21512),
    ('Blue Archive', 22345),
    ('Arknights', 17654),
    ('Fate Grand Order', 15432),
    ('Honkai Star Rail', 24567),
    ('Azur Lane', 18765),
  ];

  List<(String, String)> get _filteredTagGroups {
    if (_searchQuery.isEmpty) return _tagGroups;
    final query = _searchQuery.toLowerCase();
    return _tagGroups.where((g) {
      return g.$1.toLowerCase().contains(query) ||
          g.$2.toLowerCase().contains(query);
    }).toList();
  }

  List<(String, int)> get _filteredPools {
    if (_searchQuery.isEmpty) return _popularPools;
    final query = _searchQuery.toLowerCase();
    return _popularPools.where((p) {
      return p.$1.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_handleSourceTabChanged);
  }

  void _handleSourceTabChanged() {
    if (_tabController.index == _sourceTabIndex) return;
    setState(() {
      _sourceTabIndex = _tabController.index;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagsController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: ContentSizedAdaptiveForm(
        scrollController: widget.scrollController,
        scrollViewKey: const ValueKey('add-tag-group-form-scroll'),
        padding: EdgeInsets.zero,
        // 词组与图集列表都很短，直接排在表单里，整个表单只有这一个纵向滚动容器
        content: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              context.l10n.randomManager_addTagGroupSubtitle(
                context.l10n.randomCategoryName(widget.category),
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _buildNameSection(context),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: sectionSurfaceColor(colorScheme),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSourceTabs(context),
                  if (_sourceTabIndex > 0) _buildSearchBar(context),
                  TabSwipeDetector(
                    controller: _tabController,
                    child: KeyedSubtree(
                      key: ValueKey('add-tag-group-source-$_sourceTabIndex'),
                      child: _buildTabContent(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        footer: _buildFooter(context),
      ),
    );
  }

  Widget _buildNameSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sectionSurfaceColor(colorScheme),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: ThemedFormInput(
              controller: _nameController,
              labelText: context.l10n.randomManager_tagGroupName,
              hintText: context.l10n.randomManager_tagGroupNameHint,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.l10n.randomManager_tagGroupNameRequired;
                }
                return null;
              },
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: context.l10n.category_selectEmoji,
            child: IconButton(
              onPressed: _pickEmoji,
              icon: _selectedEmoji.isEmpty
                  ? const Icon(Icons.mood_outlined, size: 20)
                  : Text(_selectedEmoji, style: const TextStyle(fontSize: 19)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTabs(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactTabs =
              constraints.maxWidth < 460 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          return TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: compactTabs
                ? TabAlignment.start
                : TabAlignment.center,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            labelStyle: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_note, size: 16),
                    const SizedBox(width: 4),
                    Text(context.l10n.randomManager_customTab),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.label_outline, size: 16),
                    const SizedBox(width: 4),
                    Text(context.l10n.addGroup_tagGroupTab),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text(context.l10n.addGroup_poolTab),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ThemedInput(
        controller: _searchController,
        hintText: _sourceTabIndex == 1
            ? context.l10n.randomManager_searchTagGroup
            : context.l10n.randomManager_searchPool,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search, size: 20),
        ),
        showClearButton: true,
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context) {
    return switch (_sourceTabIndex) {
      1 => _buildTagGroupTab(context),
      2 => _buildPoolTab(context),
      _ => _buildCustomTagsTab(context),
    };
  }

  Widget _buildCustomTagsTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.randomManager_tagList,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.randomManager_tagListHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ThemedInput(
            controller: _tagsController,
            minLines: 6,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textAlignVertical: TextAlignVertical.top,
            hintText: 'red hair\nblue eyes:2\nlong hair',
            contentPadding: const EdgeInsets.all(12),
          ),
        ],
      ),
    );
  }

  Widget _buildTagGroupTab(BuildContext context) {
    final filtered = _filteredTagGroups;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SourceListHeader(
            title: 'Danbooru Tag Group',
            count: context.l10n.randomManager_itemCount(filtered.length),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            _EmptySourceList(
              message: context.l10n.randomManager_noMatchingTagGroup,
            )
          else
            for (final (label, groupTitle) in filtered)
              _DanbooruListTile(
                label: label,
                subtitle: groupTitle,
                isSelected: _selectedDanbooruGroup == groupTitle,
                onTap: () => _selectDanbooruGroup(groupTitle, label),
                onOpenExternal: () => _openDanbooruUrl(
                  'https://danbooru.donmai.us/wiki_pages/$groupTitle',
                ),
                itemType: DanbooruItemType.tagGroup,
                groupTitle: groupTitle,
              ),
        ],
      ),
    );
  }

  Widget _buildPoolTab(BuildContext context) {
    final filtered = _filteredPools;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SourceListHeader(
            title: 'Danbooru Pool',
            count: context.l10n.randomManager_itemCount(filtered.length),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            _EmptySourceList(message: context.l10n.randomManager_noMatchingPool)
          else
            for (final (label, poolId) in filtered)
              _DanbooruListTile(
                label: label,
                subtitle: 'Pool #$poolId',
                isSelected: _selectedPoolId == poolId,
                onTap: () => _selectPool(poolId, label),
                onOpenExternal: () => _openDanbooruUrl(
                  'https://danbooru.donmai.us/pools/$poolId',
                ),
                itemType: DanbooruItemType.pool,
                poolId: poolId,
              ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return AdaptiveFormFooter(
      primary: FilledButton.icon(
        onPressed: _canSubmit() ? _addGroup : null,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(context.l10n.common_add),
      ),
    );
  }

  Future<void> _pickEmoji() async {
    final emoji = await EmojiPickerDialog.show(context);
    if (emoji != null) setState(() => _selectedEmoji = emoji);
  }

  void _selectDanbooruGroup(String groupTitle, String label) {
    setState(() {
      _selectedDanbooruGroup = groupTitle;
      _selectedPoolId = null;
      if (_nameController.text.isEmpty) {
        _nameController.text = label;
      }
    });
  }

  void _selectPool(int poolId, String label) {
    setState(() {
      _selectedPoolId = poolId;
      _selectedDanbooruGroup = null;
      if (_nameController.text.isEmpty) {
        _nameController.text = label;
      }
    });
  }

  Future<void> _openDanbooruUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _canSubmit() {
    final hasName = _nameController.text.trim().isNotEmpty;
    switch (_sourceTabIndex) {
      case 0:
        return hasName;
      case 1:
        return hasName && _selectedDanbooruGroup != null;
      case 2:
        return hasName && _selectedPoolId != null;
      default:
        return false;
    }
  }

  void _addGroup() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final emoji = _selectedEmoji;
    RandomTagGroup newGroup;

    switch (_sourceTabIndex) {
      case 0:
        final tags = _parseTagsInput(_tagsController.text);
        newGroup = RandomTagGroup.custom(name: name, emoji: emoji, tags: tags);
        break;
      case 1:
        newGroup = RandomTagGroup.fromTagGroup(
          name: name,
          tagGroupName: _selectedDanbooruGroup!,
          tags: [],
          emoji: emoji,
        );
        break;
      case 2:
        newGroup = RandomTagGroup.fromPool(
          name: name,
          poolId: _selectedPoolId!.toString(),
          postCount: 0,
          emoji: emoji,
        );
        break;
      default:
        return;
    }

    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    final state = ref.read(randomPresetNotifierProvider);
    final preset = state.presets.firstWhere((p) => p.id == widget.presetId);
    final category = preset.categories.firstWhere(
      (c) => c.id == widget.category.id,
    );
    final updatedCategory = category.addGroup(newGroup);
    notifier.updateCategory(updatedCategory);

    Navigator.pop(context);
  }

  List<WeightedTag> _parseTagsInput(String input) {
    final lines = input.split('\n');
    final tags = <WeightedTag>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(':');
      if (parts.length >= 2) {
        final tag = parts.sublist(0, parts.length - 1).join(':');
        final weight = int.tryParse(parts.last) ?? 1;
        tags.add(WeightedTag(tag: tag, weight: weight));
      } else {
        tags.add(WeightedTag(tag: trimmed, weight: 1));
      }
    }
    return tags;
  }
}

class _SourceListHeader extends StatelessWidget {
  const _SourceListHeader({required this.title, required this.count});

  final String title;
  final String count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 标题与计数排不下同一行时计数换到下一行
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          count,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EmptySourceList extends StatelessWidget {
  const _EmptySourceList({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// Danbooru 列表项类型
enum DanbooruItemType { tagGroup, pool }

class _DanbooruListTile extends StatefulWidget {
  const _DanbooruListTile({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.onOpenExternal,
    required this.itemType,
    this.groupTitle,
    this.poolId,
  });
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onOpenExternal;
  final DanbooruItemType itemType;
  final String? groupTitle;
  final int? poolId;
  @override
  State<_DanbooruListTile> createState() => _DanbooruListTileState();
}

class _DanbooruListTileState extends State<_DanbooruListTile> {
  bool _isHovered = false;
  bool _hasFocus = false;

  Widget _buildPreviewContent(BuildContext context) {
    if (widget.itemType == DanbooruItemType.tagGroup &&
        widget.groupTitle != null) {
      return TagGroupPreviewContent(groupTitle: widget.groupTitle!);
    } else if (widget.itemType == DanbooruItemType.pool &&
        widget.poolId != null) {
      return PoolPreviewContent(poolId: widget.poolId!);
    }
    return PreviewCardError(
      message: context.l10n.randomManager_cannotLoadPreview,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    // 触屏没有悬停，外部打开入口常驻；指针下在悬停、焦点位于本行或已选中时显示
    final showOpenExternal =
        context.interactionPolicy.shouldExposeTouchAlternatives ||
        _isHovered ||
        _hasFocus ||
        widget.isSelected;

    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onFocusChange: (hasFocus) => setState(() => _hasFocus = hasFocus),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Semantics(
            container: true,
            button: true,
            selected: widget.isSelected,
            child: SurfaceInkWell(
              borderRadius: BorderRadius.circular(8),
              color: widget.isSelected
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              duration: const Duration(milliseconds: 150),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: widget.isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: widget.isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          Text(
                            widget.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 隐藏时仍占位，悬停显示不会改变标题可用宽度与行高
                    Visibility(
                      visible: showOpenExternal,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: IconButton(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        onPressed: widget.onOpenExternal,
                        tooltip: context.l10n.randomManager_openInDanbooru,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return HoverPreviewCard(previewBuilder: _buildPreviewContent, child: tile);
  }
}
