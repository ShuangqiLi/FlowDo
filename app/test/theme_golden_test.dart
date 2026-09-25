import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/theme.dart';

void main() {
  testWidgets('four theme palettes remain visually stable', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CustomPaint(
          painter: _PalettePainter(),
          child: const SizedBox.expand(),
        ),
      ),
    );

    await expectLater(
      find.byType(CustomPaint),
      matchesGoldenFile('goldens/theme_palettes.png'),
    );
  });
}

class _PalettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cell = Size(size.width / 2, size.height / 2);
    for (var i = 0; i < AppThemeKey.values.length; i++) {
      final theme = buildAppTheme(AppThemeKey.values[i]);
      final extra = theme.extension<FlowDoColors>()!;
      final origin = Offset((i % 2) * cell.width, (i ~/ 2) * cell.height);
      canvas.drawRect(
        origin & cell,
        Paint()..color = theme.scaffoldBackgroundColor,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(origin.dx + 24, origin.dy + 24, 152, 152),
          const Radius.circular(20),
        ),
        Paint()..color = extra.card,
      );
      canvas.drawCircle(
        origin + const Offset(72, 72),
        28,
        Paint()..color = theme.colorScheme.primary,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(origin.dx + 48, origin.dy + 116, 104, 28),
          const Radius.circular(14),
        ),
        Paint()..color = theme.colorScheme.primaryContainer,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
