/// 表示名（ユーザーネーム）の長さルール（DB: `whoeats_users_name_length_check` と同期）。
abstract final class UserDisplayNameFormat {
  static const maxLength = 10;

  /// 保存前の正規化（クライアント側ガード）。
  static String normalizeInput(String name) {
    final trimmed = name.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return trimmed.substring(0, maxLength);
  }

  /// 表示用（DB 移行後も念のため上限を適用）。
  static String display(String name) => normalizeInput(name);
}
