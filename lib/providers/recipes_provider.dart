import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_exception.dart';
import '../data/recipe_repository.dart';
import '../data/youtube_api.dart';
import '../data/youtube_url.dart';
import '../models/recipe.dart';
import '../parser/recipe_parser.dart';

final recipesProvider =
    NotifierProvider<RecipesNotifier, List<Recipe>>(RecipesNotifier.new);

/// URL から登録した結果
class AddRecipesResult {
  /// 新しく登録した件数
  final int added;

  /// 登録済みだったため飛ばした件数
  final int alreadySaved;

  /// レシピが見つからず登録しなかった件数
  final int noRecipe;

  /// 1本だけ登録した場合の動画 ID（料理中画面へ移るのに使う）
  final String? singleVideoId;

  const AddRecipesResult({
    required this.added,
    required this.alreadySaved,
    required this.noRecipe,
    this.singleVideoId,
  });

  String get message {
    final parts = <String>['$added件のレシピを追加しました'];
    if (alreadySaved > 0) parts.add('$alreadySaved件は登録済み');
    if (noRecipe > 0) parts.add('$noRecipe件はレシピが見つかりませんでした');
    return parts.length == 1 ? parts.first : '${parts.first}（${parts.skip(1).join('、')}）';
  }
}

class RecipesNotifier extends Notifier<List<Recipe>> {
  RecipeRepository get _repo => ref.read(recipeRepositoryProvider);

  @override
  List<Recipe> build() => ref.read(recipeRepositoryProvider).all();

  /// 動画または再生リストの URL からレシピを登録する
  Future<AddRecipesResult> addFromUrl(String url) async {
    final target = parseYoutubeUrl(url);
    if (target == null) {
      throw const AppException('YouTube の動画または再生リストの URL を入力してください');
    }

    final api = ref.read(youtubeApiProvider);
    final videos = target.videoId != null
        ? [await api.fetchVideo(target.videoId!)]
        : await api.fetchVideos(await api.fetchPlaylistVideoIds(target.playlistId!));
    if (videos.isEmpty) {
      throw const AppException('再生リストに取り込める動画がありませんでした');
    }

    final now = DateTime.now();
    final toSave = <Recipe>[];
    var alreadySaved = 0;
    var noRecipe = 0;
    for (final (i, video) in videos.indexed) {
      if (_repo.contains(video.id)) {
        alreadySaved++;
        continue;
      }
      final parsed = parseRecipe(video.description);
      if (!parsed.hasIngredients) {
        noRecipe++;
        continue;
      }
      toSave.add(Recipe(
        videoId: video.id,
        title: video.title,
        channelTitle: video.channelTitle,
        thumbnailUrl: video.thumbnailUrl,
        rawDescription: video.description,
        ingredients: parsed.ingredients,
        steps: parsed.steps,
        servings: parsed.servings,
        // 一覧（新しい順）で再生リストの順に並ぶよう、少しずつずらす
        addedAt: now.subtract(Duration(milliseconds: i)),
        parserVersion: kParserVersion,
      ));
    }

    if (toSave.isEmpty) {
      if (alreadySaved > 0 && noRecipe == 0) {
        throw const AppException('すでに登録済みです');
      }
      throw const AppException('レシピ（材料）を見つけられる動画がありませんでした');
    }

    await _repo.putAll(toSave);
    state = _repo.all();
    return AddRecipesResult(
      added: toSave.length,
      alreadySaved: alreadySaved,
      noRecipe: noRecipe,
      singleVideoId: toSave.length == 1 ? toSave.first.videoId : null,
    );
  }

  /// 概要欄のテキストを書き換えて、材料・工程を抽出し直す
  ///
  /// Phase 3 で材料・工程を個別に編集する画面に置き換える予定。
  Future<void> updateDescription(String videoId, String description) async {
    final existing = _repo.get(videoId);
    if (existing == null) return;
    final parsed = parseRecipe(description);
    await _repo.put(existing.withParsedContent(
      rawDescription: description,
      ingredients: parsed.ingredients,
      steps: parsed.steps,
      servings: parsed.servings,
      parserVersion: kParserVersion,
    ));
    state = _repo.all();
  }

  Future<void> delete(String videoId) async {
    // スワイプで消した項目（Dismissible）は同じフレーム内で一覧から外す必要があるため、
    // 保存先への書き込みを待たずに先に state から取り除く
    state = state.where((r) => r.videoId != videoId).toList();
    await _repo.delete(videoId);
  }
}
