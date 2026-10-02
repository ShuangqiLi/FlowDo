import 'package:flowdo/models/task.dart';
import 'package:flowdo/models/user.dart';
import 'package:flowdo/providers.dart';

/// 测试里塞一份固定的 /me，避免 AsyncNotifier 去打真接口。
class FixedMeController extends MeController {
  FixedMeController(this.me);

  final Me me;

  @override
  Future<Me> build() async => me;
}

meOverride(Me me) => meProvider.overrideWith(() => FixedMeController(me));

class EmptyTasksController extends TasksController {
  EmptyTasksController(super.status);

  @override
  Future<List<Task>> build() async => const [];
}

emptyTasksOverride() => tasksProvider.overrideWith2(EmptyTasksController.new);
