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

/// 比べやすいよう表記をそろえる（全角英数字→半角、小文字、半角カタカナ→全角、カタカナ→ひらがな）
String _fold(String text) {
  final buffer = StringBuffer();
  for (final rune in _widenKatakana(normalize(text).toLowerCase()).runes) {
    // 「ァ」(U+30A1)〜「ヶ」(U+30F6) をひらがなへ。「ヷ」以降は対応するひらがながない
    buffer.writeCharCode(rune >= 0x30A1 && rune <= 0x30F6 ? rune - 0x60 : rune);
  }
  return buffer.toString();
}

/// 半角カタカナ「｡」(U+FF61)〜「ﾝ」(U+FF9D) に対応する全角の文字
const _halfwidthToFullwidth =
    '。「」、・ヲァィゥェォャュョッー'
    'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン';

/// 半角カタカナを全角にする。続く濁点「ﾞ」・半濁点「ﾟ」は、前の文字と合わせて1文字にする
String _widenKatakana(String text) {
  final out = <int>[];
  for (final rune in text.runes) {
    if (rune >= 0xFF61 && rune <= 0xFF9D) {
      out.add(_halfwidthToFullwidth.codeUnitAt(rune - 0xFF61));
    } else if ((rune == 0xFF9E || rune == 0xFF9F) && out.isNotEmpty) {
      final combined = _combineMark(out.last, voiced: rune == 0xFF9E);
      if (combined != null) {
        out.last = combined;
      } else {
        out.add(rune == 0xFF9E ? 0x309B : 0x309C); // 合わせられなければ全角の「゛」「゜」
      }
    } else {
      out.add(rune);
    }
  }
  return String.fromCharCodes(out);
}

/// 全角カタカナ [base] に濁点（[voiced]）か半濁点を付けた文字。付けられなければ null
int? _combineMark(int base, {required bool voiced}) {
  const u = 0x30A6, ka = 0x30AB, to = 0x30C8, ha = 0x30CF, ho = 0x30DB;
  // 「ッ」(U+30C3) は「カ」〜「ト」の範囲にあるが、濁点は付かない
  final isKaToTo = base >= ka && base <= to && base != 0x30C3;
  final isHaToHo = base >= ha && base <= ho && (base - ha) % 3 == 0;
  if (voiced) {
    if (base == u) return 0x30F4; // ヴ
    // カ行〜タ行は清音と濁音が交互に並ぶ（カ・ガ・キ・ギ…）。「ツ」の前の「ッ」で1つずれる
    if (isKaToTo &&
        ((base < 0x30C3) ? (base - ka).isEven : (base - 0x30C4).isEven)) {
      return base + 1;
    }
    if (isHaToHo) return base + 1;
    return null;
  }
  return isHaToHo ? base + 2 : null;
}
