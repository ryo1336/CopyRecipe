/// URL から取り出した、取得対象の動画または再生リスト
class YoutubeTarget {
  final String? videoId;
  final String? playlistId;

  const YoutubeTarget({this.videoId, this.playlistId});

  @override
  bool operator ==(Object other) =>
      other is YoutubeTarget &&
      other.videoId == videoId &&
      other.playlistId == playlistId;

  @override
  int get hashCode => Object.hash(videoId, playlistId);

  @override
  String toString() => 'YoutubeTarget(video: $videoId, playlist: $playlistId)';
}

const _youtubeHosts = {
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'music.youtube.com',
};
final _videoId = RegExp(r'^[0-9A-Za-z_-]{11}$');
final _playlistId = RegExp(r'^[0-9A-Za-z_-]+$');

/// YouTube の動画・再生リストの URL を解析する。対象外の URL なら null。
///
/// 動画 ID と再生リスト ID の両方を含む URL（watch?v=...&list=...）は動画として扱う。
YoutubeTarget? parseYoutubeUrl(String input) {
  var text = input.trim();
  if (!text.contains('://')) text = 'https://$text';
  final uri = Uri.tryParse(text);
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
    return null;
  }

  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  String? videoId;

  if (host == 'youtu.be') {
    if (segments.isNotEmpty) videoId = segments.first;
  } else if (_youtubeHosts.contains(host)) {
    if (segments.length == 1 && segments.first == 'watch') {
      videoId = uri.queryParameters['v'];
    } else if (segments.length >= 2 &&
        const {'shorts', 'embed', 'live', 'v'}.contains(segments.first)) {
      videoId = segments[1];
    }
  } else {
    return null;
  }

  if (videoId != null && _videoId.hasMatch(videoId)) {
    return YoutubeTarget(videoId: videoId);
  }

  final list = uri.queryParameters['list'];
  if (list != null && _playlistId.hasMatch(list)) {
    return YoutubeTarget(playlistId: list);
  }
  return null;
}
