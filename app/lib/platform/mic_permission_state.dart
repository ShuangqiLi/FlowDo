/// 麦克风现在处于什么状态。
enum MicPermissionState {
  /// 已允许，长按就能直接说。
  granted,

  /// 用户或浏览器策略拒绝了。
  denied,

  /// 还没问过，申请时会弹窗。
  prompt,

  /// 页面是 http://IP 这种非安全地址，浏览器根本不开放麦克风。
  insecureContext,

  /// 浏览器没有麦克风 / 语音识别能力。
  unsupported,

  /// 没找到麦克风设备。
  noDevice,

  /// 查不出来（比如浏览器不支持 Permissions API）。
  unknown,
}
