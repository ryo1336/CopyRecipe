import 'dart:io';

import 'package:copy_recipe/data/app_exception.dart';
import 'package:copy_recipe/data/legacy_migration.dart';
import 'package:copy_recipe/data/recipe_repository.dart';
import 'package:copy_recipe/data/youtube_api.dart';
import 'package:copy_recipe/models/ingredient.dart';
import 'package:copy_recipe/models/recipe.dart';
import 'package:copy_recipe/models/recipe_step.dart';
import 'package:copy_recipe/models/video_model.dart';
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
  Future<List<YoutubeVideo>> fetchVideos(List<String> videoIds) async =>
      [for (final id in videoIds) if (videos[id] != null) videos[id]!];

  @override
  Future<List<String>> fetchPlaylistVideoIds(String playlistId) async => playlist;
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
    final c = ProviderContainer(overrides: [
      youtubeApiProvider.overrideWithValue(api),
      recipeRepositoryProvider.overrideWithValue(RecipeRepository(box)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('再生リストは材料のある動画だけを、再生リストの順で登録する', () async {
    final c = container(FakeYoutubeApi(
      {
        'aaaaaaaaaaa': video('aaaaaaaaaaa', _recipeDescription),
        'bbbbbbbbbbb': video('bbbbbbbbbbb', '旅行に行きました'),
        'ccccccccccc': video('ccccccccccc', _recipeDescription),
      },
      playlist: ['aaaaaaaaaaa', 'bbbbbbbbbbb', 'ccccccccccc'],
    ));

    final result = await c
        .read(recipesProvider.notifier)
        .addFromUrl('https://www.youtube.com/playlist?list=PL1');

    expect(result.added, 2);
    expect(result.noRecipe, 1);
    expect(result.singleVideoId, isNull);
    expect(result.message, '2件のレシピを追加しました（1件はレシピが見つかりませんでした）');
    expect(c.read(recipesProvider).map((r) => r.videoId), ['aaaaaaaaaaa', 'ccccccccccc']);
    expect(box.get('aaaaaaaaaaa')!.ingredients, const [Ingredient(name: '豚肉', amount: '200g')]);
    expect(box.get('aaaaaaaaaaa')!.steps, const [RecipeStep(text: '焼く')]);
  });

  test('後から追加したレシピが一覧の先頭に来る', () async {
    final c = container(FakeYoutubeApi({
      'aaaaaaaaaaa': video('aaaaaaaaaaa', _recipeDescription),
      'zzzzzzzzzzz': video('zzzzzzzzzzz', _recipeDescription),
    }));
    final notifier = c.read(recipesProvider.notifier);
    await notifier.addFromUrl('https://youtu.be/zzzzzzzzzzz');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final result = await notifier.addFromUrl('https://youtu.be/aaaaaaaaaaa');

    expect(result.singleVideoId, 'aaaaaaaaaaa');
    expect(c.read(recipesProvider).map((r) => r.videoId), ['aaaaaaaaaaa', 'zzzzzzzzzzz']);
  });

  test('登録済み・レシピなし・不正な URL はエラーになる', () async {
    final c = container(FakeYoutubeApi({
      'aaaaaaaaaaa': video('aaaaaaaaaaa', _recipeDescription),
      'bbbbbbbbbbb': video('bbbbbbbbbbb', 'レシピなし'),
    }));
    final notifier = c.read(recipesProvider.notifier);
    await notifier.addFromUrl('https://youtu.be/aaaaaaaaaaa');

    Matcher appError(String text) =>
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains(text)));
    expect(() => notifier.addFromUrl('https://youtu.be/aaaaaaaaaaa'), appError('登録済み'));
    expect(() => notifier.addFromUrl('https://youtu.be/bbbbbbbbbbb'), appError('見つけられる動画がありません'));
    expect(() => notifier.addFromUrl('https://example.com'), appError('URL'));
  });

  test('概要欄を編集して人数が書かれなくなったら、人数も消える', () async {
    final c = container(FakeYoutubeApi({
      'aaaaaaaaaaa': video('aaaaaaaaaaa', '【材料】(2人分)\n豚肉 200g'),
    }));
    final notifier = c.read(recipesProvider.notifier);
    await notifier.addFromUrl('https://youtu.be/aaaaaaaaaaa');
    expect(box.get('aaaaaaaaaaa')!.servings, '2人分');

    await notifier.updateDescription('aaaaaaaaaaa', '【材料】\n豚肉 300g');

    final updated = box.get('aaaaaaaaaaa')!;
    expect(updated.servings, isNull);
    expect(updated.ingredients, const [Ingredient(name: '豚肉', amount: '300g')]);
  });

  test('削除すると、保存先への書き込みを待たずに一覧から消える', () async {
    final c = container(FakeYoutubeApi({
      'aaaaaaaaaaa': video('aaaaaaaaaaa', _recipeDescription),
    }));
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
    expect(migrated.ingredients, const [Ingredient(name: '豚肉', amount: '200g')]);
    expect(await Hive.boxExists('Videos'), isFalse);
  });
}
