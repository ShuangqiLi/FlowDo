class Me {
  Me({
    required this.id,
    required this.username,
    required this.archiveAfterDays,
    required this.focusLimit,
    required this.deleteArchivedAfterDays,
    required this.showArchiveTab,
    required this.themeKey,
    this.voiceInputEnabled = true,
  });

  final String id;
  final String username;
  final int archiveAfterDays;
  final int focusLimit;
  final int deleteArchivedAfterDays;
  final bool showArchiveTab;
  final String themeKey;

  /// 长按加号是否用说的；关掉后首页也不再申请麦克风。跟着账号。
  final bool voiceInputEnabled;

  factory Me.fromJson(Map<String, dynamic> json) {
    return Me(
      id: json['id'] as String,
      username: json['username'] as String,
      archiveAfterDays: json['archiveAfterDays'] as int,
      focusLimit: (json['focusLimit'] as int?) ?? 3,
      deleteArchivedAfterDays: (json['deleteArchivedAfterDays'] as int?) ?? 30,
      showArchiveTab: (json['showArchiveTab'] as bool?) ?? true,
      themeKey: (json['themeKey'] as String?) ?? 'mint',
      voiceInputEnabled: (json['voiceInputEnabled'] as bool?) ?? true,
    );
  }
}
