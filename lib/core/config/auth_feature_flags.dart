/// Central toggles for authentication flows that can change with NovelAI policy.
class AuthFeatureFlags {
  AuthFeatureFlags._();

  /// NovelAI currently requires a browser-side safety check for email/password
  /// login, so keep the implementation dormant until that flow is usable again.
  static const bool credentialsLoginEnabled = false;
}
