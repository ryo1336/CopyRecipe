# Copy Recipe

YouTube の料理動画の概要欄から材料と作り方を読み取り、料理中に1画面で見られるようにするアプリです。
動画を巻き戻さずに、材料と工程を確認しながら料理できます。

## 使い方

アプリ内では、一覧画面の右上のメニュー →「使い方」からも確認できます。

### レシピを追加する

1. YouTube アプリで料理動画の「共有」→「リンクをコピー」を選ぶ
2. このアプリの右下の「レシピを追加」を押す
3. 貼り付けボタンで URL を入れ、「追加する」を押す

再生リストの URL を入れると、リスト内の動画をまとめて追加できます。
概要欄に材料が書かれていない動画は追加できません。

### 料理中に見る

- 一覧のレシピを押すと、材料と作り方を1画面で表示します。画面を開いている間はスリープしません。
- 右上のボタンで、文字の大きさを3段階で切り替えられます。
- 作り方の時刻を押すと、YouTube でその場面から再生します。
- 材料の「コピー」で、材料をまとめてコピーできます。
- 読み取りがうまくいかないときは、画面の下の「概要欄の全文」や動画で確認してください。

### 材料で絞り込む

一覧の上の入力欄に材料名を入れると、その材料を使うレシピだけを表示します。
「豚肉 大根」のように空白で区切ると、すべてを使うレシピに絞り込めます。
カタカナ・ひらがなの違いは区別しません。

### レシピを削除する

一覧のレシピを左にスワイプすると削除します。直後に出る「元に戻す」で取り消せます。

## 開発

### 準備

YouTube Data API のキーを `dart_define.json` に書きます（Git の管理外）。

```json
{
  "API_KEY": "<YouTube Data API のキー>"
}
```

### 実行とテスト

```bash
flutter run --dart-define-from-file=dart_define.json
```

```bash
flutter analyze
```

```bash
flutter test
```

### アプリアイコン

`tool/make_icon.py`（Pillow が必要）で `assets/icon/` の画像を描き、`flutter_launcher_icons` で各サイズを作ります。

```bash
python3 tool/make_icon.py assets/icon && dart run flutter_launcher_icons
```

`flutter_launcher_icons` は iOS の `project.pbxproj` と `AppIcon.appiconset/Contents.json` も書き換えますが、既存の設定のままで動くので、その変更は取り消してください。

設計は [docs/design.md](docs/design.md) を参照してください。
