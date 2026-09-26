import 'mic_permission_state.dart';

/// 非网页平台：没有浏览器权限这一层，交给各平台的语音插件自己处理。
abstract final class MicrophoneAccess {
  /// 网页端以外不存在"非安全地址"的问题。
  static bool get isSecureContext => true;

  /// 这里只是占位，真正能不能语音由 [AddTaskFab.voiceSupported] 决定。
  static bool get speechRecognitionSupported => false;

  /// 当前页面地址，网页端用来拼提示；其他平台没有。
  static String? get pageOrigin => null;

  static Future<MicPermissionState> query() async =>
      MicPermissionState.unknown;

  static Future<MicPermissionState> request() async =>
      MicPermissionState.unknown;
}
