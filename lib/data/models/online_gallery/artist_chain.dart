/// An immutable, semantics-preserving extraction of `artist:` tags from a
/// positive NovelAI prompt.
class ArtistChainExtraction {
  const ArtistChainExtraction({
    required this.formattedText,
    required this.rawFragments,
    required this.artistNames,
  });

  static const empty = ArtistChainExtraction(
    formattedText: '',
    rawFragments: <String>[],
    artistNames: <String>[],
  );

  /// Copy-ready text with the original ordering and weight scopes retained.
  final String formattedText;

  /// The matched tag fragments exactly as they appeared, apart from trimming
  /// surrounding whitespace.
  final List<String> rawFragments;

  /// Unique artist names in first-seen order.
  final List<String> artistNames;

  bool get isEmpty => formattedText.isEmpty;
  bool get isNotEmpty => !isEmpty;
  int get artistCount => artistNames.length;
  String get rawText => rawFragments.join(', ');
}
