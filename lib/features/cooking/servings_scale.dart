import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../parser/amount.dart';
import '../../providers/recipes_provider.dart';

/// レシピ（動画 ID）ごとの分量の倍率。
///
/// チェック状態と同じく、料理1回分の設定なので保存はせず、画面を閉じたら破棄する。
/// 人数の表記を編集したら、元の人数が変わるので 1 倍に戻す。
final servingsScaleProvider = NotifierProvider.autoDispose
    .family<ServingsScaleNotifier, double, String>(ServingsScaleNotifier.new);

class ServingsScaleNotifier extends Notifier<double> {
  ServingsScaleNotifier(this.videoId);

  final String videoId;

  @override
  double build() {
    ref.watch(recipeByIdProvider(videoId).select((r) => r?.servings));
    return 1;
  }

  void set(double factor) => state = factor;
}

/// 換算の選択肢
class ServingsOption {
  const ServingsOption(this.label, this.factor);

  final String label;
  final double factor;
}

/// 人数が読めるときは「1人分」〜（元の人数の2倍か6人分の大きいほう）まで、
/// 読めないときは倍率（1/2〜3倍）を選択肢にする
List<ServingsOption> servingsOptions(String? servings) {
  final count = parseServingsCount(servings);
  if (count != null) {
    final max = count * 2 > 6 ? count * 2 : 6;
    return [for (var n = 1; n <= max; n++) ServingsOption('$n人分', n / count)];
  }
  return [
    for (final f in const [0.5, 1.0, 1.5, 2.0, 3.0])
      ServingsOption('×${formatFactor(f)}', f),
  ];
}

/// 料理中画面の見出しに置く、人数（分量の倍率）のボタン
class ServingsChip extends ConsumerWidget {
  const ServingsChip({super.key, required this.videoId, this.servings});

  final String videoId;
  final String? servings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factor = ref.watch(servingsScaleProvider(videoId));
    final label = scaledServingsLabel(servings, factor) ?? '分量を変える';
    return ActionChip(
      avatar: const Icon(Icons.people_outline, size: 18),
      label: Text(label),
      tooltip: '人数を変える',
      side: factor == 1
          ? null
          : BorderSide(color: Theme.of(context).colorScheme.primary),
      onPressed: () => _showPicker(context),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ServingsPicker(videoId: videoId, servings: servings),
    );
  }
}

class _ServingsPicker extends ConsumerWidget {
  const _ServingsPicker({required this.videoId, required this.servings});

  final String videoId;
  final String? servings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factor = ref.watch(servingsScaleProvider(videoId));
    final notifier = ref.read(servingsScaleProvider(videoId).notifier);
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              parseServingsCount(servings) == null ? '分量の倍率' : '何人分作りますか',
              style: theme.textTheme.titleLarge,
            ),
            if (servings != null)
              Text('元のレシピ: $servings', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in servingsOptions(servings))
                  ChoiceChip(
                    label: Text(option.label),
                    selected: (option.factor - factor).abs() < 1e-9,
                    onSelected: (_) {
                      notifier.set(option.factor);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '分量の数字だけを計算し直します。「少々」「適量」などはそのままです。',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
