import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../enums/precise_ref_type.dart';
import '../../utils/app_logger.dart';
import '../../utils/inpaint_mask_utils.dart';
import '../../utils/nai_resolution_adapter.dart';
import '../../utils/nai_api_utils.dart';
import '../../utils/prompt_semantics_utils.dart';
import '../../../data/models/image/image_params.dart';

typedef EncodeVibeFn =
    Future<String> Function(
      Uint8List image, {
      required String model,
      double informationExtracted,
    });

class NAIImageRequestBuildResult {
  NAIImageRequestBuildResult({
    required this.seed,
    required this.effectivePrompt,
    required this.effectiveNegativePrompt,
    required this.requestParameters,
    required this.requestData,
    this.vibeEncodingMap = const {},
    this.normalizedSourceImageBytes,
    this.inpaintMaskArtifacts,
  });

  final int seed;
  final String effectivePrompt;
  final String effectiveNegativePrompt;
  final Map<String, dynamic> requestParameters;
  final Map<String, dynamic> requestData;
  final Map<int, String> vibeEncodingMap;
  final Uint8List? normalizedSourceImageBytes;
  final NovelAiInpaintMaskArtifacts? inpaintMaskArtifacts;
}

class NAIImageRequestBuilder {
  NAIImageRequestBuilder({
    required this.params,
    required this.encodeVibe,
    List<PreciseReference>? preciseReferences,
  }) : _preciseReferences =
           (preciseReferences ??
                   (params.isV45Model
                       ? params.preciseReferences
                       : <PreciseReference>[]))
               .where((reference) => reference.enabled)
               .toList(growable: false);

  final ImageParams params;
  final EncodeVibeFn encodeVibe;
  final List<PreciseReference> _preciseReferences;

  Map<String, dynamic> buildBaseParameters({
    required String sampler,
    required int seed,
    required String effectiveNegativePrompt,
    required bool isStream,
  }) {
    final requestParameters = <String, dynamic>{
      'params_version': params.paramsVersion,
      'width': params.width,
      'height': params.height,
      'scale': NAIApiUtils.toJsonNumber(params.scale),
      'sampler': sampler,
      'steps': params.steps,
      'n_samples': params.nSamples,
      'ucPreset': params.ucPreset,
      'qualityToggle': params.qualityToggle,
      'autoSmea': false,
      'dynamic_thresholding': params.isV3Model && params.decrisp,
      'controlnet_strength': 1,
      'legacy': false,
      'add_original_image': params.action == ImageGenerationAction.infill
          ? false
          : params.addOriginalImage,
      'cfg_rescale': NAIApiUtils.toJsonNumber(params.cfgRescale),
      'noise_schedule': params.isV4Model
          ? (params.noiseSchedule == 'native' ? 'karras' : params.noiseSchedule)
          : params.noiseSchedule,
      'normalize_reference_strength_multiple': true,
      'inpaintImg2ImgStrength': NAIApiUtils.toJsonNumber(
        params.inpaintStrength,
      ),
      'seed': seed,
      'negative_prompt': effectiveNegativePrompt,
      'deliberate_euler_ancestral_bug': false,
      'prefer_brownian': true,
      if (isStream) 'stream': 'msgpack',
    };

    requestParameters['skip_cfg_above_sigma'] = params.varietyPlus
        ? 58.0 * sqrt(4.0 * (params.width / 8) * (params.height / 8) / 63232)
        : null;

    if (!params.isV4Model) {
      final resolution = params.width * params.height;
      final autoSmea = resolution > 1024 * 1024;

      final isDdim = params.sampler.contains('ddim');
      final effectiveSmea = isDdim
          ? false
          : (params.smeaAuto ? autoSmea : params.smea);
      final effectiveSmeaDyn = isDdim
          ? false
          : (params.smeaAuto ? false : params.smeaDyn);

      requestParameters['sm'] = effectiveSmea;
      requestParameters['sm_dyn'] = effectiveSmeaDyn;
      requestParameters['uc'] = effectiveNegativePrompt;
    }

    return requestParameters;
  }

  void buildV4Parameters(
    Map<String, dynamic> requestParameters, {
    required String effectivePrompt,
    required String effectiveNegativePrompt,
  }) {
    requestParameters['params_version'] = 3;
    requestParameters['use_coords'] = params.useCoords;
    requestParameters['legacy_v3_extend'] = false;
    requestParameters['legacy_uc'] = false;

    final charCaptions = <Map<String, dynamic>>[];
    final negativeCharCaptions = <Map<String, dynamic>>[];
    final characterPrompts = <Map<String, dynamic>>[];

    for (final char in params.characters) {
      double x = 0, y = 0;
      if (char.position != null && char.position!.length >= 2) {
        final letter = char.position![0].toUpperCase();
        final digit = char.position![1];
        x = 0.5 + 0.2 * (letter.codeUnitAt(0) - 'C'.codeUnitAt(0));
        y = 0.5 + 0.2 * (int.tryParse(digit) ?? 3) - 0.5 - 0.4;
        x = x.clamp(0.1, 0.9);
        y = y.clamp(0.1, 0.9);
      } else if (char.positionX != null && char.positionY != null) {
        x = char.positionX!;
        y = char.positionY!;
      }

      charCaptions.add({
        'centers': [
          {'x': x, 'y': y},
        ],
        'char_caption': char.prompt,
      });

      negativeCharCaptions.add({
        'centers': [
          {'x': x, 'y': y},
        ],
        'char_caption': char.negativePrompt,
      });

      characterPrompts.add({
        'center': {'x': x, 'y': y},
        'prompt': char.prompt,
        'uc': char.negativePrompt,
        'enabled': true,
      });
    }

    requestParameters['v4_prompt'] = {
      'caption': {
        'base_caption': effectivePrompt,
        'char_captions': charCaptions,
      },
      'use_coords': params.useCoords,
      'use_order': true,
    };

    requestParameters['v4_negative_prompt'] = {
      'caption': {
        'base_caption': effectiveNegativePrompt,
        'char_captions': negativeCharCaptions,
      },
      'legacy_uc': false,
    };

    requestParameters['characterPrompts'] = characterPrompts;
  }

  Future<Map<int, String>> buildVibeTransferParameters(
    Map<String, dynamic> requestParameters, {
    required bool isStream,
  }) async {
    final vibeEncodingMap = <int, String>{};
    if (_preciseReferences.isNotEmpty) {
      // NovelAI 官方说明 Precise Reference 与 Vibe Transfer 不兼容，
      // 因此两者同时存在时优先保留 Precise Reference，避免结果偏离网页端。
      return vibeEncodingMap;
    }
    if (params.action == ImageGenerationAction.infill) {
      // NovelAI 的 infill 请求会直接携带 image + mask，继续附带
      // Vibe Transfer payload 会触发服务端 500，因此局部重绘时跳过。
      return vibeEncodingMap;
    }
    if (!params.hasVibeReferencesV4) {
      return vibeEncodingMap;
    }

    requestParameters['normalize_reference_strength_multiple'] =
        params.normalizeVibeStrength;

    if (!isStream) {
      final allEncodings = <String>[];
      final allStrengths = <double>[];
      final allInfoExtracted = <double>[];

      for (int i = 0; i < params.vibeReferencesV4.length; i++) {
        final vibe = params.vibeReferencesV4[i];
        if (!vibe.enabled) {
          continue;
        }

        if (vibe.vibeEncoding.isNotEmpty) {
          allEncodings.add(vibe.vibeEncoding);
          allStrengths.add(vibe.strength);
          allInfoExtracted.add(vibe.infoExtracted);
          vibeEncodingMap[i] = vibe.vibeEncoding;
          AppLogger.d('V4 Vibe: Using pre-encoded vibe at index $i', 'ImgGen');
        } else if (vibe.rawImageData != null) {
          AppLogger.d(
            'V4 Vibe: Encoding rawImage at index $i (2 Anlas)...',
            'ImgGen',
          );
          try {
            final encoding = await encodeVibe(
              vibe.rawImageData!,
              model: params.model,
              informationExtracted: vibe.infoExtracted,
            );
            if (encoding.isNotEmpty) {
              allEncodings.add(encoding);
              allStrengths.add(vibe.strength);
              allInfoExtracted.add(vibe.infoExtracted);
              vibeEncodingMap[i] = encoding;
              AppLogger.d(
                'V4 Vibe: Encoded raw image at index $i successfully, hash length: ${encoding.length}',
                'ImgGen',
              );
            } else {
              AppLogger.w(
                'V4 Vibe: Failed to encode raw image at index $i (empty result)',
                'ImgGen',
              );
            }
          } catch (e) {
            AppLogger.e(
              'V4 Vibe: Failed to encode raw image at index $i: $e',
              'ImgGen',
            );
          }
        }
      }

      if (allEncodings.isNotEmpty) {
        requestParameters['reference_image_multiple'] = allEncodings;
        requestParameters['reference_strength_multiple'] = allStrengths;
        requestParameters['reference_information_extracted_multiple'] =
            allInfoExtracted;

        AppLogger.d(
          'V4 Vibe Transfer: ${vibeEncodingMap.length} vibes with encodings',
          'ImgGen',
        );
      }

      return vibeEncodingMap;
    }

    final encodedVibes = params.vibeReferencesV4
        .where((v) => v.enabled)
        .where((v) => v.vibeEncoding.isNotEmpty)
        .toList();
    final rawImageVibes = params.vibeReferencesV4
        .where((v) => v.enabled)
        .where((v) => v.vibeEncoding.isEmpty && v.rawImageData != null)
        .toList();

    final allEncodings = <String>[];
    final allStrengths = <double>[];
    final allInfoExtracted = <double>[];

    for (final vibe in encodedVibes) {
      allEncodings.add(vibe.vibeEncoding);
      allStrengths.add(vibe.strength);
      allInfoExtracted.add(vibe.infoExtracted);
    }

    if (rawImageVibes.isNotEmpty) {
      AppLogger.d(
        'V4 Vibe (Stream): Encoding ${rawImageVibes.length} raw images (2 Anlas each)...',
        'ImgGen',
      );
      for (final vibe in rawImageVibes) {
        try {
          final encoding = await encodeVibe(
            vibe.rawImageData!,
            model: params.model,
            informationExtracted: vibe.infoExtracted,
          );
          if (encoding.isNotEmpty) {
            allEncodings.add(encoding);
            allStrengths.add(vibe.strength);
            allInfoExtracted.add(vibe.infoExtracted);
            AppLogger.d(
              'V4 Vibe (Stream): Encoded raw image successfully',
              'ImgGen',
            );
          } else {
            AppLogger.w(
              'V4 Vibe (Stream): Failed to encode raw image (empty result)',
              'ImgGen',
            );
          }
        } catch (e) {
          AppLogger.e(
            'V4 Vibe (Stream): Failed to encode raw image: $e',
            'ImgGen',
          );
        }
      }
    }

    if (allEncodings.isNotEmpty) {
      requestParameters['reference_image_multiple'] = allEncodings;
      requestParameters['reference_strength_multiple'] = allStrengths;
      requestParameters['reference_information_extracted_multiple'] =
          allInfoExtracted;

      AppLogger.d(
        'V4 Vibe Transfer (Stream): ${encodedVibes.length} encoded + ${rawImageVibes.length} raw = ${allEncodings.length} total vibes',
        'ImgGen',
      );
    }

    return vibeEncodingMap;
  }

  Future<void> buildPreciseReferenceParameters(
    Map<String, dynamic> requestParameters,
  ) async {
    if (_preciseReferences.isEmpty) {
      return;
    }

    final referenceImages = <String>[];
    for (final reference in _preciseReferences) {
      final imageBytes =
          NAIApiUtils.isKnownNormalizedPreciseReferencePng(reference.image)
          ? reference.image
          : await NAIApiUtils.ensurePngFormatAsync(reference.image);
      referenceImages.add(base64Encode(imageBytes));
    }

    requestParameters['normalize_reference_strength_multiple'] = true;
    requestParameters['director_reference_images'] = referenceImages;
    requestParameters['director_reference_descriptions'] = _preciseReferences
        .map(
          (r) => {
            'caption': {
              'base_caption': r.type.toApiString(),
              'char_captions': [],
            },
            'legacy_uc': false,
          },
        )
        .toList();
    requestParameters['director_reference_information_extracted'] =
        _preciseReferences.map((_) => 1).toList();
    requestParameters['director_reference_strength_values'] = _preciseReferences
        .map((r) => r.strength)
        .toList();
    requestParameters['director_reference_secondary_strength_values'] =
        _preciseReferences.map((r) => 1.0 - r.fidelity).toList();
  }

  Future<Uint8List> _normalizeRequestSourceImage(Uint8List sourceImage) async {
    return await NaiResolutionAdapter.normalizeImageForRequestAsync(
          sourceImage,
          targetWidth: params.width,
          targetHeight: params.height,
        ) ??
        sourceImage;
  }

  Future<NAIImageRequestBuildResult> build({
    required String sampler,
    bool isStream = false,
  }) async {
    if (sampler.isEmpty) {
      throw ArgumentError.value(sampler, 'sampler', 'Sampler cannot be empty');
    }

    final seed = params.seed == -1 ? Random().nextInt(4294967295) : params.seed;

    final promptSemantics = buildPromptSemanticsSnapshot(
      prompt: params.prompt,
      negativePrompt: params.negativePrompt,
      model: params.model,
      qualityToggle: params.qualityToggle,
      ucPreset: params.ucPreset,
    );
    final effectivePrompt = promptSemantics.effectivePrompt;
    final effectiveNegativePrompt = promptSemantics.effectiveNegativePrompt;

    final requestParameters = buildBaseParameters(
      sampler: sampler,
      seed: seed,
      effectiveNegativePrompt: effectiveNegativePrompt,
      isStream: isStream,
    );
    Uint8List? normalizedSourceImageBytes;
    NovelAiInpaintMaskArtifacts? inpaintMaskArtifacts;

    if (params.isV4Model) {
      buildV4Parameters(
        requestParameters,
        effectivePrompt: effectivePrompt,
        effectiveNegativePrompt: effectiveNegativePrompt,
      );
    }

    if (params.action == ImageGenerationAction.img2img &&
        params.sourceImage != null) {
      final normalizedSource = await _normalizeRequestSourceImage(
        params.sourceImage!,
      );
      normalizedSourceImageBytes = normalizedSource;
      requestParameters['image'] = base64Encode(normalizedSource);
      requestParameters['strength'] = params.strength;
      requestParameters['noise'] = params.noise;
    }

    if (params.action == ImageGenerationAction.infill &&
        params.sourceImage != null &&
        params.maskImage != null) {
      final maskArtifactsFuture =
          InpaintMaskUtils.prepareNovelAiInpaintMaskArtifactsAsync(
            params.maskImage!,
            targetWidth: params.width,
            targetHeight: params.height,
            closingIterations: params.inpaintMaskClosingIterations,
            expansionIterations: params.inpaintMaskExpansionIterations,
          );
      final normalizedSourceFuture = _normalizeRequestSourceImage(
        params.sourceImage!,
      );
      final normalizedSource = await normalizedSourceFuture;
      inpaintMaskArtifacts = await maskArtifactsFuture;
      normalizedSourceImageBytes = normalizedSource;
      requestParameters['image'] = base64Encode(normalizedSource);
      requestParameters['mask'] = base64Encode(
        inpaintMaskArtifacts.requestMaskBytes,
      );
      requestParameters['strength'] = NAIApiUtils.toJsonNumber(params.strength);
      requestParameters['noise'] = NAIApiUtils.toJsonNumber(params.noise);
    }

    final vibeEncodingMap = await buildVibeTransferParameters(
      requestParameters,
      isStream: isStream,
    );

    await buildPreciseReferenceParameters(requestParameters);

    final requestData = <String, dynamic>{
      'input': effectivePrompt,
      'model': params.model,
      'action': params.action.value,
      'parameters': requestParameters,
      'use_new_shared_trial': true,
    };

    return NAIImageRequestBuildResult(
      seed: seed,
      effectivePrompt: effectivePrompt,
      effectiveNegativePrompt: effectiveNegativePrompt,
      requestParameters: requestParameters,
      requestData: requestData,
      vibeEncodingMap: vibeEncodingMap,
      normalizedSourceImageBytes: normalizedSourceImageBytes,
      inpaintMaskArtifacts: inpaintMaskArtifacts,
    );
  }
}
