import 'package:hive/hive.dart';

import 'ingredient.dart';
import 'recipe_step.dart';

part 'recipe.g.dart';

/// 保存するレシピ（動画1本 = レシピ1件）
@HiveType(typeId: 1)
class Recipe {
  @HiveField(0)
  final String videoId;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String channelTitle;

  /// 非公開・削除済みの動画などではサムネイルが無いことがある
  @HiveField(3)
  final String? thumbnailUrl;

  /// 概要欄の原文。抽出処理を改良したときの再抽出に使う
  @HiveField(4)
  final String rawDescription;
  @HiveField(5)
  final List<Ingredient> ingredients;
  @HiveField(6)
  final List<RecipeStep> steps;

  /// 「2人分」などの原文
  @HiveField(7)
  final String? servings;

  /// 一覧の並び順に使う
  @HiveField(8)
  final DateTime addedAt;

  /// 利用者が手で直した場合は true。自動の再抽出で上書きしない
  @HiveField(9)
  final bool isEdited;

  /// どの版の抽出処理で作ったか
  @HiveField(10)
  final int parserVersion;

  const Recipe({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.rawDescription,
    required this.ingredients,
    required this.steps,
    required this.servings,
    required this.addedAt,
    this.isEdited = false,
    required this.parserVersion,
  });

  Recipe copyWith({
    String? rawDescription,
    List<Ingredient>? ingredients,
    List<RecipeStep>? steps,
    String? servings,
    bool? isEdited,
    int? parserVersion,
  }) {
    return Recipe(
      videoId: videoId,
      title: title,
      channelTitle: channelTitle,
      thumbnailUrl: thumbnailUrl,
      rawDescription: rawDescription ?? this.rawDescription,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      servings: servings ?? this.servings,
      addedAt: addedAt,
      isEdited: isEdited ?? this.isEdited,
      parserVersion: parserVersion ?? this.parserVersion,
    );
  }
}
