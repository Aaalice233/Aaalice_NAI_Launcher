import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import 'local_gallery_toolbox.dart';
import 'online_gallery_toolbox.dart';

class GalleryToolbox {
  GalleryToolbox(this._ref);

  final Ref _ref;

  List<AgentTool> tools() => [
    ...OnlineGalleryToolbox(_ref).tools(),
    ...LocalGalleryToolbox(_ref).tools(),
  ];
}
