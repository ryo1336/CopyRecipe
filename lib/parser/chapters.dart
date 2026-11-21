/// 概要欄のチャプター（タイムスタンプ）1件
class Chapter {
  final String title;
  final int seconds;

  const Chapter(this.title, this.seconds);

  @override
  bool operator ==(Object other) =>
      other is Chapter && other.title == title && other.seconds == seconds;

  @override
  int get hashCode => Object.hash(title, seconds);

  @override
  String toString() => 'Chapter($seconds, $title)';
}

final _leadingTimestamp =
    RegExp(r'^(?:(\d{1,2}):)?(\d{1,2}):(\d{2})(?!\d)\s*(.*)$');
final _trailingTimestamp =
    RegExp(r'^(.*?)\s*[(]?(?:(\d{1,2}):)?(\d{1,2}):(\d{2})[)]?$');
final _titleTrim = RegExp(r'^[\s\-–—~〜ー:|・]+|[\s\-–—~〜ー:|・]+$');

/// 1行がタイムスタンプ付きならチャプターとして返す。そうでなければ null。
///
/// 「1:23 大根を切る」「大根を切る 1:23」「1:02:03 煮込む」の形に対応する。
Chapter? parseTimestampLine(String line) {
  final text = line.trim();
  final leading = _leadingTimestamp.firstMatch(text);
  if (leading != null) {
    final seconds = _toSeconds(leading.group(1), leading.group(2)!, leading.group(3)!);
    final title = leading.group(4)!.replaceAll(_titleTrim, '');
    if (seconds == null) return null;
    return Chapter(title, seconds);
  }
  final trailing = _trailingTimestamp.firstMatch(text);
  if (trailing != null) {
    final title = trailing.group(1)!.replaceAll(_titleTrim, '');
    if (title.isEmpty) return null;
    final seconds = _toSeconds(trailing.group(2), trailing.group(3)!, trailing.group(4)!);
    if (seconds == null) return null;
    return Chapter(title, seconds);
  }
  return null;
}

int? _toSeconds(String? h, String m, String s) {
  final sec = int.parse(s);
  if (sec >= 60) return null;
  final min = int.parse(m);
  if (h != null && min >= 60) return null;
  return (h == null ? 0 : int.parse(h)) * 3600 + min * 60 + sec;
}

/// 概要欄全体からチャプターを集める。
///
/// 誤検出を避けるため、タイムスタンプ行が2行以上ある場合だけチャプターとみなす。
List<Chapter> parseChapters(List<String> lines) {
  final chapters = <Chapter>[];
  for (final line in lines) {
    final chapter = parseTimestampLine(line);
    if (chapter != null && chapter.title.isNotEmpty) chapters.add(chapter);
  }
  return chapters.length >= 2 ? chapters : const [];
}

/// 秒数を「1:05」「1:02:03」の形にする
String formatTimestamp(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}
