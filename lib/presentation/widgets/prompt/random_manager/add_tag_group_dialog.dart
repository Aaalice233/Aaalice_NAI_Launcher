import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nai_launcher/presentation/themes/core/input_surface_style.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/random_tag_group.dart';
import '../../../../data/models/prompt/weighted_tag.dart';
import '../../common/emoji_picker_dialog.dart';
import '../../common/hover_preview_card.dart';
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
      width: 580,
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
                Text(
                  panelContext.l10n.randomManager_addTagGroupSubtitle(
                    panelContext.l10n.randomCategoryName(category),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(panelContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(panelContext).colorScheme.onSurfaceVariant,
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

  // Danbooru 导入相关
  String? _selectedDanbooruGroup;
  int? _selectedPoolId;
  String _searchQuery = '';

  // 预定义 Tag Groups
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

  // 预定义 Pools
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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _sourceTabIndex = _tabController.index;
          _searchQuery = '';
          _searchController.clear();
        });
      }
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final minimumTabHeight = 220 + (textScale - 1).clamp(0, 2) * 140;
          final preferredTabHeight = constraints.maxHeight - 170;
          final tabHeight = preferredTabHeight
              .clamp(minimumTabHeight, 660)
              .toDouble();
          return ListView(
            key: const ValueKey('add-tag-group-form-scroll'),
            controller: widget.scrollController,
            padding: EdgeInsets.zero,
            children: [
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
                    children: [
                      _buildSourceTabs(context),
                      if (_sourceTabIndex > 0) _buildSearchBar(context),
                      SizedBox(
                        height: tabHeight,
                        child: _buildTabContent(context),
                      ),
                    ],
                  ),
                ),
              ),
              _buildFooter(context),
            ],
          );
        },
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
            child: TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.l10n.randomManager_tagGroupName,
                hintText: context.l10n.randomManager_tagGroupNameHint,
                border: InputBorder.none,
                filled: true,
                fillColor: inputSurfaceFillColor(colorScheme),
              ),
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
            child: IconButton.filledTonal(
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
    final colorScheme = Theme.of(context).colorScheme;

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
            labelStyle: const TextStyle(
              fontSize: 12,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchController,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: _sourceTabIndex == 1
              ? context.l10n.randomManager_searchTagGroup
              : context.l10n.randomManager_searchPool,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: inputSurfaceFillColor(colorScheme),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          isDense: true,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildCustomTagsTab(context),
        _buildTagGroupTab(context),
        _buildPoolTab(context),
      ],
    );
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
          Expanded(
            child: TextFormField(
              controller: _tagsController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: 'red hair\nblue eyes:2\nlong hair',
                filled: true,
                fillColor: inputSurfaceFillColor(colorScheme),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagGroupTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filtered = _filteredTagGroups;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Danbooru Tag Group',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                context.l10n.randomManager_itemCount(filtered.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.randomManager_noMatchingTagGroup,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final (label, groupTitle) = filtered[index];
                      final isSelected = _selectedDanbooruGroup == groupTitle;
                      return _DanbooruListTile(
                        label: label,
                        subtitle: groupTitle,
                        isSelected: isSelected,
                        onTap: () => _selectDanbooruGroup(groupTitle, label),
                        onOpenExternal: () => _openDanbooruUrl(
                          'https://danbooru.donmai.us/wiki_pages/$groupTitle',
                        ),
                        itemType: DanbooruItemType.tagGroup,
                        groupTitle: groupTitle,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoolTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filtered = _filteredPools;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Danbooru Pool',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                context.l10n.randomManager_itemCount(filtered.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.randomManager_noMatchingPool,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final (label, poolId) = filtered[index];
                      final isSelected = _selectedPoolId == poolId;
                      return _DanbooruListTile(
                        label: label,
                        subtitle: 'Pool #$poolId',
                        isSelected: isSelected,
                        onTap: () => _selectPool(poolId, label),
                        onOpenExternal: () => _openDanbooruUrl(
                          'https://danbooru.donmai.us/pools/$poolId',
                        ),
                        itemType: DanbooruItemType.pool,
                        poolId: poolId,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: OverflowBar(
        alignment: MainAxisAlignment.end,
        spacing: 8,
        overflowSpacing: 8,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton.icon(
            onPressed: _canSubmit() ? _addGroup : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(context.l10n.common_add),
          ),
        ],
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

/// Danbooru 列表项类型
enum DanbooruItemType { tagGroup, pool }

/// Danbooru 列表项
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

    final tile = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colorScheme.primaryContainer
                : _isHovered
                ? colorScheme.surfaceContainerHigh
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
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
              if (_isHovered || widget.isSelected)
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: widget.onOpenExternal,
                  tooltip: context.l10n.randomManager_openInDanbooru,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return HoverPreviewCard(previewBuilder: _buildPreviewContent, child: tile);
  }
}
