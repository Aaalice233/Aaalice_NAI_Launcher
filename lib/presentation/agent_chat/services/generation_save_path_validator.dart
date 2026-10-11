import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/harness_types.dart';
import 'defined_agent_tool.dart';
import 'generated_image_export_writer.dart';
import 'generation_save_path_template.dart';
import 'generation_workspace_path_resolver.dart';

/// v4 不会生成全零随机位，样本路径因此撞不上真实目标。
const String _sampleImageId = '00000000-0000-4000-8000-000000000000';

/// 调用方给出的 save_path 在付费提交前校验并定为绝对路径，生成与放大共用。
final class GenerationSavePathValidator {
  GenerationSavePathValidator({
    required GenerationWorkspacePathResolver pathResolver,
    required GeneratedImageExportWriter exportWriter,
  }) : _pathResolver = pathResolver,
       _exportWriter = exportWriter;

  final GenerationWorkspacePathResolver _pathResolver;
  final GeneratedImageExportWriter _exportWriter;

  /// 值为 null 表示调用方没给模板；[total] 是这次提交会产出的图片总数。
  Future<HarnessResult<String?, AgentToolResult>> validate(
    Object? requested, {
    required int total,
  }) async {
    if (requested != null && requested is! String) {
      return err(
        agentToolError(
          'invalid_save_path',
          'Parameter "save_path" must be a string file target.',
        ),
      );
    }
    final template = (requested as String?)?.trim() ?? '';
    if (template.isEmpty) return ok(null);
    if (GenerationSavePathTemplate.hasPlaceholderInDirectory(template)) {
      return err(
        agentToolError(
          'invalid_save_path',
          'save_path placeholders are only allowed in the file name.',
        ),
      );
    }
    if (total > 1 && !GenerationSavePathTemplate.hasPlaceholder(template)) {
      return err(
        agentToolError(
          'invalid_save_path',
          'This submission produces $total images, so the save_path file name '
              'must contain {index}, {seed} or {id}.',
        ),
      );
    }
    final absolute = (await _pathResolver.env.absolutePath(
      template,
    )).valueOrNull;
    if (absolute == null) return err(_notPermitted);
    // 模板本身不是文件名，展开一份样本才能校验扩展名、作用域和占位情况。
    final sample = GenerationSavePathTemplate.expand(
      absolute,
      index: 1,
      total: total,
      seed: 0,
      id: _sampleImageId,
    );
    final failure = (await _exportWriter.validate(
      sample,
      mimeType: 'image/png',
    )).errorOrNull;
    return failure == null
        ? ok(absolute.replaceAll(r'\', '/'))
        : err(_rejectionFor(failure.kind));
  }

  static final AgentToolResult _notPermitted = agentToolError(
    'save_path_not_permitted',
    'save_path is outside the permitted file scope.',
  );

  static AgentToolResult _rejectionFor(GeneratedImageExportFailureKind kind) =>
      switch (kind) {
        GeneratedImageExportFailureKind.invalidTarget => agentToolError(
          'invalid_save_path',
          'save_path must identify a file, not a directory.',
        ),
        GeneratedImageExportFailureKind.extensionMismatch => agentToolError(
          'invalid_save_path',
          'save_path must use the .png extension.',
        ),
        GeneratedImageExportFailureKind.outsideScope => _notPermitted,
        GeneratedImageExportFailureKind.exists => agentToolError(
          'save_path_exists',
          'save_path already exists; generated images are never overwritten.',
        ),
        GeneratedImageExportFailureKind.checkFailed => agentToolError(
          'save_path_unavailable',
          'save_path could not be checked safely.',
        ),
        _ => agentToolError(
          'save_path_unavailable',
          'save_path could not be validated.',
        ),
      };
}
