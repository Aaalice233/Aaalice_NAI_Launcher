/// 批量操作的进度回调
typedef BulkProgressCallback =
    void Function({
      required int current,
      required int total,
      required String currentItem,
      required bool isComplete,
    });

/// 批量操作结果
typedef BulkOperationResult = ({
  int success,
  int failed,
  List<String> errors,
  List<String> successfulItems,
});

/// 空结果；每次返回新的可增长列表，调用方可以继续追加
BulkOperationResult get emptyBulkOperationResult =>
    (success: 0, failed: 0, errors: <String>[], successfulItems: <String>[]);

/// 单张图片的目标标签
class BulkTagAssignment {
  const BulkTagAssignment({required this.path, required this.tags});

  final String path;
  final List<String> tags;
}

/// 单张图片的目标收藏状态
class BulkFavoriteAssignment {
  const BulkFavoriteAssignment({required this.path, required this.isFavorite});

  final String path;
  final bool isFavorite;
}

/// 批量标签编辑结果，附带成功项写入前后的标签供撤销/重做回放
class BulkTagEditOutcome {
  const BulkTagEditOutcome({
    required this.result,
    required this.previous,
    required this.applied,
  });

  final BulkOperationResult result;
  final List<BulkTagAssignment> previous;
  final List<BulkTagAssignment> applied;
}

/// 批量收藏结果，附带成功项写入前后的收藏状态供撤销/重做回放
class BulkFavoriteOutcome {
  const BulkFavoriteOutcome({
    required this.result,
    required this.previous,
    required this.applied,
  });

  final BulkOperationResult result;
  final List<BulkFavoriteAssignment> previous;
  final List<BulkFavoriteAssignment> applied;
}
