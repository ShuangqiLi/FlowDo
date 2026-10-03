/// 月历格子里的完成件数和提醒件数，压成最多 4 个符号。
enum CalendarTallyMark { flag, plus, dot, star, crown }

class SpaceDaySlice {
  const SpaceDaySlice({
    required this.spaceId,
    required this.themeKey,
    required this.reminderCount,
    required this.completedCount,
  });

  final String spaceId;
  final String themeKey;
  final int reminderCount;
  final int completedCount;

  List<CalendarTallyMark> get flags => reminderTally(reminderCount);
  List<CalendarTallyMark> get completions => completionTally(completedCount);

  int get glyphRows =>
      (reminderCount > 0 ? 1 : 0) + (completedCount > 0 ? 1 : 0);
}

/// 按空间拆开，完成件数各自合成，不跨空间合并。
List<SpaceDaySlice> spaceDaySlices({
  required List<String> spaceOrder,
  required Map<String, String> themeBySpace,
  required Map<String, int> reminders,
  required Map<String, int> completed,
}) {
  final seen = <String>{};
  final ids = <String>[
    for (final id in spaceOrder)
      if (seen.add(id)) id,
    for (final id in [...reminders.keys, ...completed.keys])
      if (seen.add(id)) id,
  ];
  return [
    for (final id in ids)
      if ((reminders[id] ?? 0) > 0 || (completed[id] ?? 0) > 0)
        SpaceDaySlice(
          spaceId: id,
          themeKey: themeBySpace[id] ?? 'mint',
          reminderCount: reminders[id] ?? 0,
          completedCount: completed[id] ?? 0,
        ),
  ];
}

/// 提醒：一面小旗一件。最多三面，再多在后面加一个加号。
List<CalendarTallyMark> reminderTally(int count) {
  if (count <= 0) {
    return const [];
  }
  if (count <= 3) {
    return List<CalendarTallyMark>.filled(count, CalendarTallyMark.flag);
  }
  return const [
    CalendarTallyMark.flag,
    CalendarTallyMark.flag,
    CalendarTallyMark.flag,
    CalendarTallyMark.plus,
  ];
}

/// 完成：3 个圆点合成星星，3 个星星合成皇冠。满 9 件只留一顶皇冠。
List<CalendarTallyMark> completionTally(int count) {
  if (count <= 0) {
    return const [];
  }
  if (count >= 9) {
    return const [CalendarTallyMark.crown];
  }
  final stars = count ~/ 3;
  final dots = count % 3;
  return [
    ...List<CalendarTallyMark>.filled(stars, CalendarTallyMark.star),
    ...List<CalendarTallyMark>.filled(dots, CalendarTallyMark.dot),
  ];
}
