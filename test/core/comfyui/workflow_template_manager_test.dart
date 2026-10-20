import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/comfyui/workflow_template_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../helpers/log_capture.dart';

void main() {
  late Directory documents;
  late PathProviderPlatform originalPathProvider;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('workflow_templates_');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _DocumentsPathProvider(documents.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    await documents.delete(recursive: true);
  });

  test('corrupt custom workflow is skipped without logging its prompt', () async {
    final directory = Directory(
      p.join(documents.path, 'NAI_Launcher', 'comfyui_workflows'),
    )..createSync(recursive: true);
    File(p.join(directory.path, 'broken.json')).writeAsStringSync(
      '{"workflow":{"6":{"inputs":{"text":"secret lighthouse keeper",',
    );
    final manager = WorkflowTemplateManager();

    final logs = await captureLogs(manager.loadAllTemplates);

    expect(manager.customTemplates, isEmpty);
    expect(
      logs.where((line) => line.contains('Failed to load custom workflow')),
      hasLength(1),
    );
    expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
  });
}

class _DocumentsPathProvider extends PathProviderPlatform {
  _DocumentsPathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}
