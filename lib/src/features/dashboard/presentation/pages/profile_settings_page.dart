import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/supabase/profile_icon_service.dart';
import '../../../auth/application/auth_session.dart';
import '../controllers/app_shell_controller.dart';

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key, required this.controller});
  
  final AppShellController controller;

  Future<void> _editIcon(BuildContext context) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 86,
    );
    if (file == null) return;
    try {
      await ProfileIconService().uploadAndSaveProfileIcon(File(file.path));
      await controller.initialize();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('プロフィールアイコンを更新しました')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('アイコン更新に失敗しました: $e')));
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          if (AppConfig.hasSupabase && signedIn) ...[
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('プロフィールアイコンを編集'),
              onTap: () => _editIcon(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('ログアウト', style: TextStyle(color: Colors.red)),
              onTap: () => _confirmAndSignOutFromProfile(context),
            ),
          ],
          if (!AppConfig.hasSupabase || !signedIn)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('設定項目はありません。'),
            ),
        ],
      ),
    );
  }
}
