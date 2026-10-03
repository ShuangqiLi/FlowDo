import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowdo/api/api_client.dart';
import 'package:flowdo/models/space.dart';
import 'package:flowdo/models/user.dart';
import 'package:flowdo/providers.dart';
import 'package:flowdo/theme.dart';
import 'package:flowdo/ui/space_switcher.dart';
import 'provider_overrides.dart';

class _FakeApi extends ApiClient {
  _FakeApi(super.prefs, this.count);

  final int count;
  int deletes = 0;

  @override
  Future<int> spaceTaskCount(String id) async => count;

  @override
  Future<void> deleteSpace(String id) async {
    deletes += 1;
  }
}

Future<_FakeApi> _pump(
  WidgetTester tester, {
  required int count,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final api = _FakeApi(prefs, count);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        apiProvider.overrideWithValue(api),
        meOverride(
          Me(
            id: 'user',
            activeSpaceId: 'space-a',
            archiveAfterDays: 7,
            focusLimit: 3,
            deleteArchivedAfterDays: 30,
            showArchiveTab: false,
            themeKey: 'mint',
          ),
        ),
        spacesOverride([
          Space(id: 'space-a', name: '工作'),
          Space(id: 'space-b', name: '生活'),
        ]),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: SpaceSwitcher()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('deleting a space names how many tasks would be lost', (tester) async {
    final api = await _pump(tester, count: 4);

    await tester.tap(find.text('工作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除这个空间'));
    await tester.pumpAndSettle();

    expect(find.text('删掉「工作」？'), findsOneWidget);
    expect(find.text('当前空间里有 4 件任务，删除后无法找回。'), findsOneWidget);
    expect(api.deletes, 0);

    await tester.tap(find.text('先留着'));
    await tester.pumpAndSettle();
    expect(api.deletes, 0);
  });

  testWidgets('an empty space still warns that deletion cannot be undone',
      (tester) async {
    await _pump(tester, count: 0);

    await tester.tap(find.text('工作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除这个空间'));
    await tester.pumpAndSettle();

    expect(find.text('当前空间里没有任务，删除后无法找回。'), findsOneWidget);
  });
}
