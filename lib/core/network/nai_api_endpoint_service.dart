import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nai_api_endpoint.dart';

/// Holds the API endpoint used by the currently authenticated account.
class NaiApiEndpointService {
  NaiApiEndpointConfig _current = NaiApiEndpointConfig.official;

  NaiApiEndpointConfig get current => _current;

  void setCurrent(NaiApiEndpointConfig endpoint) {
    _current = endpoint;
  }

  void resetToOfficial() {
    _current = NaiApiEndpointConfig.official;
  }

  String mainUrl(String endpoint) => _current.mainUrl(endpoint);

  String imageUrl(String endpoint) => _current.imageUrl(endpoint);

  String userUrl(String endpoint) => _current.userUrl(endpoint);
}

final naiApiEndpointServiceProvider = Provider<NaiApiEndpointService>(
  (ref) => NaiApiEndpointService(),
);
