import 'package:copy_recipe/parser/amount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scaleAmount', () {
    test('倍率が 1 なら原文のまま', () {
      expect(scaleAmount('大さじ1・1/2', 1), '大さじ1・1/2');
    });

    test('重さ・容量は小数で、10 以上は整数にする', () {
      expect(scaleAmount('200g', 1.5), '300g');
      expect(scaleAmount('250g', 1 / 3), '83g');
      expect(scaleAmount('5ml', 0.5), '2.5ml');
      expect(scaleAmount('1,000cc', 0.5), '500cc');
      expect(scaleAmount('1.5kg', 2), '3kg');
    });

    test('大さじ・個数などは分数で書く', () {
      expect(scaleAmount('大さじ1', 1.5), '大さじ1と1/2');
      expect(scaleAmount('大さじ1と1/2', 2), '大さじ3');
      expect(scaleAmount('小さじ1・1/2', 0.5), '小さじ3/4');
      expect(scaleAmount('1/3本', 3), '1本');
      expect(scaleAmount('1/2個', 3), '1と1/2個');
      expect(scaleAmount('3分の1本', 2), '2/3本');
      expect(scaleAmount('½カップ', 2), '1カップ');
      expect(scaleAmount('250g(1/4本)', 1.5), '375g(3/8本)');
      expect(scaleAmount('1/3本', 0.5), '1/6本');
    });

    test('分数で書けなければ小数第1位まで', () {
      expect(scaleAmount('1本', 0.7), '0.7本');
    });

    test('範囲や複数の数値はすべて換算する', () {
      expect(scaleAmount('2〜3個', 2), '4〜6個');
      expect(scaleAmount('1枚(300g)', 2), '2枚(600g)');
    });

    test('数値のない分量や割合・温度はそのまま', () {
      expect(scaleAmount('少々', 2), '少々');
      expect(scaleAmount('適量', 0.5), '適量');
      expect(scaleAmount('牛乳(3.6%) 200ml', 2), '牛乳(3.6%) 400ml');
    });
  });

  group('parseServingsCount', () {
    test('1つの人数だけ読む', () {
      expect(parseServingsCount('2人分'), 2);
      expect(parseServingsCount('4人前'), 4);
      expect(parseServingsCount('2〜3人分'), isNull);
      expect(parseServingsCount('18cm型1台分'), isNull);
      expect(parseServingsCount('0人分'), isNull);
      expect(parseServingsCount(null), isNull);
    });
  });

  group('scaledServingsLabel', () {
    test('人数が読めれば換算後の人数、読めなければ倍率を添える', () {
      expect(scaledServingsLabel('2人分', 1), '2人分');
      expect(scaledServingsLabel('2人分', 1.5), '3人分');
      expect(scaledServingsLabel('2〜3人分', 2), '2〜3人分 ×2');
      expect(scaledServingsLabel(null, 0.5), '×1/2');
      expect(scaledServingsLabel(null, 1), isNull);
    });
  });
}
