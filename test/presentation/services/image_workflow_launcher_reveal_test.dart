import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/generation/workflow_panel_reveal_provider.dart';
import 'package:nai_launcher/presentation/services/image_workflow_launcher.dart';

import '../../helpers/memory_local_storage.dart';

void main() {
  testWidgets('放大和增强都会请求呈现工作流面板', (tester) async {
    late WidgetRef widgetRef;
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWith((ref) => MemoryLocalStorage()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 4, height: 4)),
    );

    ImageWorkflowLauncher.openUpscale(widgetRef, bytes);
    expect(container.read(workflowPanelRevealProvider), 1);
    ImageWorkflowLauncher.openEnhance(widgetRef, bytes);
    expect(container.read(workflowPanelRevealProvider), 2);
  });
}
