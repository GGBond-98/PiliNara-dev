import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/custom_height_widget.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/home/controller.dart';
import 'package:PiliPlus/pages/home/home_preview_scope.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/size_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.preview = false});

  final bool preview;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends CommonPageState<HomePage>
    with AutomaticKeepAliveClientMixin {
  final _homeController = Get.putOrFind(HomeController.new);
  final _mainController = Get.find<MainController>();
  Worker? _nativeTopBarWorker;

  @override
  bool get needsCorrection => _homeController.hideTopBar;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 鸿蒙顶栏异步就绪 / 横竖屏切换后重建，显示或隐藏 Flutter 顶栏、分类栏。
    // 状态栏安全区移除由窗口沉浸实现（EntryAbility 设置
    // setWindowLayoutFullScreen(true) + 状态栏背景透明），保留系统状态栏
    // 图标；此处仅负责按顶栏是否生效重建 UI 布局，不操作系统状态栏。
    _nativeTopBarWorker = ever(_mainController.nativeTopBarActive, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nativeTopBarWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    // 鸿蒙原生顶栏生效时隐藏 Flutter 顶部控件。
    // 横屏/侧栏布局下 ArkTS 顶栏是隐藏的，此处必须恢复 Flutter 分类栏，
    // 否则分类栏消失且顶部留白（NativeTopSpacer）空出一大片。
    final useNativeTopBar = _mainController.nativeTopBarActive.value;
    Widget tabBar;
    if (_homeController.tabs.length > 1) {
      if (Pref.enableGradientBg) {
        // 开启渐变时用圆角 chip 标签栏（颜色随主题动态），关闭时回退原生 TabBar
        tabBar = CustomTabs(homeController: _homeController);
      } else {
        tabBar = Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SizedBox(
            height: 42,
            width: double.infinity,
            child: TabBar(
              controller: _homeController.tabController,
              tabs: _homeController.tabs.map((e) => Tab(text: e.label)).toList(),
              isScrollable: true,
              dividerColor: Colors.transparent,
              dividerHeight: 0,
              splashBorderRadius: Style.mdRadius,
              tabAlignment: TabAlignment.center,
              onTap: (_) {
                feedBack();
                if (!_homeController.tabController.indexIsChanging) {
                  if (Pref.enableCurrentPageRefresh) {
                    _homeController.toTopAndRefresh();
                  } else {
                    _homeController.animateToTop();
                  }
                }
              },
            ),
          ),
        );
        if (_homeController.hideTopBar &&
            _mainController.barHideType == .instant) {
          tabBar = Material(
            color: theme.colorScheme.surface,
            child: tabBar,
          );
        }
      }
    } else {
      tabBar = const SizedBox(height: 6);
    }
    return HomePreviewScope(
      enabled: widget.preview,
      child: Column(
        children: [
          if (!useNativeTopBar &&
              !_mainController.useSideBar &&
              MediaQuery.sizeOf(context).isPortrait)
            customAppBar(theme)
          else if (!useNativeTopBar)
            SizedBox(height: MediaQuery.of(context).padding.top),
          if (!useNativeTopBar) tabBar,
          Expanded(
            child: onBuild(
              tabBarView(
                controller: _homeController.tabController,
                children: _homeController.tabs.map((e) => e.page).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget customAppBar(ThemeData theme) {
    const padding = EdgeInsets.fromLTRB(14, 6, 14, 0);
    final child = Row(
      children: [
        searchBar(theme),
        const SizedBox(width: 4),
        msgBadge(_mainController),
        const SizedBox(width: 8),
        userAvatar(theme: theme, mainController: _mainController),
      ],
    );
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    if (_homeController.hideTopBar) {
      if (_mainController.barOffset case final barOffset?) {
        return Obx(
          () {
            final offset = barOffset.value;
            return SizedBox(
              height: statusBarHeight + Style.topBarHeight - offset,
              child: Stack(
                // 同步收起顶栏时搜索栏会随 offset 上移进入状态栏区域，需要把
                // 状态栏以下的部分挡住。挡法是裁剪而不是盖一层不透明色块：
                // Scaffold 的背景是透明的，页面真正的底色（Nara 渐变，或
                // 关闭渐变时的 colorScheme.surface）在 Scaffold 后面，盖
                // colorScheme.surface 的色块会把它顶掉——浅色模式下顶部就是
                // 一条死白。裁剪后状态栏区域透出页面背景，与沉浸光感顶栏
                // 开启时的观感一致。
                children: [
                  Positioned(
                    // 必须同时指定 left/right：只指定 top 时 Stack 会给子组件
                    // 无界宽度约束（Positioned 未指定宽度时 child 收到
                    // unconstrained），CustomHeightWidget 会把 constraints.maxWidth
                    // （Infinity）直接作为自身宽度，导致 size 为
                    // Size(Infinity, ...)，Stack 计算其偏移时产生 NaN 坐标，
                    // 内容不显示、滑动无法命中。
                    top: statusBarHeight,
                    left: 0,
                    right: 0,
                    // ClipRect 的裁剪区恒等于子组件自身尺寸，而
                    // CustomHeightWidget 是把子树画在负 offset 上的（自身
                    // 尺寸不变），所以状态栏那截会被正好切掉，效果与原遮罩
                    // 等价；命中测试同样被裁到状态栏以下。
                    child: ClipRect(
                      child: CustomHeightWidget(
                        offset: Offset(0, -offset),
                        height: Style.topBarHeight - offset,
                        child: Padding(
                          padding: padding,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
      if (_homeController.showTopBar case final showTopBar?) {
        return Obx(() {
          final showSearchBar = showTopBar.value;
          return Container(
            padding: EdgeInsets.only(
              top: statusBarHeight
            ),
            child: AnimatedOpacity(
              opacity: showSearchBar ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: AnimatedContainer(
                curve: Curves.easeInOutCubicEmphasized,
                duration: const Duration(milliseconds: 500),
                height: showSearchBar ? Style.topBarHeight : 0,
                padding: padding,
                child: child,
              ),
            ),
          );
        });
      }
    }
    final paddingWithSafeArea = EdgeInsets.fromLTRB(
      14,
      6 + statusBarHeight,
      14,
      0,
    );
    return Container(
      height: Style.topBarHeight + statusBarHeight,
      padding: paddingWithSafeArea,
      child: child,
    );
  }

  Widget searchBar(ThemeData theme) {
    const borderRadius = BorderRadius.all(Radius.circular(25));
    return Expanded(
      child: SizedBox(
        height: 44,
        child: Material(
          borderRadius: borderRadius,
          color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.05),
          child: InkWell(
            borderRadius: borderRadius,
            splashColor: theme.colorScheme.primaryContainer.withValues(
              alpha: 0.3,
            ),
            onTap: () => Get.toNamed(
              '/search',
              parameters: _homeController.enableSearchWord
                  ? {'hintText': _homeController.defaultSearch.value}
                  : null,
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  Icons.search_outlined,
                  color: theme.colorScheme.onSecondaryContainer,
                  semanticLabel: '搜索',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Obx(
                    () => Text(
                      _homeController.defaultSearch.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget userAvatar({
  required ThemeData theme,
  required MainController mainController,
}) {
  return Semantics(
    label: "我的",
    child: Obx(
      () {
        if (mainController.accountService.isLogin.value) {
          return Stack(
            clipBehavior: .none,
            children: [
              NetworkImgLayer(
                type: .avatar,
                width: 34,
                height: 34,
                src: mainController.accountService.face.value,
              ),
              Positioned.fill(
                child: Material(
                  type: .transparency,
                  child: InkWell(
                    onTap: mainController.toMinePage,
                    splashColor: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    customBorder: const CircleBorder(),
                  ),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Obx(
                  () => MineController.anonymity.value
                      ? IgnorePointer(
                          child: Container(
                            padding: const .all(2),
                            decoration: BoxDecoration(
                              shape: .circle,
                              color: theme.colorScheme.secondaryContainer,
                            ),
                            child: Icon(
                              size: 14,
                              MdiIcons.incognito,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          );
        }
        return SizedBox(
          width: 38,
          height: 38,
          child: IconButton(
            tooltip: '点击登录',
            style: IconButton.styleFrom(
              padding: .zero,
              backgroundColor: theme.colorScheme.onInverseSurface,
            ),
            onPressed: mainController.toMinePage,
            icon: Icon(
              Icons.person_rounded,
              size: 22,
              color: theme.colorScheme.primary,
            ),
          ),
        );
      },
    ),
  );
}

Widget msgBadge(MainController mainController) {
  return Obx(
    () {
      if (mainController.accountService.isLogin.value) {
        final count = mainController.msgUnReadCount.value;
        final isNumBadge = mainController.msgBadgeMode == .number;
        return IconButton(
          tooltip: '消息',
          onPressed: () {
            mainController
              ..clearUnreadMsg()
              ..lastCheckUnreadAt = DateTime.now().millisecondsSinceEpoch;
            Get.toNamed('/whisper');
          },
          icon: Badge(
            isLabelVisible:
                mainController.msgBadgeMode != .hidden && count != null,
            alignment: isNumBadge
                ? const Alignment(0.0, -0.85)
                : const Alignment(1.0, -0.85),
            label: isNumBadge && count != null ? Text(count) : null,
            child: const Icon(Icons.notifications_none),
          ),
        );
      }
      return const SizedBox.shrink();
    },
  );
}

/// 圆角 chip 标签栏：开启「首页背景渐变」时替代原生 TabBar，
/// 颜色全部取自 ColorScheme，随主题/取色动态变化（移植自 PiliPalaX）。
class CustomTabs extends StatefulWidget {
  final HomeController homeController;
  const CustomTabs({super.key, required this.homeController});

  @override
  State<CustomTabs> createState() => _CustomTabsState();
}

class _CustomTabsState extends State<CustomTabs> {
  final RxInt selected = 0.obs;

  @override
  void initState() {
    super.initState();
    selected.value = widget.homeController.tabController.index;
    widget.homeController.tabController.addListener(_sync);
  }

  void _sync() => selected.value = widget.homeController.tabController.index;

  @override
  void dispose() {
    widget.homeController.tabController.removeListener(_sync);
    super.dispose();
  }

  void onTap(int index) {
    feedBack();
    if (widget.homeController.tabController.index == index) {
      if (Pref.enableCurrentPageRefresh) {
        widget.homeController.toTopAndRefresh();
      } else {
        widget.homeController.animateToTop();
      }
    } else {
      widget.homeController.tabController.index = index;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14.0),
        scrollDirection: Axis.horizontal,
        itemCount: widget.homeController.tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final String label = widget.homeController.tabs[index].label;
          return Obx(
            () => CustomChip(
              onTap: () => onTap(index),
              label: label,
              selected: selected.value == index,
              colorScheme: cs,
            ),
          );
        },
      ),
    );
  }
}

class CustomChip extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final bool selected;
  final ColorScheme colorScheme;
  const CustomChip({
    super.key,
    required this.onTap,
    required this.label,
    required this.selected,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    const VisualDensity visualDensity =
        VisualDensity(horizontal: -4.0, vertical: -2.0);
    return InputChip(
      side: selected
          ? BorderSide(
              color: colorScheme.secondary.withValues(alpha: 0.2),
              width: 2,
            )
          : BorderSide.none,
      color: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) =>
            colorScheme.secondaryContainer.withValues(alpha: 0.6),
      ),
      padding: const EdgeInsets.fromLTRB(6, 1, 6, 1),
      label: Text(
        label,
        style: selected
            ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
            : const TextStyle(fontSize: 13),
      ),
      onPressed: onTap,
      selected: selected,
      showCheckmark: false,
      visualDensity: visualDensity,
    );
  }
}
