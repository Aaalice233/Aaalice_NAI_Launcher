import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../../../../../../data/models/prompt/random_category.dart';
// import '../../../../../../data/models/prompt/random_tag_group.dart';
import '../random_library_manager_state.dart';

/// Mixin to handle keyboard navigation for the Random Library Tree
mixin KeyboardNavigationMixin on Widget {
  // Focus management
  final FocusNode focusNode = FocusNode(debugLabel: 'RandomTreeKeyboardNavigation');

  void handleKeyEvent(BuildContext context, WidgetRef ref, KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final selectedNode = ref.read(selectedNodeProvider);
    final treeData = ref.read(randomTreeDataProvider);
    final expandedNodes = ref.read(expandedNodesProvider);
    
    // Helper to check for Control or Command key
    final bool isControlPressed = HardwareKeyboard.instance.isControlPressed || 
                           HardwareKeyboard.instance.isMetaPressed;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        _moveSelection(ref, treeData, expandedNodes, selectedNode, -1);
        break;
        
      case LogicalKeyboardKey.arrowDown:
        _moveSelection(ref, treeData, expandedNodes, selectedNode, 1);
        break;
        
      case LogicalKeyboardKey.arrowRight:
        if (selectedNode != null) {
          _handleExpand(ref, selectedNode, expandedNodes);
        }
        break;
        
      case LogicalKeyboardKey.arrowLeft:
        if (selectedNode != null) {
          _handleCollapse(ref, selectedNode, expandedNodes);
        }
        break;
        
      case LogicalKeyboardKey.enter:
        // Enter to edit/confirm - triggering rename for now as "Edit"
        if (selectedNode != null) {
          _showRenameDialog(context, ref, selectedNode);
        }
        break;
        
      case LogicalKeyboardKey.space:
        // Toggle selection
        if (selectedNode != null) {
          ref.read(selectedNodeProvider.notifier).select(null);
        }
        break;
        
      case LogicalKeyboardKey.delete:
        if (selectedNode != null) {
          ref.read(randomTreeDataProvider.notifier).deleteNode(selectedNode);
          ref.read(selectedNodeProvider.notifier).select(null);
        }
        break;
        
      case LogicalKeyboardKey.f2:
        if (selectedNode != null) {
          _showRenameDialog(context, ref, selectedNode);
        }
        break;
        
      case LogicalKeyboardKey.escape:
        ref.read(selectedNodeProvider.notifier).select(null);
        break;
        
      case LogicalKeyboardKey.keyN:
        if (isControlPressed) {
          _handleNewItem(ref, selectedNode);
        }
        break;
        
      case LogicalKeyboardKey.keyD:
        if (isControlPressed && selectedNode != null) {
          ref.read(randomTreeDataProvider.notifier).duplicateNode(selectedNode);
        }
        break;
    }
  }

  // --- Navigation Logic ---

  void _moveSelection(
    WidgetRef ref, 
    List<PresetNode> treeData, 
    Set<String> expandedNodes,
    RandomTreeNode? currentSelection, 
    int direction,
  ) {
    final visibleNodes = _getAllVisibleNodes(treeData, expandedNodes);
    if (visibleNodes.isEmpty) return;

    int currentIndex = -1;
    if (currentSelection != null) {
      currentIndex = visibleNodes.indexWhere((node) => node.id == currentSelection.id);
    }

    int newIndex;
    if (currentIndex == -1) {
      // If nothing selected, select first or last depending on direction
      newIndex = direction > 0 ? 0 : visibleNodes.length - 1;
    } else {
      newIndex = (currentIndex + direction).clamp(0, visibleNodes.length - 1);
    }

    if (newIndex != currentIndex) {
      ref.read(selectedNodeProvider.notifier).select(visibleNodes[newIndex]);
    }
  }

  List<RandomTreeNode> _getAllVisibleNodes(List<PresetNode> presets, Set<String> expandedIds) {
    final List<RandomTreeNode> visible = [];
    for (final preset in presets) {
      visible.add(preset);
      if (expandedIds.contains(preset.id)) {
        for (final category in preset.children) {
          visible.add(category);
          if (expandedIds.contains(category.id)) {
            visible.addAll(category.children);
          }
        }
      }
    }
    return visible;
  }

  void _handleExpand(WidgetRef ref, RandomTreeNode node, Set<String> expandedNodes) {
    if (node is TagGroupNode) return; // Leafs can't expand
    
    if (!expandedNodes.contains(node.id)) {
      ref.read(expandedNodesProvider.notifier).expand(node.id);
    }
  }

  void _handleCollapse(WidgetRef ref, RandomTreeNode node, Set<String> expandedNodes) {
    if (expandedNodes.contains(node.id)) {
      ref.read(expandedNodesProvider.notifier).collapse(node.id);
    } else {
      // If already collapsed (or leaf), select parent
      final parent = _findParent(ref.read(randomTreeDataProvider), node);
      if (parent != null) {
        ref.read(selectedNodeProvider.notifier).select(parent);
      }
    }
  }

  RandomTreeNode? _findParent(List<PresetNode> presets, RandomTreeNode node) {
    if (node is PresetNode) return null; // Root nodes have no parent in this view

    for (final preset in presets) {
      if (preset.children.any((c) => c.id == node.id)) return preset;
      
      for (final category in preset.children) {
        if (category.children.any((c) => c.id == node.id)) return category;
      }
    }
    return null;
  }

  // --- Action Logic ---

  void _handleNewItem(WidgetRef ref, RandomTreeNode? selectedNode) {
    final notifier = ref.read(randomTreeDataProvider.notifier);
    final expandNotifier = ref.read(expandedNodesProvider.notifier);

    if (selectedNode is PresetNode) {
      notifier.addCategory(selectedNode.id);
      expandNotifier.expand(selectedNode.id);
    } else if (selectedNode is CategoryNode) {
      notifier.addTagGroup(selectedNode.presetId, selectedNode.id);
      expandNotifier.expand(selectedNode.id);
    } else if (selectedNode is TagGroupNode) {
      // If tag group selected, add sibling
      notifier.addTagGroup(selectedNode.presetId, selectedNode.categoryId);
      // Ensure parent category is expanded (it should be if child is selected, but good to ensure)
      expandNotifier.expand(selectedNode.categoryId);
    } else {
      // No selection or unknown, maybe add to first preset if available
      final presets = ref.read(randomTreeDataProvider);
      if (presets.isNotEmpty) {
        notifier.addCategory(presets.first.id);
        expandNotifier.expand(presets.first.id);
      }
    }
  }

  // --- Dialogs ---

  void _showRenameDialog(BuildContext context, WidgetRef ref, RandomTreeNode node) {
    final controller = TextEditingController(text: node.label);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller, 
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
             _performRename(ref, node, controller.text);
             Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _performRename(ref, node, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _performRename(WidgetRef ref, RandomTreeNode node, String newName) {
    if (newName.isEmpty || newName == node.label) return;
    final notifier = ref.read(randomTreeDataProvider.notifier);
    
    if (node is PresetNode) {
      notifier.updatePreset(node.id, newName);
    } else if (node is CategoryNode) {
      notifier.updateCategory(
        node.presetId, 
        node.id, 
        node.data.copyWith(name: newName),
      );
    } else if (node is TagGroupNode) {
      notifier.updateTagGroup(
        node.presetId, 
        node.categoryId, 
        node.id, 
        node.data.copyWith(name: newName),
      );
    }
  }
}
