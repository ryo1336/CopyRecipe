import 'package:copy_recipe/screens/home_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('スワイプで削除したレシピを「元に戻す」で一覧の元の位置に戻せる', (tester) async {
    final env = TestEnv([
      sampleRecipe(
        id: 'new00000000',
        title: '新しいレシピ',
        addedAt: DateTime(2026, 3),
      ),
      sampleRecipe(
        id: 'mid00000000',
        title: '真ん中のレシピ',
        addedAt: DateTime(2026, 2),
      ),
      sampleRecipe(
        id: 'old00000000',
        title: '古いレシピ',
        addedAt: DateTime(2026, 1),
      ),
    ]);
    await env.pump(tester, const HomeScreen(), size: const Size(412, 915));

    await tester.drag(find.text('真ん中のレシピ'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('真ん中のレシピ'), findsNothing);
    expect(env.repository.contains('mid00000000'), isFalse);

    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();

    expect(env.repository.contains('mid00000000'), isTrue);
    double top(String title) => tester.getTopLeft(find.text(title)).dy;
    expect(top('新しいレシピ'), lessThan(top('真ん中のレシピ')));
    expect(top('真ん中のレシピ'), lessThan(top('古いレシピ')));
  });
}
