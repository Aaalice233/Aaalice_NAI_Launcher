import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/random_tag_group.dart';
import '../../../../data/models/prompt/weighted_tag.dart';
import 'random_library_manager_state.dart';
import 'variable_insertion_widget.dart';

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
              // Icon & Title (Breadcrumb style)
              Icon(
                _getIconForNode(selectedNode),
                color: theme.colorScheme.primary.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 12),
              
              // Breadcrumb: Type > Name
              Expanded(
                child: Row(
                  children: [
                    Text(
                      _getNodeTypeLabel(selectedNode).toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right, 
                      size: 16, 
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        selectedNode.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.dashboard_customize_outlined,
              size: 48,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Workspace Ready',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a component to configure',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
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
              child: Icon(Icons.folder_special, size: 32, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preset Configuration', style: theme.textTheme.headlineSmall),
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
          content: 'Select a category or tag group from the sidebar to edit its contents. Drag and drop items in the tree to reorganize.',
        ),
      ],
    );
  }

  // Integrated Tab Strip Switcher for Toolbar
  Widget _buildToolbarSourceSwitcher(BuildContext context, TagGroupNode node, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentType = node.data.sourceType;
    
    // Mini-Tab style
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabOption(context, 'Custom', TagGroupSourceType.custom, currentType, node, ref),
          _buildTabOption(context, 'Group', TagGroupSourceType.tagGroup, currentType, node, ref),
          _buildTabOption(context, 'Pool', TagGroupSourceType.pool, currentType, node, ref),
        ],
      ),
    );
  }

  Widget _buildTabOption(
    BuildContext context, 
    String label, 
    TagGroupSourceType type, 
    TagGroupSourceType current,
    TagGroupNode node,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final isSelected = type == current;
    
    return InkWell(
      onTap: () {
        if (!isSelected) {
          // Update via provider
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
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ] : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.outline,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  IconData _getIconForNode(RandomTreeNode node) {
    return switch (node) {
      PresetNode() => Icons.folder_special,
      CategoryNode() => Icons.category,
      TagGroupNode() => Icons.list,
    };
  }
  
  String _getNodeTypeLabel(RandomTreeNode node) {
    return switch (node) {
      PresetNode() => 'Preset',
      CategoryNode() => 'Category',
      TagGroupNode() => 'Tag Group',
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
  ConsumerState<_CategoryEditorPanel> createState() => _CategoryEditorPanelState();
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
        
        Text('Core Properties', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 16),
        
        // Grid Layout for Basic Info
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _nameController,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'Display Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (value) => _updateCategory((c) => c.copyWith(name: value)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _emojiController,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'Emoji',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (value) => _updateCategory((c) => c.copyWith(emoji: value)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _keyController,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: 'Key ID',
            hintText: 'unique_identifier',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            prefixIcon: Icon(Icons.key, size: 18, color: theme.colorScheme.outline),
          ),
          onChanged: (value) => _updateCategory((c) => c.copyWith(key: value)),
        ),
        
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 24),
        
        // Selection Logic
        Text('Selection Logic', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<SelectionMode>(
              value: data.groupSelectionMode,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down),
              items: const [
                DropdownMenuItem(value: SelectionMode.single, child: Text('Single (Weighted Random)')),
                DropdownMenuItem(value: SelectionMode.multipleNum, child: Text('Multiple (Fixed Count)')),
                DropdownMenuItem(value: SelectionMode.all, child: Text('Select All')),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  _updateCategory((c) => c.copyWith(groupSelectionMode: mode));
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Implement Add Tag Group
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
  ConsumerState<_TagGroupEditorPanel> createState() => _TagGroupEditorPanelState();
}

class _TagGroupEditorPanelState extends ConsumerState<_TagGroupEditorPanel> {
  late final TextEditingController _nameController;
  late final TextEditingController _sourceIdController;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _nameController = TextEditingController(text: widget.node.data.name);
    final data = widget.node.data;
    if (data.sourceType == TagGroupSourceType.tagGroup || data.sourceType == TagGroupSourceType.pool) {
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
        
        Text('Core Properties', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 16),
        
        TextField(
          controller: _nameController,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            labelText: 'Name',
            hintText: 'Display Name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (value) {
            if (isCustom) {
              _updateTagGroup((t) => t.copyWith(name: value, tags: value.split('\n').where((line) => line.trim().isNotEmpty).map((line) => WeightedTag.simple(line.trim(), 1)).toList()));
            } else {
              _updateTagGroup((t) => t.copyWith(name: value, sourceId: _sourceIdController.text));
            }
          },
        ),
        
        const SizedBox(height: 24),
        
        // Source ID / Content
        Text(
          data.sourceType == TagGroupSourceType.custom ? 'Content' : '${data.sourceType.name} ID',
          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 16),
        
        if (isCustom)
          SizedBox(
            height: 150,
            child: TextField(
              controller: _sourceIdController,
              maxLines: null,
              expands: true,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Enter tags here (one per line)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (value) => _updateTagGroup((t) => t.copyWith(tags: value.split('\n').where((line) => line.trim().isNotEmpty).map((line) => WeightedTag.simple(line.trim(), 1)).toList())),
            ),
          )
        else
          TextField(
            controller: _sourceIdController,
            style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: data.sourceType == TagGroupSourceType.tagGroup ? 'e.g., touhou' : 'e.g., 12345',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: Icon(
                data.sourceType == TagGroupSourceType.tagGroup ? Icons.link : Icons.numbers,
                size: 18, 
                color: theme.colorScheme.outline,
              ),
            ),
            onChanged: (value) => _updateTagGroup((t) => t.copyWith(sourceId: value)),
          ),
      ],
    );
  }
}
