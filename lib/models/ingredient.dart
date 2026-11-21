import 'package:hive/hive.dart';

part 'ingredient.g.dart';

/// 材料1行分
@HiveType(typeId: 2)
class Ingredient {
  /// 材料名（例: 豚バラ肉）
  @HiveField(0)
  final String name;

  /// 分量（例: 200g、大さじ1）。原文のまま保持する
  @HiveField(1)
  final String? amount;

  /// グループ名（例: A、タレ）。見出しごとにまとめて表示するために使う
  @HiveField(2)
  final String? group;

  const Ingredient({required this.name, this.amount, this.group});

  @override
  bool operator ==(Object other) =>
      other is Ingredient &&
      other.name == name &&
      other.amount == amount &&
      other.group == group;

  @override
  int get hashCode => Object.hash(name, amount, group);

  @override
  String toString() => 'Ingredient($name, $amount, group: $group)';
}
