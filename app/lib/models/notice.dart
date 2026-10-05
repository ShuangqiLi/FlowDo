class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.taskId,
    this.readAt,
    this.spaceId,
    this.spaceName,
    this.spaceThemeKey,
  });

  final String id;
  final String? taskId;
  final String title;
  final String message;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? spaceId;
  final String? spaceName;
  final String? spaceThemeKey;

  bool get unread => readAt == null;

  bool get isLocal => id.startsWith('local:');

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] as String,
      taskId: json['taskId'] as String?,
      title: json['title'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      readAt: json['readAt'] == null
          ? null
          : DateTime.parse(json['readAt'] as String),
      spaceId: json['spaceId'] as String?,
      spaceName: json['spaceName'] as String?,
      spaceThemeKey: json['spaceThemeKey'] as String?,
    );
  }

  Notice copyWith({
    String? id,
    String? taskId,
    String? title,
    String? message,
    DateTime? createdAt,
    DateTime? readAt,
    bool clearReadAt = false,
    String? spaceId,
    String? spaceName,
    String? spaceThemeKey,
  }) {
    return Notice(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      spaceId: spaceId ?? this.spaceId,
      spaceName: spaceName ?? this.spaceName,
      spaceThemeKey: spaceThemeKey ?? this.spaceThemeKey,
    );
  }
}

class PendingReminder {
  const PendingReminder({
    required this.id,
    required this.title,
    required this.spaceId,
    required this.spaceName,
    required this.spaceThemeKey,
    required this.remindAt,
    required this.remindRepeat,
    required this.status,
  });

  final String id;
  final String title;
  final String spaceId;
  final String spaceName;
  final String spaceThemeKey;
  final DateTime remindAt;
  final String remindRepeat;
  final String status;

  factory PendingReminder.fromJson(Map<String, dynamic> json) {
    return PendingReminder(
      id: json['id'] as String,
      title: json['title'] as String,
      spaceId: json['spaceId'] as String,
      spaceName: (json['spaceName'] as String?) ?? '',
      spaceThemeKey: (json['spaceThemeKey'] as String?) ?? 'mint',
      remindAt: DateTime.parse(json['remindAt'] as String),
      remindRepeat: (json['remindRepeat'] as String?) ?? 'ONCE',
      status: json['status'] as String,
    );
  }
}

class NoticeWatch {
  const NoticeWatch({
    required this.notices,
    this.pending = const [],
  });

  final List<Notice> notices;
  final List<PendingReminder> pending;

  factory NoticeWatch.fromJson(dynamic json) {
    if (json is List) {
      return NoticeWatch(
        notices: json
            .map((item) => Notice.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    }
    final map = json as Map<String, dynamic>;
    return NoticeWatch(
      notices: (map['notices'] as List<dynamic>? ?? const [])
          .map((item) => Notice.fromJson(item as Map<String, dynamic>))
          .toList(),
      pending: (map['pending'] as List<dynamic>? ?? const [])
          .map((item) => PendingReminder.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
