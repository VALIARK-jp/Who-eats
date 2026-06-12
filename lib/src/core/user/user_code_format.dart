/// Who eats の `@user_code` 表示・入力ルール。
abstract final class UserCodeFormat {
  /// `@` 含む全体の最大文字数。
  static const maxLength = 15;

  /// 入力欄（`@` なし）の最大文字数。
  static const maxBodyLength = maxLength - 1;

  static final bodyPattern = RegExp(r'^[A-Za-z0-9_]+$');

  /// 表示・保存用（DB: `whoeats_users_user_code_length_check` と同期）。
  static String display(String code) {
    final trimmed = code.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return trimmed.substring(0, maxLength);
  }

  /// `@` 付きコードに正規化（入力 body から生成、長さ上限あり）。
  static String fromBody(String body) {
    final cleaned = body.trim();
    if (cleaned.isEmpty) return '@';
    final withAt = cleaned.startsWith('@') ? cleaned : '@$cleaned';
    return display(withAt);
  }

  /// DB 保存前の正規化（既存の `@` 付きコードも切り詰め）。
  static String normalizeStored(String code) => display(code.trim());

  static String bodyFromStored(String stored) {
    return bodyFromStoredCode(display(stored));
  }

  static String bodyFromStoredCode(String storedWithAt) {
    final trimmed = storedWithAt.trim();
    if (trimmed.startsWith('@')) return trimmed.substring(1);
    return trimmed;
  }
}
