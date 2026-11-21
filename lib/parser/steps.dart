import '../models/recipe_step.dart';
import 'chapters.dart';

/// 番号付きの工程行（厳密版）。材料欄から作り方への切り替わりの判定に使う
final _strictNumbered = RegExp(
  r'^(?:(?:step|ステップ|手順)\s*\d{1,2}\s*[.:)、]?|\d{1,2}\s*[.)、](?!\d)|\(\d{1,2}\)|[①-⑳])\s*',
  caseSensitive: false,
);

/// 番号付きの工程行（作り方欄の中で使う緩い版。「1 大根を切る」も認める）
final _looseNumbered = RegExp(r'^\d{1,2}\s+(?=\D)');

final _bullet = RegExp(r'^[・●○■□◆◇♦◉\-*•▪︎]+\s*');

/// 番号付きの工程行かどうか（材料欄の途中で作り方が始まったことの判定に使う）
bool isNumberedStepLine(String line) => _strictNumbered.hasMatch(line.trim());

/// 作り方欄の行のリストを工程のリストに変換する。
///
/// - 番号付きの行があれば、番号ごとに1工程とし、番号のない行は直前の工程に続けて書く
/// - 番号付きの行がなければ、1行を1工程とする
/// - 行頭（または行末）にタイムスタンプがあれば、その工程の開始時刻にする
///
/// 抽出処理と編集画面の両方から使う。
List<RecipeStep> parseStepLines(List<String> lines) {
  final texts = lines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final hasNumbered = texts.any(
    (t) => _strictNumbered.hasMatch(t) || _looseNumbered.hasMatch(t),
  );

  final steps = <_StepBuilder>[];
  for (final text in texts) {
    final chapter = parseTimestampLine(text);
    if (chapter != null) {
      steps.add(_StepBuilder(_stripNumber(chapter.title), chapter.seconds));
      continue;
    }

    final numbered = _strictNumbered.firstMatch(text) ?? _looseNumbered.firstMatch(text);
    if (numbered != null) {
      steps.add(_StepBuilder(text.substring(numbered.end).trim(), null));
    } else if (hasNumbered) {
      // 番号なしの行は直前の工程の続き（番号付きの工程が始まる前の前置きは捨てる）
      if (steps.isNotEmpty) steps.last.append(text);
    } else {
      steps.add(_StepBuilder(text.replaceFirst(_bullet, ''), null));
    }
  }

  return steps
      .where((s) => s.text.isNotEmpty)
      .map((s) => RecipeStep(text: s.text, startSeconds: s.seconds))
      .toList();
}

String _stripNumber(String text) {
  final m = _strictNumbered.firstMatch(text);
  return m == null ? text : text.substring(m.end).trim();
}

class _StepBuilder {
  String text;
  final int? seconds;

  _StepBuilder(this.text, this.seconds);

  void append(String line) {
    text = text.isEmpty ? line : '$text\n$line';
  }
}

/// 工程として扱わないチャプター名
const _nonStepWords =
    r'(?:オープニング|opening|op|イントロ|intro|はじめに|ご?挨拶|試食|実食|いただきます|完成'
    r'|エンディング|ending|ed|まとめ|おわりに|終わりに|お知らせ|告知|材料紹介|材料の紹介|材料'
    r'|今日の材料|今回の材料)';
final _nonStepChapter = RegExp(
  '^$_nonStepWords(?:\\s*[・&と/]\\s*$_nonStepWords)*[!。]*\$',
  caseSensitive: false,
);

bool _isNonStepChapter(String title) => _nonStepChapter.hasMatch(title.trim());

/// 工程とチャプターを組み合わせる。
///
/// - 工程がなければ、チャプター（オープニングなどを除く）を工程として使う
/// - 工程があり時刻がなければ、文言が似ているチャプターの時刻を順番に割り当てる
List<RecipeStep> mergeStepsWithChapters(
  List<RecipeStep> steps,
  List<Chapter> chapters,
) {
  final timed = steps
      .where((s) => !(s.startSeconds != null && _isNonStepChapter(s.text)))
      .toList();

  if (chapters.isEmpty) return timed;

  final usable = chapters.where((c) => !_isNonStepChapter(c.title)).toList();
  if (timed.isEmpty) {
    return usable
        .map((c) => RecipeStep(text: c.title, startSeconds: c.seconds))
        .toList();
  }
  if (timed.any((s) => s.startSeconds != null)) return timed;

  // 順番を保ったまま、似ているチャプターを割り当てる
  final result = <RecipeStep>[];
  var from = 0;
  for (final step in timed) {
    var bestIndex = -1;
    var bestScore = 0.3; // これ未満は似ていないとみなす
    for (var i = from; i < usable.length; i++) {
      final score = _similarity(step.text, usable[i].title);
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    if (bestIndex >= 0) {
      result.add(RecipeStep(text: step.text, startSeconds: usable[bestIndex].seconds));
      from = bestIndex + 1;
    } else {
      result.add(step);
    }
  }
  return result;
}

/// 文字の2-gram による類似度（Dice 係数）
double _similarity(String a, String b) {
  Set<String> bigrams(String s) {
    final t = s.replaceAll(RegExp(r'\s'), '');
    return {for (var i = 0; i < t.length - 1; i++) t.substring(i, i + 2)};
  }

  final x = bigrams(a);
  final y = bigrams(b);
  if (x.isEmpty || y.isEmpty) return 0;
  return 2 * x.intersection(y).length / (x.length + y.length);
}
