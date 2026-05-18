import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/profile_icon_service.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/presentation/controllers/app_shell_controller.dart';
import '../application/auth_service.dart';
import '../application/profile_onboarding_store.dart';

/// 初回ログイン後のプロフィール入力（[whoeats_users] が正本）。
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _auth = AuthService();
  final _nameController = TextEditingController();
  final _userCodeController = TextEditingController();
  final _bioController = TextEditingController();
  final _picker = ImagePicker();

  File? _pickedIcon;
  String? _remoteIconUrl;
  bool _submitting = false;
  String? _error;

  static final _codeBody = RegExp(r'^[A-Za-z0-9_]{1,29}$');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  Future<void> _prefill() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Supabase.instance.client.auth.refreshSession();
    final refreshed = Supabase.instance.client.auth.currentUser ?? user;
    final metadata = refreshed.userMetadata ?? const <String, dynamic>{};
    final provider = refreshed.appMetadata['provider'] as String? ?? 'email';
    final isLine = provider == 'line';

    final displayName = metadata['displayName'] as String? ??
        metadata['name'] as String? ??
        '';
    if (displayName.isNotEmpty) _nameController.text = displayName;

    final photo = metadata['photoURL'] as String?;
    if (isLine && photo != null && photo.isNotEmpty) {
      setState(() => _remoteIconUrl = photo);
    }

    try {
      await _auth.ensureUserProfileRow();
      final row = await Supabase.instance.client
          .from(SupabaseTables.profiles)
          .select('user_code, name, bio, icon_path')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted || row == null) return;
      if (_nameController.text.isEmpty) {
        _nameController.text = row['name'] as String? ?? '';
      }
      final code = row['user_code'] as String? ?? '';
      if (_userCodeController.text.isEmpty && code.isNotEmpty) {
        _userCodeController.text = code.startsWith('@') ? code.substring(1) : code;
      }
      if (_bioController.text.isEmpty) {
        _bioController.text = row['bio'] as String? ?? '';
      }
      final icon = row['icon_path'] as String?;
      if (_pickedIcon == null && icon != null && icon.isNotEmpty) {
        setState(() => _remoteIconUrl ??= icon);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _userCodeController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    setState(() {
      _pickedIcon = File(file.path);
      _remoteIconUrl = null;
    });
  }

  Future<bool> _isUserCodeAvailable(String codeWithAt) async {
    final row = await Supabase.instance.client
        .from(SupabaseTables.profiles)
        .select('id')
        .eq('user_code', codeWithAt)
        .maybeSingle();
    if (row == null) return true;
    return row['id'] == Supabase.instance.client.auth.currentUser?.id;
  }

  Future<void> _submit() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final name = _nameController.text.trim();
    final codeBody = _userCodeController.text.trim();
    final bio = _bioController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = '名前を入力してください');
      return;
    }
    if (!_codeBody.hasMatch(codeBody)) {
      setState(() => _error = 'ユーザーコードは英数字と_のみ（@は自動で付きます）');
      return;
    }
    final userCode = '@$codeBody';

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (!await _isUserCodeAvailable(userCode)) {
        setState(() {
          _submitting = false;
          _error = 'このユーザーコードは既に使われています';
        });
        return;
      }

      String? iconPath = _remoteIconUrl;
      if (_pickedIcon != null) {
        iconPath = await ProfileIconService().uploadAndSaveProfileIcon(_pickedIcon!);
      }

      await Supabase.instance.client.from(SupabaseTables.profiles).update({
        'name': name,
        'user_code': userCode,
        'bio': bio.isEmpty ? null : bio,
        if (iconPath != null) 'icon_path': iconPath,
      }).eq('id', user.id);

      await ProfileOnboardingStore.setCompleted(user.id);

      if (mounted) {
        try {
          await context.read<AppShellController>().initialize();
        } catch (_) {}
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = '保存に失敗しました。もう一度お試しください';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'プロフィールをつくろう',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'ホームの地図はこのまま使えます。投稿・友達などはプロフィール登録後に解放されます。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSubtle,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: _submitting ? null : _pickIcon,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.cardElevated,
                  backgroundImage: _pickedIcon != null
                      ? FileImage(_pickedIcon!)
                      : (_remoteIconUrl != null
                            ? NetworkImage(_remoteIconUrl!)
                            : null),
                  child: _pickedIcon == null && _remoteIconUrl == null
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('タップしてアイコンを選ぶ', style: TextStyle(color: AppColors.textSubtle)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '名前'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _userCodeController,
              decoration: const InputDecoration(
                labelText: 'ユーザーコード',
                prefixText: '@',
                helperText: '英数字と _ のみ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(labelText: '一言'),
              maxLines: 3,
              maxLength: 160,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? '保存中…' : 'はじめる'),
            ),
          ],
        ),
      ),
    );
  }
}
