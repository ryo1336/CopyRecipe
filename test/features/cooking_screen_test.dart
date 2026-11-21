import 'dart:io';

import 'package:copy_recipe/data/recipe_repository.dart';
import 'package:copy_recipe/features/cooking/cooking_screen.dart';
import 'package:copy_recipe/features/cooking/cooking_settings.dart';
import 'package:copy_recipe/features/cooking/platform_services.dart';
import 'package:copy_recipe/models/ingredient.dart';
import 'package:copy_recipe/models/recipe.dart';
import 'package:copy_recipe/models/recipe_step.dart';
import 'package:copy_recipe/parser/chapters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class FakeScreenAwake implements ScreenAwake {
  bool enabled = false;

  @override
  Future<void> enable() async => enabled = true;

  @override
  Future<void> disable() async => enabled = false;
}

class FakeSettingsStore implements SettingsStore {
  final values = <String, String>{};

  @override
  String? getString(String key) => values[key];

  @override
  void setString(String key, String value) => values[key] = value;
}

class FakeVideoLauncher implements VideoLauncher {
  final opened = <(String, int)>[];

  @override
  Future<bool> open(String videoId, {int startSeconds = 0}) async {
    opened.add((videoId, startSeconds));
    return true;
  }
}

Recipe recipe({
  String id = 'aaaaaaaaaaa',
  List<RecipeStep> steps = const [
    RecipeStep(text: '大根を切る', startSeconds: 72),
    RecipeStep(text: '豚肉を炒める'),
  ],
}) =>
    Recipe(
      videoId: id,
      title: '豚バラ大根',
      channelTitle: 'テストチャンネル',
      thumbnailUrl: null,
      rawDescription: '概要欄の原文です',
      ingredients: const [
        Ingredient(name: '豚バラ肉', amount: '200g'),
        Ingredient(name: '大根', amount: '1/3本'),
        Ingredient(name: '醤油', amount: '大さじ2', group: 'A'),
        Ingredient(name: 'みりん', amount: '大さじ2', group: 'A'),
      ],
      steps: steps,
      servings: '2人分',
      addedAt: DateTime(2026),
      parserVersion: 1,
    );

void main() {
  late Directory dir;
  late Box<Recipe> recipes;
  late FakeSettingsStore settings;
  late FakeScreenAwake screenAwake;
  late FakeVideoLauncher launcher;

  setUpAll(() {
    Hive.registerAdapter(RecipeAdapter());
    Hive.registerAdapter(IngredientAdapter());
    Hive.registerAdapter(RecipeStepAdapter());
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cooking_screen_test');
    Hive.init(dir.path);
    recipes = await Hive.openBox<Recipe>(recipesBoxName);
    settings = FakeSettingsStore();
    await recipes.put('aaaaaaaaaaa', recipe());
    await recipes.put('nosteps0000', recipe(id: 'nosteps0000', steps: const []));
    screenAwake = FakeScreenAwake();
    launcher = FakeVideoLauncher();
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    String videoId = 'aaaaaaaaaaa',
    Size size = const Size(412, 2000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        recipeRepositoryProvider.overrideWithValue(RecipeRepository(recipes)),
        screenAwakeProvider.overrideWithValue(screenAwake),
        videoLauncherProvider.overrideWithValue(launcher),
        settingsStoreProvider.overrideWithValue(settings),
      ],
      child: MaterialApp(home: CookingScreen(videoId: videoId)),
    ));
  }

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
    expect(find.text('チェックを外す'), findsNothing);

    await tester.tap(find.text('豚バラ肉'));
    await tester.tap(find.text('大根を切る'));
    await tester.pump();
    expect(find.byIcon(Icons.check_box), findsNWidgets(2));

    await tester.tap(find.text('豚バラ肉'));
    await tester.pump();
    expect(find.byIcon(Icons.check_box), findsOneWidget);

    await tester.tap(find.text('チェックを外す'));
    await tester.pump();
    expect(find.byIcon(Icons.check_box), findsNothing);
  });

  testWidgets('時刻ボタンでその時刻から、「動画を開く」で最初から動画を開く', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('1:12'));
    await tester.tap(find.text('動画を開く'));
    await tester.pump();

    expect(launcher.opened, [('aaaaaaaaaaa', 72), ('aaaaaaaaaaa', 0)]);
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
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpScreen(tester);
    await tester.tap(find.text('コピー'));
    await tester.pump();

    expect(copied, '材料（2人分）\n豚バラ肉 200g\n大根 1/3本\n【A】\n醤油 大さじ2\nみりん 大さじ2');
    expect(find.text('材料をコピーしました'), findsOneWidget);
  });

  testWidgets('工程がなければ案内を出し、編集画面へ移れる', (tester) async {
    await pumpScreen(tester, videoId: 'nosteps0000');

    expect(find.text('工程が見つかりませんでした'), findsOneWidget);
    await tester.tap(find.text('概要欄を編集して追加'));
    await tester.pumpAndSettle();
    expect(find.text('概要欄を編集'), findsOneWidget);
  });

  testWidgets('文字サイズを変えると表示に反映され、設定が保存される', (tester) async {
    await pumpScreen(tester);
    double? fontSizeOf(String text) => tester.widget<Text>(find.text(text)).style?.fontSize;
    expect(fontSizeOf('豚バラ肉'), 17);

    await tester.tap(find.byTooltip('文字サイズ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字サイズ: 特大'));
    await tester.pumpAndSettle();

    expect(fontSizeOf('豚バラ肉'), 17 * 1.5);
    expect(settings.values[cookingFontSizeKey], 'extraLarge');
  });

  testWidgets('開いている間だけ画面のスリープを止める', (tester) async {
    await pumpScreen(tester);
    expect(screenAwake.enabled, isTrue);

    await tester.pumpWidget(const SizedBox());
    expect(screenAwake.enabled, isFalse);
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
          settings.values[cookingFontSizeKey] = fontSize.name;
          tester.platformDispatcher.textScaleFactorTestValue = c.$2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await pumpScreen(tester, size: c.$1);
          await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
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
    final r = Recipe(
      videoId: 'x',
      title: 't',
      channelTitle: 'c',
      thumbnailUrl: null,
      rawDescription: '',
      ingredients: const [Ingredient(name: '塩')],
      steps: const [],
      servings: null,
      addedAt: DateTime(2026),
      parserVersion: 1,
    );
    expect(formatIngredientsForCopy(r), '材料\n塩');
  });
}
