import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/metadata/isolate_metadata_service.dart';

void main() {
  test('metadata response gate rejects stale request ids', () {
    expect(
      metadataResponseMatchesActiveRequest(
        activeRequestId: 2,
        responseRequestId: 1,
      ),
      isFalse,
    );
    expect(
      metadataResponseMatchesActiveRequest(
        activeRequestId: 2,
        responseRequestId: 2,
      ),
      isTrue,
    );
  });
}
