import '../../models/recipe.dart';
import '../../parser/normalize.dart';

/// 材料名で [recipes] を絞り込む。
///
/// - [query] を空白で区切った語の、すべてを材料に含むレシピだけを残す（「豚肉 大根」なら両方を使うレシピ）
/// - 語は材料名の一部に含まれていればよい（「豚」で「豚バラ肉」に当たる）
/// - 全角・半角、英字の大文字・小文字、カタカナ・ひらがなの違いは無視する（「タマネギ」で「玉ねぎ」には当たらないが「たまねぎ」には当たる）
/// - [query] が空なら、そのまま返す
List<Recipe> filterByIngredients(List<Recipe> recipes, String query) {
  final words = _fold(
    query,
  ).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return recipes;

  return recipes.where((recipe) {
    final names = recipe.ingredients.map((i) => _fold(i.name)).toList();
    return words.every((w) => names.any((name) => name.contains(w)));
  }).toList();
}

/// 比べやすいよう表記をそろえる（全角英数字→半角、小文字、カタカナ→ひらがな）
String _fold(String text) {
  final buffer = StringBuffer();
  for (final rune in normalize(text).toLowerCase().runes) {
    // 「ァ」(U+30A1)〜「ヶ」(U+30F6) をひらがなへ。「ヷ」以降は対応するひらがながない
    buffer.writeCharCode(rune >= 0x30A1 && rune <= 0x30F6 ? rune - 0x60 : rune);
  }
  return buffer.toString();
}
