import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

const settingsBoxName = 'settings';
const cookingFontSizeKey = 'cookingFontScale';

/// 端末に保存する設定の読み書き
abstract class SettingsStore {
  String? getString(String key);

  /// 保存の完了は待たない（画面の反映を待たせないため）
  void setString(String key, String value);
}

class HiveSettingsStore implements SettingsStore {
  HiveSettingsStore(this._box);

  final Box<dynamic> _box;

  @override
  String? getString(String key) => _box.get(key) as String?;

  @override
  void setString(String key, String value) => _box.put(key, value);
}

final settingsStoreProvider = Provider<SettingsStore>(
  (_) => HiveSettingsStore(Hive.box<dynamic>(settingsBoxName)),
);

/// 料理中画面の文字サイズ
enum CookingFontSize {
  normal('標準', 1.0),
  large('大', 1.25),
  extraLarge('特大', 1.5);

  const CookingFontSize(this.label, this.scale);

  final String label;
  final double scale;
}

/// 料理中画面の文字サイズ。選んだサイズは端末に保存し、次回も使う
final cookingFontSizeProvider =
    NotifierProvider<CookingFontSizeNotifier, CookingFontSize>(CookingFontSizeNotifier.new);

class CookingFontSizeNotifier extends Notifier<CookingFontSize> {
  @override
  CookingFontSize build() {
    final name = ref.read(settingsStoreProvider).getString(cookingFontSizeKey);
    return CookingFontSize.values.firstWhere(
      (s) => s.name == name,
      orElse: () => CookingFontSize.normal,
    );
  }

  void set(CookingFontSize size) {
    state = size;
    ref.read(settingsStoreProvider).setString(cookingFontSizeKey, size.name);
  }
}
