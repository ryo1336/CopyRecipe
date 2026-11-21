import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ingredient.dart';
import '../../parser/serialize.dart';
import 'cooking_checks.dart';
import 'cooking_settings.dart';

/// 端末の文字サイズ設定（[base]）に、アプリ内の文字サイズの倍率を掛ける
class MultipliedTextScaler extends TextScaler {
  const MultipliedTextScaler(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is MultipliedTextScaler &&
      other.base == base &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}

/// 子の文字すべてに、料理中画面の文字サイズ設定を効かせる
class CookingTextScale extends ConsumerWidget {
  const CookingTextScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(cookingFontSizeProvider);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MultipliedTextScaler(
          MediaQuery.textScalerOf(context),
          fontSize.scale,
        ),
      ),
      child: child,
    );
  }
}

/// 料理中画面の文字のスタイル
class CookingStyles {
  /// 文字の大きさの倍率は [CookingTextScale] で掛けるので、ここでは掛けない。
  /// [scale] はアイコンや余白など、文字以外の大きさをそろえるのに使う。
  CookingStyles(ThemeData theme, this.scale)
    : title = const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      section = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      group = TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
      ),
      body = const TextStyle(fontSize: 17, height: 1.4),
      amount = const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      caption = TextStyle(fontSize: 13, color: theme.hintColor);

  /// 文字サイズの設定に合わせたスタイル
  factory CookingStyles.of(BuildContext context, WidgetRef ref) =>
      CookingStyles(
        Theme.of(context),
        ref.watch(cookingFontSizeProvider).scale,
      );

  final TextStyle title;
  final TextStyle section;
  final TextStyle group;
  final TextStyle body;
  final TextStyle amount;
  final TextStyle caption;
  final double scale;
}

/// 行全体をタップするとチェックが付く。チェック済みの行は薄く表示する
class CheckableRow extends StatelessWidget {
  const CheckableRow({
    super.key,
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

class CheckIcon extends StatelessWidget {
  const CheckIcon({super.key, required this.checked, required this.scale});

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

/// 材料のチェックリスト（グループ見出し付き）。料理中画面の材料欄に使う
class IngredientChecklist extends ConsumerWidget {
  const IngredientChecklist({
    super.key,
    required this.videoId,
    required this.ingredients,
  });

  final String videoId;
  final List<Ingredient> ingredients;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styles = CookingStyles.of(context, ref);
    final checks = ref.watch(cookingChecksProvider(videoId));
    final notifier = ref.read(cookingChecksProvider(videoId).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groupIngredients(ingredients)) ...[
          if (group.name != null)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(group.name!, style: styles.group),
            ),
          for (final (i, ingredient) in group.items)
            _IngredientRow(
              ingredient: ingredient,
              checked: checks.ingredients.contains(i),
              styles: styles,
              onTap: () => notifier.toggleIngredient(i),
            ),
        ],
      ],
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
  final CookingStyles styles;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CheckableRow(
      checked: checked,
      onTap: onTap,
      semanticsLabel: [
        ingredient.name,
        if (ingredient.amount != null) ingredient.amount!,
      ].join(' '),
      child: Row(
        children: [
          CheckIcon(checked: checked, scale: styles.scale),
          const SizedBox(width: 8),
          Expanded(
            child: ingredient.amount == null
                ? Text(ingredient.name, style: styles.body)
                : _NameAndAmount(
                    name: ingredient.name,
                    amount: ingredient.amount!,
                    styles: styles,
                  ),
          ),
        ],
      ),
    );
  }
}

/// 「材料名 ・・・・・ 分量」の1行。
///
/// 分量を右端にそろえ、間を点線でつなぐ。行ごとに分量の位置がばらつかないので、
/// 離れた場所からでも材料名から分量へ目で追える。
/// 材料名は行の幅の 42%、分量は 50% までで折り返し、残りをすべて点線にする
/// （Flexible で幅を分けると、材料名が使わなかった分が行末の空白になり、分量が右端にそろわない）。
class _NameAndAmount extends StatelessWidget {
  const _NameAndAmount({
    required this.name,
    required this.amount,
    required this.styles,
  });

  final String name;
  final String amount;
  final CookingStyles styles;

  @override
  Widget build(BuildContext context) {
    final dotColor = Theme.of(context).colorScheme.outlineVariant;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.42),
            child: Text(name, style: styles.body),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CustomPaint(
              size: const Size.fromHeight(4),
              painter: _DotLeaderPainter(dotColor),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.5),
            child: Text(amount, style: styles.amount, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _DotLeaderPainter extends CustomPainter {
  const _DotLeaderPainter(this.color);

  final Color color;

  static const _gap = 6.0;
  static const _radius = 1.3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final y = size.height / 2;
    for (var x = _radius; x < size.width; x += _gap) {
      canvas.drawCircle(Offset(x, y), _radius, paint);
    }
  }

  @override
  bool shouldRepaint(_DotLeaderPainter old) => old.color != color;
}
