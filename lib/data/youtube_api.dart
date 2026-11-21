import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../dart_define.gen.dart';
import 'app_exception.dart';

/// YouTube Data API から取得した動画の情報
class YoutubeVideo {
  final String id;
  final String title;
  final String channelTitle;
  final String? thumbnailUrl;
  final String description;

  const YoutubeVideo({
    required this.id,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.description,
  });

  /// videos API の item から作る
  factory YoutubeVideo.fromVideoItem(Map<String, dynamic> item) {
    final snippet = (item['snippet'] as Map?)?.cast<String, dynamic>() ?? const {};
    return YoutubeVideo(
      id: item['id'] as String,
      title: snippet['title'] as String? ?? '',
      channelTitle: snippet['channelTitle'] as String? ?? '',
      thumbnailUrl: _bestThumbnail(snippet['thumbnails']),
      description: snippet['description'] as String? ?? '',
    );
  }
}

String? _bestThumbnail(Object? thumbnails) {
  if (thumbnails is! Map) return null;
  for (final key in const ['high', 'medium', 'standard', 'default', 'maxres']) {
    final t = thumbnails[key];
    if (t is Map && t['url'] is String) return t['url'] as String;
  }
  return null;
}

final youtubeApiProvider = Provider<YoutubeApi>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return YoutubeApi(client: client, apiKey: DartDefine.apiKey);
});

class YoutubeApi {
  YoutubeApi({required http.Client client, required String apiKey})
      : _client = client,
        _apiKey = apiKey;

  final http.Client _client;
  final String _apiKey;

  static const _host = 'www.googleapis.com';

  /// 再生リストから取り込む動画数の上限（API 使用量を抑えるため）
  static const maxPlaylistVideos = 200;

  /// 動画1本を取得する
  Future<YoutubeVideo> fetchVideo(String videoId) async {
    final videos = await fetchVideos([videoId]);
    if (videos.isEmpty) {
      throw const AppException('動画が見つかりませんでした（非公開または削除された可能性があります）');
    }
    return videos.first;
  }

  /// 複数の動画をまとめて取得する（見つからない動画は結果に含まれない）
  Future<List<YoutubeVideo>> fetchVideos(List<String> videoIds) async {
    final result = <YoutubeVideo>[];
    for (var i = 0; i < videoIds.length; i += 50) {
      final chunk = videoIds.sublist(i, (i + 50).clamp(0, videoIds.length));
      final data = await _get('/youtube/v3/videos', {
        'part': 'snippet',
        'id': chunk.join(','),
        'maxResults': '50',
      });
      final items = (data['items'] as List?) ?? const [];
      result.addAll(
        items.map((e) => YoutubeVideo.fromVideoItem((e as Map).cast<String, dynamic>())),
      );
    }
    // API の返す順ではなく、指定した順に並べる
    final order = {for (var i = 0; i < videoIds.length; i++) videoIds[i]: i};
    result.sort((a, b) => (order[a.id] ?? 0).compareTo(order[b.id] ?? 0));
    return result;
  }

  /// 再生リストに含まれる動画の ID を、再生リストの順に取得する
  Future<List<String>> fetchPlaylistVideoIds(String playlistId) async {
    final ids = <String>[];
    String? pageToken;
    do {
      final data = await _get('/youtube/v3/playlistItems', {
        'part': 'snippet',
        'playlistId': playlistId,
        'maxResults': '50',
        if (pageToken != null) 'pageToken': pageToken,
      });
      for (final item in (data['items'] as List?) ?? const []) {
        final snippet = (item as Map)['snippet'];
        final resource = snippet is Map ? snippet['resourceId'] : null;
        final videoId = resource is Map ? resource['videoId'] : null;
        // 再生リストの項目 ID（item['id']）ではなく、動画 ID を使う
        if (videoId is String && !ids.contains(videoId)) ids.add(videoId);
      }
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null && ids.length < maxPlaylistVideos);
    return ids.take(maxPlaylistVideos).toList();
  }

  Future<Map<String, dynamic>> _get(String path, Map<String, String> params) async {
    final url = Uri.https(_host, path, {...params, 'key': _apiKey});
    final http.Response response;
    try {
      response = await _client.get(url);
    } on SocketException {
      throw const AppException('通信できませんでした。ネットワーク接続を確認してください');
    } on http.ClientException {
      throw const AppException('通信できませんでした。ネットワーク接続を確認してください');
    }

    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as Map).cast<String, dynamic>();
    }
    if (response.statusCode == 404) {
      throw const AppException('再生リストが見つかりませんでした（非公開の可能性があります）');
    }
    if (response.statusCode == 403 && response.body.contains('quotaExceeded')) {
      throw const AppException('本日の取得上限に達しました。時間をおいて再度お試しください');
    }
    throw AppException('動画情報の取得に失敗しました（${response.statusCode}）');
  }
}
