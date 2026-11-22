import 'package:copy_recipe/features/cooking/cooking_screen.dart';
import 'package:copy_recipe/features/recipe_list/ingredient_filter.dart';
import 'package:copy_recipe/models/recipe.dart';
import 'package:copy_recipe/screens/add_recipe_sheet.dart';
import 'package:copy_recipe/screens/how_to_screen.dart';
import 'package:copy_recipe/widgets/recipe_tile.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipes_provider.dart';

/// レシピ一覧。追加は右下のボタンから開くシートで行う
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _filterController = TextEditingController();

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _openRecipe(String videoId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CookingScreen(videoId: videoId)),
    );
  }

  Future<void> _openAddSheet() async {
    final singleVideoId = await showAddRecipeSheet(context);
    // 1本だけ登録した場合は、そのまま料理中画面を開く
    if (singleVideoId != null && mounted) _openRecipe(singleVideoId);
  }

  void _onMenuSelected(_MenuItem item) {
    switch (item) {
      case _MenuItem.howTo:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HowToScreen()),
        );
      case _MenuItem.licenses:
        showLicensePage(context: context, applicationName: 'Copy Recipe');
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Copy Recipe'),
        actions: [
          PopupMenuButton<_MenuItem>(
            tooltip: 'メニュー',
            onSelected: _onMenuSelected,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _MenuItem.howTo,
                child: ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text('使い方'),
                ),
              ),
              PopupMenuItem(
                value: _MenuItem.licenses,
                child: ListTile(
                  leading: Icon(Icons.description_outlined),
                  title: Text('ライセンス'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: recipes.isEmpty
          ? _EmptyState(onAdd: _openAddSheet)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: _IngredientFilterField(controller: _filterController),
                ),
                Expanded(
                  // 入力のたびに一覧を絞り込み直す
                  child: ValueListenableBuilder(
                    valueListenable: _filterController,
                    builder: (context, value, _) => _RecipeList(
                      recipes: filterByIngredients(recipes, value.text),
                      query: value.text.trim(),
                      onOpen: _openRecipe,
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: recipes.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAddSheet,
              icon: const Icon(Icons.add),
              label: const Text('レシピを追加'),
            ),
    );
  }
}

enum _MenuItem { howTo, licenses }

/// 材料名で一覧を絞り込む入力欄
class _IngredientFilterField extends StatelessWidget {
  const _IngredientFilterField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: '材料で絞り込む（例: 豚肉 大根）',
        prefixIcon: const Icon(Icons.filter_list),
        isDense: true,
        suffixIcon: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: '絞り込みを解除',
                  onPressed: controller.clear,
                ),
        ),
      ),
    );
  }
}

class _RecipeList extends StatelessWidget {
  const _RecipeList({
    required this.recipes,
    required this.query,
    required this.onOpen,
  });

  final List<Recipe> recipes;
  final String query;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '「$query」を使うレシピはありません',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      // 右下のボタンに最後のカードが隠れないよう、下に余白を取る
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: recipes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return RecipeTile(
          key: ValueKey(recipe.videoId),
          recipe: recipe,
          onTap: () => onOpen(recipe.videoId),
        );
      },
    );
  }
}

/// レシピがまだないときの案内
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.restaurant_menu,
                size: 48,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'レシピを追加しましょう',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'YouTube の料理動画や再生リストの URL から、\n材料と作り方を1画面にまとめます',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('レシピを追加'),
            ),
          ],
        ),
      ),
    );
  }
}
