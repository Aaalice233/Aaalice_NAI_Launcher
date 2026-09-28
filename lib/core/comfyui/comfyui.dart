// ComfyUI 集成核心模块
//
// 提供与 ComfyUI 服务器的通信能力：
// - [ComfyUIApiService]          HTTP REST API
// - [ComfyUIWebSocketService]    WebSocket 实时进度
// - [ComfyUIConnectionManager]   连接生命周期管理
// - 数据模型

export 'comfyui_api_service.dart';
export 'comfyui_connection_manager.dart';
export 'comfyui_models.dart';
export 'comfyui_url_utils.dart';
export 'comfyui_websocket_service.dart'
    show ComfyUIWebSocketService, ComfyUIImageFrame;
export 'seedvr2_support.dart';
export 'workflow_analyzer.dart';
export 'workflow_node_validator.dart';
export 'workflow_template.dart';
export 'workflow_template_manager.dart';
