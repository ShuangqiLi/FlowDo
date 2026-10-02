/// 往聚焦里送任务时占名额。
///
/// 名单还在路上、或者上一条请求还没回来时，后来的滑动也要排在后面数，
/// 不能各自拿一份旧数量把上限冲破。
class FocusAdmission {
  final Set<String> _pending = {};
  Future<void> _tail = Future<void>.value();

  Future<bool> tryAdmit({
    required String taskId,
    required int limit,
    required Future<List<String>> Function() focusedIds,
  }) {
    final result = _tail.then((_) => _admit(taskId, limit, focusedIds));
    _tail = result.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    return result;
  }

  void release(String taskId) {
    _pending.remove(taskId);
  }

  Future<bool> _admit(
    String taskId,
    int limit,
    Future<List<String>> Function() focusedIds,
  ) async {
    List<String> ids;
    var known = true;
    try {
      ids = await focusedIds();
    } catch (_) {
      ids = const [];
      known = false;
    }
    final have = ids.toSet();
    final extra = _pending.where((id) => !have.contains(id)).length;
    final used = known ? have.length + extra : extra;
    if (used >= limit) {
      return false;
    }
    _pending.add(taskId);
    return true;
  }
}
