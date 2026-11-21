import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:copy_recipe/models/recipe.dart';
import 'package:copy_recipe/providers/recipes_provider.dart';

/// ホーム画面に表示するレシピウィジェット
class RecipeTile extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeTile({super.key, required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(recipesProvider.notifier);

    return Dismissible(
      key: Key(recipe.videoId),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.delete, color: Colors.white),
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
        margin: EdgeInsets.all(5.0),
        color: Color(0xFFFFE8CD),
        child: GestureDetector(
          onTap: onTap,
          child: Row(
            children: [
              // サムネイル画像
              _Thumbnail(url: recipe.thumbnailUrl),
              const SizedBox(width: 5.0),
              // 動画タイトル
              Expanded(
                child: Text(
                  recipe.title,
                  style: const TextStyle(color: Colors.black, fontSize: 12.0),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// サムネイル。URL がない場合や読み込みに失敗した場合は代わりのアイコンを出す
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String? url;

  static const _width = 150.0;
  static const _height = 84.0;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: _width,
      height: _height,
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.restaurant, color: Colors.black38),
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
