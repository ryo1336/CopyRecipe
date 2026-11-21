import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:copy_recipe/providers/recipes_provider.dart';

/// レシピ画面
///
/// Phase 1 では概要欄の表示と編集のみ。Phase 2 で材料・工程を分けた料理中画面に置き換える。
class RecipeScreen extends ConsumerStatefulWidget {
  final String videoId;

  const RecipeScreen({super.key, required this.videoId});

  @override
  ConsumerState<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends ConsumerState<RecipeScreen> {
  final _controller = TextEditingController();
  // 編集モードかどうかのフラグ
  bool _isEditing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEditing(String text) {
    _controller.text = text;
    setState(() => _isEditing = true);
  }

  Future<void> _save() async {
    await ref.read(recipesProvider.notifier).updateDescription(
          widget.videoId,
          _controller.text,
        );
    if (mounted) setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    final recipe = ref.watch(
      recipesProvider.select(
        (list) => list.where((r) => r.videoId == widget.videoId).firstOrNull,
      ),
    );
    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.amber),
        body: const Center(child: Text('このレシピは削除されました')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _startEditing(recipe.rawDescription),
            ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(25.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(
                recipe.title,
                style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20.0),
              if (_isEditing)
                TextField(
                  controller: _controller,
                  maxLines: null,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                )
              else
                Text(recipe.rawDescription),
            ],
          ),
        ),
      ),
    );
  }
}
