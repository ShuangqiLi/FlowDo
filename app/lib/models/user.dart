class Me {
  Me({
    required this.id,
    this.activeSpaceId,
    required this.archiveAfterDays,
    required this.focusLimit,
    required this.deleteArchivedAfterDays,
    required this.showArchiveTab,
    this.showRecurringReminders = true,
    required this.themeKey,
    this.voiceInputEnabled = true,
    this.mustChangePassword = false,
  });

  final String id;
  final String? activeSpaceId;

  /// 还在用初始密码，进首页前得先换掉。
  final bool mustChangePassword;
  final int archiveAfterDays;
  final int focusLimit;
  final int deleteArchivedAfterDays;
  final bool showArchiveTab;
  final bool showRecurringReminders;
  final String themeKey;
  final bool voiceInputEnabled;

  factory Me.fromJson(Map<String, dynamic> json) {
    return Me(
      id: json['id'] as String,
      activeSpaceId: json['activeSpaceId'] as String?,
      archiveAfterDays: json['archiveAfterDays'] as int,
      focusLimit: (json['focusLimit'] as int?) ?? 3,
      deleteArchivedAfterDays: (json['deleteArchivedAfterDays'] as int?) ?? 30,
      showArchiveTab: (json['showArchiveTab'] as bool?) ?? false,
      showRecurringReminders:
          (json['showRecurringReminders'] as bool?) ?? true,
      themeKey: (json['themeKey'] as String?) ?? 'mint',
      voiceInputEnabled: (json['voiceInputEnabled'] as bool?) ?? true,
      mustChangePassword: (json['mustChangePassword'] as bool?) ?? false,
    );
  }

  Me copyWith({
    String? id,
    String? activeSpaceId,
    bool clearActiveSpaceId = false,
    int? archiveAfterDays,
    int? focusLimit,
    int? deleteArchivedAfterDays,
    bool? showArchiveTab,
    bool? showRecurringReminders,
    String? themeKey,
    bool? voiceInputEnabled,
    bool? mustChangePassword,
  }) {
    return Me(
      id: id ?? this.id,
      activeSpaceId:
          clearActiveSpaceId ? null : (activeSpaceId ?? this.activeSpaceId),
      archiveAfterDays: archiveAfterDays ?? this.archiveAfterDays,
      focusLimit: focusLimit ?? this.focusLimit,
      deleteArchivedAfterDays:
          deleteArchivedAfterDays ?? this.deleteArchivedAfterDays,
      showArchiveTab: showArchiveTab ?? this.showArchiveTab,
      showRecurringReminders:
          showRecurringReminders ?? this.showRecurringReminders,
      themeKey: themeKey ?? this.themeKey,
      voiceInputEnabled: voiceInputEnabled ?? this.voiceInputEnabled,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }
}
