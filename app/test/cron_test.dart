import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/utils/cron.dart';

void main() {
  test('normalizes and rejects bad crontab', () {
    expect(normalizeCron('  0  9 * * 1-5 '), '0 9 * * 1-5');
    expect(cronError('0 9 * *'), contains('五段'));
    expect(cronError('99 9 * * *'), contains('分'));
  });

  test('finds the next weekday morning', () {
    final fridayNight = DateTime(2026, 10, 2, 23, 0);
    final next = nextCronOccurrence('0 9 * * 1-5', fridayNight);
    expect(next, DateTime(2026, 10, 5, 9, 0));
  });
}
