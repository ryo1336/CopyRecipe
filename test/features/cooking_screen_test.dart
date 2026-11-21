import 'package:copy_recipe/features/cooking/cooking_screen.dart';
import 'package:copy_recipe/features/cooking/cooking_settings.dart';
import 'package:copy_recipe/features/cooking/cooking_widgets.dart';
import 'package:copy_recipe/models/ingredient.dart';
import 'package:copy_recipe/models/recipe_step.dart';
import 'package:copy_recipe/parser/chapters.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  late TestEnv env;

  setUp(() {
    env = TestEnv([
      sampleRecipe(),
      sampleRecipe(id: 'nosteps0000', steps: const []),
      sampleRecipe(id: 'noingredien', ingredients: const []),
      sampleRecipe(
        id: 'longamount0',
        ingredients: const [
          Ingredient(name: 'みりん', amount: '各 大さじ3ずつ'),
          Ingredient(name: '豚バラ肉', amount: '200g'),
        ],
      ),
      sampleRecipe(
        id: 'manysteps00',
        steps: [for (var i = 1; i <= 12; i++) RecipeStep(text: '工程$i')],
      ),
    ]);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    String videoId = 'aaaaaaaaaaa',
    Size size = const Size(412, 2000),
  }) => env.pump(tester, CookingScreen(videoId: videoId), size: size);

  testWidgets('材料（グループ付き）・人数・番号付きの工程を表示する', (tester) async {
    await pumpScreen(tester);

    expect(find.text('2人分'), findsOneWidget);
    expect(find.text('豚バラ肉'), findsOneWidget);
    expect(find.text('200g'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('大根を切る'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // 工程番号
    expect(find.text('1:12'), findsOneWidget); // 時刻のある工程だけにボタン
    expect(find.text('概要欄の原文です'), findsNothing); // 最初は折りたたむ

    await tester.tap(find.text('概要欄の全文'));
    await tester.pumpAndSettle();
    expect(find.text('概要欄の原文です'), findsOneWidget);
  });

  testWidgets('行をタップするとチェックが付き、まとめて外せる', (tester) async {
    await pumpScreen(tester);
    expect(find.byIcon(Icons.check_box), findsNothing);
    expect(find.byTooltip('すべてのチェックを外す'), findsNothing);

    await tester.tap(find.text('豚バラ肉'));
    await tester.tap(find.text('大根を切る'));
    await tester.pump();
    expect(find.byIcon(Icons.check_box), findsNWidgets(2));

    await tester.tap(find.text('豚バラ肉'));
    await tester.pump();
    expect(find.byIcon(Icons.check_box), findsOneWidget);

    await tester.tap(find.byTooltip('すべてのチェックを外す'));
    await tester.pump();
    expect(find.byIcon(Icons.check_box), findsNothing);
  });

  testWidgets('時刻ボタンでその時刻から、「動画を開く」で最初から動画を開く', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('1:12'));
    await tester.tap(find.text('動画を開く'));
    await tester.pump();

    expect(env.launcher.opened, [('aaaaaaaaaaa', 72), ('aaaaaaaaaaa', 0)]);
    // 時刻ボタンを押してもチェックは付かない
    expect(find.byIcon(Icons.check_box), findsNothing);
  });

  testWidgets('材料をグループ見出し付きでコピーする', (tester) async {
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

    await pumpScreen(tester);
    await tester.tap(find.text('コピー'));
    await tester.pump();

    expect(copied, '材料（2人分）\n豚バラ肉 200g\n大根 1/3本\n【A】\n醤油 大さじ2\nみりん 大さじ2');
    expect(find.text('材料をコピーしました'), findsOneWidget);
  });

  testWidgets('工程がなければ、概要欄の全文や動画で確認するよう案内する', (tester) async {
    await pumpScreen(tester, videoId: 'nosteps0000');

    expect(find.text('工程が見つかりませんでした'), findsOneWidget);
    expect(find.text('下の「概要欄の全文」や動画で確認してください'), findsOneWidget);
  });

  testWidgets('材料がなければ、コピーは出さずに案内する', (tester) async {
    await pumpScreen(tester, videoId: 'noingredien');

    expect(find.text('材料が見つかりませんでした'), findsOneWidget);
    expect(find.text('下の「概要欄の全文」や動画で確認してください'), findsOneWidget);
    expect(find.text('コピー'), findsNothing);
  });

  testWidgets('下端の安全領域の分だけ、本文の下に余白を足す', (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPadding);
    await pumpScreen(tester);

    final list = tester.widget<ListView>(find.byType(ListView).first);
    expect((list.padding! as EdgeInsets).bottom, 32 + 34);
  });

  testWidgets('文字サイズを変えると表示に反映され、設定が保存される', (tester) async {
    await pumpScreen(tester);
    // 本文全体（材料・人数のチップ・ボタン）に同じ倍率が掛かる
    double scaled(String text) =>
        MediaQuery.textScalerOf(tester.element(find.text(text))).scale(17);
    expect(scaled('豚バラ肉'), 17);

    await tester.tap(find.byTooltip('文字サイズ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字サイズ: 特大'));
    await tester.pumpAndSettle();

    for (final text in ['豚バラ肉', '2人分', '動画を開く', '1:12', '概要欄の全文']) {
      expect(scaled(text), 17 * 1.5, reason: text);
    }
    expect(env.settings.values[cookingFontSizeKey], 'extraLarge');
  });

  testWidgets('開いている間だけ画面のスリープを止める', (tester) async {
    await pumpScreen(tester);
    expect(env.screenAwake.enabled, isTrue);

    await tester.pumpWidget(const SizedBox());
    expect(env.screenAwake.enabled, isFalse);
  });

  testWidgets('分量は行の右端にそろう', (tester) async {
    await pumpScreen(tester);

    double right(String text) => tester.getTopRight(find.text(text).first).dx;
    expect(right('1/3本'), right('200g'));
    expect(right('大さじ2'), right('200g'));
  });

  testWidgets('材料名が短ければ、長い分量も大きな文字で1行に収める', (tester) async {
    env.settings.values[cookingFontSizeKey] = CookingFontSize.extraLarge.name;
    await pumpScreen(tester, videoId: 'longamount0');

    final oneLine = tester.getSize(find.text('200g')).height;
    expect(tester.getSize(find.text('各 大さじ3ずつ')).height, oneLine);
    expect(tester.takeException(), isNull);
  });

  testWidgets('本文のタイトルが隠れるまでスクロールしたら、上のバーにタイトルを出す', (tester) async {
    await pumpScreen(tester, size: const Size(412, 600));
    double barTitleOpacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.descendant(
              of: find.byType(AppBar),
              matching: find.text('豚バラ大根'),
            ),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    expect(barTitleOpacity(), 0);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(barTitleOpacity(), 1);
  });

  group('splitNameAndAmount', () {
    test('両方収まるなら、どちらも1行の幅のまま', () {
      expect(
        splitNameAndAmount(available: 300, nameWidth: 60, amountWidth: 120),
        (60.0, 120.0),
      );
    });

    test('収まらなければ、材料名の残りを分量に回す', () {
      expect(
        splitNameAndAmount(available: 300, nameWidth: 60, amountWidth: 400),
        (60.0, 240.0),
      );
    });

    test('どちらも長ければ、分量は半分まで取る', () {
      expect(
        splitNameAndAmount(available: 300, nameWidth: 250, amountWidth: 250),
        (150.0, 150.0),
      );
    });

    test('合計は使える幅を超えない（狭い画面でもはみ出さない）', () {
      for (final available in [-20.0, 0.0, 40.0, 150.0]) {
        final (name, amount) = splitNameAndAmount(
          available: available,
          nameWidth: 200,
          amountWidth: 200,
        );
        expect(name + amount, lessThanOrEqualTo(available < 0 ? 0 : available));
        expect(name, greaterThanOrEqualTo(0));
        expect(amount, greaterThanOrEqualTo(0));
      }
    });
  });

  testWidgets('工程番号が2桁でも、大きな文字で折り返さない', (tester) async {
    env.settings.values[cookingFontSizeKey] = CookingFontSize.extraLarge.name;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpScreen(
      tester,
      videoId: 'manysteps00',
      size: const Size(360, 4000),
    );

    final oneDigit = tester.getSize(find.text('9')).height;
    expect(tester.getSize(find.text('12')).height, oneDigit);
    expect(tester.takeException(), isNull);
  });

  group('画面サイズと文字サイズの組み合わせでレイアウトが崩れない', () {
    const cases = {
      '縦長 412x915': (Size(412, 915), 1.0),
      '横画面 915x412': (Size(915, 412), 1.0),
      '小型端末・文字1.3倍 360x640': (Size(360, 640), 1.3),
    };
    cases.forEach((name, c) {
      for (final fontSize in CookingFontSize.values) {
        testWidgets('$name / ${fontSize.label}', (tester) async {
          env.settings.values[cookingFontSizeKey] = fontSize.name;
          tester.platformDispatcher.textScaleFactorTestValue = c.$2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await pumpScreen(tester, size: c.$1);
          await tester.fling(
            find.byType(ListView),
            const Offset(0, -3000),
            3000,
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });
      }
    });
  });

  test('formatTimestamp', () {
    expect(formatTimestamp(5), '0:05');
    expect(formatTimestamp(72), '1:12');
    expect(formatTimestamp(3723), '1:02:03');
  });

  test('formatIngredientsForCopy は人数がなければ見出しだけにする', () {
    final r = sampleRecipe(
      ingredients: const [Ingredient(name: '塩')],
      servings: null,
    );
    expect(formatIngredientsForCopy(r), '材料\n塩');
  });
}
