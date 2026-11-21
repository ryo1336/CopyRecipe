import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:copy_recipe/models/recipe.dart';
import 'package:copy_recipe/providers/recipes_provider.dart';

/// レシピ一覧の1件。左にスワイプすると削除する（通知から元に戻せる）
class RecipeTile extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeTile({super.key, required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(recipesProvider.notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Dismissible(
      key: Key(recipe.videoId),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 4),
            Text('削除', style: TextStyle(color: scheme.onErrorContainer)),
          ],
        ),
      ),
      onDismissed: (direction) {
        notifier.delete(recipe.videoId);
        // 続けて削除したときに古い通知が並ばないよう、前の通知は閉じる
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('${recipe.title} を削除しました'),
              action: SnackBarAction(
                label: '元に戻す',
                onPressed: () => notifier.restore(recipe),
              ),
            ),
          );
      },
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _Thumbnail(url: recipe.thumbnailUrl),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recipe.channelTitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _summary(recipe),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 「材料 8 · 工程 5 · 2人分」のような概要
  static String _summary(Recipe recipe) => [
    '材料 ${recipe.ingredients.length}',
    '工程 ${recipe.steps.length}',
    ?recipe.servings,
  ].join(' · ');
}

/// サムネイル。URL がない場合や読み込みに失敗した場合は代わりのアイコンを出す
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String? url;

  // YouTube のサムネイルに合わせた 16:9
  static const _width = 128.0;
  static const _height = 72.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: _width,
      height: _height,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.restaurant, color: scheme.onSurfaceVariant),
    );
    if (url == null) return placeholder;
    return Image.network(
      url!,
      width: _width,
      height: _height,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}
