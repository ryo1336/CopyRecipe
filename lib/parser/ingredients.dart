import '../models/ingredient.dart';

/// 分量の書き出しになりうる文字列
final _amountStart = RegExp(
  r'^(?:大さじ|小さじ|大匙|小匙|カップ|約|各|少々|適量|適宜|お好み|好み|ひとつまみ|ひとつかみ'
  r'|少量|半分|半個|半丁|ひとかけ|ひと片|ひとつ|\d|½|¼|¾)',
);

/// 空白なしの行で分量の書き出しとみなす文字列。
///
/// 材料名の中に現れうる語（「お好み焼き」の「好み」、「マグカップ」の「カップ」など）で
/// 分けてしまわないよう、数字・大さじ・小さじと、行末にある「少々」などに限る
final _inlineAmountStart = RegExp(
  r'^(?:大さじ|小さじ|大匙|小匙|\d|½|¼|¾|(?:少々|適量|適宜|ひとつまみ|少量)$)',
);

/// 直前がこの文字なら、そこでは分けない（「(200g)」の途中や「1/2」の途中）
final _noSplitAfter = RegExp(r'[\d(/.]');

/// 分量らしい文字列が含まれているか
final _amountLike = RegExp(
  r'\d|大さじ|小さじ|大匙|小匙|カップ|少々|適量|適宜|お好み|ひとつまみ|ひとつかみ|少量|半分'
  r'|ひとかけ|ひと片|½|¼|¾',
);

/// 材料名と分量を明示的に区切る記号（「…」「・・」「..」「:」など）
final _explicitSeparator = RegExp(r'\s*(?:…+|‥+|・{2,}|\.{2,}|-{2,}|ー{2,}|─+|:)\s*');

/// 行頭の箇条書き記号（グループの意味を持たないもの）
final _plainBullet = RegExp(r'^[・●○■□◆♦◉\-*•▪︎✓✔]+\s*');

/// 行頭のグループ記号（★醤油 のように、同じ記号の材料をまとめる）
final _groupMarker = RegExp(r'^([★☆◎◇▲△])\s*');

/// 括弧で囲まれた行（【A】、(タレ) など）
final _bracketed = RegExp(r'^[【\[(<〈《「『]\s*(.+?)\s*[】\])>〉》」』]$');

/// 行頭の1文字アルファベット（「A 醤油 大さじ1」「a. 砂糖 大さじ1」）
final _letterPrefix = RegExp(r'^([A-Za-z])(?:\s+|[.:)]\s*)(.+)$');

/// グループ見出しによく使われる語
final _groupWords = RegExp(
  r'タレ|たれ|ソース|調味料|合わせ|衣|トッピング|生地|ドレッシング|下味|仕上げ|飾り|具材|スープ|つけ汁|漬け汁',
);

/// 末尾に分量だけが括弧書きされた行（「豚肉(200g)」）
final _parenAmount = RegExp(r'^(.+?)\s*\(([^()]*)\)$');

/// 材料欄の行のリストを材料のリストに変換する。
///
/// 空行（''）はグループの区切りとして扱う。
List<Ingredient> parseIngredientLines(List<String> lines) {
  final result = <Ingredient>[];
  final markerGroups = <String, String>{};
  String? currentGroup;
  var groupHasItems = false;

  for (final raw in lines) {
    var line = raw.trim();
    if (line.isEmpty) {
      if (groupHasItems) currentGroup = null;
      continue;
    }
    if (line.startsWith('※') || line.startsWith('http') || line.length > 40) {
      continue;
    }

    // 【A】 や (タレ) などの括弧付き見出し
    final bracket = _bracketed.firstMatch(line);
    if (bracket != null) {
      final inner = bracket.group(1)!;
      if (!_amountLike.hasMatch(inner) && !inner.contains('分量')) {
        currentGroup = inner;
        groupHasItems = false;
      }
      continue;
    }

    // A だけの行
    if (RegExp(r'^[A-Za-z]$').hasMatch(line)) {
      currentGroup = line;
      groupHasItems = false;
      continue;
    }

    // 「・a. 砂糖」のように箇条書き記号の後にグループ記号が来ることがあるので、先に外す
    line = line.replaceFirst(_plainBullet, '');

    // 「A 醤油 大さじ1」
    String? lineGroup;
    final letter = _letterPrefix.firstMatch(line);
    if (letter != null) {
      lineGroup = letter.group(1);
      line = letter.group(2)!;
    }

    // ★ や ◎ などのグループ記号
    final marker = _groupMarker.firstMatch(line);
    if (marker != null) {
      final symbol = marker.group(1)!;
      final rest = line.substring(marker.end);
      if (_isGroupHeading(rest)) {
        final name = _stripHeadingColon(rest);
        markerGroups[symbol] = name;
        currentGroup = name;
        groupHasItems = false;
        continue;
      }
      lineGroup ??= markerGroups[symbol] ?? symbol;
      line = rest;
    } else {
      line = line.replaceFirst(_plainBullet, '');
      if (lineGroup == null && _isGroupHeading(line)) {
        currentGroup = _stripHeadingColon(line);
        groupHasItems = false;
        continue;
      }
    }

    final ingredient = parseIngredientLine(line, group: lineGroup ?? currentGroup);
    if (ingredient == null) continue;
    result.add(ingredient);
    if (lineGroup == null) groupHasItems = true;
  }
  return result;
}

bool _isGroupHeading(String text) {
  final t = text.trim();
  if (t.isEmpty || _amountLike.hasMatch(t)) return false;
  if (t.endsWith(':')) return t.length <= 16;
  return t.length <= 12 && _groupWords.hasMatch(t);
}

String _stripHeadingColon(String text) =>
    text.trim().replaceFirst(RegExp(r'\s*:$'), '');

/// 1行を材料名と分量に分ける。材料とみなせない行は null。
Ingredient? parseIngredientLine(String line, {String? group}) {
  final text = line.trim();
  if (text.isEmpty) return null;

  String name;
  String? amount;

  final sep = _explicitSeparator.firstMatch(text);
  if (sep != null && sep.start > 0 && sep.end < text.length) {
    name = text.substring(0, sep.start);
    amount = text.substring(sep.end);
  } else {
    final split = _splitByAmount(text);
    name = split.$1;
    amount = split.$2;
  }

  name = name.trim().replaceFirst(RegExp(r'[\s:・…]+$'), '');
  amount = amount?.trim();
  if (amount != null && amount.isEmpty) amount = null;
  if (name.isEmpty) return null;
  // 句点で終わる長い文は説明文とみなす
  if (amount == null && name.endsWith('。')) return null;
  return Ingredient(name: name, amount: amount, group: group);
}

(String, String?) _splitByAmount(String text) {
  // 空白区切りで、分量らしい語から始まる最初の位置で分ける
  final ws = RegExp(r'\s+');
  for (final m in ws.allMatches(text)) {
    final rest = text.substring(m.end);
    if (_amountStart.hasMatch(rest)) {
      return (text.substring(0, m.start), rest);
    }
  }

  // 「豚肉(200g)」
  final paren = _parenAmount.firstMatch(text);
  if (paren != null && _amountLike.hasMatch(paren.group(2)!)) {
    return (paren.group(1)!, paren.group(2)!);
  }

  // 空白なしの「豚バラ肉200g」「砂糖大さじ1」
  for (var i = 1; i < text.length; i++) {
    if (_noSplitAfter.hasMatch(text[i - 1])) continue;
    if (_inlineAmountStart.hasMatch(text.substring(i))) {
      return (text.substring(0, i), text.substring(i));
    }
  }
  return (text, null);
}
