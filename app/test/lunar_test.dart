import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/utils/lunar.dart';

void main() {
  test('converts mid-autumn 2026', () {
    final lunar = solarToLunar(2026, 9, 25);
    expect(lunar, isNotNull);
    expect(lunar!.month, 8);
    expect(lunar.day, 15);
    expect(lunar.leap, isFalse);
    expect(lunarDateLabel(lunar), '八月十五');
    expect(lunarCellLabel(2026, 9, 25), '八月十五');
  });

  test('converts spring festival 2026', () {
    expect(lunarCellLabel(2026, 2, 17), '正月初一');
  });
}
