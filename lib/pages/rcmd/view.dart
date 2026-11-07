import 'dart:math' show max, min;

import 'package:PiliPlus/common/skeleton/video_card_v.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/native_top_spacer.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/home/home_preview_scope.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/fullscreen_mode.dart'
    show kScreenRatio;
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:os_type/os_type.dart';

class RcmdPage extends StatefulWidget {
  const RcmdPage({super.key});

  @override
  State<RcmdPage> createState() => _RcmdPageState();
}

class _RcmdPageState extends State<RcmdPage>
    with AutomaticKeepAliveClientMixin {
  final controller = Get.put(RcmdController());

  Worker? _fillWorker;

  /// 双指缩放固定的推荐网格列数：0 = 自动（按推荐卡片宽度推算），
  /// 2/3 = 手势固定。内屏默认 2 列，向内捏合变 3 列、向外张开回 2 列，
  /// 持久化到设置。
  int _gridColumns = Pref.rcmdGridColumns;

  /// 原始指针追踪：绕过手势竞技场——双指捏合若走 ScaleGestureRecognizer，
  /// 会与内层滚动的拖动识别器竞争，不对称捏合（一指固定一指移动）的
  /// 平均位移先过 touch slop，滚动先赢下竞技场，捏合被吞。Listener 不
  /// 参与竞技场，双指落点即稳定可判。
  final Map<int, Offset> _pinchPointers = {};
  double? _pinchInitialSpan;
  bool _pinchHandled = false;
  static const _pinchInRatio = 0.85;
  static const _pinchOutRatio = 1.15;
  static const _minPinchSpan = 40.0;

  @override
  void initState() {
    super.initState();
    controller.scrollController.addListener(_onScroll);
    // 大屏多列下一页数据可能填不满视口：此时列表不可滚动，_onScroll 永远不会
    // 触发，页面就一直空着下半屏，只有手动下拉刷新才会变多。每次数据变化后
    // 补一次判断，不可滚动就继续拉下一页，直到出现可滚动区域。
    _fillWorker = ever(controller.loadingState, (_) => _fillViewport());
  }

  void _fillViewport() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || controller.isLoading) return;
      // 只在已有数据时续拉：错误态下列表同样不可滚动，重试交给 HttpError
      if (controller.loadingState.value.dataOrNull?.isNotEmpty != true) return;
      final scrollController = controller.scrollController;
      if (scrollController.hasClients &&
          scrollController.position.maxScrollExtent <= 0) {
        controller.onLoadMore();
      }
    });
  }

  void _onScroll() {
    if (!controller.scrollController.hasClients || controller.isLoading) return;
    final position = controller.scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 1000) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => controller.onLoadMore(),
      );
    }
  }

  @override
  void dispose() {
    _fillWorker?.dispose();
    controller.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  /// 双指缩放仅鸿蒙下非小尺寸近方形窗口可用：Pura X 外屏 327×327dp
  /// 捏成 3 列卡片会窄到不可读。阈值与视频页 _isSmallNearSquareWindow
  /// 一致，按短边/长边比判断，与横竖屏无关。
  static bool _pinchZoomEnabled(Size size) {
    if (!OS.isHarmony) {
      return false;
    }
    final ratio = size.shortestSide / size.longestSide;
    return !(ratio >= 0.85 && ratio < kScreenRatio && size.shortestSide < 500);
  }

  void _onPointerDown(PointerDownEvent event) {
    _pinchPointers[event.pointer] = event.position;
    _resetPinchSpan();
  }

  void _onPointerUp(PointerEvent event) {
    _pinchPointers.remove(event.pointer);
    _resetPinchSpan();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pinchPointers.containsKey(event.pointer)) {
      return;
    }
    _pinchPointers[event.pointer] = event.position;
    _trySwitchColumns();
  }

  /// 双指集合变化后重算捏合基线；两指间距过近时忽略，避免相邻手指
  /// 抖动误触
  void _resetPinchSpan() {
    if (_pinchPointers.length < 2) {
      _pinchInitialSpan = null;
      return;
    }
    final span = _currentSpan();
    _pinchInitialSpan = span >= _minPinchSpan ? span : null;
    _pinchHandled = false;
  }

  double _currentSpan() {
    final positions = _pinchPointers.values.take(2).toList();
    return (positions.first - positions.last).distance;
  }

  void _trySwitchColumns() {
    final initialSpan = _pinchInitialSpan;
    if (initialSpan == null || _pinchHandled) {
      return;
    }
    final ratio = _currentSpan() / initialSpan;
    final current = _gridColumns == 0 ? 2 : _gridColumns;
    final int target;
    if (ratio <= _pinchInRatio) {
      // 向内捏合 → 卡片变小 → 多一列
      target = min(3, current + 1);
    } else if (ratio >= _pinchOutRatio) {
      // 向外张开 → 卡片变大 → 少一列
      target = max(2, current - 1);
    } else {
      return;
    }
    _pinchHandled = true;
    if (target == current) {
      return;
    }
    setState(() => _gridColumns = target);
    feedBack();
    GStorage.setting.put(SettingBoxKey.rcmdGridColumns, target);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = ColorScheme.of(context);
    // 外屏等不启用缩放的窗口忽略已保存的固定列数，保持自动布局
    final pinchEnabled = _pinchZoomEnabled(MediaQuery.sizeOf(context));
    if (!pinchEnabled) {
      // 折叠/窗口变化后不再追踪，清掉可能残留的指针避免误判
      _pinchPointers.clear();
    }
    final gridDelegate = _gridDelegate(pinchEnabled ? _gridColumns : 0);
    return Container(
      clipBehavior: Clip.none,
      margin: const EdgeInsets.symmetric(horizontal: Style.safeSpace),
      decoration: const BoxDecoration(borderRadius: Style.mdRadius),
      child: Listener(
        onPointerDown: pinchEnabled ? _onPointerDown : null,
        onPointerMove: pinchEnabled ? _onPointerMove : null,
        onPointerUp: pinchEnabled ? _onPointerUp : null,
        onPointerCancel: pinchEnabled ? _onPointerUp : null,
        child: NativeTopRefreshIndicator(
          refreshKey:
              HomePreviewScope.of(context) ? null : controller.refreshKey,
          onRefresh: controller.onRefresh,
          child: CustomScrollView(
            controller: controller.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 原生顶栏启用时顶部的可滚动留白（内容可滑入顶栏下方重合）
              const NativeTopSpacer(),
              SliverPadding(
                padding: const .only(top: Style.cardSpace, bottom: 100),
                sliver: Obx(
                  () => _buildBody(
                    colorScheme,
                    controller.loadingState.value,
                    gridDelegate,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// columns 为 0 时按推荐卡片宽度自动推算列数，否则用固定列数（双指
  /// 缩放），两种布局的间距、比例与文字区高度保持一致。
  SliverGridDelegate _gridDelegate(int columns) => columns == 0
      ? SliverGridDelegateWithExtentAndRatio(
          mainAxisSpacing: Style.cardSpace,
          crossAxisSpacing: Style.cardSpace,
          maxCrossAxisExtent: Pref.recommendCardWidth,
          childAspectRatio: Style.aspectRatio,
          mainAxisExtent: MediaQuery.textScalerOf(context).scale(90),
        )
      : SliverGridDelegateWithFixedCrossAxisCountAndExtent(
          crossAxisCount: columns,
          mainAxisSpacing: Style.cardSpace,
          crossAxisSpacing: Style.cardSpace,
          childAspectRatio: Style.aspectRatio,
          mainAxisExtent: MediaQuery.textScalerOf(context).scale(90),
        );

  Widget _buildBody(
    ColorScheme colorScheme,
    LoadingState<List<dynamic>?> loadingState,
    SliverGridDelegate gridDelegate,
  ) {
    return switch (loadingState) {
      Loading() => _buildSkeleton(gridDelegate),
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemBuilder: (context, index) {
                  if (controller.lastRefreshAt != null) {
                    if (controller.lastRefreshAt == index) {
                      return GestureDetector(
                        onTap: () => controller
                          ..animateToTop()
                          ..onRefresh(),
                        child: Card(
                          child: Container(
                            alignment: Alignment.center,
                            padding: const .symmetric(horizontal: 10),
                            child: Text(
                              '上次看到这里\n点击刷新',
                              textAlign: .center,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    final actualIndex = index > controller.lastRefreshAt!
                        ? index - 1
                        : index;
                    final item = response[actualIndex];
                    return VideoCardV(
                      key: ValueKey(
                        '${item.goto}_${item.bvid ?? item.param ?? item.uri}',
                      ),
                      videoItem: item,
                      enableHeroTransition: true,
                      onRemove: () {
                        if (controller.lastRefreshAt != null &&
                            actualIndex < controller.lastRefreshAt!) {
                          controller.lastRefreshAt =
                              controller.lastRefreshAt! - 1;
                        }
                        controller.loadingState
                          ..value.data!.remove(item)
                          ..refresh();
                      },
                    );
                  } else {
                    final item = response[index];
                    return VideoCardV(
                      key: ValueKey(
                        '${item.goto}_${item.bvid ?? item.param ?? item.uri}',
                      ),
                      videoItem: item,
                      enableHeroTransition: true,
                      onRemove: () => controller.loadingState
                        ..value.data!.remove(item)
                        ..refresh(),
                    );
                  }
                },
                itemCount: controller.lastRefreshAt != null
                    ? response.length + 1
                    : response.length,
              )
            : HttpError(onReload: controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: controller.onReload,
      ),
    };
  }

  /// 骨架数量按视口实际能放下的格子数算：固定 10 个在大屏多列下只能占到
  /// 页面上半部分，加载中看着像“只加载了半页”。
  Widget _buildSkeleton(SliverGridDelegate gridDelegate) => SliverLayoutBuilder(
    builder: (context, constraints) => SliverGrid(
      gridDelegate: gridDelegate,
      delegate: SliverSingleChildDelegate(
        count:
            gridDelegate
                .getLayout(constraints)
                .getMaxChildIndexForScrollOffset(
                  constraints.remainingPaintExtent,
                ) +
            1,
        child: const VideoCardVSkeleton(),
      ),
    ),
  );
}
