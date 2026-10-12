abstract final class Constants {
  static const appName = 'PiliNara';

  /// 窄列阈值（逻辑像素）：宽度低于该值的分栏列（方形屏外屏分栏、近方形
  /// 布局底部并排列等）启用紧凑布局（简介面板/评论项/Tab 栏/悬浮按钮）。
  /// 实测 Pura X：外屏 980×980px@3x ≈ 327×327dp（竖屏视频分栏右列
  /// ≈ 177dp）；内屏 1320×2120px@3x ≈ 440×707dp，为普通竖屏比例不分栏。
  /// 取 300：覆盖外屏分栏列与近方形窄列，不影响常规手机（≥360dp）全宽。
  static const double compactColumnWidth = 300;

  static const sourceCodeUrl = 'https://github.com/dev4harmony/PiliNara';
  static const upstreamCodeUrl = 'https://github.com/bggRGjQaUbCoE/PiliPlus';
  static const pilinaraCodeUrl = 'https://github.com/Starfallan/PiliNara';


  // 27eb53fc9058f8c3  移动端 Android
  // 4409e2ce8ffd12b8  HD版
  static const String appKey = 'dfca71928277209b';
  // 59b43e04ad6965f34319062b478f83dd TV端
  static const String appSec = 'b5475a8825547a4fc26c7d518eaaa02e';
  // static const String thirdSign = '04224646d1fea004e79606d3b038c84a';
  // static const String thirdApi =
  //     'https://www.mcbbs.net/template/mcbbs/image/special_photo_bg.png';

  static const String traceId =
      '11111111111111111111111111111111:1111111111111111:0:0';
  static const String userAgent =
      'Mozilla/5.0 BiliDroid/2.0.1 (bbcallen@gmail.com) os/android model/android_hd mobi_app/android_hd build/2001100 channel/master innerVer/2001100 osVer/15 network/2';
  static const String statistics =
      '{"appId":5,"platform":3,"version":"2.0.1","abtest":""}';
  // 请求时会自动encodeComponent

  // app
  static const String userAgentApp =
      'Mozilla/5.0 BiliDroid/8.43.0 (bbcallen@gmail.com) os/android model/android mobi_app/android build/8430300 channel/master innerVer/8430300 osVer/15 network/2';

  static const String statisticsApp =
      '{"appId":1,"platform":3,"version":"8.43.0","abtest":""}';

  static const baseHeaders = {
    // 'referer': HttpString.baseUrl,
    'env': 'prod',
    'app-key': 'android64',
    'x-bili-aurora-zone': 'sh001',
  };

  static final urlRegex = RegExp(
    r'https?://[-A-Za-z0-9+&@#/%?=~_|!:,.;]+[-A-Za-z0-9+&@#/%=~_|]',
  );

  static const goodsUrlPrefix = "https://gaoneng.bilibili.com/tetris";

  // 'itemOpusStyle,opusBigCover,onlyfansVote,endFooterHidden,decorationCard,onlyfansAssetsV2,ugcDelete,onlyfansQaCard,editable,opusPrivateVisible,avatarAutoTheme,sunflowerStyle,cardsEnhance,eva3CardOpus,eva3CardVideo,eva3CardComment,eva3CardVote,eva3CardUser'
  static const dynFeatures = 'itemOpusStyle,listOnlyfans,onlyfansQaCard';
}
