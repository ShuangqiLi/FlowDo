class Task {
  Task({
    required this.id,
    required this.title,
    this.body,
    required this.status,
    required this.priority,
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
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  String get priorityLabel {
    switch (priority) {
      case 'HIGH':
        return '高';
      case 'LOW':
        return '低';
      default:
        return '中';
    }
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
}
