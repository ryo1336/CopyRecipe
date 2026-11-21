import 'dart:io';

import 'package:copy_recipe/data/recipe_repository.dart';
import 'package:copy_recipe/features/cooking/cooking_checks.dart';
import 'package:copy_recipe/models/ingredient.dart';
import 'package:copy_recipe/models/recipe.dart';
import 'package:copy_recipe/models/recipe_step.dart';
import 'package:copy_recipe/providers/recipes_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Recipe recipe(String id, String description) => Recipe(
  videoId: id,
  title: 't',
  channelTitle: 'c',
  thumbnailUrl: null,
  rawDescription: description,
  ingredients: const [Ingredient(name: '豚肉', amount: '200g')],
  steps: const [RecipeStep(text: '焼く')],
  servings: null,
  addedAt: DateTime(2026),
  parserVersion: 1,
);

void main() {
  late Directory dir;
  late Box<Recipe> box;
  late ProviderContainer container;

  setUpAll(() {
    Hive.registerAdapter(RecipeAdapter());
    Hive.registerAdapter(IngredientAdapter());
    Hive.registerAdapter(RecipeStepAdapter());
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cooking_checks_test');
    Hive.init(dir.path);
    box = await Hive.openBox<Recipe>(recipesBoxName);
    await box.put('aaaaaaaaaaa', recipe('aaaaaaaaaaa', '材料\n豚肉 200g'));
    await box.put('bbbbbbbbbbb', recipe('bbbbbbbbbbb', '材料\n牛肉 100g'));
    container = ProviderContainer(
      overrides: [
        recipeRepositoryProvider.overrideWithValue(HiveRecipeRepository(box)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('材料・工程を抽出し直したらチェックをリセットする', () async {
    final provider = cookingChecksProvider('aaaaaaaaaaa');
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);

    container.read(provider.notifier)
      ..toggleIngredient(0)
      ..toggleStep(0);
    expect(container.read(provider).isEmpty, isFalse);

    await container
        .read(recipesProvider.notifier)
        .saveEdited(
          'aaaaaaaaaaa',
          ingredients: const [Ingredient(name: '鶏肉', amount: '300g')],
          steps: const [RecipeStep(text: '焼く')],
          servings: null,
        );

    expect(container.read(provider).isEmpty, isTrue);
  });

  test('ステップモードで進んだ工程は完了にする（二重には付けない）', () {
    final provider = cookingChecksProvider('aaaaaaaaaaa');
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);

    container.read(provider.notifier)
      ..checkStep(0)
      ..checkStep(0);
    expect(container.read(provider).steps, {0});
  });

  test('別のレシピが変わっても、チェックは残す', () async {
    final provider = cookingChecksProvider('aaaaaaaaaaa');
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);

    container.read(provider.notifier).toggleIngredient(0);
    await container
        .read(recipesProvider.notifier)
        .resetToExtracted('bbbbbbbbbbb');

    expect(container.read(provider).ingredients, {0});
  });
}
