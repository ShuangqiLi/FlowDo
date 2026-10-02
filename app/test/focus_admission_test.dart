import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/ui/focus_admission.dart';

void main() {
  test('later swipes wait and see slots already taken', () async {
    final admission = FocusAdmission();
    final gate = Completer<List<String>>();
    final first = admission.tryAdmit(
      taskId: 'a',
      limit: 1,
      focusedIds: () => gate.future,
    );
    final second = admission.tryAdmit(
      taskId: 'b',
      limit: 1,
      focusedIds: () => gate.future,
    );
    gate.complete(const []);

    expect(await first, isTrue);
    expect(await second, isFalse);
  });

  test('a full list refuses before any request is sent', () async {
    final admission = FocusAdmission();
    final admitted = await admission.tryAdmit(
      taskId: 'next',
      limit: 3,
      focusedIds: () async => const ['a', 'b', 'c'],
    );
    expect(admitted, isFalse);
  });
}
