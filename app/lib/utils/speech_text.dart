/// 系统识别引擎会自己补上句号、问号，任务标题不需要这个收尾。
const _trailingPunctuation = '。．.，,、；;：:！!？?…～~·　';

String stripTrailingPunctuation(String text) {
  var end = text.length;
  while (end > 0) {
    final char = text[end - 1];
    if (!_trailingPunctuation.contains(char) && char.trim().isNotEmpty) {
      break;
    }
    end--;
  }
  return text.substring(0, end);
}
