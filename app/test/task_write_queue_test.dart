import 'dart:async';

import 'package:flowdo/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writes to the same task run one after another, even when the first is slow', () async {
    final queue = TaskWriteQueue();
    final order = <String>[];
    final slowFocus = Completer<String>();

    final first = queue.run('t1', () async {
      order.add('focus:start');
      final result = await slowFocus.future;
      order.add('focus:end');
      return result;
    });
    final second = queue.run('t1', () async {
      order.add('done');
      return 'DONE';
    });

    await Future<void>.delayed(Duration.zero);
    expect(order, ['focus:start']);

    slowFocus.complete('FOCUS');
    expect(await first, 'FOCUS');
    expect(await second, 'DONE');
    expect(order, ['focus:start', 'focus:end', 'done']);
  });

  test('a failed write does not block the next one', () async {
    final queue = TaskWriteQueue();
    final failed = queue.run<void>('t1', () async => throw StateError('boom'));
    await expectLater(failed, throwsStateError);
    expect(await queue.run('t1', () async => 'ok'), 'ok');
  });

  test('different tasks do not wait for each other', () async {
    final queue = TaskWriteQueue();
    final block = Completer<void>();
    final order = <String>[];
    final a = queue.run('a', () async {
      await block.future;
      order.add('a');
    });
    final b = queue.run('b', () async => order.add('b'));
    await b;
    expect(order, ['b']);
    block.complete();
    await a;
    expect(order, ['b', 'a']);
  });
}
