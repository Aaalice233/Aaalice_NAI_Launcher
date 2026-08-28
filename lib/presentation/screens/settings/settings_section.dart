enum SettingsSection {
  account('account'),
  appearance('appearance'),
  generation('generation'),
  agent('agent'),
  storage('storage'),
  cloudSync('cloud-sync'),
  privacy('privacy'),
  network('network'),
  shortcuts('shortcuts'),
  integrations('integrations'),
  about('about');

  const SettingsSection(this.id);

  final String id;

  static SettingsSection fromId(String? value) => values.firstWhere(
    (section) => section.id == value,
    orElse: () => SettingsSection.account,
  );
}
