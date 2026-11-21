import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'data/legacy_migration.dart';
import 'data/recipe_repository.dart';
import 'features/cooking/cooking_settings.dart';
import 'models/ingredient.dart';
import 'models/recipe.dart';
import 'models/recipe_step.dart';
import 'screens/home_screen.dart';

void main() async {
  // フラッターエンジンの初期化(非同期処理を行う前に必要)
  WidgetsFlutterBinding.ensureInitialized();
  final appDir = await getApplicationDocumentsDirectory();

  // Hive設定
  Hive.init(appDir.path);
  Hive.registerAdapter(RecipeAdapter());
  Hive.registerAdapter(IngredientAdapter());
  Hive.registerAdapter(RecipeStepAdapter());
  final recipes = await Hive.openBox<Recipe>(recipesBoxName);
  await Hive.openBox<dynamic>(settingsBoxName);

  // 旧形式のデータの移行と、古い版の抽出処理で作ったレシピの再抽出
  await migrateLegacyVideos(recipes);
  await RecipeRepository(recipes).reparseOutdated();

  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}
