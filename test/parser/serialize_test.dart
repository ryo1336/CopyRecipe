import 'package:copy_recipe/models/ingredient.dart';
import 'package:copy_recipe/parser/serialize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groupIngredients は連続する同じグループをまとめる', () {
    final groups = groupIngredients(const [
      Ingredient(name: '豚肉'),
      Ingredient(name: '醤油', group: 'A'),
      Ingredient(name: 'みりん', group: 'A'),
      Ingredient(name: '塩'),
    ]);
    expect(groups.map((g) => g.name), [null, 'A', null]);
    expect(groups[1].items.map((e) => e.name), ['醤油', 'みりん']);
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
}
