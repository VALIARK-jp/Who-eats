import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum LegalDocumentType {
  terms,
  privacy,
}

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({
    super.key,
    required this.type,
  });

  final LegalDocumentType type;

  String get _title {
    switch (type) {
      case LegalDocumentType.terms:
        return '利用規約';
      case LegalDocumentType.privacy:
        return 'プライバシーポリシー';
    }
  }

  List<_LegalSection> get _sections {
    switch (type) {
      case LegalDocumentType.terms:
        return _termsSections;
      case LegalDocumentType.privacy:
        return _privacySections;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: AppColors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            _title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '最終更新日: 2026年6月6日',
            style: TextStyle(
              color: AppColors.textSubtle.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          for (final section in _sections) ...[
            Text(
              section.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              section.body,
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.82),
                fontSize: 14,
                height: 1.62,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
          ],
          Text(
            '運営者: VALIARK合同会社　大阪府吹田市　info@valiark.jp',
            style: TextStyle(
              color: AppColors.textSubtle.withValues(alpha: 0.9),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

const _termsSections = [
  _LegalSection(
    title: '第1条（適用）',
    body: '本利用規約は、VALIARK合同会社（以下「当社」）が提供するアプリケーション「Who eats」（以下「本サービス」）の利用条件を定めるものです。ユーザーは、本規約に同意したうえで本サービスを利用するものとします。当社が本サービス上で掲載するガイドライン、ヘルプ、その他のルールは、本規約の一部を構成します。',
  ),
  _LegalSection(
    title: '第2条（定義）',
    body: '「ユーザー」とは本サービスを利用するすべての者をいいます。「会員」とは利用登録を行いアカウントを保有するユーザーをいいます。「投稿コンテンツ」とは、ユーザーが本サービス上に投稿、送信、表示する写真、コメント、一言、店舗情報、位置情報、その他一切の情報をいいます。',
  ),
  _LegalSection(
    title: '第3条（サービス内容）',
    body: '本サービスは、食べた・食べたいお店の投稿・共有、地図上のピン表示、いいね・コメント等の交流機能、フォロー・友達機能、プッシュ通知等を提供するソーシャルフードアプリです。個別機能は、当社の判断により追加、変更、停止される場合があります。\n\n本サービスに表示される店舗情報、営業時間、経路、評価等は外部サービスを通じて取得・表示されるものであり、当社がその正確性・最新性・完全性を保証するものではありません。',
  ),
  _LegalSection(
    title: '第4条（利用登録）',
    body: '会員になろうとする者は、当社の定める方法（メールアドレス、Apple ID、LINE 等）により利用登録を行うものとします。会員は登録情報を正確かつ最新に保持する責任を負います。当社は、虚偽登録・規約違反・反社会的勢力への該当等の場合、登録拒否またはアカウントの停止・削除を行うことができます。会員は、アカウント情報を自己の責任で管理し、第三者に利用させてはなりません。',
  ),
  _LegalSection(
    title: '第5条（禁止事項）',
    body: 'ユーザーは以下の行為を行ってはなりません。\n・法令または公序良俗に違反する行為\n・他ユーザーへの誹謗中傷、嫌がらせ、ストーカー行為等\n・わいせつ、暴力的、差別的な投稿\n・虚偽または誤解を招く店舗情報・口コミの投稿\n・なりすまし、第三者の個人情報の不正取得・公開\n・不正アクセス、サーバー・ネットワークへの攻撃・妨害\n・リバースエンジニアリング、BOT・スクレイピング等の自動操作\n・本サービスの運営を妨害する行為\n・反社会的勢力等への利益供与\n・その他当社が不適切と判断する行為',
  ),
  _LegalSection(
    title: '第6条（投稿コンテンツ）',
    body: '投稿コンテンツに関する著作権その他の権利は、当該権利を享有する者に帰属します。ユーザーは、当社に対し、本サービスの提供・運営・改善・宣伝・広報に必要な範囲で投稿コンテンツを無償で利用する非独占的な許諾を行うものとします。ユーザーは当社に対し著作者人格権を行使しないものとします。\n\nユーザーは自身の投稿コンテンツについて一切の責任を負い、第三者との紛争が生じた場合はユーザーの費用と責任において解決するものとします。当社は規約違反のおそれがある投稿を事前通知なく削除できます。',
  ),
  _LegalSection(
    title: '第7条（アカウント停止・削除）',
    body: '当社は、ユーザーが本規約に違反した場合またはそのおそれがある場合、事前の通知なく、アカウントの停止、投稿コンテンツの削除、本サービスの利用制限等の措置を行うことができます。会員は、当社の定める方法により、自己のアカウント削除を申請できます。',
  ),
  _LegalSection(
    title: '第8条（サービス変更・中断・終了）',
    body: '当社は、ユーザーへの事前の通知なく、本サービスの内容の変更、追加、制限、一時中断、終了を行うことがあります。これによりユーザーに生じた損害について、当社に故意または重過失がある場合を除き、責任を負いません。',
  ),
  _LegalSection(
    title: '第9条（免責事項）',
    body: '当社は、本サービスの特定の目的への適合性、期待する機能・正確性・完全性・有用性、不具合が生じないことを保証しません。店舗情報、営業時間、評価、位置情報等の正確性・最新性も保証しません。ユーザー間またはユーザーと第三者間のトラブルについて、当社は一切の責任を負いません。通信回線・端末・外部サービスの障害に起因する損害について、当社に故意または重過失がある場合を除き、責任を負いません。',
  ),
  _LegalSection(
    title: '第10条（知的財産権）',
    body: '本サービスに関するプログラム、デザイン、商標、ロゴ、その他一切の知的財産権は、当社または正当な権利者に帰属します。本規約に基づく本サービスの利用許諾は、これらの知的財産権の譲渡または使用許諾を意味するものではありません。',
  ),
  _LegalSection(
    title: '第11条（個人情報の取扱い）',
    body: '当社によるユーザーの個人情報の取扱いについては、別途定める「Who eats プライバシーポリシー」に従うものとします。',
  ),
  _LegalSection(
    title: '第12条（規約の変更）',
    body: '当社は、必要に応じて本規約を変更できるものとします。変更後の本規約は、本サービス内、当社ウェブサイト、または当社が定める方法で掲示した時点から効力を生じます。変更後に本サービスを利用したユーザーは、変更後の本規約に同意したものとみなします。',
  ),
  _LegalSection(
    title: '第13条（準拠法・管轄）',
    body: '本規約は、日本法に準拠し、日本法に従って解釈されます。本サービスに関して紛争が生じた場合、大阪地方裁判所を第一審の専属的合意管轄裁判所とします。',
  ),
];

const _privacySections = [
  _LegalSection(
    title: '1. 基本方針',
    body: '当社は、個人情報の保護に関する法令およびガイドラインを遵守し、ユーザー情報を適切に取得、利用、管理します。本ポリシーは、本サービスにおけるユーザー情報の取扱いを説明するものです。',
  ),
  _LegalSection(
    title: '2. 取得する情報',
    body: '当社は、本サービスの提供にあたり、以下の情報を取得する場合があります。\n\n【アカウント・認証】メールアドレス、ユーザーID（コード）、認証プロバイダ情報（メール・Apple・LINE 等）、認証セッション識別子\n\n【プロフィール】表示名、プロフィール文、プロフィール画像\n\n【利用履歴】投稿写真・コメント・一言（キャプション）、紐付けた店舗・場所情報（店舗名・住所・位置情報等）、いいね・お気に入り・フォロー・友達申請等の操作履歴、プッシュ通知用デバイストークン\n\n【位置情報】近くの店舗候補の表示・検索、投稿への店舗紐付け、地図上のピン表示のために利用します。ユーザーが端末設定またはアプリ内で許可した場合に限ります。\n\n【技術情報】端末 OS 種別・バージョン、アプリバージョン、IP アドレス、アクセス日時、ログ・エラー情報',
  ),
  _LegalSection(
    title: '3. 利用目的',
    body: '取得した情報は以下の目的で利用します。\n・本サービスの提供、維持、改善\n・ユーザー認証、アカウント管理\n・投稿・フィード・地図ピン・いいね・コメント・フォロー・友達等の各機能の提供\n・プッシュ通知（いいね、コメント、友達申請等）の送信\n・不正利用・迷惑行為・規約違反への対応\n・お問い合わせへの対応\n・本サービスに関する重要なお知らせの送信\n・利用状況の分析、機能改善、障害対応\n・法令に基づく対応',
  ),
  _LegalSection(
    title: '4. 外部サービス',
    body: '本サービスでは以下の外部サービスを利用しています。各提供者の利用規約・プライバシーポリシーに基づき情報が処理される場合があります。\n\n・Supabase（認証・データベース・ファイルストレージ）\n・Firebase Cloud Messaging（FCM）— プッシュ通知\n・Google Maps Platform — 地図表示・店舗候補検索\n・Apple（Sign in with Apple）— Apple ID 認証\n・LINE（LINE ログイン）— LINE アカウント認証',
  ),
  _LegalSection(
    title: '5. 第三者提供',
    body: '当社は、法令に基づく場合、ユーザー本人の同意がある場合、またはサービス提供に必要な委託先へ必要な範囲で提供する場合を除き、個人情報を第三者へ提供しません。\n\n投稿写真、コメント、一言、プロフィール、紐付けた店舗情報等は、サービス仕様またはユーザーの設定に応じて他のユーザーに表示される場合があります。',
  ),
  _LegalSection(
    title: '6. 情報の保存期間・削除',
    body: '当社は、利用目的の達成に必要な期間、ユーザー情報を保存します。会員は、本サービス内の機能または info@valiark.jp への連絡によりアカウント削除を申請できます。アカウント削除後も、法令遵守・不正利用防止・紛争対応等のため一定期間情報を保持する場合があります。',
  ),
  _LegalSection(
    title: '7. 安全管理措置',
    body: '当社は、ユーザー情報への不正アクセス、漏えい、滅失、毀損等を防止するため、必要かつ適切な安全管理措置を講じます。データベースへのアクセス制御（Row Level Security 等）、通信の暗号化（HTTPS）、アクセス権限の限定等を実施します。',
  ),
  _LegalSection(
    title: '8. 未成年の利用',
    body: '未成年のユーザーは、保護者の同意を得たうえで本サービスを利用してください。保護者の方からお問い合わせがあった場合、当社は合理的な範囲で対応します。',
  ),
  _LegalSection(
    title: '9. ユーザーの権利',
    body: 'ユーザーは、個人情報保護法その他の法令に基づき、自己の個人情報について、開示、訂正、追加、削除、利用停止等を求めることができます。ご請求は info@valiark.jp までご連絡ください。本人確認のうえ、合理的な期間内に対応します。',
  ),
  _LegalSection(
    title: '10. 本ポリシーの変更',
    body: '当社は、法令の改正、サービス内容の変更等に応じて、本ポリシーを変更することがあります。変更後のポリシーは、本サービス内または当社ウェブサイトへの掲示時点から効力を生じます。重要な変更については、合理的な方法で周知します。',
  ),
];
