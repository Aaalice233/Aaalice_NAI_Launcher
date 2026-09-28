import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/screens/settings/settings_section.dart';

void main() {
  test('settings navigation uses stable IDs independent of list indexes', () {
    expect(SettingsSection.fromId('agent'), SettingsSection.agent);
    expect(SettingsSection.fromId('generation'), SettingsSection.generation);
    expect(SettingsSection.fromId('missing'), SettingsSection.account);
    expect(
      SettingsSection.values.map((section) => section.id).toSet().length,
      SettingsSection.values.length,
    );
  });
}
