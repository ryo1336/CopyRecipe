import 'package:copy_recipe/data/youtube_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = 'dQw4w9WgXcQ';

  test('動画 URL のさまざまな形式', () {
    for (final url in [
      'https://www.youtube.com/watch?v=$id',
      'https://m.youtube.com/watch?v=$id&t=30s',
      'https://youtu.be/$id?si=abc',
      'youtu.be/$id',
      'https://www.youtube.com/shorts/$id',
      'https://www.youtube.com/live/$id',
      'https://www.youtube.com/watch?v=$id&list=PLabc',
    ]) {
      expect(parseYoutubeUrl(url), const YoutubeTarget(videoId: id), reason: url);
    }
  });

  test('再生リスト URL', () {
    expect(
      parseYoutubeUrl('https://www.youtube.com/playlist?list=PLabc_-123'),
      const YoutubeTarget(playlistId: 'PLabc_-123'),
    );
  });

  test('対象外の URL', () {
    for (final url in [
      'https://evilyoutube.com/watch?v=$id',
      'https://youtube.com.example.com/watch?v=$id',
      'https://www.youtube.com/@channel',
      'https://www.youtube.com/channel/UCxxxx',
      'https://www.youtube.com/watch?v=short',
      'ftp://youtu.be/$id',
      'ただの文字列',
    ]) {
      expect(parseYoutubeUrl(url), isNull, reason: url);
    }
  });
}
