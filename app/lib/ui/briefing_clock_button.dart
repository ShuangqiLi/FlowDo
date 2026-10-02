import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../platform/location.dart';

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.label,
    required this.icon,
    required this.temperatureC,
  });

  final String label;
  final IconData icon;
  final int temperatureC;
}

/// 右上角：实时日期时间和天气，点开今日看看。
class BriefingClockButton extends ConsumerStatefulWidget {
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
  ConsumerState<BriefingClockButton> createState() =>
      _BriefingClockButtonState();
}

class _BriefingClockButtonState extends ConsumerState<BriefingClockButton> {
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
    final weather = ref.watch(weatherProvider);
    final scheme = Theme.of(context).colorScheme;
    final stamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(_now);
    final snap = weather.asData?.value;

    return Tooltip(
      message: widget.open ? '关掉今日看看' : '今日看看',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(12),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stamp,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                          height: 1.1,
                        ),
                  ),
                  if (snap != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          snap.icon,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                          semanticLabel: '${snap.label} ${snap.temperatureC}°',
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${snap.temperatureC}°',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.1,
                              ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final weatherProvider = FutureProvider<WeatherSnapshot?>((ref) async {
  try {
    final location = await _resolveLocation();
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': location.$1.toString(),
      'longitude': location.$2.toString(),
      'current': 'temperature_2m,weather_code',
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
    if (current == null) {
      return null;
    }
    final temp = (current['temperature_2m'] as num?)?.round();
    final code = (current['weather_code'] as num?)?.toInt();
    if (temp == null || code == null) {
      return null;
    }
    return WeatherSnapshot(
      label: weatherLabel(code),
      icon: weatherIcon(code),
      temperatureC: temp,
    );
  } catch (_) {
    return null;
  }
});

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
