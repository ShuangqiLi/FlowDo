import '../platform/mic_permission_state.dart';

/// Chrome / Edge 里打开这个页面能把 http 地址当安全地址用。
const insecureOriginFlag =
    'chrome://flags/#unsafely-treat-insecure-origin-as-secure';

/// 把浏览器语音识别抛出来的错误码（not-allowed、network …）翻译成能照着做的话。
///
/// 返回 null 表示这个错误不值得打扰用户（比如松手时的 aborted）。
String? voiceErrorMessage(
  String rawError, {
  required bool secureContext,
  String? origin,
}) {
  final code = rawError.trim().toLowerCase();
  switch (code) {
    case 'not-allowed':
    case 'service-not-allowed':
    case 'permission-denied':
      if (!secureContext) {
        return _insecureOriginMessage(origin);
      }
      return '麦克风被浏览器拦住了。点地址栏左边的图标 → 网站设置 → 麦克风 → 允许，'
          '刷新页面后再长按；也可以到「设置 → 语音输入」里重新申请。';
    case 'no-speech':
      return '没听到声音。靠近一点，按住加号再说一次。';
    case 'audio-capture':
      return '没找到能用的麦克风。看看设备接好没、是不是被别的应用占着。';
    case 'network':
      return '语音识别要连浏览器厂商的识别服务，当前网络连不上。'
          'Chrome 用的是谷歌的服务，国内可以换 Edge 试试。';
    case 'language-not-supported':
      return '这个浏览器不支持中文识别，换 Chrome 或 Edge 试试。';
    case 'not supported':
    case 'speech_not_supported':
      return '这个浏览器没有语音识别功能（Firefox 就没有），换 Chrome 或 Edge 就行。';
    case 'aborted':
      return null;
  }
  return '语音输入出了点问题（$rawError），先打字吧。';
}

/// 设置页里那行"麦克风现在什么状态"。
String micStateMessage(MicPermissionState state, {String? origin}) {
  return switch (state) {
    MicPermissionState.granted => '麦克风已允许，长按加号就能说话。',
    MicPermissionState.denied =>
      '浏览器拒绝了麦克风。点地址栏左边的图标 → 网站设置 → 麦克风 → 允许，再刷新页面。',
    MicPermissionState.prompt => '还没申请过麦克风。现在申请一次，之后长按加号就不用再确认了。',
    MicPermissionState.insecureContext => _insecureOriginMessage(origin),
    MicPermissionState.unsupported =>
      '这个浏览器没有麦克风或语音识别能力（Firefox 就没有），换 Chrome 或 Edge。',
    MicPermissionState.noDevice => '没找到麦克风设备，接上再试。',
    MicPermissionState.unknown => '浏览器没告诉我们麦克风状态，长按加号时会再申请一次。',
  };
}

/// 已经拿到权限、拒绝、或地址不行时，"再申请一次"按钮就没意义。
bool micRequestUseful(MicPermissionState state) {
  return switch (state) {
    MicPermissionState.prompt || MicPermissionState.unknown => true,
    _ => false,
  };
}

String _insecureOriginMessage(String? origin) {
  final where = origin == null || origin.isEmpty ? '当前地址' : origin;
  return '浏览器不允许 http 地址使用麦克风。请用 https 或 localhost 打开；'
      'Chrome / Edge 也可以在 $insecureOriginFlag 里加上 $where，重启浏览器后再试。';
}
