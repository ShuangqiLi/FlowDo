class Me {
  Me({
    required this.id,
    required this.email,
    required this.archiveAfterDays,
    required this.focusLimit,
    required this.deleteArchivedAfterDays,
    required this.showArchiveTab,
    required this.themeKey,
  });

  final String id;
  final String email;
  final int archiveAfterDays;
  final int focusLimit;
  final int deleteArchivedAfterDays;
  final bool showArchiveTab;
  final String themeKey;

  factory Me.fromJson(Map<String, dynamic> json) {
    return Me(
      id: json['id'] as String,
      email: json['email'] as String,
      archiveAfterDays: json['archiveAfterDays'] as int,
      focusLimit: (json['focusLimit'] as int?) ?? 3,
      deleteArchivedAfterDays: (json['deleteArchivedAfterDays'] as int?) ?? 30,
      showArchiveTab: (json['showArchiveTab'] as bool?) ?? true,
      themeKey: (json['themeKey'] as String?) ?? 'mint',
    );
  }
}
