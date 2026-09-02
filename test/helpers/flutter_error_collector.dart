import 'package:flutter_test/flutter_test.dart';

/// Lets layout tests assert that the Flutter test binding did not capture an
/// unexpected framework exception.
///
/// The helper deliberately does not replace [FlutterError.onError]. The test
/// binding remains the sole owner of the global handler, so parallel tests and
/// asynchronous cleanup cannot observe or restore another test's handler.
class FlutterErrorCollector {
  FlutterErrorCollector._(this._tester);

  final WidgetTester _tester;

  static FlutterErrorCollector install(WidgetTester tester) {
    return FlutterErrorCollector._(tester);
  }

  void expectNoErrors({String? reason}) {
    expect(_tester.takeException(), isNull, reason: reason);
  }

  void restoreAndAssertNoErrors() {
    expectNoErrors();
  }
}
