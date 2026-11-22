import 'package:copy_recipe/features/recipe_list/ingredient_filter.dart';
import 'package:copy_recipe/models/ingredient.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  final porkDaikon = sampleRecipe(id: 'porkdaikon1');
  final curry = sampleRecipe(
    id: 'curry000000',
    ingredients: const [
      Ingredient(name: 'タマネギ', amount: '1個'),
      Ingredient(name: '豚こま肉', amount: '200g'),
      Ingredient(name: 'カレールウ', amount: '1/2箱'),
      Ingredient(name: 'Ｓ＆Ｂガラムマサラ', amount: '少々'),
    ],
  );
  final recipes = [porkDaikon, curry];

  List<String> ids(String query) =>
      filterByIngredients(recipes, query).map((r) => r.videoId).toList();

  test('空の条件なら、すべてのレシピを返す', () {
    expect(ids(''), ['porkdaikon1', 'curry000000']);
    expect(ids('   '), ['porkdaikon1', 'curry000000']);
  });

  test('材料名の一部に含まれていれば当たる', () {
    expect(ids('豚'), ['porkdaikon1', 'curry000000']);
    expect(ids('大根'), ['porkdaikon1']);
    expect(ids('ルウ'), ['curry000000']);
  });

  test('空白で区切った語は、すべてを含むレシピだけに絞る', () {
    expect(ids('豚 大根'), ['porkdaikon1']);
    expect(ids('豚　カレー'), ['curry000000']);
    expect(ids('大根 カレー'), isEmpty);
  });

  test('カタカナとひらがな、全角と半角、大文字と小文字の違いは無視する', () {
    expect(ids('たまねぎ'), ['curry000000']);
    expect(ids('ミリン'), ['porkdaikon1']);
    expect(ids('s&b'), ['curry000000']);
  });

  test('当たらなければ空', () {
    expect(ids('鶏肉'), isEmpty);
  });
}
