import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/utils/speech_text.dart';

void main() {
  test('drops the punctuation the recognizer appends', () {
    expect(stripTrailingPunctuation('下午三点给猫剪指甲。'), '下午三点给猫剪指甲');
    expect(stripTrailingPunctuation('要买猫粮吗？'), '要买猫粮吗');
    expect(stripTrailingPunctuation('Buy cat food.'), 'Buy cat food');
    expect(stripTrailingPunctuation('记得交房租！！'), '记得交房租');
    expect(stripTrailingPunctuation('周五复盘 。 '), '周五复盘');
  });

  test('keeps punctuation inside the sentence', () {
    expect(stripTrailingPunctuation('买菜、做饭。'), '买菜、做饭');
    expect(stripTrailingPunctuation('问一下 3.5 寸的盘'), '问一下 3.5 寸的盘');
  });

  test('handles empty and punctuation-only results', () {
    expect(stripTrailingPunctuation(''), '');
    expect(stripTrailingPunctuation('。。。'), '');
  });
}
