import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/user/user_code_format.dart';
import '../../../core/user/user_display_name_format.dart';
import '../../../core/supabase/profile_icon_service.dart';
import '../../../core/supabase/supabase_storage_urls.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/supabase/user_profile_sync.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/presentation/controllers/app_shell_controller.dart';
import '../application/profile_onboarding_store.dart';

/// 初回ログイン後のプロフィール入力（name / user_code が null のときのみ）。
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key, required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _nameController = TextEditingController();
  final _userCodeController = TextEditingController();
  final _bioController = TextEditingController();
  final _picker = ImagePicker();

  File? _pickedIcon;
  String? _remoteIconUrl;
  bool _submitting = false;
  String? _error;
  String? _userCodeError;

  static RegExp get _codeBody =>
      RegExp('^[A-Za-z0-9_]{1,${UserCodeFormat.maxBodyLength}}\$');

  bool get _canSubmit {
    final name = _nameController.text.trim();
    final codeBody = _userCodeController.text.trim();
    return name.isNotEmpty && _codeBody.hasMatch(codeBody);
  }

  @override
  void initState() {
    super.initState();
    void onRequiredFieldChanged() {
      if (mounted) {
        setState(() {
          _userCodeError = null;
          _error = null;
        });
      }
    }

    _nameController.addListener(onRequiredFieldChanged);
    _userCodeController.addListener(onRequiredFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareRow());
  }

  Future<void> _prepareRow() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await syncCurrentUserProfile();
      final row = await Supabase.instance.client
          .from(SupabaseTables.profiles)
          .select('bio, icon_path')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted || row == null) return;

      if (_bioController.text.isEmpty) {
        _bioController.text = row['bio'] as String? ?? '';
      }
      final icon = row['icon_path'] as String?;
      if (_pickedIcon == null && icon != null && icon.isNotEmpty) {
        final resolved = await SupabaseStorageUrls.resolveProfileIconUrl(
          Supabase.instance.client,
          icon,
        );
        if (!mounted) return;
        if (resolved != null && resolved.isNotEmpty) {
          setState(() => _remoteIconUrl = resolved);
        }
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
    if (user == null || !_canSubmit) return;

    final name = UserDisplayNameFormat.normalizeInput(_nameController.text);
    final codeBody = _userCodeController.text.trim();
    final bio = _bioController.text.trim();
    final userCode = UserCodeFormat.fromBody(codeBody);

    setState(() {
      _submitting = true;
      _error = null;
      _userCodeError = null;
    });

    try {
      if (!await _isUserCodeAvailable(userCode)) {
        setState(() {
          _submitting = false;
          _userCodeError = 'このユーザーコードは使われています';
        });
        return;
      }

      String? iconPath;
      if (_pickedIcon != null) {
        iconPath = await ProfileIconService().uploadProfileIcon(_pickedIcon!);
      }

      await saveWhoEatsProfileFields(
        userId: user.id,
        email: user.email ?? '',
        name: name,
        userCode: userCode,
        bio: bio,
        iconPath: iconPath,
      );

      await ProfileOnboardingStore.setCompleted(user.id);

      if (mounted) {
        try {
          await context.read<AppShellController>().refreshProfileOverview();
        } catch (_) {}
        await widget.onComplete();
      }
    } on PostgrestException catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ProfileSetupPage] PostgrestException: ${e.code} ${e.message}\n$st');
      }
      if (!mounted) return;
      if (e.code == '23505') {
        setState(() {
          _submitting = false;
          _userCodeError = 'このユーザーコードは使われています';
        });
        return;
      }
      setState(() {
        _submitting = false;
        _error = _profileSaveErrorMessage(e);
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ProfileSetupPage] save failed: $e\n$st');
      }
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = _profileSaveErrorMessage(e);
        });
      }
    }
  }

  String _profileSaveErrorMessage(Object e) {
    if (e is PostgrestException) {
      final msg = e.message.trim();
      if (msg.contains('invalid user_code')) {
        return 'ユーザーコードの形式が正しくありません';
      }
      if (msg.isNotEmpty) return msg;
    }
    final text = e.toString().replaceFirst('Exception: ', '');
    if (text.contains('プロフィールを保存できませんでした')) return text;
    return '保存に失敗しました。通信環境を確認してもう一度お試しください';
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
              'Who eats 用のユーザーネームとユーザーコードを設定してください。'
              '他の Valiark アプリのアカウントでログインした場合も、初回のみ必要です。',
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
              child: Text(
                'タップしてアイコンを選ぶ（任意）',
                style: TextStyle(color: AppColors.textSubtle),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              maxLength: UserDisplayNameFormat.maxLength,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: 'ユーザーネーム',
                helperText: '10文字以内・必須',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _userCodeController,
              maxLength: UserCodeFormat.maxBodyLength,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: 'ユーザーコード',
                prefixText: '@',
                helperText: '英数字と _ のみ（15文字以内・必須）',
                errorText: _userCodeError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: '自己紹介',
                helperText: '任意（160文字以内）',
              ),
              maxLines: 3,
              maxLength: 160,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _canSubmit && !_submitting ? _submit : null,
              child: Text(_submitting ? '保存中…' : '保存する'),
            ),
          ],
        ),
      ),
    );
  }
}
