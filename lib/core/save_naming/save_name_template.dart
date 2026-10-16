/// 保存路径模板：`{token|filter:arg}` 语法的解析与渲染，`{{` 表示字面 `{`。
library;

/// 模板可引用的字段；[id] 是模板里的写法。
enum SaveNameToken {
  prompt('prompt'),
  seed('seed'),
  date('date'),
  time('time'),
  year('year'),
  month('month'),
  day('day'),
  model('model'),
  modelName('modelname'),
  resolution('resolution'),
  width('width'),
  height('height'),
  imageIndex('index'),
  imageId('id'),
  type('type'),
  characters('characters');

  const SaveNameToken(this.id);

  final String id;

  static SaveNameToken? fromId(String id) {
    for (final token in values) {
      if (token.id == id) return token;
    }
    return null;
  }

  bool get readsMetadata => switch (this) {
    prompt || seed || model || modelName || type || characters => true,
    _ => false,
  };

  bool get readsDimensions => switch (this) {
    resolution || width || height => true,
    _ => false,
  };
}

enum SaveNameFilterArgument { none, text, positiveInt, nonzeroInt }

/// 通用过滤器对任意 token 生效；角色过滤器只用于 `{characters}`，且必须写在通用过滤器之前。
enum SaveNameFilterKind {
  first('first', SaveNameFilterArgument.positiveInt),
  last('last', SaveNameFilterArgument.positiveInt),
  words('words', SaveNameFilterArgument.nonzeroInt),
  tags('tags', SaveNameFilterArgument.nonzeroInt),
  pre('pre', SaveNameFilterArgument.text),
  suf('suf', SaveNameFilterArgument.text),
  pad('pad', SaveNameFilterArgument.positiveInt),
  lower('lower', SaveNameFilterArgument.none),
  upper('upper', SaveNameFilterArgument.none),
  max('max', SaveNameFilterArgument.positiveInt, characterOnly: true),
  at('at', SaveNameFilterArgument.positiveInt, characterOnly: true),
  each('each', SaveNameFilterArgument.positiveInt, characterOnly: true),
  join('join', SaveNameFilterArgument.text, characterOnly: true),
  full('full', SaveNameFilterArgument.none, characterOnly: true);

  const SaveNameFilterKind(
    this.id,
    this.argument, {
    this.characterOnly = false,
  });

  final String id;
  final SaveNameFilterArgument argument;
  final bool characterOnly;

  static SaveNameFilterKind? fromId(String id) {
    for (final kind in values) {
      if (kind.id == id) return kind;
    }
    return null;
  }
}

enum SaveNameTemplateErrorKind {
  unclosedBrace,
  unknownToken,
  unknownFilter,
  filterOnlyForCharacters,
  characterFilterAfterTextFilter,
  filterTakesNoValue,
  filterNeedsValue,
  filterNeedsPositiveNumber,
  filterNeedsNonZeroNumber,
}

final class SaveNameTemplateException implements Exception {
  const SaveNameTemplateException(this.kind, {this.position, this.subject});

  final SaveNameTemplateErrorKind kind;

  /// 从 1 开始的字符位置，仅 [SaveNameTemplateErrorKind.unclosedBrace] 有值。
  final int? position;

  /// 出错的 token 或过滤器名。
  final String? subject;

  @override
  String toString() =>
      'SaveNameTemplateException(${kind.name}'
      '${position == null ? '' : ', position: $position'}'
      '${subject == null ? '' : ', subject: $subject'})';
}

final class SaveNameFilter {
  const SaveNameFilter(this.kind, this.argument);

  final SaveNameFilterKind kind;
  final String? argument;

  int get number => int.parse(argument!.trim());
}

sealed class SaveNameTemplatePart {
  const SaveNameTemplatePart();
}

final class SaveNameTextPart extends SaveNameTemplatePart {
  const SaveNameTextPart(this.text);

  final String text;
}

final class SaveNameTokenPart extends SaveNameTemplatePart {
  const SaveNameTokenPart(this.token, this.filters);

  final SaveNameToken token;
  final List<SaveNameFilter> filters;
}

final class SaveNameCharacter {
  const SaveNameCharacter({required this.prompt});

  final String prompt;
}

/// 渲染所需的字段值；空串表示该字段没有值。
abstract interface class SaveNameValues {
  String valueOf(SaveNameToken token);

  List<SaveNameCharacter> get characters;
}

final class SaveNameTemplate {
  const SaveNameTemplate._(this.parts);

  /// 语法错误抛出 [SaveNameTemplateException]。
  factory SaveNameTemplate.parse(String source) =>
      SaveNameTemplate._(List.unmodifiable(_parse(source)));

  static SaveNameTemplateException? validate(String source) {
    try {
      SaveNameTemplate.parse(source);
      return null;
    } on SaveNameTemplateException catch (error) {
      return error;
    }
  }

  final List<SaveNameTemplatePart> parts;

  Set<SaveNameToken> get tokens => {
    for (final part in parts)
      if (part is SaveNameTokenPart) part.token,
  };

  bool get readsMetadata => tokens.any((token) => token.readsMetadata);

  bool get readsDimensions => tokens.any((token) => token.readsDimensions);

  bool get readsDate => tokens.any(
    (token) =>
        token == SaveNameToken.date ||
        token == SaveNameToken.year ||
        token == SaveNameToken.month ||
        token == SaveNameToken.day,
  );

  /// 未清洗的渲染结果；落盘前须经过 `SavePathSanitizer`。
  String render(SaveNameValues values) =>
      renderSegments(values, splitOnSeparators: false).single;

  /// 只有模板字面文字里的 `/` 与 `\` 分段；token 值里的分隔符保留给清洗环节替换。
  List<String> renderSegments(
    SaveNameValues values, {
    bool splitOnSeparators = true,
  }) {
    final segments = <String>[];
    final current = StringBuffer();
    for (final part in parts) {
      switch (part) {
        case SaveNameTextPart(:final text):
          if (!splitOnSeparators) {
            current.write(text);
            continue;
          }
          final pieces = text.split(_separator);
          current.write(pieces.first);
          for (final piece in pieces.skip(1)) {
            segments.add(current.toString());
            current
              ..clear()
              ..write(piece);
          }
        case SaveNameTokenPart():
          current.write(_renderToken(part, values));
      }
    }
    segments.add(current.toString());
    return segments;
  }

  static final RegExp _separator = RegExp(r'[/\\]');
}

const int _promptDefaultCodePoints = 80;
const int _defaultCharacterCount = 3;
const Set<String> _genericSubjectTags = {
  'girl',
  'female',
  'boy',
  'male',
  '1girl',
  '1boy',
};

List<SaveNameTemplatePart> _parse(String source) {
  final parts = <SaveNameTemplatePart>[];
  final text = StringBuffer();
  var index = 0;
  while (index < source.length) {
    final char = source[index];
    if (char != '{') {
      text.write(char);
      index++;
      continue;
    }
    if (index + 1 < source.length && source[index + 1] == '{') {
      text.write('{');
      index += 2;
      continue;
    }
    final close = source.indexOf('}', index);
    if (close == -1) {
      throw SaveNameTemplateException(
        SaveNameTemplateErrorKind.unclosedBrace,
        position: index + 1,
      );
    }
    if (text.isNotEmpty) {
      parts.add(SaveNameTextPart(text.toString()));
      text.clear();
    }
    parts.add(_parseToken(source.substring(index + 1, close)));
    index = close + 1;
  }
  if (text.isNotEmpty) parts.add(SaveNameTextPart(text.toString()));
  return parts;
}

SaveNameTokenPart _parseToken(String body) {
  final pieces = body.split('|');
  final name = pieces.first.trim();
  final token = SaveNameToken.fromId(name);
  if (token == null) {
    throw SaveNameTemplateException(
      SaveNameTemplateErrorKind.unknownToken,
      subject: name,
    );
  }
  final isCharacters = token == SaveNameToken.characters;
  var textFiltersStarted = !isCharacters;
  final filters = <SaveNameFilter>[];
  for (final piece in pieces.skip(1)) {
    final colon = piece.indexOf(':');
    final filterName = (colon == -1 ? piece : piece.substring(0, colon)).trim();
    final argument = colon == -1 ? null : piece.substring(colon + 1);
    final kind = SaveNameFilterKind.fromId(filterName);
    if (kind == null) {
      throw SaveNameTemplateException(
        SaveNameTemplateErrorKind.unknownFilter,
        subject: filterName,
      );
    }
    if (kind.characterOnly) {
      if (!isCharacters) {
        throw SaveNameTemplateException(
          SaveNameTemplateErrorKind.filterOnlyForCharacters,
          subject: filterName,
        );
      }
      if (textFiltersStarted) {
        throw SaveNameTemplateException(
          SaveNameTemplateErrorKind.characterFilterAfterTextFilter,
          subject: filterName,
        );
      }
    } else {
      textFiltersStarted = true;
    }
    _validateArgument(kind, argument);
    filters.add(SaveNameFilter(kind, argument));
  }
  return SaveNameTokenPart(token, List.unmodifiable(filters));
}

void _validateArgument(SaveNameFilterKind kind, String? argument) {
  switch (kind.argument) {
    case SaveNameFilterArgument.none:
      if (argument != null) {
        throw SaveNameTemplateException(
          SaveNameTemplateErrorKind.filterTakesNoValue,
          subject: kind.id,
        );
      }
    case SaveNameFilterArgument.text:
      if (argument == null) {
        throw SaveNameTemplateException(
          SaveNameTemplateErrorKind.filterNeedsValue,
          subject: kind.id,
        );
      }
    case SaveNameFilterArgument.positiveInt:
      final value = _parseInteger(argument);
      if (value == null || value <= 0) {
        throw SaveNameTemplateException(
          SaveNameTemplateErrorKind.filterNeedsPositiveNumber,
          subject: kind.id,
        );
      }
    case SaveNameFilterArgument.nonzeroInt:
      final value = _parseInteger(argument);
      if (value == null || value == 0) {
        throw SaveNameTemplateException(
          SaveNameTemplateErrorKind.filterNeedsNonZeroNumber,
          subject: kind.id,
        );
      }
  }
}

final RegExp _integer = RegExp(r'^-?\d+$');

int? _parseInteger(String? argument) {
  if (argument == null) return null;
  final trimmed = argument.trim();
  return _integer.hasMatch(trimmed) ? int.tryParse(trimmed) : null;
}

String _renderToken(SaveNameTokenPart part, SaveNameValues values) {
  if (part.token == SaveNameToken.characters) {
    return _renderCharacters(part.filters, values.characters);
  }
  var value = values.valueOf(part.token);
  final hasLengthFilter = part.filters.any(
    (filter) => switch (filter.kind) {
      SaveNameFilterKind.first ||
      SaveNameFilterKind.last ||
      SaveNameFilterKind.words ||
      SaveNameFilterKind.tags => true,
      _ => false,
    },
  );
  if (part.token == SaveNameToken.prompt && !hasLengthFilter) {
    value = _firstCodePoints(value, _promptDefaultCodePoints);
  }
  for (final filter in part.filters) {
    value = _applyTextFilter(value, filter);
  }
  return value;
}

String _renderCharacters(
  List<SaveNameFilter> filters,
  List<SaveNameCharacter> characters,
) {
  // 解析器保证角色过滤器都在通用过滤器之前。
  int? max;
  int? at;
  int? each;
  var full = false;
  var join = '+';
  final textFilters = <SaveNameFilter>[];
  for (final filter in filters) {
    switch (filter.kind) {
      case SaveNameFilterKind.full:
        full = true;
      case SaveNameFilterKind.max:
        max = filter.number;
      case SaveNameFilterKind.at:
        at = filter.number;
      case SaveNameFilterKind.each:
        each = filter.number;
      case SaveNameFilterKind.join:
        join = filter.argument ?? '';
      case _:
        textFilters.add(filter);
    }
  }

  final Iterable<SaveNameCharacter> selected;
  if (at == null) {
    selected = characters.take(max ?? _defaultCharacterCount);
  } else if (at <= characters.length) {
    selected = [characters[at - 1]];
  } else {
    selected = const [];
  }
  var rendered = selected
      .map((character) {
        final label = full
            ? character.prompt.trim()
            : _leadingSubjectTag(character.prompt);
        return each == null ? label : _firstCodePoints(label, each);
      })
      .where((label) => label.isNotEmpty)
      .join(join);
  for (final filter in textFilters) {
    rendered = _applyTextFilter(rendered, filter);
  }
  return rendered;
}

// 角色提示词以 girl/1girl 这类泛指开头时，第二个 tag 才是能区分角色的名字。
String _leadingSubjectTag(String prompt) {
  final tags = prompt
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toList();
  if (tags.isEmpty) return '';
  if (_genericSubjectTags.contains(tags.first.toLowerCase())) {
    return tags.length > 1 ? tags[1] : tags.first;
  }
  return tags.first;
}

String _applyTextFilter(String value, SaveNameFilter filter) {
  switch (filter.kind) {
    case SaveNameFilterKind.first:
      return _firstCodePoints(value, filter.number);
    case SaveNameFilterKind.last:
      final runes = value.runes.toList();
      final count = filter.number;
      return String.fromCharCodes(
        runes.length <= count ? runes : runes.sublist(runes.length - count),
      );
    case SaveNameFilterKind.words:
      final words = value
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList();
      return _takeSigned(words, filter.number).join(' ');
    case SaveNameFilterKind.tags:
      final tags = value
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
      return _takeSigned(tags, filter.number).join(', ');
    case SaveNameFilterKind.pre:
      return value.isEmpty ? '' : '${filter.argument}$value';
    case SaveNameFilterKind.suf:
      return value.isEmpty ? '' : '$value${filter.argument}';
    case SaveNameFilterKind.pad:
      return RegExp(r'^\d+$').hasMatch(value)
          ? value.padLeft(filter.number, '0')
          : value;
    case SaveNameFilterKind.lower:
      return value.toLowerCase();
    case SaveNameFilterKind.upper:
      return value.toUpperCase();
    case SaveNameFilterKind.max ||
        SaveNameFilterKind.at ||
        SaveNameFilterKind.each ||
        SaveNameFilterKind.join ||
        SaveNameFilterKind.full:
      return value;
  }
}

// 正数取前 n 项，负数取后 |n| 项。
List<String> _takeSigned(List<String> items, int count) {
  if (count > 0) return items.take(count).toList();
  final tail = -count;
  return items.length <= tail ? items : items.sublist(items.length - tail);
}

String _firstCodePoints(String value, int count) {
  final runes = value.runes;
  return runes.length <= count
      ? value
      : String.fromCharCodes(runes.take(count));
}
