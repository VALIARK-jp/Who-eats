import 'package:flutter/material.dart';

import '../../domain/entities/app_entities.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/app_shell_controller.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orange_glow_button.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    required this.userId,
    required this.controller,
    required this.onClose,
  });

  final String userId;
  final AppShellController controller;
  final VoidCallback onClose;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  UserPublicProfile? _profile;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = await widget.controller.loadUserPublicProfile(widget.userId);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  Future<void> _follow() async {
    if (_busy || _profile == null) return;
    setState(() => _busy = true);
    try {
      final becameFriend = await widget.controller.followUser(widget.userId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            becameFriend ? '友達になりました' : '友達申請を送りました',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelRequest() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.controller.unfollowUser(widget.userId);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBlock() async {
    if (_busy || _profile == null) return;
    setState(() => _busy = true);
    try {
      if (_profile!.isBlocked) {
        await widget.controller.unblockUser(widget.userId);
      } else {
        await widget.controller.blockUser(widget.userId);
      }
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Material(
      color: AppColors.black.withValues(alpha: 0.96),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
                const Expanded(
                  child: Text(
                    'プロフィール',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (profile == null)
              const Expanded(
                child: Center(child: Text('プロフィールを読み込めませんでした')),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GlassPanel(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 20,
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.blackElevated,
                            backgroundImage: profile.avatarUrl.isNotEmpty
                                ? NetworkImage(profile.avatarUrl)
                                : null,
                            child: profile.avatarUrl.isEmpty
                                ? Text(
                                    profile.name.isNotEmpty
                                        ? profile.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            profile.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (profile.userCode.isNotEmpty)
                            Text(
                              profile.userCode,
                              style: TextStyle(color: AppColors.textSubtle),
                            ),
                          if (profile.bio.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(profile.bio, textAlign: TextAlign.center),
                          ],
                          const SizedBox(height: 16),
                          if (profile.isFriend)
                            const Chip(label: Text('友達'))
                          else if (profile.theyFollowMe)
                            OrangeGlowButton(
                              width: double.infinity,
                              height: 42,
                              isEnabled: !_busy,
                              onPressed: _follow,
                              child: const Text(
                                '申請を承認',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            )
                          else if (profile.iFollowThem)
                            OutlinedButton(
                              onPressed: _busy ? null : _cancelRequest,
                              child: const Text('申請を取り消す'),
                            )
                          else if (!profile.isBlocked)
                            OrangeGlowButton(
                              width: double.infinity,
                              height: 42,
                              isEnabled: !_busy,
                              onPressed: _follow,
                              child: const Text(
                                '友達申請',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _busy ? null : _toggleBlock,
                            child: Text(
                              profile.isBlocked ? 'ブロック解除' : 'ブロック',
                              style: TextStyle(
                                color: profile.isBlocked
                                    ? AppColors.orangeAccent
                                    : Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (profile.recentPosts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '最近の投稿',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: profile.recentPosts.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                            ),
                        itemBuilder: (_, i) {
                          final thumb = profile.recentPosts[i];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              thumb.imageUrl,
                              fit: BoxFit.cover,
                              height: 100,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
