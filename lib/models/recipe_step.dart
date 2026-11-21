import 'package:hive/hive.dart';

part 'recipe_step.g.dart';

/// 作り方の1工程
@HiveType(typeId: 3)
class RecipeStep {
  @HiveField(0)
  final String text;

  /// 動画内の開始位置（秒）。チャプターと対応できた場合のみ
  @HiveField(1)
  final int? startSeconds;

  const RecipeStep({required this.text, this.startSeconds});

  @override
  bool operator ==(Object other) =>
      other is RecipeStep &&
      other.text == text &&
      other.startSeconds == startSeconds;

  @override
  int get hashCode => Object.hash(text, startSeconds);

  @override
  String toString() => 'RecipeStep($text, $startSeconds)';
}
