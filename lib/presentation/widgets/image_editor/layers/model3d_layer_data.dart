/// 3D 模型图层元数据(可再编辑的增强信息;位图仍是图层的主内容)
///
/// [modelRef] 取值:
/// - `builtin:mannequin`  内置程序化人偶
/// - `lib:<sha256>`       应用内模型库文件
/// [sceneState] 为编辑器页序列化的不透明 JSON(骨骼姿势/相机/光照),
/// Dart 侧只存取、不解析。
class Model3dLayerData {
  final String modelRef;
  final Map<String, dynamic> sceneState;

  const Model3dLayerData({
    required this.modelRef,
    required this.sceneState,
  });

  Map<String, dynamic> toJson() => {
        'modelRef': modelRef,
        'sceneState': sceneState,
      };

  factory Model3dLayerData.fromJson(Map<String, dynamic> json) {
    return Model3dLayerData(
      modelRef: json['modelRef'] as String,
      sceneState: (json['sceneState'] as Map).cast<String, dynamic>(),
    );
  }
}
