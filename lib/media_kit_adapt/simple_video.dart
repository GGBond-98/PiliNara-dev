import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 极简视频纹理渲染，移植自 Nara 所用 media_kit fork 的
/// `media_kit_video/lib/src/video/simple_video_texture.dart`。
///
/// 相对原版做了 cnoim/feat-ohos（media_kit 1.2.3）适配：
/// * 该分支没有 `PlayerStream.size`（`Stream<(int, int)>`），改为 `width`、
///   `height` 两条 `Stream<int?>`；
/// * `PlayerState.width` / `height` 变为可空 `int?`。
///
/// 渲染语义与原版一致：宽高未就绪时不显示纹理（避免露出 1px 的占位 surface），
/// 且因 `VideoController.rect` 只由渲染循环驱动、尺寸就绪时可能不触发，
/// 这里主动 `notifyListeners()` 强制重建。
class SimpleVideo extends StatefulWidget {
  final Color fill;
  final VideoController controller;
  final double? aspectRatio;
  final FilterQuality filterQuality;

  const SimpleVideo({
    super.key,
    this.fill = Colors.black,
    required this.controller,
    this.aspectRatio,
    this.filterQuality = FilterQuality.low,
  });

  @override
  State<SimpleVideo> createState() => SimpleVideoState();
}

class SimpleVideoState extends State<SimpleVideo> {
  late double _devicePixelRatio;
  int? _width;
  int? _height;
  late bool _visible;
  final List<StreamSubscription<int?>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    final player = widget.controller.player;
    _width = player.state.width;
    _height = player.state.height;
    _visible = (_width ?? 0) > 0 && (_height ?? 0) > 0;
    // --------------------------------------------------
    // Do not show the video frame until width & height are available.
    // Since [ValueNotifier<Rect?>] inside [VideoController] only gets updated by
    // the render loop (i.e. it will not fire when video's width & height are
    // not available etc.), it's important to handle this separately here.
    _subscriptions
      ..add(
        player.stream.width.listen((value) {
          _width = value;
          _updateVisible();
        }),
      )
      ..add(
        player.stream.height.listen((value) {
          _height = value;
          _updateVisible();
        }),
      );
    // --------------------------------------------------
  }

  void _updateVisible() {
    final visible = (_width ?? 0) > 0 && (_height ?? 0) > 0;
    if (_visible != visible) {
      _visible = visible;
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      widget.controller.rect.notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final ctr = widget.controller;
    return ListenableBuilder(
      listenable: Listenable.merge([ctr.id, ctr.rect]),
      builder: (context, _) {
        final id = ctr.id.value;
        final rect = ctr.rect.value;
        if (id != null && rect != null && _visible) {
          return SizedBox(
            width: widget.aspectRatio == null
                ? rect.width / _devicePixelRatio
                : rect.height / _devicePixelRatio * widget.aspectRatio!,
            height: rect.height / _devicePixelRatio,
            child: Stack(
              children: [
                Texture(textureId: id, filterQuality: widget.filterQuality),
                if (rect.width <= 1.0 && rect.height <= 1.0)
                  Positioned.fill(child: ColoredBox(color: widget.fill)),
              ],
            ),
          );
        }
        return const SizedBox();
      },
    );
  }
}
