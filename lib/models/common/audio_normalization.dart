import 'dart:io' show Platform;
import 'dart:math' show min;

import 'package:PiliPlus/models/video/play/url.dart' show Volume;
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:os_type/os_type.dart';

enum AudioNormalization {
  disable('禁用'),
  // ref https://github.com/KRTirtho/spotube/commit/da10ab2e291d4ba4d3082b9a6ae535639fb8f1b7
  dynaudnorm('预设 dynaudnorm', 'dynaudnorm=g=5:f=250:r=0.9:p=0.5'),
  loudnorm('预设 loudnorm', 'loudnorm=I=-16:LRA=11:TP=-1.5'),
  custom('自定义参数'),
  ;

  final String title;
  final String param;
  const AudioNormalization(this.title, [this.param = '']);

  static String getTitleFromConfig(String config) => switch (config) {
    '0' => disable.title,
    '1' => dynaudnorm.title,
    '2' => loudnorm.title,
    _ => config,
  };

  static String getParamFromConfig(String config) => switch (config) {
    '0' => disable.param,
    '1' => dynaudnorm.param,
    '2' => loudnorm.param,
    _ => config,
  };

  static final loudnormRegExp = RegExp('loudnorm=([^,]+)');

  static String parse(Volume? volume, String param) {
    if (volume != null && volume.isNotEmpty) {
      return param.replaceFirstMapped(
        loudnormRegExp,
        (i) =>
            'loudnorm=${volume.format(
              Map.fromEntries(
                i.group(1)!.split(':').map((item) {
                  final parts = item.split('=');
                  return MapEntry(parts[0].toLowerCase(), num.parse(parts[1]));
                }),
              ),
            )}',
      );
    } else {
      return param.replaceFirst(
        loudnormRegExp,
        AudioNormalization.getParamFromConfig(Pref.fallbackNormalization),
      );
    }
  }
}

mixin AudioNormalizationMixin {
  late final _audioNormalization = Pref.audioNormalization;
  // Android：lavfi-complex 动态滤镜（dynaudnorm/loudnorm）完整生效。
  // 鸿蒙：libmpv（libmpv-ohos-build）的 FFmpeg 为 --disable-everything
  // 白名单构建，不含 dynaudnorm/loudnorm，动态滤镜图创建失败会直接
  // 导致视频无法加载；改走「B 站实测响度 + volume 滤镜」静态增益
  // （_ohosStaticGainExtras）。待 libmpv 补编滤镜后可恢复动态归一。
  late final enableAudioNormalization =
      (Platform.isAndroid || OS.isHarmony) && _audioNormalization != '0';
  late final _param = AudioNormalization.getParamFromConfig(
    _audioNormalization,
  );

  static const _kNormalizationKey = 'lavfi-complex';

  Map<String, String>? audioFilterExtras(
    Volume? volume, {
    Map<String, String>? map,
  }) {
    if (!enableAudioNormalization) return map;
    if (OS.isHarmony) {
      return _ohosStaticGainExtras(volume, map: map);
    }
    var audioNormalization = AudioNormalization.parse(volume, _param);
    if (audioNormalization.isEmpty) return map;
    audioNormalization = '"[aid1] $audioNormalization [ao]"';
    if (map != null) {
      map[_kNormalizationKey] = audioNormalization;
      return map;
    }
    return {_kNormalizationKey: audioNormalization};
  }

  /// 鸿蒙静态增益：libmpv 缺 dynaudnorm/loudnorm 滤镜，无法动态归一。
  /// 退而求其次：按 B 站下发的实测响度把整条音轨增益到目标响度
  /// （达成跨视频音量一致），并以实测真峰值封顶防止削波。
  /// 实测/目标字段缺失（响度、峰值恒为负，>=0 视为未下发）或
  /// 增益幅度过小（<0.5dB）时不挂滤镜。
  Map<String, String>? _ohosStaticGainExtras(
    Volume? volume, {
    Map<String, String>? map,
  }) {
    if (volume == null || !volume.isNotEmpty) return map;
    final measuredI = volume.measuredI;
    final measuredTp = volume.measuredTp;
    if (measuredI >= 0 || measuredTp >= 0) return map;
    // 目标值缺省时用 loudnorm 预设（I=-16 LUFS，TP=-1.5 dBTP）
    final targetI = volume.targetI == 0 ? -16.0 : volume.targetI;
    final targetTp = volume.targetTp == 0 ? -1.5 : volume.targetTp;
    final gain = min(targetI - measuredI, targetTp - measuredTp);
    if (gain.abs() < 0.5) return map;
    final filter = '"[aid1] volume=${gain.toStringAsFixed(1)}dB [ao]"';
    if (map != null) {
      map[_kNormalizationKey] = filter;
      return map;
    }
    return {_kNormalizationKey: filter};
  }
}
