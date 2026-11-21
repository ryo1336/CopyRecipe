/// 利用者にそのまま表示できるメッセージを持つ例外
class AppException implements Exception {
  final String message;

  const AppException(this.message);

  @override
  String toString() => message;
}
