import 'dart:async';

import 'package:PiliPlus/pages/webdav/onedrive.dart';
import 'package:PiliPlus/pages/webdav/webdav.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:hive_ce/hive_ce.dart' show BoxEvent;

/// 设置自动同步服务（按 [Pref.autoSyncMode]）：
/// - [modeManual]：仅手动备份/恢复，无自动行为
/// - [modeOnChange]：setting / video 盒任一设置变更后防抖自动备份
/// - [modeScheduled]：按 [Pref.autoSyncInterval] 间隔定时自动备份
///
/// 自动备份静默执行（不弹 toast），失败仅在 debug 下输出日志；
/// 走当前 [Pref.syncMode]（WebDAV / OneDrive）对应的后端。
class SettingsSyncService {
  SettingsSyncService._internal();
  static final SettingsSyncService instance = SettingsSyncService._internal();

  static const modeManual = 'manual';
  static const modeOnChange = 'onChange';
  static const modeScheduled = 'scheduled';

  /// 变更防抖：连续修改设置（如拖动滑块）时合并为一次备份
  static const _changeDebounce = Duration(seconds: 5);

  Timer? _scheduledTimer;
  Timer? _debounceTimer;
  bool _syncing = false;

  /// 应用启动后调用一次（需在 GStorage.init 完成后）
  void init() {
    GStorage.setting.watch().listen(_onSettingEvent);
    GStorage.video.watch().listen((_) => _onSettingsChanged());
    _reconfigureTimer();
  }

  void _onSettingEvent(BoxEvent event) {
    final key = event.key;
    if (key == SettingBoxKey.autoSyncMode ||
        key == SettingBoxKey.autoSyncInterval) {
      // 自动同步配置变化：重排定时器，不视为业务设置变更
      _reconfigureTimer();
      return;
    }
    _onSettingsChanged();
  }

  void _onSettingsChanged() {
    if (Pref.autoSyncMode != modeOnChange) {
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_changeDebounce, () {
      _debounceTimer = null;
      _backupSilent();
    });
  }

  void _reconfigureTimer() {
    _scheduledTimer?.cancel();
    _scheduledTimer = null;
    if (Pref.autoSyncMode != modeScheduled) {
      return;
    }
    final minutes = Pref.autoSyncInterval;
    if (minutes <= 0) {
      return;
    }
    _scheduledTimer = Timer.periodic(Duration(minutes: minutes), (_) {
      _backupSilent();
    });
  }

  Future<void> _backupSilent() async {
    if (_syncing) {
      return;
    }
    _syncing = true;
    try {
      if (Pref.syncMode == 'onedrive') {
        await OneDrive().backup(silent: true);
      } else {
        await WebDav().backup(silent: true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('auto sync backup failed: $e');
    } finally {
      _syncing = false;
    }
  }
}
