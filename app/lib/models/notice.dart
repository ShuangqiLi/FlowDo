class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.taskId,
    this.readAt,
  });

  final String id;
  final String? taskId;
  final String title;
  final String message;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;

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
    );
  }
}
