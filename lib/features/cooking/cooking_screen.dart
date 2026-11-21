import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/recipe.dart';
import '../../models/recipe_step.dart';
import '../../parser/chapters.dart';
import '../../parser/serialize.dart';
import '../../providers/recipes_provider.dart';
import 'cooking_checks.dart';
import 'cooking_settings.dart';
import 'cooking_widgets.dart';
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

  Future<void> _copyIngredients(Recipe recipe) async {
    await Clipboard.setData(
      ClipboardData(text: formatIngredientsForCopy(recipe)),
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('材料をコピーしました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = ref.watch(recipeByIdProvider(widget.videoId));
    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.amber),
        body: const Center(child: Text('このレシピは削除されました')),
      );
    }

    final checks = ref.watch(cookingChecksProvider(widget.videoId));
    final checksNotifier = ref.read(
      cookingChecksProvider(widget.videoId).notifier,
    );
    final fontSize = ref.watch(cookingFontSizeProvider);
    final styles = CookingStyles.of(context, ref);

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
          if (!checks.isEmpty)
            IconButton(
              icon: const Icon(Icons.restart_alt),
              tooltip: 'すべてのチェックを外す',
              onPressed: checksNotifier.reset,
            ),
        ],
      ),
      body: CookingTextScale(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _Header(
              recipe: recipe,
              styles: styles,
              onOpenVideo: () => openVideo(context, ref, recipe.videoId, 0),
            ),
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
              )
            else
              IngredientChecklist(
                videoId: widget.videoId,
                ingredients: recipe.ingredients,
              ),
            const SizedBox(height: 24),

            // 作り方
            _SectionTitle(title: '作り方', styles: styles),
            if (recipe.steps.isEmpty)
              _NotFound(
                message: '工程が見つかりませんでした',
                styles: styles,
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
                      : () => openVideo(
                          context,
                          ref,
                          recipe.videoId,
                          step.startSeconds!,
                        ),
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
      ),
    );
  }
}

/// 動画を開く。開けなければ通知を出す
Future<void> openVideo(
  BuildContext context,
  WidgetRef ref,
  String videoId,
  int startSeconds,
) async {
  final opened = await ref
      .read(videoLauncherProvider)
      .open(videoId, startSeconds: startSeconds);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('動画を開けませんでした')));
  }
}

/// 材料をクリップボード用のテキストにする（グループは【】の見出しにする）
String formatIngredientsForCopy(Recipe recipe) => [
  if (recipe.servings != null) '材料（${recipe.servings}）' else '材料',
  ...ingredientsToLines(recipe.ingredients).where((l) => l.isNotEmpty),
].join('\n');

class _Header extends StatelessWidget {
  const _Header({
    required this.recipe,
    required this.styles,
    required this.onOpenVideo,
  });

  final Recipe recipe;
  final CookingStyles styles;
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
  const _SectionTitle({
    required this.title,
    required this.styles,
    this.trailing,
  });

  final String title;
  final CookingStyles styles;
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
  final CookingStyles styles;
  final VoidCallback onTap;
  final VoidCallback? onOpenVideo;

  @override
  Widget build(BuildContext context) {
    return CheckableRow(
      checked: checked,
      onTap: onTap,
      semanticsLabel: '手順$number ${step.text}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckIcon(checked: checked, scale: styles.scale),
            const SizedBox(width: 8),
            // 2桁以上の番号や大きな文字でも折り返さないよう、幅は最小値だけ決める
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: 28 * styles.scale),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('$number', style: styles.amount, softWrap: false),
              ),
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

class _NotFound extends StatelessWidget {
  const _NotFound({
    required this.message,
    required this.styles,
  });

  final String message;
  final CookingStyles styles;

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
            const SizedBox(height: 4),
            Text('下の「概要欄の全文」や動画で確認してください', style: styles.caption),
          ],
        ),
      ),
    );
  }
}
