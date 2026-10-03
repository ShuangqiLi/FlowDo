import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/models/notice.dart';
import 'package:flowdo/theme.dart';
import 'package:flowdo/ui/notice_button.dart';
import 'package:flowdo/widgets/priority_selector.dart';

void main() {
  testWidgets('notice panel shows the title, time and a red capsule clear button',
      (tester) async {
    var cleared = false;
    final theme = buildAppTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: NoticePanel(
            notices: [
              Notice(
                id: '1',
                title: '浇花',
                message: '到点了，已经放进聚焦',
                createdAt: DateTime(2026, 10, 3, 22, 17),
              ),
            ],
            onOpen: (_) {},
            onClear: () => cleared = true,
          ),
        ),
      ),
    );

    expect(find.text('浇花'), findsOneWidget);
    expect(find.text('10月3日 22:17'), findsOneWidget);
    expect(find.text('到点了，已经放进聚焦'), findsNothing);
    expect(find.byType(PriorityBadge), findsNothing);

    final button =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '清空'));
    expect(button.style?.shape?.resolve({}), isA<StadiumBorder>());
    expect(
      button.style?.backgroundColor?.resolve({}),
      theme.colorScheme.error,
    );
    expect(
      button.style?.foregroundColor?.resolve({}),
      theme.colorScheme.onError,
    );

    await tester.tap(find.text('清空'));
    expect(cleared, isTrue);
  });

  testWidgets('empty notice panel says 暂无通知', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: NoticePanel(
            notices: [],
            onOpen: _noopOpen,
            onClear: _noopClear,
          ),
        ),
      ),
    );

    expect(find.text('暂无通知'), findsOneWidget);
    expect(find.text('还没有通知'), findsNothing);
    expect(find.text('清空'), findsNothing);
  });
}

void _noopOpen(Notice notice) {}

void _noopClear() {}
