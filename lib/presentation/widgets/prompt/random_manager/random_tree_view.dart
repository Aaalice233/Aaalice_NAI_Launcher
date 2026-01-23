
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'components/pro_context_menu.dart';
import 'random_library_manager_state.dart';

RandomTreeNode? _clipboardNode;

class RandomTreeView extends ConsumerWidget {
  const RandomTreeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(randomTreeDataProvider);
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.account_tree_outlined, 
                size: 16, 
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'LIBRARY STRUCTURE',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: presets.length,
            itemBuilder: (context, index) {
              return _TreeNodeWidget(
                node: presets[index],
                level: 0,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TreeNodeWidget extends ConsumerWidget {
  final RandomTreeNode node;
  final int level;

  const _TreeNodeWidget({
    required this.node,
    required this.level,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedNodes = ref.watch(expandedNodesProvider);
    final selectedNode = ref.watch(selectedNodeProvider);
    final isExpanded = expandedNodes.contains(node.id);
    final isSelected = selectedNode?.id == node.id;
    
    // Determine node type and children
    List<RandomTreeNode> children = [];
    bool isLeaf = true;
    IconData icon = Icons.circle;
    Color? iconColor;
    String tooltipMessage = '';
    
    if (node is PresetNode) {
      children = (node as PresetNode).children;
      isLeaf = false;
      icon = isExpanded ? Icons.folder_open : Icons.folder;
      iconColor = Colors.amber;
      tooltipMessage = 'Preset: ${node.label}';
    } else if (node is CategoryNode) {
      children = (node as CategoryNode).children;
      isLeaf = false;
      icon = isExpanded ? Icons.folder_open_outlined : Icons.folder_outlined;
      iconColor = Colors.blueAccent;
      tooltipMessage = 'Category: ${node.label}';
    } else if (node is TagGroupNode) {
      isLeaf = true;
      icon = Icons.tag;
      iconColor = Colors.green;
      tooltipMessage = 'Tag Group: ${node.label}';
    }

    final theme = Theme.of(context);
    
    // TagGroup is draggable
    Widget content = Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.colorScheme.secondaryContainer.withOpacity(0.5) 
              : Colors.transparent,
          border: isSelected
              ? Border(left: BorderSide(color: theme.colorScheme.primary, width: 3))
              : const Border(left: BorderSide(color: Colors.transparent, width: 3)),
        ),
        child: InkWell(
          onSecondaryTapUp: (details) => _showContextMenu(context, details.globalPosition, ref),
          onTap: () {
            ref.read(selectedNodeProvider.notifier).select(node);
            if (!isLeaf) {
              ref.read(expandedNodesProvider.notifier).toggle(node.id);
            }
          },
          hoverColor: theme.colorScheme.onSurface.withOpacity(0.05),
          highlightColor: theme.colorScheme.onSurface.withOpacity(0.1),
          child: Padding(
            padding: EdgeInsets.only(
              left: 8.0 + (level * 12.0),
              right: 8.0,
              top: 2.0,
              bottom: 2.0,
            ),
            child: SizedBox(
              height: 24.0,
              child: Row(
              children: [
                // Expansion arrow or spacer
                if (!isLeaf)
                  Tooltip(
                    message: isExpanded ? 'Collapse' : 'Expand',
                    waitDuration: const Duration(milliseconds: 500),
                      child: InkWell(
                        onTap: () {
                          ref.read(expandedNodesProvider.notifier).toggle(node.id);
                        },
                        borderRadius: BorderRadius.circular(12),
                        hoverColor: theme.colorScheme.primary.withOpacity(0.1),
                        child: AnimatedRotation(
                          turns: isExpanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: const Icon(Icons.arrow_right, size: 20),
                        ),
                      ),
                  )
                else
                  const SizedBox(width: 20),
                  
                const SizedBox(width: 4),
                
                // Node Icon
                Tooltip(
                  message: tooltipMessage,
                  waitDuration: const Duration(milliseconds: 500),
                  child: Icon(icon, size: 18, color: iconColor ?? theme.iconTheme.color),
                ),
                const SizedBox(width: 8),
                
                // Label
                Expanded(
                  child: Text(
                    node.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected 
                          ? theme.colorScheme.primary 
                          : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Drag handle for leaf nodes
                if (isLeaf)
                  Tooltip(
                    message: 'Drag to reorder or move',
                    child: Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),
                  ),
              ],
            ),
            ),
          ),
        ),
      ),
    );

    // Wrap with Draggable/DragTarget for TagGroups
    if (node is TagGroupNode) {
      content = LongPressDraggable<TagGroupNode>(
        data: node as TagGroupNode,
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.surface,
          shadowColor: Colors.black45,
          child: Container(
            width: 250,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.tag, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    node.label,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: content,
        ),
        child: content,
      );
    }
    
    // Wrap with DragTarget for CategoryNodes (to accept drops)
    if (node is CategoryNode) {
      content = DragTarget<TagGroupNode>(
        onWillAcceptWithDetails: (details) => details.data.categoryId != node.id,
        onAcceptWithDetails: (details) {
          ref.read(randomTreeDataProvider.notifier).moveTagGroup(details.data, node.id);
          // Auto expand target category
          ref.read(expandedNodesProvider.notifier).expand(node.id);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovered = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: isHovered 
                ? BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    border: Border.all(color: theme.colorScheme.primary, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ) 
                : const BoxDecoration(),
            child: content,
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        content,
        // Animated expansion
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: isExpanded && children.isNotEmpty
              ? Column(
                  children: children.map((child) => _TreeNodeWidget(
                        node: child, 
                        level: level + 1,
                      ),).toList(),
                )
              : const SizedBox(width: double.infinity), // Empty container instead of nothing for animation
        ),
      ],
    );
  }

  void _showContextMenu(BuildContext context, Offset position, WidgetRef ref) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => overlayEntry.remove(),
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          ProContextMenu(
            position: position,
            items: _buildMenuItems(context, ref, overlayEntry),
            onSelect: (item) {
              overlayEntry.remove();
            },
          ),
        ],
      ),
    );

    overlay.insert(overlayEntry);
  }

  List<ProMenuItem> _buildMenuItems(BuildContext context, WidgetRef ref, OverlayEntry overlayEntry) {
    final items = <ProMenuItem>[];
    final notifier = ref.read(randomTreeDataProvider.notifier);

    // Add Child
    if (node is PresetNode || node is CategoryNode) {
      items.add(ProMenuItem(
        id: 'add_child',
        label: node is PresetNode ? 'Add Category' : 'Add Tag Group',
        icon: Icons.add,
        onTap: () {
          if (node is PresetNode) {
            notifier.addCategory(node.id);
            ref.read(expandedNodesProvider.notifier).expand(node.id);
          } else if (node is CategoryNode) {
            notifier.addTagGroup((node as CategoryNode).presetId, node.id);
            ref.read(expandedNodesProvider.notifier).expand(node.id);
          }
        },
      ),
    );
  }

  // Rename
  items.add(
    ProMenuItem(
      id: 'rename',
      label: 'Rename',
      icon: Icons.edit,
      onTap: () {
        Future.delayed(Duration.zero, () {
          if (context.mounted) _showRenameDialog(context, ref);
        });
      },
    ),
  );

  // Copy
  items.add(
    ProMenuItem(
      id: 'copy',
      label: 'Copy',
      icon: Icons.copy,
      onTap: () {
        _clipboardNode = node;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copied ${node.label}')),
        );
      },
    ),
  );

  // Paste
  bool canPaste = false;
  if (_clipboardNode != null) {
    if (node is PresetNode && _clipboardNode is CategoryNode) canPaste = true;
    if (node is CategoryNode && _clipboardNode is TagGroupNode) {
      canPaste = true;
    }
  }

  if (canPaste) {
    items.add(
      ProMenuItem(
        id: 'paste',
        label: 'Paste',
        icon: Icons.paste,
        onTap: () {
          if (_clipboardNode != null) {
            notifier.pasteNode(node, _clipboardNode!);
            ref.read(expandedNodesProvider.notifier).expand(node.id);
          }
        },
      ),
    );
  }

  // Delete
  items.add(
    ProMenuItem(
      id: 'delete',
      label: 'Delete',
      icon: Icons.delete_outline,
      onTap: () {
        if (ref.read(selectedNodeProvider)?.id == node.id) {
          ref.read(selectedNodeProvider.notifier).select(null);
        }
        notifier.deleteNode(node);
      },
    ),
  );

    return items;
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: node.label);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller, 
          autofocus: true,
          onSubmitted: (_) {
             _performRename(ref, controller.text);
             Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              _performRename(ref, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _performRename(WidgetRef ref, String newName) {
    if (newName.isEmpty || newName == node.label) return;
    final notifier = ref.read(randomTreeDataProvider.notifier);
    
    if (node is PresetNode) {
      notifier.updatePreset(node.id, newName);
    } else if (node is CategoryNode) {
      final catNode = node as CategoryNode;
      notifier.updateCategory(catNode.presetId, catNode.id, catNode.data.copyWith(name: newName));
    } else if (node is TagGroupNode) {
      final tagNode = node as TagGroupNode;
      notifier.updateTagGroup(
        tagNode.presetId, 
        tagNode.categoryId, 
        tagNode.id, 
        tagNode.data.copyWith(name: newName),
      );
    }
  }
}
