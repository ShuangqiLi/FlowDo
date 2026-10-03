import 'package:flutter/material.dart';

enum AppThemeKey {
  mint('mint', '闲云', Color(0xFF5F9B82)),
  hazeBlue('hazeBlue', '远山', Color(0xFF5B82A8)),
  warmOrange('warmOrange', '归途', Color(0xFF8E6E58)),
  lightPurple('lightPurple', '微光', Color(0xFF8A7BA5)),
  willowOlive('willowOlive', '柳烟', Color(0xFF7E8A58)),
  nightIndigo('nightIndigo', '夜泊', Color(0xFF58567A)),
  mistPlum('mistPlum', '雾梅', Color(0xFF8E6A80));

  const AppThemeKey(this.key, this.label, this.preview);

  final String key;
  final String label;
  final Color preview;

  static AppThemeKey fromKey(String? key) {
    for (final value in values) {
      if (value.key == key) return value;
    }
    return mint;
  }
}

/// 五种任务卡片共用、不跟主题走的低饱和色。
abstract final class FlowDoPriorityPalette {
  static const high = Color(0xFFB0686C);
  static const medium = Color(0xFFC4895A);
  static const low = Color(0xFF3E8288);
  static const none = Color(0xFF85827C);
  static const reminder = Color(0xFFC4A86C);
}

class FlowDoColors extends ThemeExtension<FlowDoColors> {
  const FlowDoColors({
    required this.canvas,
    required this.card,
    required this.softFill,
    required this.success,
    required this.themeAccent,
    required this.highPriority,
    required this.mediumPriority,
    required this.lowPriority,
    required this.nonePriority,
    required this.reminder,
  });

  final Color canvas;
  final Color card;
  final Color softFill;
  final Color success;
  final Color themeAccent;
  final Color highPriority;
  final Color mediumPriority;
  final Color lowPriority;
  final Color nonePriority;

  /// 浅橙黄，和中优先级杏橙靠色相和明度分开。
  final Color reminder;

  Color priority(String priority) => switch (priority) {
        'HIGH' => highPriority,
        'MEDIUM' => mediumPriority,
        'LOW' => lowPriority,
        'REMINDER' => reminder,
        _ => nonePriority,
      };

  @override
  FlowDoColors copyWith({
    Color? canvas,
    Color? card,
    Color? softFill,
    Color? success,
    Color? themeAccent,
    Color? highPriority,
    Color? mediumPriority,
    Color? lowPriority,
    Color? nonePriority,
    Color? reminder,
  }) {
    return FlowDoColors(
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      softFill: softFill ?? this.softFill,
      success: success ?? this.success,
      themeAccent: themeAccent ?? this.themeAccent,
      highPriority: highPriority ?? this.highPriority,
      mediumPriority: mediumPriority ?? this.mediumPriority,
      lowPriority: lowPriority ?? this.lowPriority,
      nonePriority: nonePriority ?? this.nonePriority,
      reminder: reminder ?? this.reminder,
    );
  }

  @override
  FlowDoColors lerp(covariant FlowDoColors? other, double t) {
    if (other == null) return this;
    return FlowDoColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      card: Color.lerp(card, other.card, t)!,
      softFill: Color.lerp(softFill, other.softFill, t)!,
      success: Color.lerp(success, other.success, t)!,
      themeAccent: Color.lerp(themeAccent, other.themeAccent, t)!,
      highPriority: Color.lerp(highPriority, other.highPriority, t)!,
      mediumPriority: Color.lerp(mediumPriority, other.mediumPriority, t)!,
      lowPriority: Color.lerp(lowPriority, other.lowPriority, t)!,
      nonePriority: Color.lerp(nonePriority, other.nonePriority, t)!,
      reminder: Color.lerp(reminder, other.reminder, t)!,
    );
  }
}

extension FlowDoTheme on BuildContext {
  FlowDoColors get flowColors => Theme.of(this).extension<FlowDoColors>()!;
}
