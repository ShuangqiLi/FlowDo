import 'task.dart';

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
    required this.completedThisWeek,
    required this.pendingArchive,
  });

  final String date;
  final int todoCount;
  final int focusCount;
  final int doneCount;
  final int archivedCount;
  final List<Task> focusedTasks;
  final List<Task> suggestedFocus;
  final List<Task> completedToday;
  final List<Task> completedYesterday;
  final List<Task> completedThisWeek;
  final int pendingArchive;

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
      completedThisWeek: list(json['completedThisWeek'] ?? []),
      pendingArchive: json['pendingArchive'] as int,
    );
  }
}
