import '../models/ingredient.dart';

/// 材料をグループごとにまとめたもの
class IngredientGroup {
  final String? name;
  final List<Ingredient> items;

  const IngredientGroup(this.name, this.items);
}

/// 連続する同じグループの材料をまとめる（表示とコピーで共通に使う）
List<IngredientGroup> groupIngredients(List<Ingredient> ingredients) {
  final groups = <IngredientGroup>[];
  for (final ingredient in ingredients) {
    if (groups.isEmpty || groups.last.name != ingredient.group) {
      groups.add(IngredientGroup(ingredient.group, []));
    }
    groups.last.items.add(ingredient);
  }
  return groups;
}

/// 材料をテキスト（行のリスト）にする（コピー用）。
///
/// - 1行に1材料で「材料名 分量」
/// - グループは【】で囲んだ見出し行で始め、空行で終える
List<String> ingredientsToLines(List<Ingredient> ingredients) {
  final lines = <String>[];
  for (final group in groupIngredients(ingredients)) {
    if (group.name != null) lines.add('【${group.name}】');
    for (final ingredient in group.items) {
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
