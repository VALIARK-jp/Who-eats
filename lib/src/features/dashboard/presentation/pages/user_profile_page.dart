import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/user/user_code_format.dart';
import '../../domain/entities/app_entities.dart';
import '../controllers/app_shell_controller.dart';
import '../widgets/friend_avatar.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orange_glow_button.dart';
import '../widgets/report_reason_sheet.dart';
import '../widgets/segmented_tab.dart';

enum _ProfileGallerySection { pinned, recent }

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
  _ProfileGallerySection _gallerySection = _ProfileGallerySection.pinned;

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
      _gallerySection = profile?.pinnedPosts.isNotEmpty == true
          ? _ProfileGallerySection.pinned
          : _ProfileGallerySection.recent;
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

  Future<void> _reportUser() async {
    final profile = _profile;
    if (_busy || profile == null) return;
    final reason = await showReportReasonSheet(
      context,
      targetLabel: profile.name,
    );
    if (reason == null || reason.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.controller.reportUser(widget.userId, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('通報を送信しました')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildGalleryGrid(List<ProfilePostThumb> thumbs) {
    if (thumbs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.blackElevated.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border2),
        ),
        child: Text(
          'まだ表示できる投稿がありません',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: thumbs.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemBuilder: (_, i) {
        final thumb = thumbs[i];
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            thumb.imageUrl,
            fit: BoxFit.cover,
            height: 100,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final isSelf =
        widget.controller.currentUserId != null &&
        widget.controller.currentUserId == widget.userId;
    final visiblePosts = profile == null
        ? const <ProfilePostThumb>[]
        : _gallerySection == _ProfileGallerySection.pinned
        ? profile.pinnedPosts
        : profile.recentPosts;

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
                          FriendAvatar(
                            displayName: profile.name,
                            avatarUrl: FriendAvatar.networkUrl(profile.avatarUrl),
                            radius: 40,
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
                              UserCodeFormat.display(profile.userCode),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppColors.textSubtle),
                            ),
                          if (profile.bio.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(profile.bio, textAlign: TextAlign.center),
                          ],
                          const SizedBox(height: 16),
                          if (!isSelf) ...[
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
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _busy ? null : _reportUser,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(
                                    color: Colors.redAccent,
                                  ),
                                ),
                                child: const Text('この人を通報する'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          if (!isSelf)
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
                    const SizedBox(height: 16),
                    SegmentedTab<_ProfileGallerySection>(
                      items: const [
                        SegmentedTabItem(
                          value: _ProfileGallerySection.pinned,
                          label: 'ピン留め',
                        ),
                        SegmentedTabItem(
                          value: _ProfileGallerySection.recent,
                          label: '投稿',
                        ),
                      ],
                      selected: _gallerySection,
                      onChanged: (value) {
                        setState(() => _gallerySection = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildGalleryGrid(visiblePosts),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
