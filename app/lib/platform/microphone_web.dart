import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'mic_permission_state.dart';

/// 网页端麦克风权限。
///
/// 浏览器只在 https:// 或 localhost 下开放麦克风（`isSecureContext`），内网 http://IP
/// 打开时 `navigator.mediaDevices` 直接是 undefined，语音识别一启动就报 not-allowed。
/// 这里把这几种情况分开，提示才能说到点子上。
abstract final class MicrophoneAccess {
  static bool get isSecureContext => web.window.isSecureContext;

  static bool get speechRecognitionSupported =>
      web.window.has('SpeechRecognition') ||
      web.window.has('webkitSpeechRecognition');

  static String? get pageOrigin => web.window.location.origin;

  static bool get _hasMediaDevices {
    final devices = web.window.navigator.getProperty<JSAny?>('mediaDevices'.toJS);
    return !devices.isUndefinedOrNull;
  }

  /// 不弹窗，只看现在是允许、拒绝还是没问过。
  static Future<MicPermissionState> query() async {
    if (!isSecureContext) {
      return MicPermissionState.insecureContext;
    }
    if (!_hasMediaDevices) {
      return MicPermissionState.unsupported;
    }
    try {
      final descriptor = JSObject()..setProperty('name'.toJS, 'microphone'.toJS);
      final status =
          await web.window.navigator.permissions.query(descriptor).toDart;
      return switch (status.state) {
        'granted' => MicPermissionState.granted,
        'denied' => MicPermissionState.denied,
        _ => MicPermissionState.prompt,
      };
    } catch (_) {
      // Firefox / Safari 不支持查 microphone，只能等真正申请时再看。
      return MicPermissionState.unknown;
    }
  }

  /// 主动申请一次麦克风：拿到流立刻停掉，只为让浏览器记住"允许"。
  /// 之后语音识别启动就不会再弹窗，也不用在按住加号的时候分神去点允许。
  static Future<MicPermissionState> request() async {
    if (!isSecureContext) {
      return MicPermissionState.insecureContext;
    }
    if (!_hasMediaDevices) {
      return MicPermissionState.unsupported;
    }
    try {
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;
      for (final track in stream.getTracks().toDart) {
        track.stop();
      }
      return MicPermissionState.granted;
    } catch (error) {
      return switch (_jsErrorName(error)) {
        'NotAllowedError' || 'SecurityError' || 'PermissionDeniedError' =>
          MicPermissionState.denied,
        'NotFoundError' || 'DevicesNotFoundError' || 'OverconstrainedError' =>
          MicPermissionState.noDevice,
        'NotSupportedError' || 'TypeError' => MicPermissionState.unsupported,
        _ => MicPermissionState.unknown,
      };
    }
  }

  static String? _jsErrorName(Object error) {
    // 被 await 的 JS Promise 拒绝时，抛出来的就是原始的 DOMException 对象。
    final js = error.jsify();
    if (js == null || !js.isA<JSObject>()) {
      return null;
    }
    final name = (js as JSObject).getProperty<JSAny?>('name'.toJS);
    return name.isA<JSString>() ? (name as JSString).toDart : null;
  }
}
