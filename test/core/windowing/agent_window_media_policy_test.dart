import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/windowing/agent_window_transcript_widgets.dart';

void main() {
  test(
    'secondary window only projects explicit tool media outside the turn',
    () {
      expect(
        agentWindowShouldProjectToolMedia({'toolName': 'display_images'}),
        isTrue,
      );
      expect(
        agentWindowShouldProjectToolMedia({'toolName': 'submit_generation'}),
        isTrue,
      );
      expect(
        agentWindowShouldProjectToolMedia({'toolName': 'get_recent_images'}),
        isFalse,
      );
      expect(
        agentWindowShouldProjectToolMedia({'toolName': 'search_local_gallery'}),
        isFalse,
      );
    },
  );
}
