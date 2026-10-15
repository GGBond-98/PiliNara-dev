import 'package:PiliPlus/harmony_adapt/harmony_channel.dart';
import 'package:PiliPlus/models/common/harmony/hds_material_level.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/widgets/slider_dialog.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:os_type/os_type.dart';

List<SettingsModel> get experimentalSettings => [
  SwitchModel(
    title: '鸿蒙沉浸光感导航栏',
    subtitle: '仅鸿蒙6.1及以上支持，侧边栏下不显示',
    leading: const Icon(Icons.water_drop_outlined),
    setKey: SettingBoxKey.enableHdsBar,
    defaultVal: false,
    onChanged: (_) => SmartDialog.showToast("重启生效"),
  ),
  if (OS.isHarmony)
    PopupModel(
      title: '沉浸光感导航栏材质',
      leading: const Icon(Icons.water_drop_outlined),
      value: () => Pref.hdsTabMaterialLevel,
      items: HdsMaterialLevel.values,
      onSelected: (value, setState) {
        GStorage.setting
            .put(SettingBoxKey.hdsTabMaterialLevel, value.index)
            .whenComplete(() {
          setState();
          HarmonyChannel.setTabMaterialLevel(value);
        });
      },
    ),
  SwitchModel(
    title: '鸿蒙沉浸光感顶栏',
    subtitle: '鸿蒙6.1以上支持，鸿蒙7以上完整效果\n侧边栏下不显示，不支持调节强度',
    leading: const Icon(Icons.blur_on_outlined),
    setKey: SettingBoxKey.enableHdsTopBar,
    defaultVal: false,
    onChanged: (_) => SmartDialog.showToast("重启生效"),
  ),
  if (OS.isHarmony)
    SwitchModel(
      title: '智感握持侧边栏',
      subtitle: '横屏侧边栏随握持手自动切换左右，需设备支持',
      leading: const Icon(Icons.back_hand_outlined),
      setKey: SettingBoxKey.enableSmartGripSidebar,
      defaultVal: false,
      onChanged: (value) {
        if (value) {
          HarmonyChannel.startGripSidebar();
        } else {
          HarmonyChannel.stopGripSidebar();
          // 关闭后恢复默认左侧
          Get.find<MainController>().gripSideBarRight.value = false;
        }
      },
    ),
  const SwitchModel(
    title: '显示实际百分比音量',
    subtitle: '适配鸿蒙音量调节步进',
    leading: Icon(Icons.science_outlined),
    setKey: SettingBoxKey.showActualVolume,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '点击状态栏快速回顶',
    subtitle: '关闭后除部分原生支持界面，不再响应状态栏点击',
    leading: Icon(Icons.vertical_align_top_outlined),
    setKey: SettingBoxKey.enableStatusBarTapToTop,
    defaultVal: false,
  ),
  SwitchModel(
    title: '首页一镜到底动画',
    subtitle: '仅支持首页的视频卡片',
    leading: const Icon(Icons.motion_photos_on_outlined),
    setKey: SettingBoxKey.enableHeroCoverAnimation,
    defaultVal: false,
    onChanged: (_) => SmartDialog.showToast("建议重启以应用更改"),
  ),
  if (OS.isHarmony)
    const SwitchModel(
      title: '展开延续全屏动画',
      subtitle: '外屏全屏时展开进入内屏，全屏延续且视频以扩张动画铺满内屏\n点击开关动画，长按调节动画时长；关闭则无动画直接延续全屏',
      leading: Icon(Icons.open_in_full_outlined),
      setKey: SettingBoxKey.unfoldExpandFullScreen,
      defaultVal: true,
      onLongPress: showUnfoldAnimDurationDialog,
    ),
  NormalModel(
    title: '应用接续',
    subtitle: '相同华为用户播放视频可在不同设备中快速流转视频。（始终开启）',
    leading: const Icon(Icons.devices_other),
    getTrailing: (theme) => IgnorePointer(
      child: Transform.scale(
        scale: 0.8,
        alignment: Alignment.centerRight,
        child: Switch(
          value: true,
          onChanged: (_) {},
          thumbIcon: WidgetStateProperty.all(
            const Icon(Icons.lock_outline_rounded),
          ),
        ),
      ),
    ),
  ),
    NormalModel(
    title: '后台下载离线缓存视频',
    subtitle: '接入鸿蒙后台任务，切换至后台不中断离线缓存视频下载（始终开启）',
    leading: const Icon(Icons.downloading),
    getTrailing: (theme) => IgnorePointer(
      child: Transform.scale(
        scale: 0.8,
        alignment: Alignment.centerRight,
        child: Switch(
          value: true,
          onChanged: (_) {},
          thumbIcon: WidgetStateProperty.all(
            const Icon(Icons.lock_outline_rounded),
          ),
        ),
      ),
    ),
  ),
];

/// 长按「展开延续全屏动画」开关弹出滑动条，调节扩张动画时长
Future<void> showUnfoldAnimDurationDialog(BuildContext context) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('展开动画时长'),
      min: 200,
      max: 2000,
      divisions: 36,
      precise: 0,
      suffix: 'ms',
      value: Pref.unfoldExpandAnimDuration.toDouble().clamp(200, 2000).toDouble(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.unfoldExpandAnimDuration,
      res.toInt(),
    );
    SmartDialog.showToast('展开动画时长：${res.toInt()} ms');
  }
}