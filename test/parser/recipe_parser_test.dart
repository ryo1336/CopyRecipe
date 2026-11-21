import 'dart:io';

import 'package:copy_recipe/models/ingredient.dart';
import 'package:copy_recipe/models/recipe_step.dart';
import 'package:copy_recipe/parser/chapters.dart';
import 'package:copy_recipe/parser/ingredients.dart';
import 'package:copy_recipe/parser/normalize.dart';
import 'package:copy_recipe/parser/recipe_parser.dart';
import 'package:copy_recipe/parser/sections.dart';
import 'package:copy_recipe/parser/steps.dart';
import 'package:flutter_test/flutter_test.dart';

String fixture(String name) =>
    File('test/parser/fixtures/$name').readAsStringSync();

void main() {
  group('parseRecipe（フィクスチャ）', () {
    test('01: 見出し・グループ・番号付き工程・フッター', () {
      final r = parseRecipe(fixture('01_basic_numbered.txt'));

      expect(r.servings, '2人分');
      expect(r.ingredients, const [
        Ingredient(name: '豚バラ肉', amount: '200g'),
        Ingredient(name: '大根', amount: '1/3本'),
        Ingredient(name: 'しょうが', amount: '1かけ'),
        Ingredient(name: '醤油', amount: '大さじ2', group: 'A'),
        Ingredient(name: 'みりん', amount: '大さじ2', group: 'A'),
        Ingredient(name: '砂糖', amount: '小さじ1', group: 'A'),
      ]);
      expect(r.steps.map((s) => s.text).toList(), [
        '大根は皮をむいて2cm幅のいちょう切りにする。',
        '豚肉を炒め、色が変わったら大根を加える。',
        'Aを加えて落とし蓋をし、20分煮る。\n※焦げやすいので火加減に注意',
      ]);
      expect(r.chapters, isEmpty);
    });

    test('02: 作り方がなくチャプターだけある場合はチャプターを工程にする', () {
      final r = parseRecipe(fixture('02_chapters_only.txt'));

      expect(r.servings, '2〜3人分');
      expect(r.ingredients, const [
        Ingredient(name: '鶏もも肉', amount: '1枚(300g)'),
        Ingredient(name: '玉ねぎ', amount: '1/2個'),
        Ingredient(name: '卵', amount: '3個'),
        Ingredient(name: 'めんつゆ(3倍濃縮)', amount: '大さじ3'),
        Ingredient(name: '水', amount: '100ml'),
      ]);
      expect(r.steps, const [
        RecipeStep(text: '玉ねぎを切る', startSeconds: 65),
        RecipeStep(text: '鶏肉を煮る', startSeconds: 130),
        RecipeStep(text: '卵でとじる', startSeconds: 220),
      ]);
    });

    test('03: 記号グループと、工程へのチャプター時刻の割り当て', () {
      final r = parseRecipe(fixture('03_steps_with_chapters.txt'));

      expect(r.ingredients, const [
        Ingredient(name: 'キャベツ', amount: '1/4個'),
        Ingredient(name: 'ひき肉', amount: '150g'),
        Ingredient(name: '塩こしょう', amount: '少々'),
        Ingredient(name: 'ケチャップ', amount: '大さじ2', group: 'ソース'),
        Ingredient(name: 'ウスターソース', amount: '大さじ1', group: 'ソース'),
      ]);
      expect(r.steps, const [
        RecipeStep(text: 'キャベツを千切りにする', startSeconds: 30),
        RecipeStep(text: 'ひき肉を炒めて塩こしょうする', startSeconds: 105),
        RecipeStep(text: '★を混ぜてかける'),
      ]);
    });

    test('04: レシピのない概要欄', () {
      final r = parseRecipe(fixture('04_no_recipe.txt'));

      expect(r.hasIngredients, isFalse);
      expect(r.hasSteps, isFalse);
    });

    test('05: 全角表記と、見出しなしで始まる番号付き工程', () {
      final r = parseRecipe(fixture('05_fullwidth_no_header_steps.txt'));

      expect(r.servings, '4人分');
      expect(r.ingredients, const [
        Ingredient(name: 'じゃがいも', amount: '3個'),
        Ingredient(name: 'にんじん', amount: '1本'),
        Ingredient(name: '牛肉', amount: '200g'),
        Ingredient(name: 'カレールウ', amount: '1/2箱'),
        Ingredient(name: 'サラダ油', amount: '適量'),
      ]);
      expect(r.steps.map((s) => s.text).toList(), [
        '野菜を一口大に切る。',
        '鍋に油を熱し、牛肉と野菜を炒める。',
        '水を加えて15分煮込み、ルウを溶かす。',
      ]);
    });

    test('07: 小文字のグループ記号と、番号付き工程の前の下ごしらえ', () {
      final r = parseRecipe(fixture('07_lowercase_group_prep.txt'));

      expect(r.servings, '2〜3人分');
      expect(r.ingredients, const [
        Ingredient(name: '鶏もも肉', amount: '300g'),
        Ingredient(name: '大根', amount: '1/4本'),
        Ingredient(name: '砂糖', amount: '大さじ1', group: 'a'),
        Ingredient(name: 'しょうゆ', amount: '大さじ2', group: 'a'),
        Ingredient(name: '水', amount: '100cc', group: 'a'),
        Ingredient(name: 'サラダ油', amount: '大さじ1/2'),
      ]);
      expect(r.steps.map((s) => s.text).toList(), [
        '大根は皮をむいて2cm幅の半月切りにします。',
        '鍋にサラダ油を熱し、鶏もも肉を焼きます。',
        '大根と(a)を加え、落とし蓋をして15分煮ます。',
        '器に盛り付けて完成です。',
      ]);
    });

    test('06: 「〇〇の材料」見出しのグループと、番号なしの工程', () {
      final r = parseRecipe(fixture('06_group_sections.txt'));

      expect(r.servings, isNull);
      expect(r.ingredients, const [
        Ingredient(name: '卵', amount: '3個'),
        Ingredient(name: 'グラニュー糖', amount: '90g'),
        Ingredient(name: '薄力粉', amount: '90g'),
        Ingredient(name: '水', amount: '50ml', group: 'シロップ'),
        Ingredient(name: '砂糖', amount: '20g', group: 'シロップ'),
      ]);
      expect(r.steps.map((s) => s.text).toList(), [
        '卵と砂糖を湯せんにかけながら泡立てる',
        '薄力粉をふるい入れてさっくり混ぜる',
        '170℃のオーブンで30分焼く',
      ]);
    });
  });

  group('normalize', () {
    test('全角英数字と全角スペースを半角にする', () {
      expect(normalize('牛肉　２００ｇ\r\n（Ａ）'), '牛肉 200g\n(A)');
    });
  });

  group('parseIngredientLine', () {
    final cases = <String, Ingredient>{
      '豚バラ肉 200g': const Ingredient(name: '豚バラ肉', amount: '200g'),
      '豚バラ肉200g': const Ingredient(name: '豚バラ肉', amount: '200g'),
      '砂糖大さじ1': const Ingredient(name: '砂糖', amount: '大さじ1'),
      '塩 こしょう 少々': const Ingredient(name: '塩 こしょう', amount: '少々'),
      'ごま油 (炒め用) 大さじ1': const Ingredient(name: 'ごま油 (炒め用)', amount: '大さじ1'),
      '鶏もも肉 1枚 (300g)': const Ingredient(name: '鶏もも肉', amount: '1枚 (300g)'),
      '豚肉(200g)': const Ingredient(name: '豚肉', amount: '200g'),
      '塩……ひとつまみ': const Ingredient(name: '塩', amount: 'ひとつまみ'),
      '小ねぎ': const Ingredient(name: '小ねぎ'),
      '塩少々': const Ingredient(name: '塩', amount: '少々'),
      'お好み焼きソース大さじ2': const Ingredient(name: 'お好み焼きソース', amount: '大さじ2'),
      'マグカップ1杯の水': const Ingredient(name: 'マグカップ', amount: '1杯の水'),
    };
    cases.forEach((input, expected) {
      test(input, () => expect(parseIngredientLine(input), expected));
    });
  });

  group('parseIngredientLines のグループ', () {
    test('「A 醤油 大さじ1」形式', () {
      expect(parseIngredientLines(['A 醤油 大さじ1', '塩 少々']), const [
        Ingredient(name: '醤油', amount: '大さじ1', group: 'A'),
        Ingredient(name: '塩', amount: '少々'),
      ]);
    });

    test('空行でグループが終わる', () {
      expect(parseIngredientLines(['合わせ調味料:', '酢 大さじ1', '', 'ごま 適量']), const [
        Ingredient(name: '酢', amount: '大さじ1', group: '合わせ調味料'),
        Ingredient(name: 'ごま', amount: '適量'),
      ]);
    });
  });

  group('parseTimestampLine', () {
    test('行頭・行末・時間付き', () {
      expect(parseTimestampLine('1:23 大根を切る'), const Chapter('大根を切る', 83));
      expect(parseTimestampLine('大根を切る (1:23)'), const Chapter('大根を切る', 83));
      expect(parseTimestampLine('1:02:03 - 煮込む'), const Chapter('煮込む', 3723));
    });

    test('比率や分量は時刻とみなさない', () {
      expect(parseTimestampLine('醤油とみりん 1:1'), isNull);
      expect(parseTimestampLine('1/2本'), isNull);
    });
  });

  group('classifyHeader', () {
    test('材料・作り方の見出し', () {
      expect(classifyHeader('【材料】(2人分)')?.kind, HeaderKind.ingredients);
      expect(classifyHeader('■材料 18cm型1台分')?.kind, HeaderKind.ingredients);
      expect(classifyHeader('ソースの材料')?.group, 'ソース');
      expect(classifyHeader('◆作り方◆')?.kind, HeaderKind.steps);
      expect(classifyHeader('How to make')?.kind, HeaderKind.steps);
    });

    test('文中の「材料」は見出しとみなさない', () {
      expect(classifyHeader('材料をすべて混ぜる'), isNull);
    });

    test('「ポイント」「注意」などは行全体が一致するときだけ見出しとみなす', () {
      expect(classifyHeader('【ポイント】')?.kind, HeaderKind.other);
      expect(classifyHeader('▼関連動画はこちら')?.kind, HeaderKind.other);
      expect(classifyHeader('注意しながら弱火で焼く'), isNull);
      expect(classifyHeader('おすすめの薬味 適量'), isNull);
    });

    test('「注意」「おすすめ」で始まる本文の行で欄が途切れない', () {
      final r = parseRecipe(
        '材料\n豚肉 200g\nおすすめの薬味 適量\nねぎ 1本\n\n'
        '作り方\n肉を焼く\n注意しながら弱火で焼く\n皿に盛る',
      );
      expect(r.ingredients.map((i) => i.name), ['豚肉', 'おすすめの薬味', 'ねぎ']);
      expect(r.steps.map((s) => s.text), ['肉を焼く', '注意しながら弱火で焼く', '皿に盛る']);
    });
  });

  group('mergeStepsWithChapters', () {
    test('「完成・試食」のような複合の章も工程から除く', () {
      final steps = mergeStepsWithChapters(const [], const [
        Chapter('オープニング', 0),
        Chapter('焼く', 30),
        Chapter('完成・試食', 90),
      ]);
      expect(steps, const [RecipeStep(text: '焼く', startSeconds: 30)]);
    });
  });

  test('isNumberedStepLine は分量の分数や小数を工程とみなさない', () {
    expect(isNumberedStepLine('1. 切る'), isTrue);
    expect(isNumberedStepLine('①切る'), isTrue);
    expect(isNumberedStepLine('1.5カップ'), isFalse);
    expect(isNumberedStepLine('1/2本'), isFalse);
  });
}
