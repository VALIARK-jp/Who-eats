/// valiark-dev 共通 LINE Login チャンネル（Panda Talk と同値）。
const valiarkLineChannelId = '2010102462';

/// Who eats 専用メール確認 / PKCE リダイレクト（Panda Talk の `io.valiark.pandatalk` と分離）。
///
/// `.env` の [whoeatsAuthRedirectEnvKey]、iOS/Android URL Types、
/// Supabase Dashboard → Redirect URLs の3か所で同じ値に揃える。
const whoeatsAuthRedirectUrl = 'io.valiark.whoeats://callback';

const whoeatsAuthRedirectEnvKey = 'WHOEATS_AUTH_REDIRECT_URL';

/// 後方互換（旧 .env キー）。新規は [whoeatsAuthRedirectEnvKey] を推奨。
const legacyValiarkAuthRedirectEnvKey = 'VALIARK_AUTH_REDIRECT_URL';
