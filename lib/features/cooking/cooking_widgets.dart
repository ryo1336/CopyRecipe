import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ingredient.dart';
import '../../parser/serialize.dart';
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

/// 材料・工程の1行。濡れた手で画面に触れずに読むだけなので、操作はなく、
/// 離れた場所からでも行の区切りが分かるよう高さだけ確保する
class RecipeRow extends StatelessWidget {
  const RecipeRow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Align(alignment: AlignmentDirectional.centerStart, child: child),
    );
  }
}

/// 材料の一覧（グループ見出し付き）。料理中画面の材料欄に使う
class IngredientList extends ConsumerWidget {
  const IngredientList({super.key, required this.ingredients});

  final List<Ingredient> ingredients;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styles = CookingStyles.of(context, ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groupIngredients(ingredients)) ...[
          if (group.name != null)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(group.name!, style: styles.group),
            ),
          for (final (_, ingredient) in group.items)
            _IngredientRow(ingredient: ingredient, styles: styles),
        ],
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ingredient, required this.styles});

  final Ingredient ingredient;
  final CookingStyles styles;

  @override
  Widget build(BuildContext context) {
    return RecipeRow(
      // 材料名と分量を1つの項目として読み上げる
      child: MergeSemantics(
        child: ingredient.amount == null
            ? Text(ingredient.name, style: styles.body)
            : _NameAndAmount(
                name: ingredient.name,
                amount: ingredient.amount!,
                styles: styles,
              ),
      ),
    );
  }
}

/// 「材料名 ・・・・・ 分量」の1行。
///
/// 分量を右端にそろえ、間を点線でつなぐ。行ごとに分量の位置がばらつかないので、
/// 離れた場所からでも材料名から分量へ目で追える。
/// 材料名と分量の実際の幅を測って割り当てる（[splitNameAndAmount]）ので、
/// 収まるときは折り返さず、残りはすべて点線になる。
class _NameAndAmount extends StatelessWidget {
  const _NameAndAmount({
    required this.name,
    required this.amount,
    required this.styles,
  });

  final String name;
  final String amount;
  final CookingStyles styles;

  static const _gap = 8.0;

  /// 1行で書いたときの幅（端数で折り返さないよう切り上げる）
  static double _measure(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble() + 1;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = Theme.of(context).colorScheme.outlineVariant;
    return LayoutBuilder(
      builder: (context, constraints) {
        final (nameWidth, amountWidth) = splitNameAndAmount(
          available: constraints.maxWidth - _gap * 2 - minDotLeaderWidth,
          nameWidth: _measure(context, name, styles.body),
          amountWidth: _measure(context, amount, styles.amount),
        );
        return Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: nameWidth),
              child: Text(name, style: styles.body),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: CustomPaint(
                size: const Size.fromHeight(4),
                painter: _DotLeaderPainter(dotColor),
              ),
            ),
            const SizedBox(width: _gap),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: amountWidth),
              child: Text(
                amount,
                style: styles.amount,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 点線に最低限残す幅
const minDotLeaderWidth = 12.0;

/// 材料名と分量に割り当てる最大の幅を決める。
///
/// - 両方が [available] に収まるなら、どちらも1行の幅のまま（残りは点線）
/// - 収まらなければ分量を優先し、材料名の残りを分量に回す。
///   ただし分量が長すぎて材料名が潰れないよう、分量は最低でも半分までは取れるようにする
/// - 2つの合計は [available] を超えないので、狭い画面でも行からはみ出さない
@visibleForTesting
(double, double) splitNameAndAmount({
  required double available,
  required double nameWidth,
  required double amountWidth,
}) {
  final space = available < 0 ? 0.0 : available;
  if (nameWidth + amountWidth <= space) return (nameWidth, amountWidth);
  final rest = space - nameWidth;
  final amount = amountWidth.clamp(0.0, rest > space / 2 ? rest : space / 2);
  return (space - amount, amount);
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
