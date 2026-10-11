import 'package:path/path.dart' as p;

final class GenerationSavePathSeedUnavailable implements Exception {
  const GenerationSavePathSeedUnavailable();

  @override
  String toString() =>
      'GenerationSavePathSeedUnavailable: {seed} needs a resolved seed.';
}

/// Expands {index} / {seed} / {id} placeholders in explicit save targets.
abstract final class GenerationSavePathTemplate {
  static const indexPlaceholder = '{index}';
  static const seedPlaceholder = '{seed}';
  static const idPlaceholder = '{id}';

  static bool hasPlaceholder(String path) =>
      _containsPlaceholder(p.windows.basename(path));

  /// Placeholders outside the basename would spread one batch over directories.
  static bool hasPlaceholderInDirectory(String path) =>
      _containsPlaceholder(p.windows.dirname(path));

  static String expand(
    String template, {
    required int index,
    required int total,
    required int? seed,
    required String id,
  }) {
    var expanded = template;
    if (expanded.contains(indexPlaceholder)) {
      final width = total > 0 ? total.toString().length : 1;
      expanded = expanded.replaceAll(
        indexPlaceholder,
        index.toString().padLeft(width, '0'),
      );
    }
    if (expanded.contains(seedPlaceholder)) {
      if (seed == null) throw const GenerationSavePathSeedUnavailable();
      expanded = expanded.replaceAll(seedPlaceholder, seed.toString());
    }
    // id 最后展开：它是不透明运行时值，展开结果不再参与占位符替换。
    return expanded.replaceAll(idPlaceholder, id);
  }

  static bool _containsPlaceholder(String segment) =>
      segment.contains(indexPlaceholder) ||
      segment.contains(seedPlaceholder) ||
      segment.contains(idPlaceholder);
}
