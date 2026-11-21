import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/recipe.dart';
import '../../models/recipe_step.dart';
import '../../parser/chapters.dart';
import '../../providers/recipes_provider.dart';
import 'cooking_checks.dart';
import 'cooking_screen.dart';
import 'cooking_widgets.dart';

/// 1工程ずつ大きな文字で表示する画面。
///
/// 濡れた手でも操作できるよう、画面の右半分のタップで次へ、左半分で前へ進む
/// （スワイプでも移動できる）。「次へ」で進んだ工程は完了としてチェックする。
class StepModeScreen extends ConsumerStatefulWidget {
  const StepModeScreen({
    super.key,
    required this.videoId,
    this.initialStep = 0,
  });

  final String videoId;
  final int initialStep;

  @override
  ConsumerState<StepModeScreen> createState() => _StepModeScreenState();
}

class _StepModeScreenState extends ConsumerState<StepModeScreen> {
  late final PageController _controller;
  late int _page;

  static const _pageDuration = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    _page = widget.initialStep;
    _controller = PageController(initialPage: widget.initialStep);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  CookingChecksNotifier get _checks =>
      ref.read(cookingChecksProvider(widget.videoId).notifier);

  void _next(Recipe recipe) {
    _checks.checkStep(_page);
    if (_page >= recipe.steps.length - 1) {
      // 最後の工程の「次へ」は完了。料理中画面に戻る
      Navigator.pop(context);
      return;
    }
    _controller.nextPage(duration: _pageDuration, curve: Curves.easeOut);
  }

  void _previous() {
    if (_page == 0) return;
    _controller.previousPage(duration: _pageDuration, curve: Curves.easeOut);
  }

  void _showIngredients(Recipe recipe) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scrollController) => CookingTextScale(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                recipe.servings == null ? '材料' : '材料（${recipe.servings}）',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IngredientChecklist(
                videoId: widget.videoId,
                ingredients: recipe.ingredients,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = ref.watch(recipeByIdProvider(widget.videoId));
    if (recipe == null || recipe.steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.amber),
        body: const Center(child: Text('表示できる工程がありません')),
      );
    }

    final total = recipe.steps.length;
    final page = _page.clamp(0, total - 1);
    final step = recipe.steps[page];
    final isLast = page == total - 1;
    final doneSteps = ref.watch(cookingChecksProvider(widget.videoId)).steps;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber,
        title: Text('手順 ${page + 1} / $total'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (page + 1) / total),
        ),
      ),
      body: CookingTextScale(
        child: PageView.builder(
          controller: _controller,
          itemCount: total,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => _StepPage(
            number: i + 1,
            step: recipe.steps[i],
            done: doneSteps.contains(i),
            onTapLeft: _previous,
            onTapRight: () => _next(recipe),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              IconButton.filledTonal(
                onPressed: page == 0 ? null : _previous,
                icon: const Icon(Icons.chevron_left),
                tooltip: '前の手順',
                iconSize: 32,
              ),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    if (recipe.ingredients.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _showIngredients(recipe),
                        icon: const Icon(Icons.list_alt),
                        label: const Text('材料'),
                      ),
                    if (step.startSeconds != null)
                      TextButton.icon(
                        onPressed: () => openVideo(
                          context,
                          ref,
                          recipe.videoId,
                          step.startSeconds!,
                        ),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(formatTimestamp(step.startSeconds!)),
                      ),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: () => _next(recipe),
                icon: Icon(isLast ? Icons.check : Icons.chevron_right),
                tooltip: isLast ? '完了' : '次の手順',
                iconSize: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.number,
    required this.step,
    required this.done,
    required this.onTapLeft,
    required this.onTapRight,
  });

  final int number;
  final RecipeStep step;
  final bool done;
  final VoidCallback onTapLeft;
  final VoidCallback onTapRight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) =>
            details.localPosition.dx < constraints.maxWidth / 2
            ? onTapLeft()
            : onTapRight(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$number',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (done)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '完了済み',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  step.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
