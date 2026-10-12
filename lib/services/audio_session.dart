import 'dart:io';

import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:audio_session/audio_session.dart';
import 'package:os_type/os_type.dart';

class AudioSessionHandler {
  late AudioSession session;
  bool _playInterrupted = false;

  Future<bool> setActive(bool active) {
    return session.setActive(
      active,
      // 鸿蒙：会话并发模式是「与其他应用同时播放」的唯一控制点（iOS 用
      // AVAudioSession 类别、Android 用焦点协商）。开启混音或有存活实例处于
      // 画中画（含小窗并行播放）时请求 concurrencyMixWithOthers，否则不传、
      // 回落到插件默认的 concurrencyPauseOthers，非鸿蒙平台行为与上游一致。
      ohosAudioConcurrencyMode:
          OS.isHarmony &&
              (Pref.mixWithOthers || PlPlayerController.anyPipInstance)
          ? AudioConcurrencyMode.concurrencyMixWithOthers
          : null,
    );
  }

  AudioSessionHandler() {
    initSession();
  }

  Future<void> _configureSession() async {
    if (Pref.mixWithOthers && Platform.isIOS) {
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        ),
      );
    } else {
      await session.configure(const AudioSessionConfiguration.music());
    }
  }

  Future<void> reconfigure() async {
    await session.setActive(false);
    await _configureSession();
  }

  Future<void> initSession() async {
    session = await AudioSession.instance;
    await _configureSession();

    session.interruptionEventStream.listen((event) {
      final playerStatus = PlPlayerController.getPlayerStatusIfExists();
      // final player = PlPlayerController.getInstance();
      if (event.begin) {
        if (playerStatus != PlayerStatus.playing) return;
        // if (!player.playerStatus.playing) return;
        switch (event.type) {
          case AudioInterruptionType.duck:
            PlPlayerController.instance?.handleDuck(true);
            break;
          case AudioInterruptionType.pause:
            // 接收到其他 App 播放音频的通知，如果允许了同时播放，就无视
            if (Pref.mixWithOthers) return;
            PlPlayerController.pauseIfExists(isInterrupt: true);
            // player.pause(isInterrupt: true);
            _playInterrupted = true;
            break;
          case AudioInterruptionType.unknown:
            // Android 的 unknown 对应永久失去音频焦点；iOS 的 unknown
            // 对应音频中断开始，不能复用 Android 的豁免逻辑。
            if (Platform.isAndroid && Pref.mixWithOthers) return;
            PlPlayerController.pauseIfExists(isInterrupt: true);
            // player.pause(isInterrupt: true);
            _playInterrupted = true;
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            PlPlayerController.instance?.handleDuck(false);
            break;
          case AudioInterruptionType.pause:
            if (_playInterrupted) PlPlayerController.playIfExists();
            //player.play();
            break;
          case AudioInterruptionType.unknown:
            break;
        }
        _playInterrupted = false;
      }
    });

    // 耳机拔出暂停
    session.becomingNoisyEventStream.listen((_) {
      PlPlayerController.pauseIfExists();
      // final player = PlPlayerController.getInstance();
      // if (player.playerStatus.playing) {
      //   player.pause();
      // }
    });
  }
}
