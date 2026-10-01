class Reminder {
  Reminder({
    required this.id,
    required this.title,
    this.note,
    required this.calendar,
    required this.recurrence,
    required this.kind,
    required this.nextDate,
    this.lunarMonth,
    this.lunarDay,
    this.leapMonth = false,
    this.lunarText,
  });

  final String id;
  final String title;
  final String? note;
  final String calendar;
  final String recurrence;
  final String kind;
  final String nextDate;
  final int? lunarMonth;
  final int? lunarDay;
  final bool leapMonth;
  final String? lunarText;

  String get whenLabel {
    if (calendar == 'LUNAR' && lunarText != null) {
      return lunarText!;
    }
    return nextDate;
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String,
      title: json['title'] as String,
      note: json['note'] as String?,
      calendar: (json['calendar'] as String?) ?? 'SOLAR',
      recurrence: (json['recurrence'] as String?) ?? 'NONE',
      kind: (json['kind'] as String?) ?? 'NORMAL',
      nextDate: json['nextDate'] as String,
      lunarMonth: (json['lunarMonth'] as num?)?.toInt(),
      lunarDay: (json['lunarDay'] as num?)?.toInt(),
      leapMonth: (json['leapMonth'] as bool?) ?? false,
      lunarText: json['lunarText'] as String?,
    );
  }
}

class DayReminder {
  DayReminder({
    required this.id,
    required this.title,
    required this.kind,
    required this.calendar,
  });

  final String id;
  final String title;
  final String kind;
  final String calendar;

  factory DayReminder.fromJson(Map<String, dynamic> json) {
    return DayReminder(
      id: json['id'] as String,
      title: json['title'] as String,
      kind: (json['kind'] as String?) ?? 'NORMAL',
      calendar: (json['calendar'] as String?) ?? 'SOLAR',
    );
  }
}
