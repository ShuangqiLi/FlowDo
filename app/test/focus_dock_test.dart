import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/theme.dart';
import 'package:flowdo/ui/focus_dock.dart';

Future<void> _pumpDock(
  WidgetTester tester, {
  required HomeTab selected,
  required ValueChanged<HomeTab> onSelected,
  AppThemeKey theme = AppThemeKey.mint,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(theme),
      themeAnimationDuration: Duration.zero,
      home: Scaffold(
        bottomNavigationBar: FocusDock(
          tabs: homeTabsFor(showArchive: false),
          selected: selected,
          onSelected: onSelected,
        ),
      ),
    ),
  );
}

Color _fill(WidgetTester tester, HomeTab tab) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byKey(ValueKey(tab)),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  testWidgets('leaving a tab fades the same pill color instead of flashing',
      (tester) async {
    var selected = HomeTab.todo;
    await _pumpDock(
      tester,
      selected: selected,
      onSelected: (tab) => selected = tab,
    );

    await tester.tap(find.text('聚焦'));
    selected = HomeTab.focus;
    await _pumpDock(
      tester,
      selected: selected,
      onSelected: (tab) => selected = tab,
    );
    await tester.pump(const Duration(milliseconds: 40));

    final container = buildAppTheme().colorScheme.primaryContainer;
    final fading = _fill(tester, HomeTab.todo);
    expect((fading.r - container.r).abs(), lessThan(0.02));
    expect((fading.g - container.g).abs(), lessThan(0.02));
    expect((fading.b - container.b).abs(), lessThan(0.02));
    expect(fading.a, greaterThan(0.05));
    expect(fading.a, lessThan(0.95));
  });

  testWidgets('a new space theme recolors the selected pill immediately',
      (tester) async {
    await _pumpDock(
      tester,
      selected: HomeTab.todo,
      onSelected: (_) {},
    );
    await _pumpDock(
      tester,
      selected: HomeTab.todo,
      onSelected: (_) {},
      theme: AppThemeKey.warmOrange,
    );
    await tester.pump(const Duration(milliseconds: 40));

    final container =
        buildAppTheme(AppThemeKey.warmOrange).colorScheme.primaryContainer;
    final fill = _fill(tester, HomeTab.todo);
    expect(fill, container);
  });
}
