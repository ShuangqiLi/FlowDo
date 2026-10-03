import 'package:flowdo/ui/calendar_tally.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reminder flags cap at three plus a plus sign', () {
    expect(reminderTally(0), isEmpty);
    expect(reminderTally(1), [CalendarTallyMark.flag]);
    expect(reminderTally(3), [
      CalendarTallyMark.flag,
      CalendarTallyMark.flag,
      CalendarTallyMark.flag,
    ]);
    expect(reminderTally(4), [
      CalendarTallyMark.flag,
      CalendarTallyMark.flag,
      CalendarTallyMark.flag,
      CalendarTallyMark.plus,
    ]);
    expect(reminderTally(9), hasLength(4));
  });

  test('completions combine dots into stars and stars into one crown', () {
    expect(completionTally(0), isEmpty);
    expect(completionTally(2), [
      CalendarTallyMark.dot,
      CalendarTallyMark.dot,
    ]);
    expect(completionTally(3), [CalendarTallyMark.star]);
    expect(completionTally(5), [
      CalendarTallyMark.star,
      CalendarTallyMark.dot,
      CalendarTallyMark.dot,
    ]);
    expect(completionTally(8), [
      CalendarTallyMark.star,
      CalendarTallyMark.star,
      CalendarTallyMark.dot,
      CalendarTallyMark.dot,
    ]);
    expect(completionTally(9), [CalendarTallyMark.crown]);
    expect(completionTally(20), [CalendarTallyMark.crown]);
    expect(completionTally(8), hasLength(4));
  });
}
