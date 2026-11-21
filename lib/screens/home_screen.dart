import 'package:copy_recipe/features/cooking/cooking_screen.dart';
import 'package:copy_recipe/screens/add_recipe_sheet.dart';
import 'package:copy_recipe/widgets/recipe_tile.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipes_provider.dart';

/// レシピ一覧。追加は右下のボタンから開くシートで行う
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openRecipe(BuildContext context, String videoId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CookingScreen(videoId: videoId)),
    );
  }

  Future<void> _openAddSheet(BuildContext context) async {
    final singleVideoId = await showAddRecipeSheet(context);
    // 1本だけ登録した場合は、そのまま料理中画面を開く
    if (singleVideoId != null && context.mounted) {
      _openRecipe(context, singleVideoId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Copy Recipe')),
      body: recipes.isEmpty
          ? _EmptyState(onAdd: () => _openAddSheet(context))
          : ListView.separated(
              // 右下のボタンに最後のカードが隠れないよう、下に余白を取る
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: recipes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final recipe = recipes[index];
                return RecipeTile(
                  recipe: recipe,
                  onTap: () => _openRecipe(context, recipe.videoId),
                );
              },
            ),
      floatingActionButton: recipes.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openAddSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('レシピを追加'),
            ),
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
