import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/random_tag_group.dart';
import '../../../../data/models/prompt/weighted_tag.dart';
import 'components/pro_empty_state.dart';
import 'inspector_section.dart';
import 'property_field.dart';
import 'random_library_manager_state.dart';
import 'variable_insertion_widget.dart';
import 'package:nai_launcher/presentation/widgets/autocomplete/autocomplete_controller.dart';
import 'package:nai_launcher/presentation/widgets/autocomplete/autocomplete_wrapper.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

class RandomDetailView extends ConsumerWidget {
  const RandomDetailView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedNode = ref.watch(selectedNodeProvider);
    final theme = Theme.of(context);

    if (selectedNode == null) {
      return _buildNoSelectionView(context, theme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Refactored Toolbar
        Container(
          height: 56, // Fixed height for toolbar feel
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
            ),
          ),
          child: Row(
            children: [
              // Icon & Title
              Icon(
                _getIconForNode(selectedNode),
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),

              // Name
              Expanded(
                child: Text(
                  selectedNode.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Source Switcher (for TagGroups) integrated into toolbar
              if (selectedNode is TagGroupNode)
                _buildToolbarSourceSwitcher(context, selectedNode, ref),
            ],
          ),
        ),

        // Editor Content
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.02, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: SingleChildScrollView(
              key: ValueKey(selectedNode.id),
              padding: const EdgeInsets.all(24),
              child: switch (selectedNode) {
                final PresetNode preset => _buildPresetView(context, preset),
                final CategoryNode category => _CategoryEditorPanel(
                    node: category,
                  ),
                final TagGroupNode tagGroup => _TagGroupEditorPanel(
                    node: tagGroup,
                  ),
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoSelectionView(BuildContext context, ThemeData theme) {
    return const ProEmptyState(
      icon: Icons.dashboard_customize_outlined,
      title: 'Workspace Ready',
      description:
          'Select a component from the sidebar to configure its properties.',
    );
  }

  Widget _buildPresetView(BuildContext context, PresetNode node) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.folder_special,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preset Configuration',
                  style: theme.textTheme.headlineSmall,
                ),
                Text(
                  'ID: ${node.id}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        const _InfoCard(
          icon: Icons.lightbulb_outline,
          title: 'Getting Started',
          content:
              'Select a category or tag group from the sidebar to edit its contents. Drag and drop items in the tree to reorganize.',
        ),
      ],
    );
  }

  // Integrated Segmented Control Switcher for Toolbar
  Widget _buildToolbarSourceSwitcher(
    BuildContext context,
    TagGroupNode node,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final currentType = node.data.sourceType;

    return SegmentedButton<TagGroupSourceType>(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStateProperty.all(theme.textTheme.labelSmall),
      ),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: TagGroupSourceType.custom,
          label: Text('Custom'),
          icon: Icon(Icons.edit_note, size: 14),
        ),
        ButtonSegment(
          value: TagGroupSourceType.tagGroup,
          label: Text('Group'),
          icon: Icon(Icons.link, size: 14),
        ),
        ButtonSegment(
          value: TagGroupSourceType.pool,
          label: Text('Pool'),
          icon: Icon(Icons.numbers, size: 14),
        ),
      ],
      selected: {currentType},
      onSelectionChanged: (Set<TagGroupSourceType> newSelection) {
        final type = newSelection.first;
        if (type != currentType) {
          final newData = node.data.copyWith(sourceType: type);
          ref.read(randomTreeDataProvider.notifier).updateTagGroup(
                node.presetId,
                node.categoryId,
                node.id,
                newData,
              );
          // Update selection
          final newNode = TagGroupNode(
            node.presetId,
            node.categoryId,
            newData,
          );
          ref.read(selectedNodeProvider.notifier).select(newNode);
        }
      },
    );
  }

  IconData _getIconForNode(RandomTreeNode node) {
    return switch (node) {
      PresetNode() => Icons.folder_special,
      CategoryNode() => Icons.category,
      TagGroupNode() => Icons.list,
    };
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryEditorPanel extends ConsumerStatefulWidget {
  final CategoryNode node;

  const _CategoryEditorPanel({required this.node});

  @override
  ConsumerState<_CategoryEditorPanel> createState() =>
      _CategoryEditorPanelState();
}

class _CategoryEditorPanelState extends ConsumerState<_CategoryEditorPanel> {
  late final TextEditingController _nameController;
  late final TextEditingController _keyController;
  late final TextEditingController _emojiController;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _nameController = TextEditingController(text: widget.node.data.name);
    _keyController = TextEditingController(text: widget.node.data.key);
    _emojiController = TextEditingController(text: widget.node.data.emoji);
  }

  @override
  void didUpdateWidget(_CategoryEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.data.id != widget.node.data.id) {
      _initControllers();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  void _updateCategory(RandomCategory Function(RandomCategory) update) {
    final newData = update(widget.node.data);

    // 1. Update the tree data
    ref.read(randomTreeDataProvider.notifier).updateCategory(
          widget.node.presetId,
          widget.node.id,
          newData,
        );

    // 2. Update the selection to reflect changes (e.g. name change in header)
    final newNode = CategoryNode(
      widget.node.presetId,
      newData,
      children: widget.node.children,
    );
    ref.read(selectedNodeProvider.notifier).select(newNode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.node.data;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Variable Insertion Strip - positioned near the top inputs
        VariableInsertionWidget(controller: _nameController),

        InspectorSection(
          title: 'Core Properties',
          children: [
            // Grid Layout for Basic Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: PropertyField(
                    label: 'Name',
                    child: ThemedInput(
                      controller: _nameController,
                      style: theme.textTheme.bodyLarge,
                      decoration: const InputDecoration(
                        hintText: 'Display Name',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) =>
                          _updateCategory((c) => c.copyWith(name: value)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: PropertyField(
                    label: 'Emoji',
                    child: ThemedInput(
                      controller: _emojiController,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: 'Icon',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) =>
                          _updateCategory((c) => c.copyWith(emoji: value)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PropertyField(
              label: 'Key ID',
              child: ThemedInput(
                controller: _keyController,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'unique_identifier',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  prefixIcon: Icon(
                    Icons.key,
                    size: 14,
                    color: theme.colorScheme.outline,
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 24, minHeight: 16),
                ),
                onChanged: (value) =>
                    _updateCategory((c) => c.copyWith(key: value)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Selection Logic
        InspectorSection(
          title: 'Selection Logic',
          children: [
            PropertyField(
              label: 'Mode',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<SelectionMode>(
                  value: data.groupSelectionMode,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(
                      value: SelectionMode.single,
                      child: Text('Single (Weighted Random)'),
                    ),
                    DropdownMenuItem(
                      value: SelectionMode.multipleNum,
                      child: Text('Multiple (Fixed Count)'),
                    ),
                    DropdownMenuItem(
                      value: SelectionMode.all,
                      child: Text('Select All'),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) {
                      _updateCategory(
                        (c) => c.copyWith(groupSelectionMode: mode),
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final newTagGroup = ref
                      .read(randomTreeDataProvider.notifier)
                      .addTagGroup(widget.node.presetId, widget.node.id);
                  // 自动选中新创建的标签组
                  ref.read(selectedNodeProvider.notifier).select(
                        TagGroupNode(
                          widget.node.presetId,
                          widget.node.id,
                          newTagGroup,
                        ),
                      );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Tag Group'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TagGroupEditorPanel extends ConsumerStatefulWidget {
  final TagGroupNode node;

  const _TagGroupEditorPanel({required this.node});

  @override
  ConsumerState<_TagGroupEditorPanel> createState() =>
      _TagGroupEditorPanelState();
}

class _TagGroupEditorPanelState extends ConsumerState<_TagGroupEditorPanel> {
  late final TextEditingController _nameController;
  late final TextEditingController _sourceIdController;
  final FocusNode _sourceIdFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _nameController = TextEditingController(text: widget.node.data.name);
    final data = widget.node.data;
    if (data.sourceType == TagGroupSourceType.tagGroup ||
        data.sourceType == TagGroupSourceType.pool) {
      _sourceIdController = TextEditingController(text: data.sourceId ?? '');
    } else {
      _sourceIdController = TextEditingController(text: '');
    }
  }

  @override
  void didUpdateWidget(_TagGroupEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.data.id != widget.node.data.id) {
      _initControllers();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sourceIdController.dispose();
    _sourceIdFocusNode.dispose();
    super.dispose();
  }

  void _updateTagGroup(RandomTagGroup Function(RandomTagGroup) update) {
    final newData = update(widget.node.data);
    ref.read(randomTreeDataProvider.notifier).updateTagGroup(
          widget.node.presetId,
          widget.node.categoryId,
          widget.node.id,
          newData,
        );

    // Update selection
    final newNode = TagGroupNode(
      widget.node.presetId,
      widget.node.categoryId,
      newData,
    );
    ref.read(selectedNodeProvider.notifier).select(newNode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.node.data;
    final isCustom = data.sourceType == TagGroupSourceType.custom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VariableInsertionWidget(controller: _nameController),

        InspectorSection(
          title: 'Core Properties',
          children: [
            PropertyField(
              label: 'Name',
              child: ThemedInput(
                controller: _nameController,
                style: theme.textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'Display Name',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) {
                  if (isCustom) {
                    _updateTagGroup(
                      (t) => t.copyWith(
                        name: value,
                        tags: value
                            .split('\n')
                            .where((line) => line.trim().isNotEmpty)
                            .map((line) => WeightedTag.simple(line.trim(), 1))
                            .toList(),
                      ),
                    );
                  } else {
                    _updateTagGroup(
                      (t) => t.copyWith(
                        name: value,
                        sourceId: _sourceIdController.text,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Source ID / Content
        InspectorSection(
          title: data.sourceType == TagGroupSourceType.custom
              ? 'Content'
              : '${data.sourceType.name} ID',
          children: [
            if (isCustom)
              SizedBox(
                height: 150,
                child: AutocompleteWrapper(
                  controller: _sourceIdController,
                  focusNode: _sourceIdFocusNode,
                  config: const AutocompleteConfig(
                    maxSuggestions: 10,
                    showTranslation: true,
                    showCategory: true,
                    autoInsertComma: false,
                  ),
                  maxLines: null,
                  expands: true,
                  child: ThemedInput(
                    controller: _sourceIdController,
                    maxLines: null,
                    expands: true,
                    style: theme.textTheme.bodyMedium,
                    decoration: const InputDecoration(
                      hintText: 'Enter tags here (one per line)',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) => _updateTagGroup(
                      (t) => t.copyWith(
                        tags: value
                            .split('\n')
                            .where((line) => line.trim().isNotEmpty)
                            .map((line) => WeightedTag.simple(line.trim(), 1))
                            .toList(),
                      ),
                    ),
                  ),
                ),
              )
            else
              PropertyField(
                label: 'ID',
                child: ThemedInput(
                  controller: _sourceIdController,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: data.sourceType == TagGroupSourceType.tagGroup
                        ? 'e.g., touhou'
                        : 'e.g., 12345',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    prefixIcon: Icon(
                      data.sourceType == TagGroupSourceType.tagGroup
                          ? Icons.link
                          : Icons.numbers,
                      size: 14,
                      color: theme.colorScheme.outline,
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 24, minHeight: 16),
                  ),
                  onChanged: (value) =>
                      _updateTagGroup((t) => t.copyWith(sourceId: value)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
