import 'task.dart';

class ReviewDay {
  ReviewDay({
    required this.date,
    required this.count,
    this.tasks = const [],
  });

  final String date;
  final int count;
  final List<Task> tasks;

  factory ReviewDay.fromJson(Map<String, dynamic> json) {
    final rawTasks = json['tasks'] as List<dynamic>? ?? const [];
    return ReviewDay(
      date: json['date'] as String,
      count: (json['count'] as num?)?.toInt() ?? 0,
      tasks: rawTasks
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MonthReview {
  MonthReview({
    required this.year,
    required this.month,
    required this.completedCount,
    required this.activeDays,
    required this.days,
  });

  final int year;
  final int month;
  final int completedCount;
  final int activeDays;
  final List<ReviewDay> days;

  factory MonthReview.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      final now = DateTime.now();
      return MonthReview(
        year: now.year,
        month: now.month,
        completedCount: 0,
        activeDays: 0,
        days: const [],
      );
    }
    return MonthReview(
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      activeDays: (json['activeDays'] as num?)?.toInt() ?? 0,
      days: (json['days'] as List<dynamic>? ?? const [])
          .map((e) => ReviewDay.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Briefing {
  Briefing({
    required this.date,
    required this.todoCount,
    required this.focusCount,
    required this.doneCount,
    required this.archivedCount,
    required this.focusedTasks,
    required this.suggestedFocus,
    required this.completedToday,
    required this.completedYesterday,
    required this.pendingArchive,
    MonthReview? monthReview,
  })  : monthReview = monthReview ??
            MonthReview(
              year: DateTime.now().year,
              month: DateTime.now().month,
              completedCount: 0,
              activeDays: 0,
              days: const [],
            );

  final String date;
  final int todoCount;
  final int focusCount;
  final int doneCount;
  final int archivedCount;
  final List<Task> focusedTasks;
  final List<Task> suggestedFocus;
  final List<Task> completedToday;
  final List<Task> completedYesterday;
  final int pendingArchive;
  final MonthReview monthReview;

  factory Briefing.fromJson(Map<String, dynamic> json) {
    List<Task> list(dynamic raw) {
      return (raw as List<dynamic>)
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final counts = json['counts'] as Map<String, dynamic>;
    return Briefing(
      date: json['date'] as String,
      todoCount: counts['todo'] as int,
      focusCount: counts['focus'] as int,
      doneCount: counts['done'] as int,
      archivedCount: counts['archived'] as int,
      focusedTasks: list(json['focusedTasks']),
      suggestedFocus: list(json['suggestedFocus']),
      completedToday: list(json['completedToday']),
      completedYesterday: list(json['completedYesterday']),
      pendingArchive: json['pendingArchive'] as int,
      monthReview: MonthReview.fromJson(
        json['monthReview'] as Map<String, dynamic>?,
      ),
    );
  }
}
