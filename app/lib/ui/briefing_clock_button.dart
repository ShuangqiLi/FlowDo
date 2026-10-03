import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/location.dart';
import '../providers.dart';
import '../theme.dart';

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.label,
    required this.icon,
    required this.minC,
    required this.maxC,
  });

  final String label;
  final IconData icon;
  final int minC;
  final int maxC;

  String get rangeLabel => '$minC~$maxC°';
}

/// 右上角：天气进今日看看；打开后换成叉。
class BriefingClockButton extends ConsumerWidget {
  const BriefingClockButton({
    super.key,
    required this.open,
    required this.onPressed,
  });

  final bool open;
  final VoidCallback onPressed;

  /// 测试里关掉每秒刷新，否则 [pumpAndSettle] 永远等不到空闲。
  static bool tick = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final snap = ref.watch(weatherProvider).asData?.value;
    final tooltip = open ? '关掉今日看看' : '今日看看';

    return IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        style: const ButtonStyle(
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          minimumSize: WidgetStatePropertyAll(Size(44, 44)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: open
            ? Icon(
                Icons.close_rounded,
                color: scheme.onSurface,
                semanticLabel: tooltip,
              )
            : Icon(
                snap?.icon ?? Icons.wb_cloudy_outlined,
                color: scheme.onSurface,
                semanticLabel: snap == null
                    ? tooltip
                    : '${snap.label} ${snap.rangeLabel}',
              ),
      );
  }
}

/// 今日看看第一行：左边时间，右边天气和温度。
class BriefingNowRow extends ConsumerStatefulWidget {
  const BriefingNowRow({super.key});

  @override
  ConsumerState<BriefingNowRow> createState() => _BriefingNowRowState();
}

class _BriefingNowRowState extends ConsumerState<BriefingNowRow> {
  late DateTime _now;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    if (BriefingClockButton.tick) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          return;
        }
        setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final snap = ref.watch(weatherProvider).asData?.value;
    final stamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(_now);
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
          height: 1.2,
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            stamp,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (snap != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(
            snap.icon,
            size: 20,
            color: scheme.onSurface,
            semanticLabel: '${snap.label} ${snap.rangeLabel}',
          ),
          const SizedBox(width: 4),
          Text(
            '${snap.label} ${snap.rangeLabel}',
            style: style,
          ),
        ],
      ],
    );
  }
}

final weatherProvider =
    AsyncNotifierProvider<WeatherController, WeatherSnapshot?>(
  WeatherController.new,
);

class WeatherController extends AsyncNotifier<WeatherSnapshot?> {
  @override
  Future<WeatherSnapshot?> build() async {
    final prefs = ref.watch(prefsProvider);
    final cached = _readWeatherCache(prefs);
    if (cached != null) {
      unawaited(refresh());
      return cached;
    }
    return _fetchWeather(prefs);
  }

  Future<void> refresh() async {
    final prefs = ref.read(prefsProvider);
    final next = await _fetchWeather(prefs);
    if (next != null) {
      state = AsyncData(next);
    }
  }
}

Future<WeatherSnapshot?> _fetchWeather(SharedPreferences prefs) async {
  try {
    final location = await _resolveLocation();
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': location.$1.toString(),
      'longitude': location.$2.toString(),
      'current': 'weather_code',
      'daily': 'temperature_2m_max,temperature_2m_min',
      'forecast_days': '1',
      'timezone': 'auto',
    });
    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>?;
    final daily = json['daily'] as Map<String, dynamic>?;
    if (current == null || daily == null) {
      return null;
    }
    final code = (current['weather_code'] as num?)?.toInt();
    final maxList = daily['temperature_2m_max'];
    final minList = daily['temperature_2m_min'];
    final maxC = maxList is List && maxList.isNotEmpty
        ? (maxList.first as num?)?.round()
        : null;
    final minC = minList is List && minList.isNotEmpty
        ? (minList.first as num?)?.round()
        : null;
    if (code == null || maxC == null || minC == null) {
      return null;
    }
    final snap = WeatherSnapshot(
      label: weatherLabel(code),
      icon: weatherIcon(code),
      minC: minC,
      maxC: maxC,
    );
    await _writeWeatherCache(prefs, code: code, minC: minC, maxC: maxC);
    return snap;
  } catch (_) {
    return null;
  }
}

const _weatherCacheKey = 'weatherCache.v1';

WeatherSnapshot? _readWeatherCache(SharedPreferences prefs) {
  final raw = prefs.getString(_weatherCacheKey);
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final code = (json['code'] as num?)?.toInt();
    final minC = (json['minC'] as num?)?.toInt();
    final maxC = (json['maxC'] as num?)?.toInt();
    final day = json['day'] as String?;
    if (code == null || minC == null || maxC == null || day == null) {
      return null;
    }
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (day != today) {
      return null;
    }
    return WeatherSnapshot(
      label: weatherLabel(code),
      icon: weatherIcon(code),
      minC: minC,
      maxC: maxC,
    );
  } catch (_) {
    return null;
  }
}

Future<void> _writeWeatherCache(
  SharedPreferences prefs, {
  required int code,
  required int minC,
  required int maxC,
}) {
  final payload = jsonEncode({
    'code': code,
    'minC': minC,
    'maxC': maxC,
    'day': DateFormat('yyyy-MM-dd').format(DateTime.now()),
  });
  return prefs.setString(_weatherCacheKey, payload);
}

Future<(double, double)> _resolveLocation() async {
  try {
    final coords = await readDeviceLocation();
    if (coords != null) {
      return coords;
    }
  } catch (_) {
    // 浏览器不给定位就用 IP 大概位置。
  }
  try {
    final response = await http
        .get(
          Uri.parse('https://ipapi.co/json/'),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final lat = (json['latitude'] as num?)?.toDouble();
      final lon = (json['longitude'] as num?)?.toDouble();
      if (lat != null && lon != null) {
        return (lat, lon);
      }
    }
  } catch (_) {
    // 最后退回北京，总比一片空白好。
  }
  return (39.9042, 116.4074);
}

@visibleForTesting
IconData weatherIcon(int code) {
  return switch (code) {
    0 => Icons.wb_sunny_rounded,
    1 || 2 => Icons.wb_cloudy_outlined,
    3 => Icons.cloud_rounded,
    45 || 48 => Icons.blur_on_rounded,
    51 || 53 || 55 || 56 || 57 => Icons.grain_rounded,
    61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => Icons.water_drop_rounded,
    71 || 73 || 75 || 77 || 85 || 86 => Icons.ac_unit_rounded,
    95 || 96 || 99 => Icons.thunderstorm_rounded,
    _ => Icons.cloud_outlined,
  };
}

@visibleForTesting
String weatherLabel(int code) {
  return switch (code) {
    0 => '晴',
    1 || 2 => '少云',
    3 => '阴',
    45 || 48 => '雾',
    51 || 53 || 55 => '毛毛雨',
    56 || 57 => '冻雨',
    61 || 63 || 65 => '雨',
    66 || 67 => '冻雨',
    71 || 73 || 75 || 77 => '雪',
    80 || 81 || 82 => '阵雨',
    85 || 86 => '阵雪',
    95 => '雷雨',
    96 || 99 => '冰雹',
    _ => '天气',
  };
}
