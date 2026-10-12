import '../../../../../core/save_naming/save_name_template.dart';
import '../../../../../l10n/app_localizations.dart';

/// 保存命名模板的字段说明、过滤器说明与语法错误文案。
extension SaveNamingMessages on AppLocalizations {
  String saveNameTokenDescription(SaveNameToken token) => switch (token) {
    SaveNameToken.prompt => settings_saveNamingFieldPrompt,
    SaveNameToken.seed => settings_saveNamingFieldSeed,
    SaveNameToken.date => settings_saveNamingFieldDate,
    SaveNameToken.time => settings_saveNamingFieldTime,
    SaveNameToken.year => settings_saveNamingFieldYear,
    SaveNameToken.month => settings_saveNamingFieldMonth,
    SaveNameToken.day => settings_saveNamingFieldDay,
    SaveNameToken.model => settings_saveNamingFieldModel,
    SaveNameToken.modelName => settings_saveNamingFieldModelName,
    SaveNameToken.resolution => settings_saveNamingFieldResolution,
    SaveNameToken.width => settings_saveNamingFieldWidth,
    SaveNameToken.height => settings_saveNamingFieldHeight,
    SaveNameToken.imageIndex => settings_saveNamingFieldIndex,
    SaveNameToken.imageId => settings_saveNamingFieldId,
    SaveNameToken.type => settings_saveNamingFieldType,
    SaveNameToken.characters => settings_saveNamingFieldCharacters,
  };

  String saveNameFilterDescription(SaveNameFilterKind kind) => switch (kind) {
    SaveNameFilterKind.first => settings_saveNamingFilterFirst,
    SaveNameFilterKind.last => settings_saveNamingFilterLast,
    SaveNameFilterKind.words => settings_saveNamingFilterWords,
    SaveNameFilterKind.tags => settings_saveNamingFilterTags,
    SaveNameFilterKind.pre => settings_saveNamingFilterPre,
    SaveNameFilterKind.suf => settings_saveNamingFilterSuf,
    SaveNameFilterKind.pad => settings_saveNamingFilterPad,
    SaveNameFilterKind.lower => settings_saveNamingFilterLower,
    SaveNameFilterKind.upper => settings_saveNamingFilterUpper,
    SaveNameFilterKind.max => settings_saveNamingFilterMax,
    SaveNameFilterKind.at => settings_saveNamingFilterAt,
    SaveNameFilterKind.each => settings_saveNamingFilterEach,
    SaveNameFilterKind.join => settings_saveNamingFilterJoin,
    SaveNameFilterKind.full => settings_saveNamingFilterFull,
  };

  String saveNameTemplateError(SaveNameTemplateException error) {
    final subject = error.subject ?? '';
    return switch (error.kind) {
      SaveNameTemplateErrorKind.unclosedBrace =>
        settings_saveNamingErrorUnclosedBrace(error.position ?? 0),
      SaveNameTemplateErrorKind.unknownToken =>
        settings_saveNamingErrorUnknownField(subject),
      SaveNameTemplateErrorKind.unknownFilter =>
        settings_saveNamingErrorUnknownFilter(subject),
      SaveNameTemplateErrorKind.filterOnlyForCharacters =>
        settings_saveNamingErrorFilterOnlyForCharacters(subject),
      SaveNameTemplateErrorKind.characterFilterAfterTextFilter =>
        settings_saveNamingErrorCharacterFilterOrder(subject),
      SaveNameTemplateErrorKind.filterTakesNoValue =>
        settings_saveNamingErrorFilterTakesNoValue(subject),
      SaveNameTemplateErrorKind.filterNeedsValue =>
        settings_saveNamingErrorFilterNeedsValue(subject),
      SaveNameTemplateErrorKind.filterNeedsPositiveNumber =>
        settings_saveNamingErrorFilterNeedsPositiveNumber(subject),
      SaveNameTemplateErrorKind.filterNeedsNonZeroNumber =>
        settings_saveNamingErrorFilterNeedsNonZeroNumber(subject),
    };
  }
}

/// 过滤器在帮助里的写法，参数用 N / X 占位。
String saveNameFilterSyntax(SaveNameFilterKind kind) => switch (kind.argument) {
  SaveNameFilterArgument.none => kind.id,
  SaveNameFilterArgument.text => '${kind.id}:X',
  SaveNameFilterArgument.positiveInt ||
  SaveNameFilterArgument.nonzeroInt => '${kind.id}:N',
};
