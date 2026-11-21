import 'package:material_ui/material_ui.dart';

/// アプリ全体の配色と部品の見た目。
///
/// - 料理アプリらしい暖色（トマト色）を基調色にし、ボタン・見出しの色をそろえる
/// - キッチンの照明や夜の利用を考え、端末の設定に合わせてダークモードにも切り替える
/// - 色は ColorScheme から取り、画面ごとに色を直接書かない
const _seed = Color(0xFFD9541E);

ThemeData buildTheme(Brightness brightness) {
  // 既定の配色だと基調色がくすんで茶色に寄るので、元の色味を保つ fidelity にする
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  return ThemeData(
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: scheme.surfaceTint,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
    // 普段は枠線なしの塗りつぶしにし、フォーカス中とエラーのときだけ枠線で知らせる
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: _inputBorder(BorderSide.none),
      enabledBorder: _inputBorder(BorderSide.none),
      focusedBorder: _inputBorder(BorderSide(color: scheme.primary, width: 2)),
      errorBorder: _inputBorder(BorderSide(color: scheme.error)),
      focusedErrorBorder: _inputBorder(
        BorderSide(color: scheme.error, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

OutlineInputBorder _inputBorder(BorderSide side) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(12),
  borderSide: side,
);
