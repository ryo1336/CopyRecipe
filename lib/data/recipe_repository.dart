import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../models/recipe.dart';
import '../parser/recipe_parser.dart';

const recipesBoxName = 'recipes';

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => RecipeRepository(Hive.box<Recipe>(recipesBoxName)),
);

/// レシピの保存先（Hive）
class RecipeRepository {
  RecipeRepository(this._box);

  final Box<Recipe> _box;

  /// 追加日時の新しい順
  List<Recipe> all() =>
      _box.values.toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  Recipe? get(String videoId) => _box.get(videoId);

  bool contains(String videoId) => _box.containsKey(videoId);

  Future<void> put(Recipe recipe) => _box.put(recipe.videoId, recipe);

  Future<void> putAll(Iterable<Recipe> recipes) =>
      _box.putAll({for (final r in recipes) r.videoId: r});

  Future<void> delete(String videoId) => _box.delete(videoId);

  /// 古い版の抽出処理で作ったレシピを、原文から抽出し直す（手で直したものは除く）
  Future<void> reparseOutdated() async {
    final outdated = _box.values
        .where((r) => !r.isEdited && r.parserVersion < kParserVersion)
        .map((r) {
      final parsed = parseRecipe(r.rawDescription);
      return r.copyWith(
        ingredients: parsed.ingredients,
        steps: parsed.steps,
        servings: parsed.servings,
        parserVersion: kParserVersion,
      );
    }).toList();
    if (outdated.isNotEmpty) await putAll(outdated);
  }
}
