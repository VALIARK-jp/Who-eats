import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/legal/legal_document_page.dart';
import '../../../../core/user/user_code_format.dart';
import '../../../../core/supabase/account_deletion_service.dart';
import '../../../../core/supabase/profile_icon_service.dart';
import '../../../../core/supabase/supabase_tables.dart';
import '../../../auth/application/auth_session.dart';
import '../../../auth/application/profile_onboarding_store.dart';
import '../../domain/entities/app_entities.dart';
import '../controllers/app_shell_controller.dart';
import 'favorite_posts_page.dart';

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({
    super.key,
    required this.controller,
    this.onOpenPostDetail,
    this.onOpenProfile,
  });

  final AppShellController controller;
  final ValueChanged<FeedPost>? onOpenPostDetail;
  final ValueChanged<String>? onOpenProfile;

  Future<void> _confirmAndDeleteAccount(BuildContext context) async {
    final firstOk = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('アカウントを削除'),
        content: const Text(
          'アカウントを削除すると、プロフィール・投稿・いいね・コメント・'
          'フォロー関係など、すべてのデータが完全に削除されます。\n\n'
          'この操作は取り消せません。本当に削除しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (firstOk != true || !context.mounted) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final secondOk = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('最終確認'),
        content: const Text(
          '削除を実行すると、すぐにログアウトされ、'
          '同じアカウントで再度ログインすることはできません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('完全に削除する'),
          ),
        ],
      ),
    );
    if (secondOk != true || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      await AccountDeletionService().deleteCurrentAccount();
      await ProfileOnboardingStore.clearForUser(uid);
      if (!context.mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('アカウントを削除しました')));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('アカウント削除に失敗しました: $e')));
    }
  }

  Future<void> _confirmAndSignOutFromProfile(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await signOutCurrentUser();
      if (context.mounted) {
        Navigator.of(context).pop(); // Go back to profile page
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ログアウトに失敗しました: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = Supabase.instance.client.auth.currentUser != null;

    if (!AppConfig.hasSupabase || !signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('設定')),
        body: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('設定項目はありません。'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        children: [
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton.tonal(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ProfileEditPage(controller: controller),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('プロフィールを編集', style: TextStyle(fontSize: 16)),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _FeedScopeSettingsSection(controller: controller),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton.tonal(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => FavoritePostsPage(
                      controller: controller,
                      onOpenProfile: onOpenProfile,
                      onOpenPost: onOpenPostDetail == null
                          ? null
                          : (post) {
                              Navigator.pop(ctx);
                              Navigator.pop(context);
                              onOpenPostDetail!(post);
                            },
                    ),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('お気に入りの投稿を見る', style: TextStyle(fontSize: 16)),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: const Text('利用規約'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const LegalDocumentPage(type: LegalDocumentType.terms),
                ),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const LegalDocumentPage(type: LegalDocumentType.privacy),
                ),
              );
            },
          ),
          const Divider(),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('ログアウト', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmAndSignOutFromProfile(context),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.delete_forever_outlined,
              color: Colors.red,
            ),
            title: const Text(
              'アカウントを削除',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('プロフィール・投稿などすべてのデータが完全に削除されます'),
            onTap: () => _confirmAndDeleteAccount(context),
          ),
        ],
      ),
    );
  }
}

class _FeedScopeSettingsSection extends StatefulWidget {
  const _FeedScopeSettingsSection({required this.controller});

  final AppShellController controller;

  @override
  State<_FeedScopeSettingsSection> createState() =>
      _FeedScopeSettingsSectionState();
}

class _FeedScopeSettingsSectionState extends State<_FeedScopeSettingsSection> {
  FeedTimelineScope? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.controller.loadFeedScopePreference();
    if (!mounted) return;
    setState(() {
      _selected = widget.controller.feedTimelineScope;
      _loading = false;
    });
  }

  Future<void> _onSelect(FeedTimelineScope scope) async {
    setState(() => _selected = scope);
    await widget.controller.setDefaultFeedTimelineScope(scope);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('ホームの初期表示を「${scope.label}」にしました')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _selected == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ホームの初期表示',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'タイムラインを開いたときのデフォルトです。画面上部のチップでもいつでも切り替えられます。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        RadioGroup<FeedTimelineScope>(
          groupValue: _selected,
          onChanged: (v) {
            if (v != null) _onSelect(v);
          },
          child: Column(
            children: [
              for (final scope in FeedTimelineScope.values)
                RadioListTile<FeedTimelineScope>(
                  value: scope,
                  title: Text(
                    scope.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(scope.description),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileEditPage extends StatefulWidget {
  const _ProfileEditPage({required this.controller});
  final AppShellController controller;

  @override
  State<_ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<_ProfileEditPage> {
  final _nameController = TextEditingController();
  final _userCodeController = TextEditingController();
  final _bioController = TextEditingController();
  String _defaultVisibility = 'friends';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.profileOverview;
    if (profile != null) {
      _nameController.text = profile.name;
      _userCodeController.text = UserCodeFormat.bodyFromStored(profile.userCode);
      _bioController.text = profile.bio;
      _defaultVisibility = _normalizeVisibility(profile.defaultVisibility);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _userCodeController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _editIcon() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 86,
    );
    if (file == null) return;
    try {
      await ProfileIconService().uploadAndSaveProfileIcon(File(file.path));
      await widget.controller.refreshProfileOverview();
      await widget.controller.invalidateMapPins();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('プロフィールアイコンを更新しました')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('アイコン更新に失敗しました: $e')));
    }
  }

  Future<void> _saveProfile() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      final codeBody = _userCodeController.text.trim();
      if (codeBody.isNotEmpty &&
          !UserCodeFormat.bodyPattern.hasMatch(
            codeBody.startsWith('@') ? codeBody.substring(1) : codeBody,
          )) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ユーザーコードは英数字と _ のみ使えます')),
        );
        setState(() => _isSaving = false);
        return;
      }
      final userCode = codeBody.isEmpty
          ? ''
          : UserCodeFormat.fromBody(
              codeBody.startsWith('@') ? codeBody.substring(1) : codeBody,
            );

      await Supabase.instance.client
          .from(SupabaseTables.profiles)
          .update({
            'name': _nameController.text.trim(),
            if (userCode.isNotEmpty) 'user_code': userCode,
            'bio': _bioController.text.trim(),
            'default_visibility': _defaultVisibility,
          })
          .eq('id', uid);

      await widget.controller.refreshProfileOverview();
      await widget.controller.invalidateMapPins();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('プロフィールを更新しました')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('プロフィールの更新に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _normalizeVisibility(String value) {
    return switch (value.trim()) {
      'public' => 'public',
      'private' => 'private',
      'friends' => 'friends',
      _ => 'friends',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プロフィールを編集')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_circle, size: 40),
            title: const Text('プロフィールアイコンを編集'),
            onTap: _editIcon,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'ユーザーネーム',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _userCodeController,
            maxLength: UserCodeFormat.maxBodyLength,
            decoration: const InputDecoration(
              labelText: 'ユーザーID',
              prefixText: '@',
              helperText: '英数字と _ のみ（15文字以内）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            decoration: const InputDecoration(
              labelText: '自己紹介',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          const Text(
            '投稿のデフォルト公開範囲',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'public', label: Text('全体公開')),
              ButtonSegment(value: 'friends', label: Text('友達のみ')),
              ButtonSegment(value: 'private', label: Text('自分のみ')),
            ],
            selected: {_defaultVisibility},
            onSelectionChanged: _isSaving
                ? null
                : (s) => setState(() {
                    _defaultVisibility = _normalizeVisibility(s.first);
                  }),
          ),
          const SizedBox(height: 8),
          Text(switch (_defaultVisibility) {
            'public' => '新しい投稿は全体公開で作成されます。',
            'friends' => '新しい投稿は友達のみ公開で作成されます。',
            'private' => '新しい投稿は自分のみ公開で作成されます。',
            _ => '',
          }, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('保存する'),
          ),
        ],
      ),
    );
  }
}
