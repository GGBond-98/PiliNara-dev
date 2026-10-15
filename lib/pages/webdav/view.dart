import 'dart:async';

import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/pages/webdav/onedrive.dart';
import 'package:PiliPlus/pages/webdav/webdav.dart';
import 'package:PiliPlus/services/settings_sync_service.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class WebDavSettingPage extends StatefulWidget {
  const WebDavSettingPage({
    super.key,
    this.showAppBar = true,
  });

  final bool showAppBar;

  @override
  State<WebDavSettingPage> createState() => _WebDavSettingPageState();
}

class _WebDavSettingPageState extends State<WebDavSettingPage> {
  static const _modeWebDav = 'webdav';
  static const _modeOneDrive = 'onedrive';

  static const _intervalOptions = [
    (label: '15分钟', minutes: 15),
    (label: '30分钟', minutes: 30),
    (label: '1小时', minutes: 60),
    (label: '6小时', minutes: 360),
    (label: '12小时', minutes: 720),
    (label: '每天', minutes: 1440),
  ];

  String _mode = Pref.syncMode == _modeOneDrive ? _modeOneDrive : _modeWebDav;
  String _autoSync = Pref.autoSyncMode;
  int _autoSyncInterval = Pref.autoSyncInterval;
  final _uriCtr = TextEditingController(text: Pref.webdavUri);
  final _usernameCtr = TextEditingController(text: Pref.webdavUsername);
  final _passwordCtr = TextEditingController(text: Pref.webdavPassword);
  final _directoryCtr = TextEditingController(text: Pref.webdavDirectory);
  final _odDirCtr = TextEditingController(text: Pref.onedriveDirectory);
  bool _obscureText = true;
  bool _odLogin = OneDrive().isLogin;

  @override
  void dispose() {
    _uriCtr.dispose();
    _usernameCtr.dispose();
    _passwordCtr.dispose();
    _directoryCtr.dispose();
    _odDirCtr.dispose();
    super.dispose();
  }

  Future<void> _backup() =>
      _mode == _modeWebDav ? WebDav().backup() : OneDrive().backup();

  Future<void> _restore() =>
      _mode == _modeWebDav ? WebDav().restore() : OneDrive().restore();

  Future<void> _startOdLogin() async {
    try {
      final info = await OneDrive().startDeviceLogin();
      if (!mounted) {
        return;
      }
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _DeviceLoginDialog(info: info),
      );
      if (result == 'ok') {
        setState(() => _odLogin = true);
        SmartDialog.showToast('登录成功');
      }
    } catch (e) {
      SmartDialog.showToast('发起登录失败: $e');
    }
  }

  Future<void> _odLogout() async {
    await OneDrive().logout();
    if (!mounted) {
      return;
    }
    setState(() => _odLogin = false);
    SmartDialog.showToast('已退出登录');
  }

  Future<void> _save() async {
    await GStorage.setting.putAll({
      SettingBoxKey.syncMode: _mode,
      SettingBoxKey.webdavUri: _uriCtr.text,
      SettingBoxKey.webdavUsername: _usernameCtr.text,
      SettingBoxKey.webdavPassword: _passwordCtr.text,
      SettingBoxKey.webdavDirectory: _directoryCtr.text,
      SettingBoxKey.onedriveDirectory: _odDirCtr.text.trim(),
    });
    if (_mode == _modeWebDav) {
      if (_uriCtr.text.isEmpty) {
        return;
      }
      try {
        final res = await WebDav().init();
        if (res.first) {
          SmartDialog.showToast('配置成功');
        } else {
          SmartDialog.showToast('配置失败: ${res.second}');
        }
      } catch (e) {
        SmartDialog.showToast('配置失败: $e');
      }
      return;
    }
    if (!OneDrive().isLogin) {
      SmartDialog.showToast('已保存，请点击「登录」完成授权');
      return;
    }
    try {
      final name = await OneDrive().init();
      SmartDialog.showToast(name.isEmpty ? '配置成功' : '配置成功（$name）');
    } catch (e) {
      SmartDialog.showToast('配置失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final showAppBar = widget.showAppBar;
    final padding = MediaQuery.viewPaddingOf(context);
    return SimpleScaffold(
      appBar: showAppBar ? AppBar(title: const Text('同步设置')) : null,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          ListView(
            padding: padding.copyWith(
              top: 20,
              left: 20 + (showAppBar ? padding.left : 0),
              right: 20 + (showAppBar ? padding.right : 0),
              bottom: padding.bottom + 100,
            ),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: _modeWebDav,
                    label: Text('WebDAV'),
                  ),
                  ButtonSegment(
                    value: _modeOneDrive,
                    label: Text('OneDrive'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selected) {
                  setState(() => _mode = selected.first);
                  GStorage.setting.put(SettingBoxKey.syncMode, _mode);
                },
              ),
              const SizedBox(height: 20),
              if (_mode == _modeWebDav) ...[
                TextField(
                  controller: _uriCtr,
                  decoration: const InputDecoration(
                    labelText: '地址',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _usernameCtr,
                  decoration: const InputDecoration(
                    labelText: '用户',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordCtr,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: '密码',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureText = !_obscureText),
                      icon: _obscureText
                          ? const Icon(Icons.visibility)
                          : const Icon(Icons.visibility_off),
                    ),
                  ),
                  obscureText: _obscureText,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _directoryCtr,
                  decoration: const InputDecoration(
                    labelText: '路径',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _odDirCtr,
                  decoration: const InputDecoration(
                    labelText: '保存路径',
                    helperText: 'OneDrive 内的文件夹名，默认 PiliNara',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      _odLogin ? Icons.cloud_done : Icons.cloud_off,
                      size: 20,
                      color: _odLogin
                          ? ColorScheme.of(context).primary
                          : ColorScheme.of(context).outline,
                    ),
                    const SizedBox(width: 6),
                    Text(_odLogin ? '已登录' : '未登录'),
                    const Spacer(),
                    TextButton(
                      onPressed: _odLogin ? _odLogout : _startOdLogin,
                      child: Text(_odLogin ? '退出登录' : '登录'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                          borderRadius: Style.mdRadius,
                        ),
                      ),
                      onPressed: _backup,
                      child: const Text('备份设置'),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                          borderRadius: Style.mdRadius,
                        ),
                      ),
                      onPressed: _restore,
                      child: const Text('恢复设置'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: SettingsSyncService.modeManual,
                    label: Text('手动同步'),
                  ),
                  ButtonSegment(
                    value: SettingsSyncService.modeOnChange,
                    label: Text('修改后同步'),
                  ),
                  ButtonSegment(
                    value: SettingsSyncService.modeScheduled,
                    label: Text('定时同步'),
                  ),
                ],
                selected: {_autoSync},
                onSelectionChanged: (selected) {
                  setState(() => _autoSync = selected.first);
                  GStorage.setting.put(SettingBoxKey.autoSyncMode, _autoSync);
                },
              ),
              const SizedBox(height: 8),
              Text(
                '自动同步静默执行：修改后同步在设置变更 5 秒后备份，'
                '定时同步按所选间隔备份',
                style: TextStyle(
                  color: ColorScheme.of(context).outline,
                  fontSize: 12,
                ),
              ),
              if (_autoSync == SettingsSyncService.modeScheduled) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final option in _intervalOptions)
                      ChoiceChip(
                        label: Text(option.label),
                        selected: _autoSyncInterval == option.minutes,
                        onSelected: (_) {
                          setState(() => _autoSyncInterval = option.minutes);
                          GStorage.setting.put(
                            SettingBoxKey.autoSyncInterval,
                            option.minutes,
                          );
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
          Positioned(
            right:
                kFloatingActionButtonMargin + (showAppBar ? padding.right : 0),
            bottom: kFloatingActionButtonMargin + padding.bottom,
            child: FloatingActionButton(
              onPressed: _save,
              child: const Icon(Icons.save),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceLoginDialog extends StatefulWidget {
  const _DeviceLoginDialog({required this.info});

  final DeviceLoginInfo info;

  @override
  State<_DeviceLoginDialog> createState() => _DeviceLoginDialogState();
}

class _DeviceLoginDialogState extends State<_DeviceLoginDialog> {
  Timer? _timer;
  String? _error;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      Duration(seconds: widget.info.interval),
      (_) => _poll(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling || _error != null) {
      return;
    }
    _polling = true;
    try {
      final result = await OneDrive().pollToken(widget.info);
      if (!mounted) {
        return;
      }
      if (result == null) {
        Navigator.of(context).pop('ok');
      } else if (result != 'pending') {
        setState(() => _error = result);
      }
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return AlertDialog(
      title: const Text('OneDrive 登录'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('请在任意设备的浏览器中打开：'),
          const SizedBox(height: 4),
          Text(
            info.url,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text('输入以下代码，并使用微软账号授权：'),
          const SizedBox(height: 4),
          Text(
            info.userCode,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: ColorScheme.of(context).error),
            )
          else
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('等待授权…'),
              ],
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Utils.copyText(info.url, toastText: '链接已复制'),
          child: const Text('复制链接'),
        ),
        TextButton(
          onPressed: () => Utils.copyText(info.userCode, toastText: '代码已复制'),
          child: const Text('复制代码'),
        ),
        TextButton(
          onPressed: () async {
            try {
              await launchUrl(
                Uri.parse(info.url),
                mode: LaunchMode.externalApplication,
              );
            } on Exception {
              SmartDialog.showToast('无法打开浏览器，请手动复制链接');
            }
          },
          child: const Text('打开链接'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop('cancel'),
          child: Text(
            '取消',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
      ],
    );
  }
}
