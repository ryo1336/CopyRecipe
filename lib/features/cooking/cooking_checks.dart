import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 料理中画面のチェック状態（どの材料をそろえ、どの工程まで進んだか）
class CookingChecks {
  final Set<int> ingredients;
  final Set<int> steps;

  const CookingChecks({this.ingredients = const {}, this.steps = const {}});

  bool get isEmpty => ingredients.isEmpty && steps.isEmpty;
}

/// レシピ（動画 ID）ごとのチェック状態。
///
/// 料理は1回ごとに終わるので保存はせず、画面を閉じたら破棄する（autoDispose）。
final cookingChecksProvider = NotifierProvider.autoDispose
    .family<CookingChecksNotifier, CookingChecks, String>(
      // 動画 ID はレシピごとに別のチェック状態を持つためのキーで、中では使わない
      (_) => CookingChecksNotifier(),
    );

class CookingChecksNotifier extends Notifier<CookingChecks> {
  @override
  CookingChecks build() => const CookingChecks();

  void toggleIngredient(int index) {
    state = CookingChecks(
      ingredients: _toggle(state.ingredients, index),
      steps: state.steps,
    );
  }

  void toggleStep(int index) {
    state = CookingChecks(
      ingredients: state.ingredients,
      steps: _toggle(state.steps, index),
    );
  }

  void reset() => state = const CookingChecks();

  static Set<int> _toggle(Set<int> set, int index) =>
      set.contains(index) ? ({...set}..remove(index)) : {...set, index};
}
