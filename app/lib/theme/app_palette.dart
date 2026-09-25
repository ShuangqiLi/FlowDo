import 'package:flutter/material.dart';

enum AppThemeKey {
  mint('mint', '闲云', Color(0xFF5F9B82)),
  hazeBlue('hazeBlue', '远山', Color(0xFF5B82A8)),
  warmOrange('warmOrange', '归途', Color(0xFFC4895A)),
  lightPurple('lightPurple', '微光', Color(0xFF8A7BA5));

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

class FlowDoColors extends ThemeExtension<FlowDoColors> {
  const FlowDoColors({
    required this.canvas,
    required this.card,
    required this.softFill,
    required this.success,
    required this.highPriority,
    required this.mediumPriority,
    required this.lowPriority,
  });

  final Color canvas;
  final Color card;
  final Color softFill;
  final Color success;
  final Color highPriority;
  final Color mediumPriority;
  final Color lowPriority;

  Color priority(String priority) => switch (priority) {
        'HIGH' => highPriority,
        'LOW' => lowPriority,
        _ => mediumPriority,
      };

  @override
  FlowDoColors copyWith({
    Color? canvas,
    Color? card,
    Color? softFill,
    Color? success,
    Color? highPriority,
    Color? mediumPriority,
    Color? lowPriority,
  }) {
    return FlowDoColors(
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      softFill: softFill ?? this.softFill,
      success: success ?? this.success,
      highPriority: highPriority ?? this.highPriority,
      mediumPriority: mediumPriority ?? this.mediumPriority,
      lowPriority: lowPriority ?? this.lowPriority,
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
      highPriority: Color.lerp(highPriority, other.highPriority, t)!,
      mediumPriority: Color.lerp(mediumPriority, other.mediumPriority, t)!,
      lowPriority: Color.lerp(lowPriority, other.lowPriority, t)!,
    );
  }
}

extension FlowDoTheme on BuildContext {
  FlowDoColors get flowColors => Theme.of(this).extension<FlowDoColors>()!;
}
