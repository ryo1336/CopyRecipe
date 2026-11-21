import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 画面のスリープを止める／戻す
abstract class ScreenAwake {
  Future<void> enable();
  Future<void> disable();
}

class WakelockScreenAwake implements ScreenAwake {
  const WakelockScreenAwake();

  @override
  Future<void> enable() => _ignoreErrors(WakelockPlus.enable);

  @override
  Future<void> disable() => _ignoreErrors(WakelockPlus.disable);

  // スリープを止められなくても料理中画面は使えるので、失敗は記録だけにする
  static Future<void> _ignoreErrors(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('wakelock failed: $e');
    }
  }
}

final screenAwakeProvider = Provider<ScreenAwake>(
  (_) => const WakelockScreenAwake(),
);

/// 動画を YouTube アプリ（なければブラウザ）で開く
abstract class VideoLauncher {
  /// 開けなかった場合は false
  Future<bool> open(String videoId, {int startSeconds = 0});
}

class UrlVideoLauncher implements VideoLauncher {
  const UrlVideoLauncher();

  @override
  Future<bool> open(String videoId, {int startSeconds = 0}) async {
    try {
      return await launchUrl(
        videoUrl(videoId, startSeconds: startSeconds),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('launch failed: $e');
      return false;
    }
  }
}

/// 指定した時刻から再生する動画の URL
Uri videoUrl(String videoId, {int startSeconds = 0}) => Uri.https(
  'www.youtube.com',
  '/watch',
  {'v': videoId, if (startSeconds > 0) 't': '${startSeconds}s'},
);

final videoLauncherProvider = Provider<VideoLauncher>(
  (_) => const UrlVideoLauncher(),
);
