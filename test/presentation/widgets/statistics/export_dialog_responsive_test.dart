import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/gallery_statistics.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/statistics/export_dialog.dart';

void main() {
  testWidgets('dialog remains reachable from 320 to 1600 including 3x text', (
    tester,
  ) async {
    for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
      await _pumpHost(
        tester,
        size: Size(width, 760),
        textScaler: width == 320
            ? const TextScaler.linear(3)
            : TextScaler.noScaling,
      );
      await tester.tap(find.byKey(const Key('open-statistics-export')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('statistics-export-submit')), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width=$width');

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('short height, IME, and SafeArea keep close action reachable', (
    tester,
  ) async {
    await _pumpHost(
      tester,
      size: const Size(320, 480),
      textScaler: const TextScaler.linear(3),
      viewInsets: const EdgeInsets.only(bottom: 180),
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 20),
    );
    await tester.tap(find.byKey(const Key('open-statistics-export')));
    await tester.pumpAndSettle();

    final close = find.byTooltip('Close');
    expect(close, findsOneWidget);
    final rect = tester.getRect(close);
    expect(rect.top, greaterThanOrEqualTo(24));
    expect(rect.bottom, lessThanOrEqualTo(480 - 180 - 20));
    expect(tester.takeException(), isNull);

    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byType(StatisticsExportDialog), findsNothing);
  });

  testWidgets('JSON and CSV choices generate complete correctly escaped data', (
    tester,
  ) async {
    String? exportedText;
    String? exportedFileName;
    String? exportedMimeType;
    List<String>? exportedExtensions;

    Future<String?> capture({
      required String text,
      required String fileName,
      required String dialogTitle,
      required String mimeType,
      required List<String> allowedExtensions,
    }) async {
      exportedText = text;
      exportedFileName = fileName;
      exportedMimeType = mimeType;
      exportedExtensions = allowedExtensions;
      return null;
    }

    await _pumpDialog(tester, writer: capture);
    await tester.tap(find.byKey(const Key('statistics-export-submit')));
    await tester.pump();

    expect(exportedFileName, endsWith('.json'));
    expect(exportedMimeType, 'application/json');
    expect(exportedExtensions, ['json']);
    final payload = jsonDecode(exportedText!) as Map<String, dynamic>;
    final statistics = payload['statistics'] as Map<String, dynamic>;
    expect((statistics['overview'] as Map<String, dynamic>)['totalImages'], 10);
    expect(
      (statistics['tagDistribution'] as List).single['tagName'],
      'tag,one',
    );

    await _pumpDialog(tester, writer: capture);
    await tester.tap(find.byKey(const Key('statistics-export-format-csv')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('statistics-export-submit')));
    await tester.pump();

    expect(exportedFileName, endsWith('.csv'));
    expect(exportedMimeType, 'text/csv');
    expect(exportedExtensions, ['csv']);
    expect(exportedText, contains('Model Distribution'));
    expect(exportedText, contains('"model ""quoted""",4,40.00%'));
    expect(exportedText, contains('"tag,one",3,30.00%'));
  });

  testWidgets(
    'parameter distribution goes to JSON and CSV, recent activity to JSON only',
    (tester) async {
      String? exportedText;
      Future<String?> capture({
        required String text,
        required String fileName,
        required String dialogTitle,
        required String mimeType,
        required List<String> allowedExtensions,
      }) async {
        exportedText = text;
        return null;
      }

      final statistics = _statistics.copyWith(
        parameterDistribution: const [
          ParameterStatistics(
            parameterName: 'sampler',
            value: 'k_euler',
            count: 6,
            percentage: 60,
          ),
          ParameterStatistics(
            parameterName: 'scale',
            value: '5.0',
            count: 4,
            percentage: 40,
          ),
        ],
        recentActivity: const [
          {
            'path': '/gallery/recent.png',
            'size': 1024,
            'modifiedAt': '2026-09-29T08:30:00.000',
            'isFavorite': false,
            'tags': ['portrait'],
            'hasMetadata': true,
            'width': 832,
            'height': 1216,
            'model': 'model-a',
            'sampler': 'k_euler',
            'steps': 28,
            'scale': 5.0,
          },
        ],
      );

      await _pumpDialog(tester, writer: capture, statistics: statistics);
      await tester.tap(find.byKey(const Key('statistics-export-submit')));
      await tester.pump();

      final payload = jsonDecode(exportedText!) as Map<String, dynamic>;
      final exported = payload['statistics'] as Map<String, dynamic>;
      expect(exported['parameterDistribution'], [
        {
          'parameterName': 'sampler',
          'value': 'k_euler',
          'count': 6,
          'percentage': 60.0,
        },
        {
          'parameterName': 'scale',
          'value': '5.0',
          'count': 4,
          'percentage': 40.0,
        },
      ]);
      expect(exported['recentActivity'], statistics.recentActivity);

      await _pumpDialog(tester, writer: capture, statistics: statistics);
      await tester.tap(find.byKey(const Key('statistics-export-format-csv')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('statistics-export-submit')));
      await tester.pump();

      expect(exportedText, contains('Parameter Distribution'));
      expect(exportedText, contains('Parameter Name,Value,Count,Percentage'));
      expect(exportedText, contains('sampler,k_euler,6,60.00%'));
      expect(exportedText, contains('scale,5.0,4,40.00%'));
      expect(exportedText, isNot(contains('/gallery/recent.png')));
    },
  );

  testWidgets('pending export shows progress and disables format changes', (
    tester,
  ) async {
    final save = Completer<String?>();
    Future<String?> pending({
      required String text,
      required String fileName,
      required String dialogTitle,
      required String mimeType,
      required List<String> allowedExtensions,
    }) => save.future;

    await _pumpDialog(tester, writer: pending, size: const Size(320, 300));
    await tester.tap(find.byKey(const Key('statistics-export-submit')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('statistics-export-submit')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<InkWell>(
            find.byKey(const Key('statistics-export-format-csv')),
          )
          .onTap,
      isNull,
    );
    expect(find.byKey(const Key('statistics-export-cancel')), findsOneWidget);
    expect(tester.takeException(), isNull);

    save.complete(null);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('export errors remain visible and leave close action reachable', (
    tester,
  ) async {
    Future<String?> fail({
      required String text,
      required String fileName,
      required String dialogTitle,
      required String mimeType,
      required List<String> allowedExtensions,
    }) async {
      throw StateError('disk denied');
    }

    await _pumpDialog(tester, writer: fail, size: const Size(320, 300));
    await tester.tap(find.byKey(const Key('statistics-export-submit')));
    await tester.pump();

    expect(find.textContaining('disk denied'), findsOneWidget);
    expect(find.byType(StatisticsExportDialog), findsOneWidget);
    expect(find.byKey(const Key('statistics-export-cancel')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required StatisticsExportWriter writer,
  Size size = const Size(840, 600),
  GalleryStatistics? statistics,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatisticsExportDialog(
            statistics: statistics ?? _statistics,
            exportWriter: writer,
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required Size size,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets viewInsets = EdgeInsets.zero,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        key: UniqueKey(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: textScaler,
            viewInsets: viewInsets,
            padding: padding,
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open-statistics-export'),
                onPressed: () => StatisticsExportDialog.show(
                  context,
                  statistics: _statistics,
                ),
                child: const Text('Open export'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

final _statistics = GalleryStatistics(
  totalImages: 10,
  totalSizeBytes: 2048,
  averageFileSizeBytes: 204.8,
  favoriteCount: 2,
  taggedImageCount: 3,
  imagesWithMetadata: 4,
  calculatedAt: DateTime.utc(2025, 1, 2, 3, 4, 5),
  modelDistribution: const [
    ModelStatistics(modelName: 'model "quoted"', count: 4, percentage: 40),
  ],
  resolutionDistribution: const [
    ResolutionStatistics(label: '1024x1024', count: 5, percentage: 50),
  ],
  samplerDistribution: const [
    SamplerStatistics(samplerName: 'Euler', count: 6, percentage: 60),
  ],
  tagDistribution: const [
    TagStatistics(tagName: 'tag,one', count: 3, percentage: 30),
  ],
  parameterDistribution: const [
    ParameterStatistics(
      parameterName: 'prompt',
      value: 'line one\nline two',
      count: 1,
      percentage: 10,
    ),
  ],
  sizeDistribution: const [
    SizeDistributionStatistics(label: '< 1MB', count: 10, percentage: 100),
  ],
);
