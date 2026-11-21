import '../models/ingredient.dart';
import '../models/recipe_step.dart';
import 'chapters.dart';
import 'ingredients.dart';
import 'normalize.dart';
import 'sections.dart';
import 'steps.dart';

/// 抽出処理の版。ルールを変えたら上げる（保存済みレシピの再抽出に使う）
const int kParserVersion = 2;

class ParseResult {
  final List<Ingredient> ingredients;
  final List<RecipeStep> steps;
  final String? servings;
  final List<Chapter> chapters;

  const ParseResult({
    required this.ingredients,
    required this.steps,
    required this.servings,
    required this.chapters,
  });

  bool get hasIngredients => ingredients.isNotEmpty;
  bool get hasSteps => steps.isNotEmpty;
}

enum _Section { none, ingredients, steps, other }

final _ruleOnly = RegExp(r'^[━─=\-_~〜*＊・.。◆◇■□●○★☆▼▽▲△♦◉♪]+$');

/// 概要欄からレシピ（材料・工程・人数・チャプター）を抽出する
ParseResult parseRecipe(String description) {
  final lines = normalize(description).split('\n');

  var section = _Section.none;
  var blankCount = 0;
  String? servings;
  final ingredientLines = <String>[];
  final stepLines = <String>[];

  for (final line in lines) {
    final text = line.trim();

    if (text.isEmpty) {
      blankCount++;
      if (blankCount >= 3 &&
          (section == _Section.ingredients || section == _Section.steps)) {
        section = _Section.other;
      }
      if (section == _Section.ingredients) ingredientLines.add('');
      continue;
    }
    blankCount = 0;

    // 「━━━━」のような罫線だけの行は読み飛ばす
    if (_ruleOnly.hasMatch(text)) continue;

    final header = classifyHeader(text);
    if (header != null) {
      switch (header.kind) {
        case HeaderKind.ingredients:
          section = _Section.ingredients;
          servings ??= extractServings(text);
          // 「ソースの材料」などはグループ見出しとして渡す
          ingredientLines.add('');
          if (header.group != null) ingredientLines.add('【${header.group}】');
        case HeaderKind.steps:
          section = _Section.steps;
        case HeaderKind.other:
          section = _Section.other;
      }
      continue;
    }

    if (isFooterLine(text)) {
      section = _Section.other;
      continue;
    }

    switch (section) {
      case _Section.ingredients:
        if (parseTimestampLine(text) != null) {
          // 材料の直後にチャプター一覧が続くケース
          section = _Section.other;
        } else if (isNumberedStepLine(text)) {
          // 見出しなしで作り方が始まったケース
          section = _Section.steps;
          stepLines.add(text);
        } else {
          ingredientLines.add(text);
        }
      case _Section.steps:
        // 時刻なしの工程の後に続くタイムスタンプ行は、チャプター一覧とみなす
        if (parseTimestampLine(text) != null &&
            stepLines.any((l) => parseTimestampLine(l) == null)) {
          section = _Section.other;
        } else {
          stepLines.add(text);
        }
      case _Section.none:
      case _Section.other:
        if (ingredientLines.any((l) => l.isNotEmpty) &&
            stepLines.isEmpty &&
            isNumberedStepLine(text)) {
          section = _Section.steps;
          stepLines.add(text);
        }
    }
  }

  final chapters = parseChapters(lines);
  return ParseResult(
    ingredients: parseIngredientLines(ingredientLines),
    steps: mergeStepsWithChapters(parseStepLines(stepLines), chapters),
    servings: servings,
    chapters: chapters,
  );
}
