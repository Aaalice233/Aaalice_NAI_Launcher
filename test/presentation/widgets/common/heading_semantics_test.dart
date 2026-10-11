import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/heading_semantics.dart';

void main() {
  testWidgets(
    'sets both the desktop header flag and the mobile heading level',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: HeadingSemantics(level: 2, child: Text('Section')),
        ),
      );

      final node = tester.getSemantics(find.text('Section'));
      expect(node.flagsCollection.isHeader, isTrue);
      expect(node.headingLevel, 2);
    },
  );

  test('lib declares headings only through HeadingSemantics', () {
    const allowed = 'lib/presentation/widgets/common/heading_semantics.dart';
    final pattern = RegExp(r'\bheader\s*:\s*true\b|\bheadingLevel\s*:');

    final offenders = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final path = file.path.replaceAll(r'\', '/');
      if (path == allowed) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!pattern.hasMatch(lines[i])) continue;
        offenders.add('  $path:${i + 1}  ${lines[i].trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Desktop accessibility reads only `header` while Android and iOS '
          'read only `headingLevel`. Wrap headings in HeadingSemantics so '
          'both are set:\n${offenders.join('\n')}',
    );
  });
}
