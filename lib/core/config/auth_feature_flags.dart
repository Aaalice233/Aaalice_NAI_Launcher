/// Central toggles for authentication flows that can change with NovelAI policy.
class AuthFeatureFlags {
  AuthFeatureFlags._();

  /// NovelAI supports exchanging a client-derived access key on the user API.
  /// Keep this alongside Token login so users can choose either flow.
  static const bool credentialsLoginEnabled = true;
}
