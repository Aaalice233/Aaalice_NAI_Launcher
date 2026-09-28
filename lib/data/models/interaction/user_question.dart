/// A question has three concrete directions; the UI adds a fourth custom answer.
class UserQuestion {
  const UserQuestion({
    required this.id,
    required this.title,
    required this.options,
    required this.recommendedOptionId,
  });

  final String id;
  final String title;
  final List<UserQuestionOption> options;
  final String recommendedOptionId;

  factory UserQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    if (rawOptions is! List || rawOptions.length != 3) {
      throw const FormatException(
        'Each question requires three meaningful options.',
      );
    }
    final options = rawOptions
        .map((value) {
          if (value is! Map<String, dynamic>) {
            throw const FormatException('Invalid question option.');
          }
          return UserQuestionOption(
            id: _requiredText(value, 'id'),
            label: _requiredText(value, 'label'),
            description: _requiredText(value, 'description'),
          );
        })
        .toList(growable: false);
    if (options.map((option) => option.id).toSet().length != options.length ||
        options.map((option) => option.label).toSet().length !=
            options.length) {
      throw const FormatException('Option IDs and labels must be distinct.');
    }
    final recommended = _requiredText(json, 'recommended_option_id');
    if (!options.any((option) => option.id == recommended)) {
      throw const FormatException('Recommend one of the supplied options.');
    }
    return UserQuestion(
      id: _requiredText(json, 'id'),
      title: _requiredText(json, 'title'),
      options: List.unmodifiable(options),
      recommendedOptionId: recommended,
    );
  }
}

class UserQuestionOption {
  const UserQuestionOption({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

class UserQuestionAnswer {
  const UserQuestionAnswer.option(
    this.optionId, {
    this.automaticallySelected = false,
  }) : customText = null;
  const UserQuestionAnswer.custom(this.customText)
    : optionId = null,
      automaticallySelected = false;

  final bool automaticallySelected;

  final String? optionId;
  final String? customText;

  bool isValidFor(UserQuestion question) => optionId != null
      ? question.options.any((option) => option.id == optionId)
      : customText != null && customText!.trim().isNotEmpty;

  Map<String, dynamic> toJson(UserQuestion question) => {
    'question_id': question.id,
    'question': question.title,
    'option_id': optionId,
    'answer': optionId == null
        ? customText!.trim()
        : question.options.firstWhere((option) => option.id == optionId).label,
    'custom': optionId == null,
    if (automaticallySelected) 'source': 'timeout_recommendation',
  };
}

String _requiredText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('"$key" must be a non-empty string.');
  }
  return value.trim();
}
