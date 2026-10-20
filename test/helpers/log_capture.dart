import 'dart:async';

Future<List<String>> captureLogs(FutureOr<void> Function() action) async {
  final logs = <String>[];
  await runZoned(
    () async => action(),
    zoneSpecification: ZoneSpecification(
      print: (_, _, _, line) => logs.add(line),
    ),
  );
  return logs;
}
