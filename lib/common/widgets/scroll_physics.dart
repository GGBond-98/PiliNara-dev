import 'package:PiliPlus/common/widgets/gesture/horizontal_drag_gesture_recognizer.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/gestures.dart' show HorizontalDragGestureRecognizer;
import 'package:material_ui/material_ui.dart';
import 'package:os_type/os_type.dart';

Widget tabBarView({
  required List<Widget> children,
  TabController? controller,
  HitTestBehavior hitTestBehavior = .opaque,
  ScrollPhysics? physics,
}) => RawGestureDetector(
  behavior: hitTestBehavior,
  // CustomHorizontalDragGestureRecognizer 把 runtimeType 覆盖成了
  // HorizontalDragGestureRecognizer（上游为了顶替 Scrollable 内置识别器），
  // RawGestureDetector 在 debug 下断言「实例 runtimeType == map 的 key」，
  // 因此这里必须以 HorizontalDragGestureRecognizer 为 key，否则 debug 包首页直接红屏
  gestures: {
    HorizontalDragGestureRecognizer:
        GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
          CustomHorizontalDragGestureRecognizer.new,
          (_) {},
        ),
  },
  child: TabBarView(
    controller: controller,
    physics: physics ?? tabBarScrollPhysics,
    children: children,
  ),
);

SpringDescription kSpringDescription = _customSpringDescription();

SpringDescription _customSpringDescription() {
  final List<double> springDescription = Pref.springDescription;
  return SpringDescription(
    mass: springDescription[0],
    stiffness: springDescription[1],
    damping: springDescription[2],
  );
}

const tabBarScrollPhysics = _TabBarViewScrollPhysics();

class _TabBarViewScrollPhysics extends ClampingScrollPhysics {
  const _TabBarViewScrollPhysics({super.parent});

  @override
  _TabBarViewScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _TabBarViewScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => kSpringDescription;
}

const homeTabBarScrollPhysics = _HomeTabBarViewScrollPhysics();

/// 首页 tabBarView 专用：加长切换 tab 所需的滑动距离。
///
/// TabBarView 固定以 PageScrollPhysics.applyTo(传入物理) 组合，
/// PageScrollPhysics._getTargetPixels 在释放速度超过 tolerance.velocity
/// （框架默认约 20/dpr px/s，几乎任何抬手都会超过）时，会给目标页加上
/// ±0.5 的偏置再取整——因此小幅拖动或轻微甩动即可翻页，导致首页
/// 左右滑很容易误切到热门/分区。
///
/// 本类通过覆写 toleranceFor 把速度阈值提高到 800 px/s：
/// 低于 800 px/s 的抬手不再获得偏置，必须拖过半屏（round 阈值）才切换；
/// 明显用力的甩动仍可直接翻页。spring / 边界行为沿用
/// [_TabBarViewScrollPhysics]；距离容差保持框架默认值（1/dpr），
/// 不影响弹簧动画的停止精度。
class _HomeTabBarViewScrollPhysics extends _TabBarViewScrollPhysics {
  const _HomeTabBarViewScrollPhysics({super.parent});

  @override
  _HomeTabBarViewScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _HomeTabBarViewScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Tolerance toleranceFor(ScrollMetrics metrics) {
    return Tolerance(
      velocity: 800,
      distance: 1.0 / metrics.devicePixelRatio,
    );
  }
}

mixin ReloadMixin {
  late bool reload = false;
}

class ReloadScrollPhysics extends AlwaysScrollableScrollPhysics {
  const ReloadScrollPhysics({super.parent, required this.controller});

  final ReloadMixin controller;

  @override
  ReloadScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ReloadScrollPhysics(
      parent: buildParent(ancestor),
      controller: controller,
    );
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    if (controller.reload) {
      controller.reload = false;
      return 0;
    }
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}

final platformClampingPhysics = PlatformUtils.isDarwin || OS.isHarmony
    ? const BouncingScrollPhysicsExt()
    : const ClampingScrollPhysics();

final platformAlwaysClampingPhysics = PlatformUtils.isDarwin || OS.isHarmony
    ? const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysicsExt())
    : const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics());

class BouncingScrollPhysicsExt extends BouncingScrollPhysics
    with ClampingBoundaryMixin {
  const BouncingScrollPhysicsExt({super.parent});

  @override
  BouncingScrollPhysicsExt applyTo(ScrollPhysics? ancestor) {
    return BouncingScrollPhysicsExt(parent: buildParent(ancestor));
  }
}

/// [ClampingScrollPhysics.applyBoundaryConditions]
mixin ClampingBoundaryMixin on ScrollPhysics {
  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.pixels &&
        position.pixels <= position.minScrollExtent) {
      // Underscroll.
      return value - position.pixels;
    }
    if (position.maxScrollExtent <= position.pixels &&
        position.pixels < value) {
      // Overscroll.
      return value - position.pixels;
    }
    if (value < position.minScrollExtent &&
        position.minScrollExtent < position.pixels) {
      // Hit top edge.
      return value - position.minScrollExtent;
    }
    if (position.pixels < position.maxScrollExtent &&
        position.maxScrollExtent < value) {
      // Hit bottom edge.
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }
}
