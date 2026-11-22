import 'package:copy_recipe/data/app_exception.dart';
import 'package:copy_recipe/features/cooking/cooking_screen.dart';
import 'package:copy_recipe/screens/add_recipe_sheet.dart';
import 'package:copy_recipe/screens/home_screen.dart';
import 'package:copy_recipe/screens/how_to_screen.dart';
import 'package:copy_recipe/models/ingredient.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('スワイプで削除したレシピを「元に戻す」で一覧の元の位置に戻せる', (tester) async {
    final env = TestEnv([
      sampleRecipe(
        id: 'new00000000',
        title: '新しいレシピ',
        addedAt: DateTime(2026, 3),
      ),
      sampleRecipe(
        id: 'mid00000000',
        title: '真ん中のレシピ',
        addedAt: DateTime(2026, 2),
      ),
      sampleRecipe(
        id: 'old00000000',
        title: '古いレシピ',
        addedAt: DateTime(2026, 1),
      ),
    ]);
    await env.pump(tester, const HomeScreen(), size: const Size(412, 915));

    await tester.drag(find.text('真ん中のレシピ'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('真ん中のレシピ'), findsNothing);
    expect(env.repository.contains('mid00000000'), isFalse);

    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();

    expect(env.repository.contains('mid00000000'), isTrue);
    double top(String title) => tester.getTopLeft(find.text(title)).dy;
    expect(top('新しいレシピ'), lessThan(top('真ん中のレシピ')));
    expect(top('真ん中のレシピ'), lessThan(top('古いレシピ')));
  });

  testWidgets('レシピがなければ案内を出し、ボタンから追加のシートを開ける', (tester) async {
    final env = TestEnv([]);
    await env.pump(tester, const HomeScreen(), size: const Size(412, 915));

    expect(find.text('レシピを追加しましょう'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'レシピを追加'));
    await tester.pumpAndSettle();
    expect(find.text('追加する'), findsOneWidget);

    // 空のまま追加しようとすると、シートの中で知らせる
    await tester.tap(find.text('追加する'));
    await tester.pump();
    expect(find.text('URL を入力してください'), findsOneWidget);
  });

  testWidgets('追加のシートでは、クリップボードの URL を貼り付けられる', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? {'text': ' https://youtu.be/aaaaaaaaaaa '}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final env = TestEnv([sampleRecipe()]);
    await env.pump(tester, const HomeScreen(), size: const Size(412, 915));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('貼り付け'));
    await tester.pump();

    expect(find.text('https://youtu.be/aaaaaaaaaaa'), findsOneWidget);
  });

  testWidgets('一覧のカードに、チャンネル名と材料・工程の数を出す', (tester) async {
    final env = TestEnv([sampleRecipe()]);
    await env.pump(tester, const HomeScreen(), size: const Size(412, 915));

    expect(find.text('テストチャンネル'), findsOneWidget);
    expect(find.text('材料 4 · 工程 2 · 2人分'), findsOneWidget);
  });

  Future<void> startAdding(WidgetTester tester, TestEnv env) async {
    await env.pump(tester, const HomeScreen(), size: const Size(412, 915));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AddRecipeSheet),
        matching: find.byType(TextField),
      ),
      'https://youtu.be/vvvvvvvvvvv',
    );
    await tester.tap(find.text('追加する'));
    await tester.pump();
  }

  testWidgets('1本だけ追加できたら、シートを閉じてそのレシピを開く', (tester) async {
    final api = PendingYoutubeApi();
    final env = TestEnv([sampleRecipe()], youtubeApi: api);
    await startAdding(tester, env);

    api.requests['vvvvvvvvvvv']!.complete(recipeVideo('vvvvvvvvvvv'));
    await tester.pumpAndSettle();

    expect(find.byType(AddRecipeSheet), findsNothing);
    expect(find.byType(CookingScreen), findsOneWidget);
    expect(env.repository.contains('vvvvvvvvvvv'), isTrue);
  });

  testWidgets('読み込み中は背景をタップしてもシートを閉じない', (tester) async {
    final api = PendingYoutubeApi();
    final env = TestEnv([sampleRecipe()], youtubeApi: api);
    await startAdding(tester, env);

    await tester.tapAt(const Offset(200, 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AddRecipeSheet), findsOneWidget);

    api.requests['vvvvvvvvvvv']!.complete(recipeVideo('vvvvvvvvvvv'));
    await tester.pumpAndSettle();
  });

  testWidgets('読み込み中にシートが閉じられても、結果は通知で知らせる', (tester) async {
    final api = PendingYoutubeApi();
    final env = TestEnv([sampleRecipe()], youtubeApi: api);
    await startAdding(tester, env);

    // 下に払って閉じたときと同じく、戻る操作の確認を通さずに閉じる
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(AddRecipeSheet), findsNothing);

    api.requests['vvvvvvvvvvv']!.completeError(
      const AppException('動画が見つかりませんでした'),
    );
    // 例外が呼び出し元まで伝わってから通知が出るので、少し時間を進める
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('動画が見つかりませんでした'), findsOneWidget);
  });

  testWidgets('材料名を入れると、その材料を使うレシピだけに絞り込める', (tester) async {
    final env = TestEnv([
      sampleRecipe(id: 'daikon00000', title: '豚バラ大根'),
      sampleRecipe(
        id: 'chicken0000',
        title: '鶏の照り焼き',
        ingredients: const [Ingredient(name: '鶏もも肉', amount: '1枚')],
      ),
    ]);
    await env.pump(tester, const HomeScreen(), size: const Size(412, 915));

    await tester.enterText(find.byType(TextField), '鶏');
    await tester.pump();
    expect(find.text('鶏の照り焼き'), findsOneWidget);
    expect(find.text('豚バラ大根'), findsNothing);

    await tester.enterText(find.byType(TextField), 'えび');
    await tester.pump();
    expect(find.text('「えび」を使うレシピはありません'), findsOneWidget);

    await tester.tap(find.byTooltip('絞り込みを解除'));
    await tester.pump();
    expect(find.text('鶏の照り焼き'), findsOneWidget);
    expect(find.text('豚バラ大根'), findsOneWidget);
  });

  testWidgets('メニューから使い方を開ける', (tester) async {
    final env = TestEnv([]);
    await env.pump(tester, const HomeScreen(), size: const Size(412, 915));

    await tester.tap(find.byTooltip('メニュー'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('使い方'));
    await tester.pumpAndSettle();

    expect(find.byType(HowToScreen), findsOneWidget);
    expect(find.text('レシピを追加する'), findsOneWidget);
  });

  testWidgets('絞り込み中にレシピをすべて消すと、絞り込みの語も消える', (tester) async {
    final env = TestEnv([sampleRecipe(id: 'only0000000', title: '豚バラ大根')]);
    await env.pump(tester, const HomeScreen(), size: const Size(412, 915));

    await tester.enterText(find.byType(TextField), '大根');
    await tester.pump();
    await tester.drag(find.text('豚バラ大根'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('レシピを追加しましょう'), findsOneWidget);

    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
    expect(find.text('豚バラ大根'), findsOneWidget);
  });
}
