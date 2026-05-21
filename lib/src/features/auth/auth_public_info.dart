// 認証画面フッター用の文言・リンク（Panda Talk の valiark_public_info 同型）。

class AuthSisterAppLink {
  const AuthSisterAppLink({required this.title, required this.uri});

  final String title;
  final Uri uri;
}

/// 「Created by」直下に表示する制作クレジット（VALIARK ロゴの代わり）。
const authCreatedByAffiliationJa = '大阪大学　基礎工学部　情報科学科　B2　1班';

/// ログイン／新規登録時の主メッセージ（Valiark 横断アカウント共通）。
const valiarkUnifiedAccountLeadJa =
    'ログイン・新規登録に使うアカウントは、VALIARK合同会社が提供するアプリどうしで共通です。'
    'メール・LINE・Apple など、どの方法でサインインしても同じアカウントとして扱われます。'
    'ほかの Valiark アプリでも、そのログイン情報のままお使いいただけます。';

/// 取得情報の扱い（全ログイン方式共通の補足）。
const valiarkAuthSupplementJa = '取得する情報は各アプリの提供に必要な範囲に限定します。';

/// 姉妹アプリ（ストア・Web）。URL は公開後に [uri] だけ更新すればよい。
final authSisterAppLinks = <AuthSisterAppLink>[
  AuthSisterAppLink(
    title: 'パンダトーク',
    uri: Uri.parse('https://valiark.jp'),
  ),
];
