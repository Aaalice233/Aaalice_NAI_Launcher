import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
// ignore: implementation_imports
import 'package:onnxruntime_v2/src/bindings/onnxruntime_bindings_generated.dart'
    as bg;

import 'local_onnx_tagger_preprocessor.dart';

// 模型图声明的输入形状；动态维度为 -1
class OnnxSessionInputSpec {
  const OnnxSessionInputSpec(this.dimensions);

  final List<int> dimensions;

  OnnxTensorLayout? get layout {
    if (dimensions.length != 4) return null;
    if (dimensions[1] == 3) return OnnxTensorLayout.nchw;
    if (dimensions[3] == 3) return OnnxTensorLayout.nhwc;
    return null;
  }

  int? get squareSize {
    final (height, width) = switch (layout) {
      OnnxTensorLayout.nchw => (dimensions[2], dimensions[3]),
      OnnxTensorLayout.nhwc => (dimensions[1], dimensions[2]),
      null => (-1, -1),
    };
    return height > 0 && height == width ? height : null;
  }

  // 部分导出把 batch 固定成 2 等常量，只能按声明数量喂入
  int get batchSize =>
      dimensions.isNotEmpty && dimensions.first > 0 ? dimensions.first : 1;

  static OnnxSessionInputSpec read(OrtSession session, int inputIndex) {
    final api = OrtEnv.instance.ortApiPtr.ref;
    final typeInfoOut = calloc<ffi.Pointer<bg.OrtTypeInfo>>();
    try {
      OrtStatus.checkOrtStatus(
        api.SessionGetInputTypeInfo.asFunction<
          bg.OrtStatusPtr Function(
            ffi.Pointer<bg.OrtSession>,
            int,
            ffi.Pointer<ffi.Pointer<bg.OrtTypeInfo>>,
          )
        >()(ffi.Pointer.fromAddress(session.address), inputIndex, typeInfoOut),
      );
      final typeInfo = typeInfoOut.value;
      try {
        return OnnxSessionInputSpec(_tensorDimensions(api, typeInfo));
      } finally {
        api.ReleaseTypeInfo.asFunction<
          void Function(ffi.Pointer<bg.OrtTypeInfo>)
        >()(typeInfo);
      }
    } finally {
      calloc.free(typeInfoOut);
    }
  }

  static List<int> _tensorDimensions(
    bg.OrtApi api,
    ffi.Pointer<bg.OrtTypeInfo> typeInfo,
  ) {
    final tensorInfoOut = calloc<ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>>();
    final countOut = calloc<ffi.Size>();
    try {
      // 返回的张量信息归 typeInfo 所有，不能单独释放
      OrtStatus.checkOrtStatus(
        api.CastTypeInfoToTensorInfo.asFunction<
          bg.OrtStatusPtr Function(
            ffi.Pointer<bg.OrtTypeInfo>,
            ffi.Pointer<ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>>,
          )
        >()(typeInfo, tensorInfoOut),
      );
      final tensorInfo = tensorInfoOut.value;
      if (tensorInfo == ffi.nullptr) return const [];

      OrtStatus.checkOrtStatus(
        api.GetDimensionsCount.asFunction<
          bg.OrtStatusPtr Function(
            ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>,
            ffi.Pointer<ffi.Size>,
          )
        >()(tensorInfo, countOut),
      );
      final count = countOut.value;
      if (count == 0) return const [];
      final dimensions = calloc<ffi.Int64>(count);
      try {
        OrtStatus.checkOrtStatus(
          api.GetDimensions.asFunction<
            bg.OrtStatusPtr Function(
              ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>,
              ffi.Pointer<ffi.Int64>,
              int,
            )
          >()(tensorInfo, dimensions, count),
        );
        return List<int>.unmodifiable([
          for (var index = 0; index < count; index++) dimensions[index],
        ]);
      } finally {
        calloc.free(dimensions);
      }
    } finally {
      calloc.free(countOut);
      calloc.free(tensorInfoOut);
    }
  }
}
