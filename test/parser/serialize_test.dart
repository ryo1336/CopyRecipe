import 'dart:io';

import 'package:copy_recipe/models/ingredient.dart';
import 'package:copy_recipe/models/recipe_step.dart';
import 'package:copy_recipe/parser/ingredients.dart';
import 'package:copy_recipe/parser/recipe_parser.dart';
import 'package:copy_recipe/parser/serialize.dart';
import 'package:copy_recipe/parser/steps.dart';
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

  test('stepsToLines は時刻を行頭に付け、工程内の改行は空白にする', () {
    expect(
      stepsToLines(const [
        RecipeStep(text: '切る', startSeconds: 72),
        RecipeStep(text: '焼く\n※焦げやすい'),
      ]),
      ['1:12 切る', '焼く ※焦げやすい'],
    );
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
        parseIngredientLines(ingredientsToLines(parsed.ingredients)),
        parsed.ingredients,
      );
      expect(parseStepLines(stepsToLines(parsed.steps)), [
        for (final s in parsed.steps)
          RecipeStep(
            text: s.text.replaceAll('\n', ' '),
            startSeconds: s.startSeconds,
          ),
      ]);
    });
  }
}
