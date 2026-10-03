class CronFields {
  const CronFields({
    required this.minute,
    required this.hour,
    required this.day,
    required this.month,
    required this.weekday,
  });

  final List<bool> minute;
  final List<bool> hour;
  final List<bool> day;
  final List<bool> month;
  final List<bool> weekday;
}

class CronParseException implements Exception {
  CronParseException(this.message);
  final String message;

  @override
  String toString() => message;
}

List<bool> _parsePart(String part, int min, int max, String name) {
  final allowed = List<bool>.filled(max + 1, false);
  if (part == '*' || part == '?') {
    for (var i = min; i <= max; i++) {
      allowed[i] = true;
    }
    return allowed;
  }
  for (final item in part.split(',')) {
    if (item.isEmpty) {
      throw CronParseException('crontab 的$name不太对');
    }
    final bits = item.split('/');
    final step = bits.length == 1 ? 1 : int.tryParse(bits[1]);
    if (step == null || step < 1) {
      throw CronParseException('crontab 的$name不太对');
    }
    final rangeRaw = bits[0];
    late final int start;
    late final int end;
    if (rangeRaw == '*') {
      start = min;
      end = max;
    } else if (rangeRaw.contains('-')) {
      final range = rangeRaw.split('-');
      if (range.length != 2) {
        throw CronParseException('crontab 的$name不太对');
      }
      start = int.tryParse(range[0]) ?? -1;
      end = int.tryParse(range[1]) ?? -1;
    } else {
      start = int.tryParse(rangeRaw) ?? -1;
      end = start;
    }
    if (start < min || end > max || start > end) {
      throw CronParseException('crontab 的$name不太对');
    }
    for (var value = start; value <= end; value += step) {
      allowed[value] = true;
    }
  }
  return allowed;
}

bool _allSet(List<bool> flags, int min, int max) {
  for (var i = min; i <= max; i++) {
    if (!flags[i]) {
      return false;
    }
  }
  return true;
}

CronFields parseCron(String raw) {
  final parts = raw.trim().split(RegExp(r'\s+'));
  if (parts.length != 5) {
    throw CronParseException('crontab 用五段：分 时 日 月 周');
  }
  return CronFields(
    minute: _parsePart(parts[0], 0, 59, '分'),
    hour: _parsePart(parts[1], 0, 23, '时'),
    day: _parsePart(parts[2], 1, 31, '日'),
    month: _parsePart(parts[3], 1, 12, '月'),
    weekday: _parsePart(parts[4], 0, 7, '周'),
  );
}

String normalizeCron(String raw) {
  final trimmed = raw.trim().split(RegExp(r'\s+')).join(' ');
  if (trimmed.isEmpty) {
    throw CronParseException('crontab 要写完整');
  }
  if (trimmed.length > 80) {
    throw CronParseException('crontab 太长啦');
  }
  parseCron(trimmed);
  return trimmed;
}

String? cronError(String raw) {
  try {
    normalizeCron(raw);
    return null;
  } on CronParseException catch (error) {
    return error.message;
  }
}

bool cronMatches(CronFields fields, DateTime local) {
  if (!fields.minute[local.minute] ||
      !fields.hour[local.hour] ||
      !fields.month[local.month]) {
    return false;
  }
  final weekday = local.weekday % 7;
  final weekdayHit = fields.weekday[weekday] || (weekday == 0 && fields.weekday[7]);
  final dayAny = _allSet(fields.day, 1, 31);
  final weekdayAny = _allSet(fields.weekday, 0, 7);
  if (dayAny && weekdayAny) {
    return true;
  }
  if (!dayAny && weekdayAny) {
    return fields.day[local.day];
  }
  if (dayAny && !weekdayAny) {
    return weekdayHit;
  }
  return fields.day[local.day] || weekdayHit;
}

DateTime nextCronOccurrence(String expr, DateTime from) {
  final fields = parseCron(expr);
  var cursor = DateTime(
    from.year,
    from.month,
    from.day,
    from.hour,
    from.minute,
  ).add(const Duration(minutes: 1));
  final limit = cursor.add(const Duration(days: 366 * 4));
  while (!cursor.isAfter(limit)) {
    if (cronMatches(fields, cursor)) {
      return cursor;
    }
    cursor = cursor.add(const Duration(minutes: 1));
  }
  throw CronParseException('crontab 找不到下一次');
}
