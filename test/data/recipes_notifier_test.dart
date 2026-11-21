import 'dart:io';

import 'package:copy_recipe/data/app_exception.dart';
import 'package:copy_recipe/data/legacy_migration.dart';
import 'package:copy_recipe/data/recipe_repository.dart';
import 'package:copy_recipe/data/youtube_api.dart';
import 'package:copy_recipe/models/ingredient.dart';
import 'package:copy_recipe/models/recipe.dart';
import 'package:copy_recipe/models/recipe_step.dart';
import 'package:copy_recipe/models/video_model.dart';
import 'package:copy_recipe/parser/recipe_parser.dart';
import 'package:copy_recipe/providers/recipes_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

const _recipeDescription = '【材料】\n豚肉 200g\n\n【作り方】\n1. 焼く';

class FakeYoutubeApi extends YoutubeApi {
  FakeYoutubeApi(this.videos, {this.playlist = const []})
    : super(client: http.Client(), apiKey: '');

  final Map<String, YoutubeVideo> videos;
  final List<String> playlist;

  @override
  Future<YoutubeVideo> fetchVideo(String videoId) async => videos[videoId]!;

  @override
  Future<List<YoutubeVideo>> fetchVideos(List<String> videoIds) async => [
    for (final id in videoIds)
      if (videos[id] != null) videos[id]!,
  ];

  @override
  Future<List<String>> fetchPlaylistVideoIds(String playlistId) async =>
      playlist;
}

YoutubeVideo video(String id, String description) => YoutubeVideo(
  id: id,
  title: 'title $id',
  channelTitle: 'ch',
  thumbnailUrl: null,
  description: description,
);

void main() {
  late Directory dir;
  late Box<Recipe> box;

  setUpAll(() {
    Hive.registerAdapter(RecipeAdapter());
    Hive.registerAdapter(IngredientAdapter());
    Hive.registerAdapter(RecipeStepAdapter());
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('copy_recipe_test');
    Hive.init(dir.path);
    box = await Hive.openBox<Recipe>(recipesBoxName);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  ProviderContainer container(FakeYoutubeApi api) {
    final c = ProviderContainer(
      overrides: [
        youtubeApiProvider.overrideWithValue(api),
        recipeRepositoryProvider.overrideWithValue(HiveRecipeRepository(box)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('再生リストは材料のある動画だけを、再生リストの順で登録する', () async {
    final c = container(
      FakeYoutubeApi(
        {
          'aaaaaaaaaaa': video('aaaaaaaaaaa', _recipeDescription),
          'bbbbbbbbbbb': video('bbbbbbbbbbb', '旅行に行きました'),
          'ccccccccccc': video('ccccccccccc', _recipeDescription),
        },
        playlist: ['aaaaaaaaaaa', 'bbbbbbbbbbb', 'ccccccccccc'],
      ),
    );

    final result = await c
        .read(recipesProvider.notifier)
        .addFromUrl('https://www.youtube.com/playlist?list=PL1');

    expect(result.added, 2);
    expect(result.noRecipe, 1);
    expect(result.singleVideoId, isNull);
    expect(result.message, '2件のレシピを追加しました（1件はレシピが見つかりませんでした）');
    expect(c.read(recipesProvider).map((r) => r.videoId), [
      'aaaaaaaaaaa',
      'ccccccccccc',
    ]);
    expect(box.get('aaaaaaaaaaa')!.ingredients, const [
      Ingredient(name: '豚肉', amount: '200g'),
    ]);
    expect(box.get('aaaaaaaaaaa')!.steps, const [RecipeStep(text: '焼く')]);
  });

  test('後から追加したレシピが一覧の先頭に来る', () async {
    final c = container(
      FakeYoutubeApi({
        'aaaaaaaaaaa': video('aaaaaaaaaaa', _recipeDescription),
        'zzzzzzzzzzz': video('zzzzzzzzzzz', _recipeDescription),
      }),
    );
    final notifier = c.read(recipesProvider.notifier);
    await notifier.addFromUrl('https://youtu.be/zzzzzzzzzzz');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final result = await notifier.addFromUrl('https://youtu.be/aaaaaaaaaaa');

    expect(result.singleVideoId, 'aaaaaaaaaaa');
    expect(c.read(recipesProvider).map((r) => r.videoId), [
      'aaaaaaaaaaa',
      'zzzzzzzzzzz',
    ]);
  });

  test('登録済み・レシピなし・不正な URL はエラーになる', () async {
    final c = container(
      FakeYoutubeApi({
        'aaaaaaaaaaa': video('aaaaaaaaaaa', _recipeDescription),
        'bbbbbbbbbbb': video('bbbbbbbbbbb', 'レシピなし'),
      }),
    );
    final notifier = c.read(recipesProvider.notifier);
    await notifier.addFromUrl('https://youtu.be/aaaaaaaaaaa');

    Matcher appError(String text) => throwsA(
      isA<AppException>().having((e) => e.message, 'message', contains(text)),
    );
    expect(
      () => notifier.addFromUrl('https://youtu.be/aaaaaaaaaaa'),
      appError('登録済み'),
    );
    expect(
      () => notifier.addFromUrl('https://youtu.be/bbbbbbbbbbb'),
      appError('見つけられる動画がありません'),
    );
    expect(() => notifier.addFromUrl('https://example.com'), appError('URL'));
  });

  test('古い版の抽出処理で作ったレシピと、以前に手で直したレシピを抽出し直す', () async {
    final old = Recipe(
      videoId: 'old00000001',
      title: 't',
      channelTitle: 'c',
      thumbnailUrl: null,
      rawDescription: '材料\n豚肉 200g',
      ingredients: const [],
      steps: const [],
      servings: null,
      addedAt: DateTime(2026),
      parserVersion: 0,
    );
    await box.put(old.videoId, old);
    await box.put(
      'edited00001',
      Recipe(
        videoId: 'edited00001',
        title: 't',
        channelTitle: 'c',
        thumbnailUrl: null,
        rawDescription: '材料\n豚肉 200g',
        ingredients: const [Ingredient(name: '手で直した')],
        steps: const [],
        servings: null,
        addedAt: DateTime(2026),
        isEdited: true,
        parserVersion: kParserVersion,
      ),
    );

    await HiveRecipeRepository(box).reparseOutdated();

    expect(box.get('old00000001')!.ingredients, const [
      Ingredient(name: '豚肉', amount: '200g'),
    ]);
    expect(box.get('old00000001')!.parserVersion, kParserVersion);
    // 編集機能は廃止したので、手で直したレシピも原文からの抽出結果に戻す
    final edited = box.get('edited00001')!;
    expect(edited.ingredients, const [Ingredient(name: '豚肉', amount: '200g')]);
    expect(edited.isEdited, isFalse);
  });

  test('削除したレシピを元に戻すと、元の位置に戻る', () async {
    final c = container(
      FakeYoutubeApi(
        {
          'aaaaaaaaaaa': video('aaaaaaaaaaa', _recipeDescription),
          'bbbbbbbbbbb': video('bbbbbbbbbbb', _recipeDescription),
          'ccccccccccc': video('ccccccccccc', _recipeDescription),
        },
        playlist: ['aaaaaaaaaaa', 'bbbbbbbbbbb', 'ccccccccccc'],
      ),
    );
    final notifier = c.read(recipesProvider.notifier);
    await notifier.addFromUrl('https://www.youtube.com/playlist?list=PL1');
    final removed = box.get('bbbbbbbbbbb')!;

    await notifier.delete('bbbbbbbbbbb');
    await notifier.restore(removed);

    expect(c.read(recipesProvider).map((r) => r.videoId), [
      'aaaaaaaaaaa',
      'bbbbbbbbbbb',
      'ccccccccccc',
    ]);
    expect(box.containsKey('bbbbbbbbbbb'), isTrue);
  });

  test('削除すると、保存先への書き込みを待たずに一覧から消える', () async {
    final c = container(
      FakeYoutubeApi({'aaaaaaaaaaa': video('aaaaaaaaaaa', _recipeDescription)}),
    );
    final notifier = c.read(recipesProvider.notifier);
    await notifier.addFromUrl('https://youtu.be/aaaaaaaaaaa');

    final pending = notifier.delete('aaaaaaaaaaa');
    expect(c.read(recipesProvider), isEmpty);
    await pending;
    expect(box.containsKey('aaaaaaaaaaa'), isFalse);
  });

  test('旧形式のデータを Recipe に移し、旧 Box を削除する', () async {
    Hive.registerAdapter(VideoAdapter());
    final legacy = await Hive.openBox<Video>('Videos');
    await legacy.put(
      'old00000001',
      Video(
        id: 'old00000001',
        title: '旧レシピ',
        thumbnailUrl: 'https://img/old.jpg',
        channelTitle: 'ch',
        description: _recipeDescription,
      ),
    );
    await legacy.close();

    await migrateLegacyVideos(box);

    final migrated = box.get('old00000001')!;
    expect(migrated.title, '旧レシピ');
    expect(migrated.ingredients, const [
      Ingredient(name: '豚肉', amount: '200g'),
    ]);
    expect(await Hive.boxExists('Videos'), isFalse);
  });
}
