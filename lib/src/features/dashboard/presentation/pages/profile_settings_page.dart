import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/legal/legal_document_page.dart';
import '../../../../core/supabase/profile_icon_service.dart';
import '../../../../core/supabase/supabase_tables.dart';
import '../../../auth/application/auth_session.dart';
import '../../domain/entities/app_entities.dart';
import '../controllers/app_shell_controller.dart';
import 'favorite_posts_page.dart';

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({
    super.key,
    required this.controller,
    this.onOpenPostDetail,
  });

  final AppShellController controller;
  final ValueChanged<FeedPost>? onOpenPostDetail;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ログアウトに失敗しました: $e')),
      );
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
      appBar: AppBar(
        title: const Text('設定'),
      ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ホームの初期表示を「${scope.label}」にしました')),
    );
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.profileOverview;
    if (profile != null) {
      _nameController.text = profile.name;
      _userCodeController.text = profile.userCode;
      _bioController.text = profile.bio;
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
      await widget.controller.initialize();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロフィールアイコンを更新しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('アイコン更新に失敗しました: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.from(SupabaseTables.profiles).update({
        'name': _nameController.text.trim(),
        'user_code': _userCodeController.text.trim(),
        'bio': _bioController.text.trim(),
      }).eq('id', uid);

      await widget.controller.initialize();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロフィールを更新しました')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('プロフィールの更新に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィールを編集'),
      ),
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
            decoration: const InputDecoration(
              labelText: 'ユーザーID (例: @ryota)',
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
