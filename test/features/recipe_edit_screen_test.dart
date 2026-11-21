import 'package:copy_recipe/features/recipe_edit/recipe_edit_screen.dart';
import 'package:copy_recipe/models/ingredient.dart';
import 'package:copy_recipe/models/recipe_step.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

/// 編集画面を、閉じたかどうか分かるよう「開く」ボタンのあるホームの上に重ねて表示する
Future<void> pumpEditor(WidgetTester tester, TestEnv env) async {
  await env.pump(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RecipeEditScreen(videoId: 'aaaaaaaaaaa'),
              ),
            ),
            child: const Text('開く'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('開く'));
  await tester.pumpAndSettle();
}

Finder field(String label) => find.widgetWithText(TextField, label);

String textOf(WidgetTester tester, String label) =>
    tester.widget<TextField>(field(label)).controller!.text;

void main() {
  late TestEnv env;

  setUp(() {
    env = TestEnv([
      sampleRecipe(rawDescription: '【材料】(3人分)\n鶏肉 300g\n\n【作り方】\n1. 焼く'),
    ]);
  });

  testWidgets('今の材料・作り方・人数をテキストにして表示する', (tester) async {
    await pumpEditor(tester, env);

    expect(textOf(tester, '人数'), '2人分');
    expect(textOf(tester, '材料'), '豚バラ肉 200g\n大根 1/3本\n【A】\n醤油 大さじ2\nみりん 大さじ2');
    expect(textOf(tester, '作り方'), '1. 1:12 大根を切る\n2. 豚肉を炒める');
  });

  testWidgets('保存すると構造化して保存し、手で直した印を付けて閉じる', (tester) async {
    await pumpEditor(tester, env);

    await tester.enterText(field('人数'), '');
    await tester.enterText(field('材料'), '鶏肉 300g\n【タレ】\n醤油 大さじ1');
    await tester.enterText(field('作り方'), '0:30 鶏肉を焼く\nタレを絡める');
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    final saved = env.repository.get('aaaaaaaaaaa')!;
    expect(saved.isEdited, isTrue);
    expect(saved.servings, isNull);
    expect(saved.ingredients, const [
      Ingredient(name: '鶏肉', amount: '300g'),
      Ingredient(name: '醤油', amount: '大さじ1', group: 'タレ'),
    ]);
    expect(saved.steps, const [
      RecipeStep(text: '鶏肉を焼く', startSeconds: 30),
      RecipeStep(text: 'タレを絡める'),
    ]);
    expect(find.byType(RecipeEditScreen), findsNothing);
  });

  testWidgets('保存ボタンを連打しても、保存も画面を閉じるのも1回だけ', (tester) async {
    await pumpEditor(tester, env);
    await tester.enterText(field('人数'), '4人分');

    await tester.tap(find.byTooltip('保存'));
    await tester.tap(find.byTooltip('保存'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(env.repository.putCount, 1);
    expect(find.text('開く'), findsOneWidget);
  });

  testWidgets('何も変えずに保存したら、保存せずに閉じる（手で直した扱いにしない）', (tester) async {
    await pumpEditor(tester, env);

    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(env.repository.putCount, 0);
    expect(env.repository.get('aaaaaaaaaaa')!.isEdited, isFalse);
    expect(find.text('開く'), findsOneWidget);
  });

  testWidgets('変更がなければ、戻るときに確認しない', (tester) async {
    await pumpEditor(tester, env);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('開く'), findsOneWidget);
  });

  testWidgets('保存していない変更があれば、戻る前に確認する', (tester) async {
    await pumpEditor(tester, env);
    await tester.enterText(field('材料'), '鶏肉 300g');
    await tester.pump(); // 入力が反映されて、戻る前の確認が有効になる

    // 「キャンセル」なら編集画面に残る
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('変更を破棄しますか？'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeEditScreen), findsOneWidget);

    // 「破棄」なら保存せずに閉じる
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('破棄'));
    await tester.pumpAndSettle();
    expect(find.text('開く'), findsOneWidget);
    expect(env.repository.putCount, 0);
  });

  testWidgets('「自動抽出に戻す」で、概要欄から抽出し直した内容に戻す', (tester) async {
    env = TestEnv([
      sampleRecipe(
        rawDescription: '【材料】(3人分)\n鶏肉 300g\n\n【作り方】\n1. 焼く',
        isEdited: true,
      ),
    ]);
    await pumpEditor(tester, env);

    await tester.tap(find.byTooltip('その他'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自動抽出に戻す'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('戻す'));
    await tester.pumpAndSettle();

    final saved = env.repository.get('aaaaaaaaaaa')!;
    expect(saved.isEdited, isFalse);
    expect(saved.servings, '3人分');
    expect(saved.ingredients, const [Ingredient(name: '鶏肉', amount: '300g')]);
    expect(saved.steps, const [RecipeStep(text: '焼く')]);
    expect(find.text('開く'), findsOneWidget);
  });
}
