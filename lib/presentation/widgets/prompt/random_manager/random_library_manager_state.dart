
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/random_tag_group.dart';

/// Base class for nodes in the random library tree
sealed class RandomTreeNode {
  final String id;
  final String label;
  const RandomTreeNode(this.id, this.label);
}

class PresetNode extends RandomTreeNode {
  final List<CategoryNode> children;
  const PresetNode(super.id, super.label, {this.children = const []});
}

class CategoryNode extends RandomTreeNode {
  final String presetId;
  final RandomCategory data;
  final List<TagGroupNode> children;
  
  CategoryNode(this.presetId, this.data, {this.children = const []}) 
      : super(data.id, data.name);
}

class TagGroupNode extends RandomTreeNode {
  final String presetId;
  final String categoryId;
  final RandomTagGroup data;
  
  TagGroupNode(this.presetId, this.categoryId, this.data) 
      : super(data.id, data.name);
}

/// State for the currently selected node
class SelectedNodeNotifier extends StateNotifier<RandomTreeNode?> {
  SelectedNodeNotifier() : super(null);

  void select(RandomTreeNode? node) {
    state = node;
  }
}

final selectedNodeProvider = StateNotifierProvider<SelectedNodeNotifier, RandomTreeNode?>((ref) {
  return SelectedNodeNotifier();
});

/// State for expanded nodes in the tree
class ExpandedNodesNotifier extends StateNotifier<Set<String>> {
  ExpandedNodesNotifier() : super({});

  void toggle(String nodeId) {
    if (state.contains(nodeId)) {
      state = {...state}..remove(nodeId);
    } else {
      state = {...state, nodeId};
    }
  }

  void expand(String nodeId) {
    if (!state.contains(nodeId)) {
      state = {...state, nodeId};
    }
  }

  void collapse(String nodeId) {
    if (state.contains(nodeId)) {
      state = {...state}..remove(nodeId);
    }
  }
}

final expandedNodesProvider = StateNotifierProvider<ExpandedNodesNotifier, Set<String>>((ref) {
  return ExpandedNodesNotifier();
});

/// Data provider for the random tree
class RandomTreeDataNotifier extends StateNotifier<List<PresetNode>> {
  RandomTreeDataNotifier() : super([]) {
    _initSampleData();
  }

  void _initSampleData() {
    // Helper to create sample data
    final tagGroup1 = RandomTagGroup.custom(name: 'Main Character');
    final tagGroup2 = RandomTagGroup.custom(name: 'Side Characters');
    final category1 = RandomCategory.create(name: 'Characters', key: 'chars', groups: [tagGroup1, tagGroup2],);
    
    final tagGroup3 = RandomTagGroup.custom(name: 'Location');
    final tagGroup4 = RandomTagGroup.custom(name: 'Weather');
    final tagGroup5 = RandomTagGroup.custom(name: 'Time of Day');
    final category2 = RandomCategory.create(name: 'Environment', key: 'env', groups: [tagGroup3, tagGroup4, tagGroup5],);

    final tagGroup6 = RandomTagGroup.custom(name: 'Elves');
    final tagGroup7 = RandomTagGroup.custom(name: 'Dwarves');
    final category3 = RandomCategory.create(name: 'Race', key: 'race', groups: [tagGroup6, tagGroup7],);

    final tagGroup8 = RandomTagGroup.custom(name: 'Weapons');
    final tagGroup9 = RandomTagGroup.custom(name: 'Armor');
    final category4 = RandomCategory.create(name: 'Equipment', key: 'equip', groups: [tagGroup8, tagGroup9],);

    state = [
      PresetNode('preset1', 'Official Preset (V4)', children: [
        CategoryNode('preset1', category1, children: [
          TagGroupNode('preset1', category1.id, tagGroup1),
          TagGroupNode('preset1', category1.id, tagGroup2),
        ],
        ),
        CategoryNode('preset1', category2, children: [
          TagGroupNode('preset1', category2.id, tagGroup3),
          TagGroupNode('preset1', category2.id, tagGroup4),
          TagGroupNode('preset1', category2.id, tagGroup5),
        ],
        ),
      ],
      ),
      PresetNode('preset2', 'Fantasy Custom', children: [
        CategoryNode('preset2', category3, children: [
          TagGroupNode('preset2', category3.id, tagGroup6),
          TagGroupNode('preset2', category3.id, tagGroup7),
        ],
        ),
        CategoryNode('preset2', category4, children: [
          TagGroupNode('preset2', category4.id, tagGroup8),
          TagGroupNode('preset2', category4.id, tagGroup9),
        ],
        ),
      ],
      ),
    ];
  }

  void updateCategory(String presetId, String categoryId, RandomCategory newCategory,) {
    state = [
      for (final preset in state)
        if (preset.id == presetId)
          PresetNode(
            preset.id,
            preset.label,
            children: [
              for (final category in preset.children)
                if (category.id == categoryId)
                  CategoryNode(
                    presetId,
                    newCategory,
                    children: category.children,
                  )
                else
                  category,
            ],
          )
        else
          preset,
    ];
  }

  RandomCategory addCategory(String presetId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final newCategory = RandomCategory(
      id: timestamp,
      name: "新建类别",
      key: "new_category_$timestamp",
      groupSelectionMode: SelectionMode.single,
      groups: const [],
    );

    state = [
      for (final preset in state)
        if (preset.id == presetId)
          PresetNode(
            preset.id,
            preset.label,
            children: [
              ...preset.children,
              CategoryNode(presetId, newCategory, children: const []),
            ],
          )
        else
          preset,
    ];

    return newCategory;
  }

  RandomTagGroup addTagGroup(String presetId, String categoryId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final newTagGroup = RandomTagGroup(
      id: timestamp,
      name: "新建标签组",
      sourceType: TagGroupSourceType.custom,
      tags: const [],
    );

    state = [
      for (final preset in state)
        if (preset.id == presetId)
          PresetNode(
            preset.id,
            preset.label,
            children: [
              for (final category in preset.children)
                if (category.id == categoryId)
                  CategoryNode(
                    presetId,
                    category.data,
                    children: [
                      ...category.children,
                      TagGroupNode(presetId, categoryId, newTagGroup),
                    ],
                  )
                else
                  category,
            ],
          )
        else
          preset,
    ];

    return newTagGroup;
  }

  void updateTagGroup(
    String presetId,
    String categoryId,
    String tagGroupId,
    RandomTagGroup newTagGroup,
  ) {
    state = [
      for (final preset in state)
        if (preset.id == presetId)
          PresetNode(
            preset.id,
            preset.label,
            children: [
              for (final category in preset.children)
                if (category.id == categoryId)
                  CategoryNode(
                    presetId,
                    category.data,
                    children: [
                      for (final tagGroup in category.children)
                        if (tagGroup.id == tagGroupId)
                          TagGroupNode(presetId, categoryId, newTagGroup)
                        else
                          tagGroup,
                    ],
                  )
                else
                  category,
            ],
          )
        else
          preset,
    ];
  }

  void moveTagGroup(TagGroupNode node, String targetCategoryId) {
    // Reconstruct the tree with the node moved
    final List<PresetNode> newPresets = [];
    
    for (final preset in state) {
      if (preset.id == node.presetId) {
        final List<CategoryNode> newCategories = [];
        
        for (final category in preset.children) {
           final List<TagGroupNode> newTagGroups = [...category.children];
           
           // Remove from old category
           if (category.id == node.categoryId) {
             newTagGroups.removeWhere((t) => t.id == node.id);
           }
           
           // Add to new category
           if (category.id == targetCategoryId) {
             if (!newTagGroups.any((t) => t.id == node.id)) {
                // Update the categoryId in the node
                newTagGroups.add(TagGroupNode(node.presetId, targetCategoryId, node.data),);
             }
           }
           
           newCategories.add(CategoryNode(category.presetId, category.data, children: newTagGroups,),);
        }
        
        newPresets.add(PresetNode(preset.id, preset.label, children: newCategories));
      } else {
        newPresets.add(preset);
      }
    }
    
    state = newPresets;
  }

  void deleteNode(RandomTreeNode node) {
    if (node is PresetNode) {
      state = state.where((p) => p.id != node.id).toList();
    } else if (node is CategoryNode) {
      state = [
        for (final preset in state)
          if (preset.id == node.presetId)
            PresetNode(
              preset.id,
              preset.label,
              children: preset.children.where((c) => c.id != node.id).toList(),
            )
          else
            preset,
      ];
    } else if (node is TagGroupNode) {
      state = [
        for (final preset in state)
          if (preset.id == node.presetId)
            PresetNode(
              preset.id,
              preset.label,
              children: [
                for (final category in preset.children)
                  if (category.id == node.categoryId)
                    CategoryNode(
                      node.presetId,
                      category.data,
                      children: category.children.where((t) => t.id != node.id).toList(),
                    )
                  else
                    category,
              ],
            )
          else
            preset,
      ];
    }
  }

  RandomTreeNode duplicateNode(RandomTreeNode node) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    if (node is PresetNode) {
      final newNode = PresetNode(
        timestamp,
        '${node.label} (副本)',
        children: node.children,
      );
      final index = state.indexWhere((p) => p.id == node.id);
      if (index != -1) {
        state = [
          ...state.sublist(0, index + 1),
          newNode,
          ...state.sublist(index + 1),
        ];
      }
      return newNode;
    }

    if (node is CategoryNode) {
      final newData = node.data.copyWith(
        id: timestamp,
        name: '${node.data.name} (副本)',
      );
      final newNode = CategoryNode(
        node.presetId,
        newData,
        children: node.children,
      );
      state = [
        for (final preset in state)
          if (preset.id == node.presetId)
            PresetNode(
              preset.id,
              preset.label,
              children: [
                for (final category in preset.children) ...[
                  category,
                  if (category.id == node.id) newNode,
                ],
              ],
            )
          else
            preset,
      ];
      return newNode;
    }

    if (node is TagGroupNode) {
      final newData = node.data.copyWith(
        id: timestamp,
        name: '${node.data.name} (副本)',
      );
      final newNode = TagGroupNode(
        node.presetId,
        node.categoryId,
        newData,
      );
      state = [
        for (final preset in state)
          if (preset.id == node.presetId)
            PresetNode(
              preset.id,
              preset.label,
              children: [
                for (final category in preset.children)
                  if (category.id == node.categoryId)
                    CategoryNode(
                      node.presetId,
                      category.data,
                      children: [
                        for (final tagGroup in category.children) ...[
                          tagGroup,
                          if (tagGroup.id == node.id) newNode,
                        ],
                      ],
                    )
                  else
                    category,
              ],
            )
          else
            preset,
      ];
      return newNode;
    }

    throw Exception('Unknown node type');
  }

  void updatePreset(String presetId, String newLabel) {
    state = [
      for (final preset in state)
        if (preset.id == presetId)
          PresetNode(
            preset.id,
            newLabel,
            children: preset.children,
          )
        else
          preset,
    ];
  }

  void pasteNode(RandomTreeNode targetParent, RandomTreeNode clipboardNode) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    if (targetParent is PresetNode && clipboardNode is CategoryNode) {
      final newCategoryData = clipboardNode.data.copyWith(
        id: timestamp,
        name: '${clipboardNode.data.name} (副本)',
      );
      
      final newChildren = clipboardNode.children.map((child) {
        final childTimestamp = DateTime.now().millisecondsSinceEpoch.toString() + child.id; 
        final newTagGroupData = child.data.copyWith(id: childTimestamp);
        return TagGroupNode(targetParent.id, timestamp, newTagGroupData);
      }).toList();

      final newCategoryNode = CategoryNode(
        targetParent.id,
        newCategoryData,
        children: newChildren,
      );

      state = [
        for (final preset in state)
          if (preset.id == targetParent.id)
            PresetNode(
              preset.id,
              preset.label,
              children: [...preset.children, newCategoryNode],
            )
          else
            preset,
      ];
    } else if (targetParent is CategoryNode && clipboardNode is TagGroupNode) {
      final newTagGroupData = clipboardNode.data.copyWith(
        id: timestamp,
        name: '${clipboardNode.data.name} (副本)',
      );
      
      final newTagGroupNode = TagGroupNode(
        targetParent.presetId,
        targetParent.id,
        newTagGroupData,
      );

      state = [
        for (final preset in state)
          if (preset.id == targetParent.presetId)
            PresetNode(
              preset.id,
              preset.label,
              children: [
                for (final category in preset.children)
                  if (category.id == targetParent.id)
                    CategoryNode(
                      category.presetId,
                      category.data,
                      children: [...category.children, newTagGroupNode],
                    )
                  else
                    category,
              ],
            )
          else
            preset,
      ];
    }
  }
}

final randomTreeDataProvider = StateNotifierProvider<RandomTreeDataNotifier, List<PresetNode>>((ref) {
  return RandomTreeDataNotifier();
});
