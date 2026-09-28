enum InpaintDraftStatus {
  prepared,
  editing,
  ready,
  cancelled,
  submitting,
  submitted,
  failed;

  static InpaintDraftStatus fromJson(Object? value) {
    return InpaintDraftStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () =>
          throw FormatException('Unknown inpaint draft status: $value'),
    );
  }
}
