/// 农历 1900–2100，和服务器同一张表。
const _lunarInfo = <int>[
  0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0,
  0x09ad0, 0x055d2, 0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540,
  0x0d6a0, 0x0ada2, 0x095b0, 0x14977, 0x04970, 0x0a4b0, 0x0b4b5, 0x06a50,
  0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970, 0x06566, 0x0d4a0,
  0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
  0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2,
  0x0a950, 0x0b557, 0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5d0, 0x14573,
  0x052d0, 0x0a9a8, 0x0e950, 0x06aa0, 0x0aea6, 0x0ab50, 0x04b60, 0x0aae4,
  0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0, 0x096d0, 0x04dd5,
  0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b5a0, 0x195a6,
  0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46,
  0x0ab60, 0x09570, 0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58,
  0x055c0, 0x0ab60, 0x096d5, 0x092e0, 0x0c960, 0x0d954, 0x0d4a0, 0x0da50,
  0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5, 0x0a950, 0x0b4a0,
  0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
  0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260,
  0x0ea65, 0x0d530, 0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0,
  0x1d0b6, 0x0d250, 0x0d520, 0x0dd45, 0x0b5a0, 0x056d0, 0x055b2, 0x049b0,
  0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0, 0x14b63, 0x09370,
  0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0,
  0x0a2e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0,
  0x0a6d0, 0x055d4, 0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50,
  0x055a0, 0x0aba4, 0x0a5b0, 0x052b0, 0x0b273, 0x06930, 0x07337, 0x06aa0,
  0x0ad50, 0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160, 0x0e968, 0x0d520,
  0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, 0x0d150, 0x0f252,
  0x0d520,
];

const _monthNames = [
  '正',
  '二',
  '三',
  '四',
  '五',
  '六',
  '七',
  '八',
  '九',
  '十',
  '冬',
  '腊',
];

const _dayNames = [
  '',
  '初一',
  '初二',
  '初三',
  '初四',
  '初五',
  '初六',
  '初七',
  '初八',
  '初九',
  '初十',
  '十一',
  '十二',
  '十三',
  '十四',
  '十五',
  '十六',
  '十七',
  '十八',
  '十九',
  '二十',
  '廿一',
  '廿二',
  '廿三',
  '廿四',
  '廿五',
  '廿六',
  '廿七',
  '廿八',
  '廿九',
  '三十',
];

class LunarDate {
  const LunarDate({
    required this.year,
    required this.month,
    required this.day,
    required this.leap,
  });

  final int year;
  final int month;
  final int day;
  final bool leap;
}

int _info(int year) {
  final index = year - 1900;
  if (index < 0 || index >= _lunarInfo.length) {
    return 0;
  }
  return _lunarInfo[index];
}

int leapMonth(int year) => _info(year) & 0xf;

int leapDays(int year) {
  if (leapMonth(year) == 0) {
    return 0;
  }
  return _info(year) & 0x10000 != 0 ? 30 : 29;
}

int lunarMonthDays(int year, int month) {
  if (month < 1 || month > 12) {
    return 0;
  }
  return _info(year) & (0x10000 >> month) != 0 ? 30 : 29;
}

int lunarYearDays(int year) {
  var sum = 348;
  for (var bit = 0x8000; bit > 0x8; bit >>= 1) {
    if (_info(year) & bit != 0) {
      sum += 1;
    }
  }
  return sum + leapDays(year);
}

int lunarMonthLength(int year, int month, bool leap) {
  if (leap) {
    return leapMonth(year) == month ? leapDays(year) : 0;
  }
  return lunarMonthDays(year, month);
}

LunarDate? solarToLunar(int year, int month, int day) {
  if (year < 1900 || year > 2100 || month < 1 || month > 12 || day < 1) {
    return null;
  }
  final offset = DateTime.utc(year, month, day)
      .difference(DateTime.utc(1900, 1, 31))
      .inDays;
  if (offset < 0) {
    return null;
  }
  var remain = offset;
  var y = 1900;
  var temp = 0;
  for (; y < 2101 && remain > 0; y++) {
    temp = lunarYearDays(y);
    remain -= temp;
  }
  if (remain < 0) {
    remain += temp;
    y -= 1;
  }
  final leap = leapMonth(y);
  var isLeap = false;
  var m = 1;
  for (; m < 13 && remain > 0; m++) {
    if (leap > 0 && m == leap + 1 && !isLeap) {
      m -= 1;
      isLeap = true;
      temp = leapDays(y);
    } else {
      temp = lunarMonthDays(y, m);
    }
    if (isLeap && m == leap + 1) {
      isLeap = false;
    }
    remain -= temp;
  }
  if (remain == 0 && leap > 0 && m == leap + 1) {
    if (isLeap) {
      isLeap = false;
    } else {
      isLeap = true;
      m -= 1;
    }
  }
  if (remain < 0) {
    remain += temp;
    m -= 1;
  }
  return LunarDate(year: y, month: m, day: remain + 1, leap: isLeap);
}

String lunarDateLabel(LunarDate lunar) {
  final month = '${lunar.leap ? '闰' : ''}${_monthNames[lunar.month - 1]}月';
  return '$month${_dayNames[lunar.day]}';
}

String lunarCellLabel(int year, int month, int day) {
  final lunar = solarToLunar(year, month, day);
  return lunar == null ? '' : lunarDateLabel(lunar);
}
