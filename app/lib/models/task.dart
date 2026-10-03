class Task {
  Task({
    required this.id,
    required this.title,
    this.body,
    required this.status,
    required this.priority,
    this.remindAt,
    this.remindRepeat = 'ONCE',
    this.deleted = false,
    this.completedAt,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? body;
  final String status;
  final String priority;
  final DateTime? remindAt;
  final String remindRepeat;
  final bool deleted;
  final DateTime? completedAt;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      status: json['status'] as String,
      priority: json['priority'] as String,
      remindAt: json['remindAt'] == null
          ? null
          : DateTime.parse(json['remindAt'] as String),
      remindRepeat: (json['remindRepeat'] as String?) ?? 'ONCE',
      deleted: json['deleted'] == true,
      completedAt:
          json['completedAt'] == null ? null : DateTime.parse(json['completedAt'] as String),
      archivedAt: json['archivedAt'] == null ? null : DateTime.parse(json['archivedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Task copyWith({
    String? id,
    String? title,
    String? body,
    bool clearBody = false,
    String? status,
    String? priority,
    DateTime? remindAt,
    bool clearRemindAt = false,
    String? remindRepeat,
    bool? deleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      body: clearBody ? null : (body ?? this.body),
      status: status ?? this.status,
      priority: priority ?? this.priority,
      remindAt: clearRemindAt ? null : (remindAt ?? this.remindAt),
      remindRepeat: clearRemindAt ? 'ONCE' : (remindRepeat ?? this.remindRepeat),
      deleted: deleted ?? this.deleted,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get priorityLabel {
    return switch (priority) {
      'HIGH' => '高',
      'MEDIUM' => '中',
      'LOW' => '低',
      'REMINDER' => '提醒',
      _ => '无',
    };
  }

  /// 任务池用创建日，完成页用完成日，归档页用归档日。
  String listDateLabel([DateTime? now]) {
    return switch (status) {
      'DONE' => '${_dayLabel(completedAt ?? updatedAt, now)}完成',
      'ARCHIVED' => '${_dayLabel(archivedAt ?? updatedAt, now)}归档',
      _ => '${_dayLabel(createdAt, now)}加入',
    };
  }

  static String _dayLabel(DateTime date, DateTime? now) {
    final local = date.toLocal();
    final today = (now ?? DateTime.now()).toLocal();
    final todayDate = DateTime(today.year, today.month, today.day);
    final that = DateTime(local.year, local.month, local.day);
    final diff = todayDate.difference(that).inDays;
    if (diff == 0) {
      return '今天';
    }
    if (diff == 1) {
      return '昨天';
    }
    if (local.year == today.year) {
      return '${local.month}月${local.day}日';
    }
    return '${local.year}年${local.month}月${local.day}日';
  }

  int daysUntilArchive(int archiveAfterDays) {
    if (completedAt == null) {
      return archiveAfterDays;
    }
    final due = completedAt!.add(Duration(days: archiveAfterDays));
    return due.difference(DateTime.now()).inDays;
  }

  int daysUntilDelete(int deleteArchivedAfterDays) {
    final from = archivedAt ?? updatedAt;
    final due = from.add(Duration(days: deleteArchivedAfterDays));
    return due.difference(DateTime.now()).inDays;
  }

  /// 归档列表副标题。0 天表示永不自动清掉。
  String archiveKeepHint(int deleteArchivedAfterDays, [DateTime? now]) {
    final when = listDateLabel(now);
    if (deleteArchivedAfterDays <= 0) {
      return '$when · 永久保留';
    }
    final from = archivedAt ?? updatedAt;
    final due = from.add(Duration(days: deleteArchivedAfterDays));
    final days = due.difference(now ?? DateTime.now()).inDays;
    return days <= 0 ? '$when · 马上要清掉啦' : '$when · 还有 $days 天自动清掉';
  }
}
