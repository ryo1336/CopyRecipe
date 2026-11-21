import 'package:copy_recipe/models/recipe.dart';
import 'package:copy_recipe/screens/add_url_screen.dart';
import 'package:copy_recipe/screens/recipe_screen.dart';
import 'package:copy_recipe/widgets/recipe_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipes_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  void _openRecipe(String videoId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecipeScreen(videoId: videoId)),
    );
  }

  /// 登録後は一覧に戻り、1本だけ登録した場合はそのレシピを開く
  void _onAdded(String? singleVideoId) {
    setState(() => _currentIndex = 0);
    if (singleVideoId != null) _openRecipe(singleVideoId);
  }

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipesProvider);

    final recipeListBody = recipes.isNotEmpty
        ? ListView.builder(
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final Recipe recipe = recipes[index];
              return RecipeTile(
                recipe: recipe,
                onTap: () => _openRecipe(recipe.videoId),
              );
            },
          )
        : Container(
            alignment: Alignment.center,
            child: const Text('Youtubeの料理動画または再生リストを追加してください'),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Copy Recipe'),
        backgroundColor: Colors.amber,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          recipeListBody,
          AddUrlScreen(onAdded: _onAdded),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'レシピ一覧',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_link),
            label: 'URL追加',
          ),
        ],
      ),
    );
  }
}
