import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/supabase/profile_icon_service.dart';
import '../../../../core/supabase/supabase_tables.dart';
import '../../../auth/application/auth_session.dart';
import '../controllers/app_shell_controller.dart';
import '../widgets/profile_food_grid.dart';

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key, required this.controller});
  
  final AppShellController controller;

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
          SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton.tonal(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _FavoriteImagesEditPage(controller: controller),
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
                  Text('お気に入り画像を編集', style: TextStyle(fontSize: 16)),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
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

class _FavoriteImagesEditPage extends StatelessWidget {
  const _FavoriteImagesEditPage({required this.controller});
  final AppShellController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('お気に入り画像を編集'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'ピン留めする画像を設定します。',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('プロフィール画面のトップに表示されるお気に入りの画像を選択してください。'),
          const SizedBox(height: 16),
          if (controller.profileOverview?.pinnedShots != null &&
              controller.profileOverview!.pinnedShots.isNotEmpty)
            ProfileFoodGrid(
              urls: controller.profileOverview!.pinnedShots,
            )
          else
            Container(
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('ピン留めされた画像はありません'),
            ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('画像選択機能は現在開発中です')),
              );
            },
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('画像を選択・変更する'),
          ),
        ],
      ),
    );
  }
}
