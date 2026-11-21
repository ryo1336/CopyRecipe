import 'dart:io';

import 'package:copy_recipe/models/ingredient.dart';
import 'package:copy_recipe/models/recipe_step.dart';
import 'package:copy_recipe/parser/recipe_parser.dart';
import 'package:copy_recipe/parser/serialize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groupIngredients は連続する同じグループをまとめ、元の番号を保つ', () {
    final groups = groupIngredients(const [
      Ingredient(name: '豚肉'),
      Ingredient(name: '醤油', group: 'A'),
      Ingredient(name: 'みりん', group: 'A'),
      Ingredient(name: '塩'),
    ]);
    expect(groups.map((g) => g.name), [null, 'A', null]);
    expect(groups[1].items.map((e) => e.$1), [1, 2]);
  });

  test('ingredientsToLines はグループの前後に見出しと空行を入れる', () {
    expect(
      ingredientsToLines(const [
        Ingredient(name: '豚肉', amount: '200g'),
        Ingredient(name: '醤油', amount: '大さじ1', group: 'A'),
        Ingredient(name: '小ねぎ'),
      ]),
      ['豚肉 200g', '【A】', '醤油 大さじ1', '', '小ねぎ'],
    );
  });

  test('stepsToLines は番号を付け、時刻は番号の後、工程内の改行は字下げした行にする', () {
    expect(
      stepsToLines(const [
        RecipeStep(text: '切る', startSeconds: 72),
        RecipeStep(text: '焼く\n※焦げやすい'),
      ]),
      ['1. 1:12 切る', '2. 焼く', '    ※焦げやすい'],
    );
  });

  group('編集画面のテキストを何も直さずに戻すと、元と同じになる', () {
    test('分量のない材料に「トッピング」「仕上げ」などが含まれても、見出しにしない', () {
      const ingredients = [
        Ingredient(name: '豚肉', amount: '200g'),
        Ingredient(name: 'トッピング用ねぎ'),
        Ingredient(name: '仕上げのごま'),
        Ingredient(name: '塩', amount: '少々'),
        Ingredient(name: '醤油', amount: '大さじ1', group: 'a'),
        Ingredient(name: '水を足す。', group: 'a'),
      ];
      expect(
        parseEditedIngredientLines(ingredientsToLines(ingredients)),
        ingredients,
      );
    });

    test('「①」「(1)」で始まる工程や、工程内の改行もそのまま残す', () {
      const steps = [
        RecipeStep(text: '卵を溶く', startSeconds: 5),
        RecipeStep(text: '①を鍋に入れる'),
        RecipeStep(text: '(1)と(2)を合わせる\n※焦げやすいので注意'),
        RecipeStep(text: '2.5cm幅に切る'),
        RecipeStep(text: '火を止める'),
      ];
      expect(parseEditedStepLines(stepsToLines(steps)), steps);
    });
  });

  test('parseEditedStepLines は番号なし・時刻だけの入力も受け付ける', () {
    expect(
      parseEditedStepLines([
        '0:30 鶏肉を焼く',
        'タレを絡める',
        '',
        '  ※弱火で',
        '3. 1:02:03 盛り付ける',
      ]),
      const [
        RecipeStep(text: '鶏肉を焼く', startSeconds: 30),
        RecipeStep(text: 'タレを絡める\n※弱火で'),
        RecipeStep(text: '盛り付ける', startSeconds: 3723),
      ],
    );
  });

  test('parseEditedIngredientLines は空行でグループを終える', () {
    expect(parseEditedIngredientLines(['【A】', '醤油 大さじ1', '', '塩 少々']), const [
      Ingredient(name: '醤油', amount: '大さじ1', group: 'A'),
      Ingredient(name: '塩', amount: '少々'),
    ]);
  });

  // 編集画面は「テキストにする → 利用者が直す → パースし直す」ので、
  // 何も直さなければ元の材料・工程に戻ることを、すべてのフィクスチャで確かめる
  final fixtures =
      Directory('test/parser/fixtures').listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in fixtures) {
    test('テキストにしてパースし直すと元に戻る: ${file.uri.pathSegments.last}', () {
      final parsed = parseRecipe(file.readAsStringSync());

      expect(
        parseEditedIngredientLines(ingredientsToLines(parsed.ingredients)),
        parsed.ingredients,
      );
      expect(parseEditedStepLines(stepsToLines(parsed.steps)), parsed.steps);
    });
  }
}
