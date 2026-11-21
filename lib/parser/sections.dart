/// 見出し行の種類
enum HeaderKind { ingredients, steps, other }

class HeaderMatch {
  final HeaderKind kind;

  /// 「ソースの材料」の「ソース」のように、見出しから分かるグループ名
  final String? group;

  const HeaderMatch(this.kind, {this.group});
}

/// 見出しの判定前に取り除く装飾記号
final _decoration = RegExp(
  r'[【】\[\]()<>〈〉《》「」『』■□◆◇●○◎★☆▼▽▲△♦◉・:\-=━─_~〜*#|♪!、。\s]',
);

final _ingredientsHeader = RegExp(
  r'^(?:今回の|基本の|本日の|今日の)?(?:(.{1,10}?)の)?(?:材料|ingredients?|レシピ|recipe)(.*)$',
);
final _ingredientsRest = RegExp(
  r'^(?:\d+(?:人分|人前|個分|枚分|本分|台分|皿分|杯分|cm型|cm|型|号|合)?'
  r'|作りやすい分量|分量|はこちら|です|一覧|リスト|/|と|約|直径|用)*$',
);
final _servingsOnlyHeader = RegExp(r'^\d+(?:人分|人前)(?:の材料)?$');

final _stepsHeader = RegExp(
  r'^(?:(.{1,10}?)の)?(?:作り方|つくり方|作りかた|手順|調理手順|工程|調理工程|レシピ手順'
  r'|howto|howtomake|directions|method)(?:はこちら)?\d*$',
);

/// 材料・作り方以外の見出し。本文の行（「注意しながら焼く」など）を見出しと
/// 取り違えないよう、装飾記号を除いた行全体が一致する場合だけ見出しとみなす
final _otherHeader = RegExp(
  r'^(?:ポイント|コツ|memo|メモ|注意|注意点|目次|チャプター|タイムスタンプ|chapters?|index'
  r'|保存方法|アレンジ|おすすめ|関連動画|おすすめ動画|使用した道具|道具|調理器具|使ったもの'
  r'|使用した器具|動画の内容)(?:はこちら|一覧)?$',
);

/// 見出しとしてのグループ名に使わない語
const _notGroupNames = {'今回', '基本', '本日', '今日'};

/// 見出し行なら種類を返す。見出しでなければ null。
HeaderMatch? classifyHeader(String line) {
  final core = line.replaceAll(_decoration, '').toLowerCase();
  if (core.isEmpty || core.length > 25) return null;

  if (_servingsOnlyHeader.hasMatch(core)) {
    return const HeaderMatch(HeaderKind.ingredients);
  }

  final ing = _ingredientsHeader.firstMatch(core);
  if (ing != null && _ingredientsRest.hasMatch(ing.group(2)!)) {
    final group = ing.group(1);
    return HeaderMatch(
      HeaderKind.ingredients,
      group: group == null || _notGroupNames.contains(group) ? null : group,
    );
  }

  if (_stepsHeader.hasMatch(core)) return const HeaderMatch(HeaderKind.steps);

  if (_otherHeader.hasMatch(core)) {
    return const HeaderMatch(HeaderKind.other);
  }
  return null;
}

final _leadingDecoration = RegExp(r'^[\s【\[(<〈《「『■□◆◇●○◎★☆▼▽▲△♦◉・\-=━─*▶▷►→]+');
final _footer = RegExp(
  r'^(?:sns|instagram|insta|twitter|tiktok|line(?:\s|$|[:@])|facebook|x\s*[:(]|提供|協賛|スポンサー'
  r'|チャンネル登録|お仕事|コラボ|https?://|bgm|音楽|使用機材|撮影機材|お問い合わせ|書籍|著書'
  r'|楽天|amazon|pr(?:\s|$|[:)])|#\S)',
);

/// SNS リンクや宣伝など、レシピの範囲外を示す行かどうか
bool isFooterLine(String line) {
  final text = line.replaceFirst(_leadingDecoration, '').toLowerCase();
  return _footer.hasMatch(text);
}

final _servings = RegExp(r'(\d+(?:\s*[~〜\-]\s*\d+)?)\s*人(?:分|前)');

/// 「材料(2〜3人分)」のような行から「2〜3人分」を取り出す
String? extractServings(String line) {
  final m = _servings.firstMatch(line);
  if (m != null) {
    return '${m.group(1)!.replaceAll(RegExp(r'\s'), '').replaceAll(RegExp(r'[~\-]'), '〜')}人分';
  }
  if (line.contains('作りやすい分量')) return '作りやすい分量';
  return null;
}
