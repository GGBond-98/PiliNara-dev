import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

typedef DeviceLoginInfo = ({
  String userCode,
  String url,
  String deviceCode,
  int interval,
});

typedef _HttpResult = ({
  int status,
  Map<dynamic, dynamic>? body,
  String text,
});

class OneDriveException implements Exception {
  OneDriveException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OneDrive {
  OneDrive._internal();
  static final OneDrive _instance = OneDrive._internal();
  factory OneDrive() => _instance;

  static const _clientId = 'c48176f8-b27d-469c-8130-9213f39d6e3b';
  static const _deviceCodeUrl =
      'https://login.microsoftonline.com/common/oauth2/v2.0/devicecode';
  static const _tokenUrl =
      'https://login.microsoftonline.com/common/oauth2/v2.0/token';
  static const _graphBaseUrl = 'https://graph.microsoft.com/v1.0';
  static const _scope = 'Files.ReadWrite offline_access';
  static const _timeout = Duration(seconds: 30);

  final HttpClient _http = HttpClient()..connectionTimeout = _timeout;

  bool get isLogin =>
      Pref.onedriveAccessToken.isNotEmpty ||
      Pref.onedriveRefreshToken.isNotEmpty;

  String _encodeForm(Map<String, String> fields) => fields.entries
      .map(
        (e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
      )
      .join('&');

  Future<_HttpResult> _readResponse(HttpClientResponse response) async {
    final bytes = await response
        .expand((chunk) => chunk)
        .toList()
        .timeout(_timeout);
    final text = utf8.decode(bytes, allowMalformed: true);
    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      decoded = null;
    }
    return (
      status: response.statusCode,
      body: decoded is Map<dynamic, dynamic> ? decoded : null,
      text: text,
    );
  }

  /// 发送表单 POST：显式设置 contentLength，避免部分网关/引擎产生
  /// chunked 传输编码而被微软登录端点以 411 拒绝。
  Future<_HttpResult> _postForm(
    String url,
    Map<String, String> fields,
  ) async {
    try {
      final body = utf8.encode(_encodeForm(fields));
      final request = await _http.postUrl(Uri.parse(url));
      request
        ..headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
          charset: 'utf-8',
        )
        ..contentLength = body.length
        ..add(body);
      return _readResponse(await request.close());
    } on SocketException catch (e) {
      throw OneDriveException('网络错误: ${e.message}');
    } on TimeoutException {
      throw OneDriveException('连接微软服务器超时，请检查网络');
    } on HttpException catch (e) {
      throw OneDriveException('网络错误: ${e.message}');
    }
  }

  Future<_HttpResult> _graph(
    String method,
    String path,
    String token, {
    List<int>? body,
  }) async {
    try {
      final request = await _http.openUrl(
        method,
        Uri.parse('$_graphBaseUrl$path'),
      )..headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (body != null) {
        request
          ..headers.contentType = ContentType(
            'application',
            'json',
            charset: 'utf-8',
          )
          ..contentLength = body.length
          ..add(body);
      }
      return _readResponse(await request.close());
    } on SocketException catch (e) {
      throw OneDriveException('网络错误: ${e.message}');
    } on TimeoutException {
      throw OneDriveException('连接微软服务器超时，请检查网络');
    } on HttpException catch (e) {
      throw OneDriveException('网络错误: ${e.message}');
    }
  }

  String _briefText(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= 160 ? normalized : '${normalized.substring(0, 160)}…';
  }

  String _oauthError(_HttpResult result) {
    final desc = result.body?['error_description'];
    if (desc is String && desc.isNotEmpty) {
      return desc;
    }
    final error = result.body?['error'];
    if (error is String && error.isNotEmpty) {
      return error;
    }
    return _briefText(result.text);
  }

  String _graphError(_HttpResult result) {
    final error = result.body?['error'];
    if (error is Map<dynamic, dynamic>) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    return _briefText(result.text);
  }

  Future<void> _saveToken(Map<dynamic, dynamic> data) async {
    final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
    await GStorage.setting.putAll({
      SettingBoxKey.onedriveAccessToken: data['access_token'] ?? '',
      SettingBoxKey.onedriveRefreshToken: data['refresh_token'] ?? '',
      SettingBoxKey.onedriveExpiresAt:
          DateTime.now().millisecondsSinceEpoch + expiresIn * 1000,
    });
  }

  Future<void> logout() async {
    await GStorage.setting.putAll({
      SettingBoxKey.onedriveAccessToken: '',
      SettingBoxKey.onedriveRefreshToken: '',
      SettingBoxKey.onedriveExpiresAt: 0,
    });
  }

  Future<DeviceLoginInfo> startDeviceLogin() async {
    final result = await _postForm(_deviceCodeUrl, {
      'client_id': _clientId,
      'scope': _scope,
    });
    if (result.status != 200 || result.body == null) {
      throw OneDriveException(
        '获取登录码失败(${result.status}): ${_oauthError(result)}',
      );
    }
    final data = result.body!;
    final userCode = data['user_code'];
    final deviceCode = data['device_code'];
    if (userCode is! String || deviceCode is! String) {
      throw OneDriveException('获取登录码失败: ${_oauthError(result)}');
    }
    return (
      userCode: userCode,
      url: (data['verification_uri'] ??
              data['verification_uri_complete'] ??
              'https://microsoft.com/devicelogin')
          as String,
      deviceCode: deviceCode,
      interval: (data['interval'] as num?)?.toInt() ?? 5,
    );
  }

  /// 轮询授权结果：null 表示成功；'pending' 表示继续等待（含瞬时网络错误）；
  /// 其他为致命错误信息。
  Future<String?> pollToken(DeviceLoginInfo info) async {
    final _HttpResult result;
    try {
      result = await _postForm(_tokenUrl, {
        'client_id': _clientId,
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        'device_code': info.deviceCode,
      });
    } on OneDriveException {
      // 轮询期间网络抖动按等待处理，由授权码 15 分钟有效期兜底
      return 'pending';
    }
    if (result.status == 200) {
      final data = result.body;
      if (data != null && data['access_token'] is String) {
        await _saveToken(data);
        return null;
      }
      return '登录响应异常，请重试';
    }
    final error = result.body?['error'];
    return switch (error) {
      'authorization_pending' || 'slow_down' => 'pending',
      'authorization_declined' => '已拒绝授权',
      'expired_token' => '授权码已过期，请重新登录',
      _ => '登录失败: ${_oauthError(result)}',
    };
  }

  Future<String> _validToken() async {
    final accessToken = Pref.onedriveAccessToken;
    if (accessToken.isNotEmpty &&
        Pref.onedriveExpiresAt - DateTime.now().millisecondsSinceEpoch >
            60000) {
      return accessToken;
    }
    final refreshToken = Pref.onedriveRefreshToken;
    if (refreshToken.isEmpty) {
      throw OneDriveException('未登录，请先登录 OneDrive');
    }
    final result = await _postForm(_tokenUrl, {
      'client_id': _clientId,
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'scope': _scope,
    });
    final data = result.body;
    if (result.status == 200 &&
        data != null &&
        data['access_token'] is String) {
      await _saveToken(data);
      return data['access_token'] as String;
    }
    if (result.status == 400) {
      await logout();
      throw OneDriveException('登录已过期，请重新登录');
    }
    throw OneDriveException('刷新登录状态失败: ${_oauthError(result)}');
  }

  String _remotePath() {
    final dir =
        Pref.onedriveDirectory.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    final fileName = 'piliplus_settings_${DeviceUtils.platformName}.json';
    return Uri.encodeFull(
      '/${dir.isEmpty ? Constants.appName : dir}/$fileName',
    );
  }

  /// 测试连接，返回账号显示名（可能为空）
  Future<String> init() async {
    final token = await _validToken();
    final result = await _graph('GET', '/me/drive', token);
    if (result.status != 200) {
      throw OneDriveException('连接失败(${result.status}): ${_graphError(result)}');
    }
    final owner = result.body?['owner'];
    final user = owner is Map<dynamic, dynamic> ? owner['user'] : null;
    final name = user is Map<dynamic, dynamic> ? user['displayName'] : null;
    return name is String ? name : '';
  }

  Future<void> backup() async {
    try {
      final token = await _validToken();
      final data = utf8.encode(GStorage.exportAllSettings());
      final result = await _graph(
        'PUT',
        '/me/drive/root:/${_remotePath()}:/content',
        token,
        body: data,
      );
      if (result.status >= 200 && result.status < 300) {
        SmartDialog.showToast('备份成功');
      } else {
        SmartDialog.showToast(
          '备份失败(${result.status}): ${_graphError(result)}',
        );
      }
    } catch (e) {
      SmartDialog.showToast('备份失败: $e');
    }
  }

  Future<void> restore() async {
    try {
      final token = await _validToken();
      final result = await _graph(
        'GET',
        '/me/drive/root:/${_remotePath()}:/content',
        token,
      );
      if (result.status == 404) {
        SmartDialog.showToast('云端暂无备份文件');
        return;
      }
      if (result.status != 200) {
        SmartDialog.showToast(
          '恢复失败(${result.status}): ${_graphError(result)}',
        );
        return;
      }
      await GStorage.importAllSettings(result.text);
      SmartDialog.showToast('恢复成功');
    } catch (e) {
      SmartDialog.showToast('恢复失败: $e');
    }
  }
}
