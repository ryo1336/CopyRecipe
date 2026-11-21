import 'package:hive/hive.dart';

import '../models/recipe.dart';
import '../models/video_model.dart';
import '../parser/recipe_parser.dart';

const _legacyBoxName = 'Videos';

/// 旧形式（Video / 'Videos' Box）のデータを Recipe に移す。
///
/// 移行が終わったら旧 Box は削除する。旧 Box がなければ何もしない。
Future<void> migrateLegacyVideos(Box<Recipe> recipes) async {
  if (!await Hive.boxExists(_legacyBoxName)) return;

  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(VideoAdapter());
  final legacy = await Hive.openBox<Video>(_legacyBoxName);

  final now = DateTime.now();
  final videos = legacy.values.toList();
  final migrated = <String, Recipe>{};
  for (var i = 0; i < videos.length; i++) {
    final v = videos[i];
    if (recipes.containsKey(v.id)) continue;
    final parsed = parseRecipe(v.description);
    migrated[v.id] = Recipe(
      videoId: v.id,
      title: v.title,
      channelTitle: v.channelTitle,
      thumbnailUrl: v.thumbnailUrl.isEmpty ? null : v.thumbnailUrl,
      rawDescription: v.description,
      ingredients: parsed.ingredients,
      steps: parsed.steps,
      servings: parsed.servings,
      // 旧データには追加日時がないので、保存されていた順を保つ
      addedAt: now.subtract(Duration(seconds: i)),
      parserVersion: kParserVersion,
    );
  }
  await recipes.putAll(migrated);
  await legacy.deleteFromDisk();
}
