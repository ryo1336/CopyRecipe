import 'package:copy_recipe/data/recipe_repository.dart';
import 'package:copy_recipe/features/cooking/cooking_settings.dart';
import 'package:copy_recipe/features/cooking/platform_services.dart';
import 'package:copy_recipe/models/ingredient.dart';
import 'package:copy_recipe/models/recipe.dart';
import 'package:copy_recipe/models/recipe_step.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeScreenAwake implements ScreenAwake {
  bool enabled = false;

  @override
  Future<void> enable() async => enabled = true;

  @override
  Future<void> disable() async => enabled = false;
}

class FakeSettingsStore implements SettingsStore {
  final values = <String, String>{};

  @override
  String? getString(String key) => values[key];

  @override
  void setString(String key, String value) => values[key] = value;
}

class FakeVideoLauncher implements VideoLauncher {
  final opened = <(String, int)>[];

  @override
  Future<bool> open(String videoId, {int startSeconds = 0}) async {
    opened.add((videoId, startSeconds));
    return true;
  }
}

/// メモリ上だけで読み書きする RecipeRepository。
///
/// ウィジェットテストは疑似時間の中で動くため、Hive のファイル書き込みが完了せず
/// テストが止まってしまう。ウィジェットテストではこちらを使う。
class InMemoryRecipeRepository implements RecipeRepository {
  InMemoryRecipeRepository([Iterable<Recipe> recipes = const []])
    : _recipes = {for (final r in recipes) r.videoId: r};

  final Map<String, Recipe> _recipes;
  int putCount = 0;

  @override
  List<Recipe> all() =>
      _recipes.values.toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  @override
  Recipe? get(String videoId) => _recipes[videoId];

  @override
  bool contains(String videoId) => _recipes.containsKey(videoId);

  @override
  Future<void> put(Recipe recipe) async {
    putCount++;
    _recipes[recipe.videoId] = recipe;
  }

  @override
  Future<void> putAll(Iterable<Recipe> recipes) async {
    for (final r in recipes) {
      _recipes[r.videoId] = r;
    }
  }

  @override
  Future<void> delete(String videoId) async => _recipes.remove(videoId);
}

/// テスト用のレシピ
Recipe sampleRecipe({
  String id = 'aaaaaaaaaaa',
  String title = '豚バラ大根',
  List<Ingredient> ingredients = const [
    Ingredient(name: '豚バラ肉', amount: '200g'),
    Ingredient(name: '大根', amount: '1/3本'),
    Ingredient(name: '醤油', amount: '大さじ2', group: 'A'),
    Ingredient(name: 'みりん', amount: '大さじ2', group: 'A'),
  ],
  List<RecipeStep> steps = const [
    RecipeStep(text: '大根を切る', startSeconds: 72),
    RecipeStep(text: '豚肉を炒める'),
  ],
  String? servings = '2人分',
  String rawDescription = '概要欄の原文です',
  DateTime? addedAt,
  bool isEdited = false,
}) => Recipe(
  videoId: id,
  title: title,
  channelTitle: 'テストチャンネル',
  thumbnailUrl: null,
  rawDescription: rawDescription,
  ingredients: ingredients,
  steps: steps,
  servings: servings,
  addedAt: addedAt ?? DateTime(2026),
  isEdited: isEdited,
  parserVersion: 1,
);

/// 画面をテストするための環境（フェイク一式と、それを差し込んだ ProviderScope）
class TestEnv {
  TestEnv(Iterable<Recipe> recipes)
    : repository = InMemoryRecipeRepository(recipes);

  final InMemoryRecipeRepository repository;
  final screenAwake = FakeScreenAwake();
  final launcher = FakeVideoLauncher();
  final settings = FakeSettingsStore();

  Widget wrap(Widget home) => ProviderScope(
    overrides: [
      recipeRepositoryProvider.overrideWithValue(repository),
      screenAwakeProvider.overrideWithValue(screenAwake),
      videoLauncherProvider.overrideWithValue(launcher),
      settingsStoreProvider.overrideWithValue(settings),
    ],
    child: MaterialApp(home: home),
  );

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(412, 2000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(home));
  }
}
