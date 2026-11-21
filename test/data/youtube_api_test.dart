import 'dart:convert';

import 'package:copy_recipe/data/app_exception.dart';
import 'package:copy_recipe/data/youtube_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> videoItem(String id, {Map<String, dynamic>? thumbnails}) => {
      'id': id,
      'snippet': {
        'title': 'title $id',
        'channelTitle': 'channel',
        'description': 'desc $id',
        'thumbnails': thumbnails ?? {'high': {'url': 'https://img/$id.jpg'}},
      },
    };

Map<String, dynamic> playlistItem(String itemId, String? videoId) => {
      'id': itemId,
      'snippet': {
        'title': 'item',
        if (videoId != null) 'resourceId': {'kind': 'youtube#video', 'videoId': videoId},
      },
    };

void main() {
  test('再生リストは全ページを取得し、項目 ID ではなく動画 ID を返す', () async {
    final requests = <Uri>[];
    final api = YoutubeApi(
      apiKey: 'k',
      client: MockClient((req) async {
        requests.add(req.url);
        final token = req.url.queryParameters['pageToken'];
        final body = token == null
            ? {
                'items': [playlistItem('PLITEM1', 'video00001a'), playlistItem('PLITEM2', 'video00002a')],
                'nextPageToken': 'p2',
              }
            : {
                'items': [playlistItem('PLITEM3', 'video00003a'), playlistItem('PLITEM4', null)],
              };
        return http.Response(jsonEncode(body), 200);
      }),
    );

    final ids = await api.fetchPlaylistVideoIds('PL1');
    expect(ids, ['video00001a', 'video00002a', 'video00003a']);
    expect(requests, hasLength(2));
  });

  test('動画が見つからない場合はわかりやすいエラーになる', () async {
    final api = YoutubeApi(
      apiKey: 'k',
      client: MockClient((_) async => http.Response(jsonEncode({'items': []}), 200)),
    );
    expect(
      () => api.fetchVideo('xxxxxxxxxxx'),
      throwsA(isA<AppException>().having((e) => e.message, 'message', contains('見つかりません'))),
    );
  });

  test('サムネイルがなくても落ちず、指定した順に並ぶ', () async {
    final api = YoutubeApi(
      apiKey: 'k',
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'items': [videoItem('b'), videoItem('a', thumbnails: {})],
            }),
            200,
          )),
    );
    final videos = await api.fetchVideos(['a', 'b']);
    expect(videos.map((v) => v.id), ['a', 'b']);
    expect(videos.first.thumbnailUrl, isNull);
    expect(videos.last.thumbnailUrl, 'https://img/b.jpg');
  });

  test('上限超過は専用のメッセージ', () async {
    final api = YoutubeApi(
      apiKey: 'k',
      client: MockClient((_) async => http.Response('{"error":{"errors":[{"reason":"quotaExceeded"}]}}', 403)),
    );
    expect(
      () => api.fetchVideo('xxxxxxxxxxx'),
      throwsA(isA<AppException>().having((e) => e.message, 'message', contains('上限'))),
    );
  });
}
