/// 浏览器麦克风权限：查询、提前申请，以及判断当前地址能不能用麦克风。
///
/// 只有网页端有真实现；桌面调试时走 stub，永远报"不支持"。
library;

export 'mic_permission_state.dart';
export 'microphone_stub.dart'
    if (dart.library.js_interop) 'microphone_web.dart';
