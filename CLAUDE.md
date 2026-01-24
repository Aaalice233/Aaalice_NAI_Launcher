# Multi-Language Support Reminder

When adding new features with user-facing text, always add translations to both `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb`. Access translations via `context.l10n.key_name` using the localization extension, then run `flutter gen-l10n` to regenerate the localization files.
