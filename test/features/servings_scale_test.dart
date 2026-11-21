import 'package:copy_recipe/features/cooking/cooking_screen.dart';
import 'package:copy_recipe/features/cooking/servings_scale.dart';
import 'package:copy_recipe/features/cooking/step_mode_screen.dart';
import 'package:copy_recipe/models/ingredient.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fakes.dart';

void main() {
  late TestEnv env;

  setUp(() {
    env = TestEnv([
      sampleRecipe(),
      sampleRecipe(
        id: 'noservings0',
        servings: null,
        ingredients: const [Ingredient(name: '塩', amount: '小さじ1')],
      ),
    ]);
  });

  Future<void> choose(WidgetTester tester, String chip, String option) async {
    await tester.tap(find.text(chip));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, option));
    await tester.pumpAndSettle();
  }

  testWidgets('人数を選ぶと分量を換算し、元に戻せる', (tester) async {
    await env.pump(tester, const CookingScreen(videoId: 'aaaaaaaaaaa'));
    expect(find.byType(ActionChip), findsOneWidget);

    await choose(tester, '2人分', '3人分');

    expect(find.text('3人分'), findsOneWidget);
    expect(find.text('300g'), findsOneWidget);
    expect(find.text('1/2本'), findsOneWidget);
    expect(find.text('大さじ3'), findsNWidgets(2));
    expect(find.text('3人分に換算しています（元は2人分）'), findsOneWidget);

    await tester.tap(find.text('元に戻す'));
    await tester.pump();
    expect(find.text('200g'), findsOneWidget);
    expect(find.textContaining('換算しています'), findsNothing);
  });

  testWidgets('人数がなければ倍率で換算する', (tester) async {
    await env.pump(tester, const CookingScreen(videoId: 'noservings0'));

    await choose(tester, '分量を変える', '×2');

    expect(find.text('×2'), findsOneWidget);
    expect(find.text('小さじ2'), findsOneWidget);
    expect(find.text('分量を×2で表示しています'), findsOneWidget);
  });

  testWidgets('換算した分量でコピーする', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await env.pump(tester, const CookingScreen(videoId: 'aaaaaaaaaaa'));
    await choose(tester, '2人分', '4人分');
    await tester.tap(find.text('コピー'));
    await tester.pump();

    expect(copied, '材料（4人分）\n豚バラ肉 400g\n大根 2/3本\n【A】\n醤油 大さじ4\nみりん 大さじ4');
  });

  testWidgets('ステップモードの材料一覧にも換算が効く', (tester) async {
    await env.pump(tester, const CookingScreen(videoId: 'aaaaaaaaaaa'));
    await choose(tester, '2人分', '1人分');

    await tester.tap(find.text('ステップモードで開始'));
    await tester.pumpAndSettle();
    expect(find.byType(StepModeScreen), findsOneWidget);
    await tester.tap(find.text('材料'));
    await tester.pumpAndSettle();

    expect(find.text('材料（1人分）'), findsOneWidget);
    expect(find.text('100g'), findsOneWidget);
  });

  test('人数が読めれば人数、読めなければ倍率を選択肢にする', () {
    expect(servingsOptions('2人分').map((o) => o.label), [
      '1人分',
      '2人分',
      '3人分',
      '4人分',
      '5人分',
      '6人分',
    ]);
    expect(servingsOptions('4人分').length, 8);
    expect(servingsOptions('2〜3人分').map((o) => o.label), [
      '×1/2',
      '×1',
      '×1.5',
      '×2',
      '×3',
    ]);
  });
}
