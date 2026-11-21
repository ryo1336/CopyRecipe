import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../models/recipe.dart';
import '../parser/recipe_parser.dart';

const recipesBoxName = 'recipes';

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => HiveRecipeRepository(Hive.box<Recipe>(recipesBoxName)),
);

/// レシピの保存先
abstract interface class RecipeRepository {
  /// 追加日時の新しい順
  List<Recipe> all();

  Recipe? get(String videoId);

  bool contains(String videoId);

  Future<void> put(Recipe recipe);

  Future<void> putAll(Iterable<Recipe> recipes);

  Future<void> delete(String videoId);
}

/// Hive に保存する [RecipeRepository]
class HiveRecipeRepository implements RecipeRepository {
  HiveRecipeRepository(this._box);

  final Box<Recipe> _box;

  @override
  List<Recipe> all() =>
      _box.values.toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  @override
  Recipe? get(String videoId) => _box.get(videoId);

  @override
  bool contains(String videoId) => _box.containsKey(videoId);

  @override
  Future<void> put(Recipe recipe) => _box.put(recipe.videoId, recipe);

  @override
  Future<void> putAll(Iterable<Recipe> recipes) =>
      _box.putAll({for (final r in recipes) r.videoId: r});

  @override
  Future<void> delete(String videoId) => _box.delete(videoId);

  /// 古い版の抽出処理で作ったレシピを、原文から抽出し直す（手で直したものは除く）
  Future<void> reparseOutdated() async {
    final outdated = _box.values
        .where((r) => !r.isEdited && r.parserVersion < kParserVersion)
        .map((r) {
      final parsed = parseRecipe(r.rawDescription);
      return r.withParsedContent(
        ingredients: parsed.ingredients,
        steps: parsed.steps,
        servings: parsed.servings,
        parserVersion: kParserVersion,
      );
    }).toList();
    if (outdated.isNotEmpty) await putAll(outdated);
  }
}
