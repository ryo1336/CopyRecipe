import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ingredient.dart';
import '../../models/recipe.dart';
import '../../models/recipe_step.dart';
import '../../parser/chapters.dart';
import '../../providers/recipes_provider.dart';
import '../recipe_edit/raw_description_edit_screen.dart';
import 'cooking_checks.dart';
import 'cooking_settings.dart';
import 'platform_services.dart';

/// 料理中に見る画面。材料と作り方を1画面に並べる
class CookingScreen extends ConsumerStatefulWidget {
  const CookingScreen({super.key, required this.videoId});

  final String videoId;

  @override
  ConsumerState<CookingScreen> createState() => _CookingScreenState();
}

class _CookingScreenState extends ConsumerState<CookingScreen> {
  late final ScreenAwake _screenAwake;

  @override
  void initState() {
    super.initState();
    // 料理中に画面が消えないよう、開いている間はスリープを止める
    _screenAwake = ref.read(screenAwakeProvider);
    _screenAwake.enable();
  }

  @override
  void dispose() {
    _screenAwake.disable();
    super.dispose();
  }

  Future<void> _openVideo(Recipe recipe, [int startSeconds = 0]) async {
    final opened = await ref
        .read(videoLauncherProvider)
        .open(recipe.videoId, startSeconds: startSeconds);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('動画を開けませんでした')),
      );
    }
  }

  Future<void> _copyIngredients(Recipe recipe) async {
    await Clipboard.setData(ClipboardData(text: formatIngredientsForCopy(recipe)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('材料をコピーしました')),
      );
    }
  }

  void _openEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RawDescriptionEditScreen(videoId: widget.videoId),
      ),
    );
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

    final checks = ref.watch(cookingChecksProvider(widget.videoId));
    final checksNotifier = ref.read(cookingChecksProvider(widget.videoId).notifier);
    final fontSize = ref.watch(cookingFontSizeProvider);
    final styles = _CookingStyles(Theme.of(context), fontSize.scale);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber,
        title: Text(recipe.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<CookingFontSize>(
            icon: const Icon(Icons.format_size),
            tooltip: '文字サイズ',
            initialValue: fontSize,
            onSelected: ref.read(cookingFontSizeProvider.notifier).set,
            itemBuilder: (_) => [
              for (final size in CookingFontSize.values)
                PopupMenuItem(
                  value: size,
                  child: Row(
                    children: [
                      Icon(size == fontSize ? Icons.check : null, size: 20),
                      const SizedBox(width: 8),
                      Text('文字サイズ: ${size.label}'),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '概要欄を編集',
            onPressed: _openEditor,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _Header(recipe: recipe, styles: styles, onOpenVideo: () => _openVideo(recipe)),
          const SizedBox(height: 24),

          // 材料
          _SectionTitle(
            title: '材料',
            styles: styles,
            trailing: recipe.ingredients.isEmpty
                ? null
                : TextButton.icon(
                    onPressed: () => _copyIngredients(recipe),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('コピー'),
                  ),
          ),
          if (recipe.ingredients.isEmpty)
            _NotFound(
              message: '材料が見つかりませんでした',
              styles: styles,
              onEdit: _openEditor,
            )
          else
            ..._ingredientRows(recipe.ingredients, checks, checksNotifier, styles),
          const SizedBox(height: 24),

          // 作り方
          _SectionTitle(
            title: '作り方',
            styles: styles,
            trailing: checks.isEmpty
                ? null
                : TextButton.icon(
                    onPressed: checksNotifier.reset,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('チェックを外す'),
                  ),
          ),
          if (recipe.steps.isEmpty)
            _NotFound(
              message: '工程が見つかりませんでした',
              styles: styles,
              onEdit: _openEditor,
            )
          else
            for (final (i, step) in recipe.steps.indexed)
              _StepRow(
                number: i + 1,
                step: step,
                checked: checks.steps.contains(i),
                styles: styles,
                onTap: () => checksNotifier.toggleStep(i),
                onOpenVideo: step.startSeconds == null
                    ? null
                    : () => _openVideo(recipe, step.startSeconds!),
              ),
          const SizedBox(height: 24),

          // 概要欄の全文（最初は折りたたむ）
          Card(
            margin: EdgeInsets.zero,
            child: ExpansionTile(
              title: const Text('概要欄の全文'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [SelectableText(recipe.rawDescription)],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _ingredientRows(
    List<Ingredient> ingredients,
    CookingChecks checks,
    CookingChecksNotifier notifier,
    _CookingStyles styles,
  ) {
    final rows = <Widget>[];
    String? currentGroup;
    for (final (i, ingredient) in ingredients.indexed) {
      if (ingredient.group != currentGroup) {
        currentGroup = ingredient.group;
        if (currentGroup != null) {
          rows.add(Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(currentGroup, style: styles.group),
          ));
        }
      }
      rows.add(_IngredientRow(
        ingredient: ingredient,
        checked: checks.ingredients.contains(i),
        styles: styles,
        onTap: () => notifier.toggleIngredient(i),
      ));
    }
    return rows;
  }
}

/// 材料をクリップボード用のテキストにする（グループは【】の見出しにする）
String formatIngredientsForCopy(Recipe recipe) {
  final lines = <String>[
    if (recipe.servings != null) '材料（${recipe.servings}）' else '材料',
  ];
  String? currentGroup;
  for (final ingredient in recipe.ingredients) {
    if (ingredient.group != currentGroup) {
      currentGroup = ingredient.group;
      if (currentGroup != null) lines.add('【$currentGroup】');
    }
    lines.add(ingredient.amount == null
        ? ingredient.name
        : '${ingredient.name} ${ingredient.amount}');
  }
  return lines.join('\n');
}

/// 文字サイズの設定に合わせた文字のスタイル
class _CookingStyles {
  _CookingStyles(ThemeData theme, this.scale)
      : title = TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold),
        section = TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.bold),
        group = TextStyle(
          fontSize: 15 * scale,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
        body = TextStyle(fontSize: 17 * scale, height: 1.4),
        amount = TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w600),
        caption = TextStyle(fontSize: 13 * scale, color: theme.hintColor);

  final TextStyle title;
  final TextStyle section;
  final TextStyle group;
  final TextStyle body;
  final TextStyle amount;
  final TextStyle caption;
  final double scale;
}

class _Header extends StatelessWidget {
  const _Header({required this.recipe, required this.styles, required this.onOpenVideo});

  final Recipe recipe;
  final _CookingStyles styles;
  final VoidCallback onOpenVideo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(recipe.title, style: styles.title),
        const SizedBox(height: 4),
        Text(recipe.channelTitle, style: styles.caption),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (recipe.servings != null)
              Chip(
                avatar: const Icon(Icons.people_outline, size: 18),
                label: Text(recipe.servings!),
              ),
            OutlinedButton.icon(
              onPressed: onOpenVideo,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('動画を開く'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.styles, this.trailing});

  final String title;
  final _CookingStyles styles;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text('■ $title', style: styles.section)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 行全体をタップするとチェックが付く。チェック済みの行は薄く表示する
class _CheckableRow extends StatelessWidget {
  const _CheckableRow({
    required this.checked,
    required this.onTap,
    required this.semanticsLabel,
    required this.child,
  });

  final bool checked;
  final VoidCallback onTap;
  final String semanticsLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        checked: checked,
        label: semanticsLabel,
        child: InkWell(
          onTap: onTap,
          // 濡れた手でも押しやすいよう、Material の推奨より高めにする
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: checked ? 0.4 : 1,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.ingredient,
    required this.checked,
    required this.styles,
    required this.onTap,
  });

  final Ingredient ingredient;
  final bool checked;
  final _CookingStyles styles;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CheckableRow(
      checked: checked,
      onTap: onTap,
      semanticsLabel: '${ingredient.name} ${ingredient.amount ?? ''}',
      child: Row(
        children: [
          _CheckIcon(checked: checked, scale: styles.scale),
          const SizedBox(width: 8),
          Expanded(child: Text(ingredient.name, style: styles.body)),
          if (ingredient.amount != null) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                ingredient.amount!,
                style: styles.amount,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.step,
    required this.checked,
    required this.styles,
    required this.onTap,
    required this.onOpenVideo,
  });

  final int number;
  final RecipeStep step;
  final bool checked;
  final _CookingStyles styles;
  final VoidCallback onTap;
  final VoidCallback? onOpenVideo;

  @override
  Widget build(BuildContext context) {
    return _CheckableRow(
      checked: checked,
      onTap: onTap,
      semanticsLabel: '手順$number ${step.text}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CheckIcon(checked: checked, scale: styles.scale),
            const SizedBox(width: 8),
            SizedBox(
              width: 28 * styles.scale,
              child: Text('$number', style: styles.amount),
            ),
            Expanded(child: Text(step.text, style: styles.body)),
            if (onOpenVideo != null)
              TextButton.icon(
                onPressed: onOpenVideo,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(formatTimestamp(step.startSeconds!)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckIcon extends StatelessWidget {
  const _CheckIcon({required this.checked, required this.scale});

  final bool checked;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Icon(
      checked ? Icons.check_box : Icons.check_box_outline_blank,
      size: 24 * scale,
      color: checked ? Theme.of(context).colorScheme.primary : null,
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.message, required this.styles, required this.onEdit});

  final String message;
  final _CookingStyles styles;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: styles.body),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit),
              label: const Text('概要欄を編集して追加'),
            ),
          ],
        ),
      ),
    );
  }
}
