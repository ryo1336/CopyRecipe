/// 概要欄のテキストを抽出しやすい形にそろえる。
///
/// - 改行コードを `\n` に統一
/// - 全角英数字・記号（！〜～）を半角に変換（「（」→「(」、「：」→「:」など）
/// - 全角スペースを半角スペースに変換
/// - 行末の空白を除去
String normalize(String text) {
  final unified = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final buffer = StringBuffer();
  for (final rune in unified.runes) {
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      buffer.writeCharCode(rune - 0xFEE0);
    } else if (rune == 0x3000) {
      buffer.write(' ');
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer
      .toString()
      .split('\n')
      .map((line) => line.trimRight())
      .join('\n');
}
