import '../models/ingredient.dart';
import '../models/recipe_step.dart';
import 'chapters.dart';
import 'ingredients.dart';

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

/// 材料を編集用のテキスト（行のリスト）にする。
///
/// - 1行に1材料で「材料名 分量」
/// - グループは【】で囲んだ見出し行で始め、空行で終える
///
/// [parseEditedIngredientLines] で同じ材料に戻せる。
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

final _editedGroupHeading = RegExp(r'^【(.+)】$');

/// 編集画面で入力された材料のテキストを材料のリストに戻す。
///
/// 概要欄の抽出（parseIngredientLines）と違い、推測はしない。
/// 見出しは【】で囲んだ行だけで、それ以外の行はすべて材料として残す
/// （「トッピング用ねぎ」のような分量のない材料が見出しに化けないように）。
List<Ingredient> parseEditedIngredientLines(List<String> lines) {
  final result = <Ingredient>[];
  String? group;
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) {
      group = null;
      continue;
    }
    final heading = _editedGroupHeading.firstMatch(line);
    if (heading != null) {
      group = heading.group(1)!.trim();
      continue;
    }
    result.add(
      parseIngredientLine(line, group: group) ??
          Ingredient(name: line, group: group),
    );
  }
  return result;
}

/// 工程を編集用のテキスト（行のリスト）にする。
///
/// - 1行に1工程で、行頭に「1.」の番号を付ける
/// - 時刻がある工程は番号の後に「1:12」を付ける
/// - 工程内の改行は、字下げした続きの行にする
///
/// [parseEditedStepLines] で同じ工程に戻せる。
List<String> stepsToLines(List<RecipeStep> steps) => [
  for (final (i, step) in steps.indexed) ...[
    [
      '${i + 1}.',
      if (step.startSeconds != null) formatTimestamp(step.startSeconds!),
      step.text.split('\n').first,
    ].join(' '),
    for (final rest in step.text.split('\n').skip(1))
      '$_continuationIndent$rest',
  ],
];

const _continuationIndent = '    ';
final _editedNumber = RegExp(r'^\d{1,3}\.(?!\d)\s*');
final _editedTimestamp = RegExp(r'^(?:(\d{1,2}):)?(\d{1,2}):(\d{2})(?:\s+|$)');
final _indented = RegExp(r'^[ \t\u3000]');

/// 編集画面で入力された作り方のテキストを工程のリストに戻す。
///
/// - 1行に1工程。行頭の「1.」の番号は省略できる（書いてあれば外す）
/// - 番号の後（または行頭）の「1:12」は動画の開始時刻にする
/// - 字下げした行は直前の工程の続き（工程内の改行）にする
///
/// 概要欄の抽出（parseStepLines）と違い、「①」「(1)」などで始まる本文は
/// 番号とみなさず、そのまま残す。
List<RecipeStep> parseEditedStepLines(List<String> lines) {
  final steps = <(String, int?)>[];
  for (final raw in lines) {
    if (raw.trim().isEmpty) continue;
    if (_indented.hasMatch(raw) && steps.isNotEmpty) {
      final (text, seconds) = steps.removeLast();
      steps.add(('$text\n${raw.trim()}', seconds));
      continue;
    }
    var line = raw.trim().replaceFirst(_editedNumber, '');
    int? seconds;
    final ts = _editedTimestamp.firstMatch(line);
    if (ts != null) {
      final sec = int.parse(ts.group(3)!);
      final min = int.parse(ts.group(2)!);
      if (sec < 60) {
        seconds =
            (int.tryParse(ts.group(1) ?? '') ?? 0) * 3600 + min * 60 + sec;
        line = line.substring(ts.end);
      }
    }
    if (line.trim().isEmpty) continue;
    steps.add((line.trim(), seconds));
  }
  return [
    for (final (text, seconds) in steps)
      RecipeStep(text: text, startSeconds: seconds),
  ];
}
