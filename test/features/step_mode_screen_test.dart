import 'package:copy_recipe/features/cooking/cooking_checks.dart';
import 'package:copy_recipe/features/cooking/cooking_settings.dart';
import 'package:copy_recipe/features/cooking/step_mode_screen.dart';
import 'package:copy_recipe/models/recipe_step.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  late TestEnv env;

  setUp(() {
    env = TestEnv([
      sampleRecipe(
        steps: const [
          RecipeStep(text: '大根を切る', startSeconds: 72),
          RecipeStep(text: '豚肉を炒める'),
          RecipeStep(text: '煮込む'),
        ],
      ),
    ]);
  });

  /// ステップモードを、閉じたかどうか分かるようホームの上に重ねて開く
  Future<void> pumpStepMode(
    WidgetTester tester, {
    int initialStep = 0,
    Size size = const Size(412, 915),
  }) async {
    await env.pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StepModeScreen(
                  videoId: 'aaaaaaaaaaa',
                  initialStep: initialStep,
                ),
              ),
            ),
            child: const Text('開く'),
          ),
        ),
      ),
      size: size,
    );
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
  }

  Set<int> doneSteps(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(StepModeScreen)),
  ).read(cookingChecksProvider('aaaaaaaaaaa')).steps;

  Offset rightHalf(WidgetTester tester) {
    final rect = tester.getRect(find.byType(PageView));
    return Offset(rect.left + rect.width * 0.8, rect.center.dy);
  }

  Offset leftHalf(WidgetTester tester) {
    final rect = tester.getRect(find.byType(PageView));
    return Offset(rect.left + rect.width * 0.2, rect.center.dy);
  }

  testWidgets('右半分のタップで次へ進み、進んだ工程は完了にする', (tester) async {
    await pumpStepMode(tester);
    expect(find.text('手順 1 / 3'), findsOneWidget);
    expect(find.text('大根を切る'), findsOneWidget);

    await tester.tapAt(rightHalf(tester));
    await tester.pumpAndSettle();

    expect(find.text('手順 2 / 3'), findsOneWidget);
    expect(find.text('豚肉を炒める'), findsOneWidget);
    expect(doneSteps(tester), {0});
  });

  testWidgets('左半分のタップで前へ戻る。最初の工程では何もしない', (tester) async {
    await pumpStepMode(tester, initialStep: 1);

    await tester.tapAt(leftHalf(tester));
    await tester.pumpAndSettle();
    expect(find.text('手順 1 / 3'), findsOneWidget);

    await tester.tapAt(leftHalf(tester));
    await tester.pumpAndSettle();
    expect(find.text('手順 1 / 3'), findsOneWidget);
    expect(doneSteps(tester), isEmpty);
  });

  testWidgets('最後の工程で「完了」を押すと、完了にして閉じる', (tester) async {
    await pumpStepMode(tester, initialStep: 2);
    expect(find.byTooltip('完了'), findsOneWidget);

    await tester.tap(find.byTooltip('完了'));
    await tester.pumpAndSettle();

    expect(find.byType(StepModeScreen), findsNothing);
    expect(find.text('開く'), findsOneWidget);
  });

  testWidgets('スワイプでも移動でき、ボタンでも進める', (tester) async {
    await pumpStepMode(tester);

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('手順 2 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip('次の手順'));
    await tester.pumpAndSettle();
    expect(find.text('手順 3 / 3'), findsOneWidget);
  });

  testWidgets('時刻のある工程では、その時刻から動画を開ける', (tester) async {
    await pumpStepMode(tester);

    await tester.tap(find.text('1:12'));
    await tester.pump();
    expect(env.launcher.opened, [('aaaaaaaaaaa', 72)]);

    await tester.tap(find.byTooltip('次の手順'));
    await tester.pumpAndSettle();
    expect(find.text('1:12'), findsNothing);
  });

  testWidgets('材料を下から出して確認・チェックできる', (tester) async {
    await pumpStepMode(tester);

    await tester.tap(find.text('材料'));
    await tester.pumpAndSettle();
    expect(find.text('材料（2人分）'), findsOneWidget);
    expect(find.text('豚バラ肉'), findsOneWidget);

    await tester.tap(find.text('豚バラ肉'));
    await tester.pump();
    expect(find.byIcon(Icons.check_box), findsOneWidget);
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

          await pumpStepMode(tester, size: c.$1);
          await tester.tap(find.text('材料'));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });
      }
    });
  });
}
