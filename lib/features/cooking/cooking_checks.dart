import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/recipes_provider.dart';

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
/// チェックは行の番号で持つため、編集などで材料・工程が変わったらリセットする。
final cookingChecksProvider = NotifierProvider.autoDispose
    .family<CookingChecksNotifier, CookingChecks, String>(
      CookingChecksNotifier.new,
    );

class CookingChecksNotifier extends Notifier<CookingChecks> {
  CookingChecksNotifier(this.videoId);

  final String videoId;

  @override
  CookingChecks build() {
    // 抽出し直すと材料・工程のリストが新しいインスタンスになるので、
    // それを監視して build をやり直し、チェックを空に戻す
    ref.watch(
      recipeByIdProvider(
        videoId,
      ).select((recipe) => (recipe?.ingredients, recipe?.steps)),
    );
    return const CookingChecks();
  }

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

  /// ステップモードで「次へ」進んだ工程を、完了として付ける
  void checkStep(int index) {
    if (state.steps.contains(index)) return;
    state = CookingChecks(
      ingredients: state.ingredients,
      steps: {...state.steps, index},
    );
  }

  void reset() => state = const CookingChecks();

  static Set<int> _toggle(Set<int> set, int index) =>
      set.contains(index) ? ({...set}..remove(index)) : {...set, index};
}
