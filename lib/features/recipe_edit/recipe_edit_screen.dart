import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/recipe.dart';
import '../../parser/ingredients.dart';
import '../../parser/serialize.dart';
import '../../parser/steps.dart';
import '../../providers/recipes_provider.dart';

/// 材料・作り方・人数を手で直す画面。
///
/// 材料と作り方はテキストで編集し、保存するときに抽出処理と同じパーサーで構造化する。
/// 保存したレシピは、抽出処理を改良しても自動では上書きしない。
class RecipeEditScreen extends ConsumerStatefulWidget {
  const RecipeEditScreen({super.key, required this.videoId});

  final String videoId;

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  final _servings = TextEditingController();
  final _ingredients = TextEditingController();
  final _steps = TextEditingController();
  (String, String, String) _initial = ('', '', '');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final recipe = ref.read(recipeByIdProvider(widget.videoId));
    if (recipe != null) _fill(recipe);
    for (final c in [_servings, _ingredients, _steps]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _servings.dispose();
    _ingredients.dispose();
    _steps.dispose();
    super.dispose();
  }

  void _fill(Recipe recipe) {
    _servings.text = recipe.servings ?? '';
    _ingredients.text = ingredientsToLines(recipe.ingredients).join('\n');
    _steps.text = stepsToLines(recipe.steps).join('\n');
    _initial = _current;
  }

  (String, String, String) get _current =>
      (_servings.text, _ingredients.text, _steps.text);

  bool get _dirty => !_saving && _current != _initial;

  Future<void> _save() async {
    // 連打で保存と画面を閉じる処理が二重に走らないようにする
    if (_saving) return;
    setState(() => _saving = true);
    final servings = _servings.text.trim();
    await ref
        .read(recipesProvider.notifier)
        .saveEdited(
          widget.videoId,
          ingredients: parseIngredientLines(_ingredients.text.split('\n')),
          steps: parseStepLines(_steps.text.split('\n')),
          servings: servings.isEmpty ? null : servings,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _resetToExtracted() async {
    final ok = await _confirm(
      title: '自動抽出に戻しますか？',
      message: '手で直した内容を捨てて、概要欄から抽出し直します。',
      okLabel: '戻す',
    );
    if (!ok || _saving) return;
    setState(() => _saving = true);
    await ref.read(recipesProvider.notifier).resetToExtracted(widget.videoId);
    if (mounted) Navigator.pop(context);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String okLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(okLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _confirmDiscard() async {
    final discard = await _confirm(
      title: '変更を破棄しますか？',
      message: '保存していない変更は失われます。',
      okLabel: '破棄',
    );
    if (discard && mounted) {
      // 破棄を選んだので、以後は確認なしで閉じる
      setState(() => _initial = _current);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = ref.watch(recipeByIdProvider(widget.videoId));

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.amber,
          title: const Text('レシピを編集'),
          actions: [
            PopupMenuButton<void>(
              tooltip: 'その他',
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: _resetToExtracted,
                  child: const Text('自動抽出に戻す'),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: '保存',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _servings,
              decoration: const InputDecoration(
                labelText: '人数',
                hintText: '例: 2人分',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ingredients,
              minLines: 6,
              maxLines: null,
              decoration: const InputDecoration(
                labelText: '材料',
                helperText: '1行に1つ、「材料名 分量」の形で入力。グループは【A】のように見出しの行を入れます',
                helperMaxLines: 3,
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _steps,
              minLines: 6,
              maxLines: null,
              decoration: const InputDecoration(
                labelText: '作り方',
                helperText: '1行に1工程。行頭に「1:12」のように時刻を書くと、動画のその時刻へのリンクになります',
                helperMaxLines: 3,
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (recipe != null)
              Card(
                margin: EdgeInsets.zero,
                child: ExpansionTile(
                  title: const Text('概要欄の原文（参照用）'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [SelectableText(recipe.rawDescription)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
