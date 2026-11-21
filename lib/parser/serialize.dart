import '../models/ingredient.dart';
import '../models/recipe_step.dart';
import 'chapters.dart';

/// 材料をグループごとにまとめたもの。[items] の番号は元のリストでの位置
class IngredientGroup {
  final String? name;
  final List<(int, Ingredient)> items;

  const IngredientGroup(this.name, this.items);
}

/// 連続する同じグループの材料をまとめる（表示・コピー・編集用テキストで共通に使う）
List<IngredientGroup> groupIngredients(List<Ingredient> ingredients) {
  final groups = <IngredientGroup>[];
  for (final (i, ingredient) in ingredients.indexed) {
    if (groups.isEmpty || groups.last.name != ingredient.group) {
      groups.add(IngredientGroup(ingredient.group, []));
    }
    groups.last.items.add((i, ingredient));
  }
  return groups;
}

/// 材料を「材料名 分量」の行にする。グループは【】の見出し行にし、
/// グループの終わりには空行を入れる（parseIngredientLines で同じ材料に戻せる形）
List<String> ingredientsToLines(List<Ingredient> ingredients) {
  final lines = <String>[];
  for (final group in groupIngredients(ingredients)) {
    if (group.name != null) lines.add('【${group.name}】');
    for (final (_, ingredient) in group.items) {
      lines.add(
        ingredient.amount == null
            ? ingredient.name
            : '${ingredient.name} ${ingredient.amount}',
      );
    }
    if (group.name != null) lines.add('');
  }
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}

/// 工程を1行1工程にする。時刻がある工程は行頭に「1:12」を付ける
/// （parseStepLines で同じ工程に戻せる形。工程内の改行は空白にする）
List<String> stepsToLines(List<RecipeStep> steps) => [
  for (final step in steps)
    [
      if (step.startSeconds != null) formatTimestamp(step.startSeconds!),
      step.text.replaceAll('\n', ' '),
    ].join(' '),
];
