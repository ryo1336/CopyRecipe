import 'package:material_ui/material_ui.dart';

/// アプリの使い方。メニューの「使い方」から開く
class HowToScreen extends StatelessWidget {
  const HowToScreen({super.key});

  static const _sections = [
    (
      icon: Icons.add_link,
      title: 'レシピを追加する',
      body:
          'YouTube アプリで料理動画の「共有」→「リンクをコピー」を選びます。'
          'このアプリに戻って右下の「レシピを追加」を押し、貼り付けボタンで URL を入れて「追加する」を押します。\n'
          '再生リストの URL を入れると、リスト内の動画をまとめて追加できます。',
    ),
    (
      icon: Icons.restaurant_menu,
      title: '料理中に見る',
      body:
          '一覧のレシピを押すと、材料と作り方を1画面で表示します。'
          '画面を開いている間はスリープしません。\n'
          '右上のボタンで文字の大きさを3段階で切り替えられます。'
          '作り方の時刻を押すと、YouTube でその場面から再生します。'
          '材料の「コピー」を押すと、材料をまとめてコピーでき、買い物メモなどに貼り付けられます。',
    ),
    (
      icon: Icons.filter_list,
      title: '材料で絞り込む',
      body:
          '一覧の上の入力欄に材料名を入れると、その材料を使うレシピだけを表示します。'
          '「豚肉 大根」のように空白で区切ると、すべてを使うレシピに絞り込めます。',
    ),
    (
      icon: Icons.delete_outline,
      title: 'レシピを削除する',
      body: '一覧のレシピを左にスワイプすると削除します。直後に出る「元に戻す」で取り消せます。',
    ),
    (
      icon: Icons.info_outline,
      title: '材料や作り方が見つからないとき',
      body:
          '材料と作り方は、動画の概要欄から自動で読み取ります。'
          '概要欄に材料が書かれていない動画は追加できません。'
          '読み取りがうまくいかないときは、料理中画面の下にある「概要欄の全文」や動画で確認してください。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('使い方')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: _sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final section = _sections[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: Icon(section.icon),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          section.body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
