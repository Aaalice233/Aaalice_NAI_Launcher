/// 参数分布统计的生成参数；[key] 即导出与统计缓存里的 parameterName
///
/// SMEA 与 SMEA DYN 不在其中：库里把未设置记成关，分不出真实取值。
enum GalleryParameter {
  sampler('sampler'),
  steps('steps'),
  scale('scale'),
  noiseSchedule('noise_schedule'),
  cfgRescale('cfg_rescale');

  const GalleryParameter(this.key);

  final String key;
}
