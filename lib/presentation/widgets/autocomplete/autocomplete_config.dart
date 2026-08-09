/// Presentation options kept for compatibility with existing prompt fields.
/// User-level autocomplete settings take precedence where explicitly set.
class AutocompleteConfig {
  const AutocompleteConfig({
    this.maxSuggestions,
    this.showTranslation = true,
    this.showCategory = true,
    this.showCount = true,
    this.enableChineseSearch = true,
    this.debounceDelay = const Duration(milliseconds: 150),
    this.minQueryLength = 2,
    this.autoInsertComma = true,
    this.replaceUnderscoreWithSpace = false,
    this.treatSpacesAsSeparators = false,
  });

  /// Overrides the user-level result count only for space-constrained fields.
  final int? maxSuggestions;
  final bool showTranslation;
  final bool showCategory;
  final bool showCount;
  final bool enableChineseSearch;
  final Duration debounceDelay;
  final int minQueryLength;
  final bool autoInsertComma;
  final bool replaceUnderscoreWithSpace;
  final bool treatSpacesAsSeparators;
}
