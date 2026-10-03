import 'task.dart';

class ReviewDay {
  ReviewDay({
    required this.date,
    required this.count,
    this.tasks = const [],
    this.reminders = const [],
  });

  final String date;
  final int count;
  final List<Task> tasks;
  final List<Task> reminders;

  factory ReviewDay.fromJson(Map<String, dynamic> json) {
    List<Task> readTasks(String key) {
      final raw = json[key] as List<dynamic>? ?? const [];
      return raw.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
    }

    return ReviewDay(
      date: json['date'] as String,
      count: (json['count'] as num?)?.toInt() ?? 0,
      tasks: readTasks('tasks'),
      reminders: readTasks('reminders'),
    );
  }
}

class MonthSpaceReview {
  MonthSpaceReview({
    required this.id,
    required this.name,
    required this.themeKey,
    required this.completedCount,
    required this.activeDays,
  });

  final String id;
  final String name;
  final String themeKey;
  final int completedCount;
  final int activeDays;

  factory MonthSpaceReview.fromJson(Map<String, dynamic> json) {
    return MonthSpaceReview(
      id: json['id'] as String,
      name: json['name'] as String,
      themeKey: (json['themeKey'] as String?) ?? 'mint',
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      activeDays: (json['activeDays'] as num?)?.toInt() ?? 0,
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
    this.spaces = const [],
  });

  final int year;
  final int month;
  final int completedCount;
  final int activeDays;
  final List<ReviewDay> days;
  final List<MonthSpaceReview> spaces;

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
      spaces: (json['spaces'] as List<dynamic>? ?? const [])
          .map((e) => MonthSpaceReview.fromJson(e as Map<String, dynamic>))
          .toList(),
      days: (json['days'] as List<dynamic>? ?? const [])
          .map((e) => ReviewDay.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SpaceBriefing {
  SpaceBriefing({
    required this.id,
    required this.name,
    required this.themeKey,
    required this.todo,
    required this.focus,
    required this.done,
    required this.archived,
    required this.reminders,
    required this.completedToday,
    required this.completedYesterday,
  });

  final String id;
  final String name;
  final String themeKey;
  final int todo;
  final int focus;
  final int done;
  final int archived;
  final int reminders;
  final int completedToday;
  final int completedYesterday;

  int get total => todo + focus + done + archived;

  factory SpaceBriefing.fromJson(Map<String, dynamic> json) {
    return SpaceBriefing(
      id: json['id'] as String,
      name: json['name'] as String,
      themeKey: (json['themeKey'] as String?) ?? 'mint',
      todo: (json['todo'] as num?)?.toInt() ?? 0,
      focus: (json['focus'] as num?)?.toInt() ?? 0,
      done: (json['done'] as num?)?.toInt() ?? 0,
      archived: (json['archived'] as num?)?.toInt() ?? 0,
      reminders: (json['reminders'] as num?)?.toInt() ?? 0,
      completedToday: (json['completedToday'] as num?)?.toInt() ?? 0,
      completedYesterday: (json['completedYesterday'] as num?)?.toInt() ?? 0,
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
    this.reminderCount = 0,
    required this.focusedTasks,
    required this.suggestedFocus,
    required this.completedToday,
    required this.completedYesterday,
    required this.pendingArchive,
    this.spaces = const [],
    int? totalCount,
    MonthReview? monthReview,
  })  : totalCount =
            totalCount ?? todoCount + focusCount + doneCount + archivedCount,
        monthReview = monthReview ??
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
  final int reminderCount;
  final int totalCount;
  final List<Task> focusedTasks;
  final List<Task> suggestedFocus;
  final List<Task> completedToday;
  final List<Task> completedYesterday;
  final int pendingArchive;
  final List<SpaceBriefing> spaces;
  final MonthReview monthReview;

  factory Briefing.fromJson(Map<String, dynamic> json) {
    List<Task> list(dynamic raw) {
      return (raw as List<dynamic>)
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final counts = json['counts'] as Map<String, dynamic>;
    final todo = (counts['todo'] as num?)?.toInt() ?? 0;
    final focus = (counts['focus'] as num?)?.toInt() ?? 0;
    final done = (counts['done'] as num?)?.toInt() ?? 0;
    final archived = (counts['archived'] as num?)?.toInt() ?? 0;
    return Briefing(
      date: json['date'] as String,
      todoCount: todo,
      focusCount: focus,
      doneCount: done,
      archivedCount: archived,
      reminderCount: (counts['reminders'] as num?)?.toInt() ?? 0,
      totalCount:
          (counts['total'] as num?)?.toInt() ?? todo + focus + done + archived,
      focusedTasks: list(json['focusedTasks']),
      suggestedFocus: list(json['suggestedFocus']),
      completedToday: list(json['completedToday']),
      completedYesterday: list(json['completedYesterday']),
      pendingArchive: json['pendingArchive'] as int,
      spaces: (json['spaces'] as List<dynamic>? ?? const [])
          .map((e) => SpaceBriefing.fromJson(e as Map<String, dynamic>))
          .toList(),
      monthReview: MonthReview.fromJson(
        json['monthReview'] as Map<String, dynamic>?,
      ),
    );
  }
}
