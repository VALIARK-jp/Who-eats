import 'package:flutter/material.dart';

import '../../domain/entities/app_entities.dart';
import '../controllers/app_shell_controller.dart';
import '../widgets/food_post_card.dart';

class FavoritePostsPage extends StatefulWidget {
  const FavoritePostsPage({
    super.key,
    required this.controller,
    this.onOpenPost,
  });

  final AppShellController controller;
  final ValueChanged<FeedPost>? onOpenPost;

  @override
  State<FavoritePostsPage> createState() => _FavoritePostsPageState();
}

class _FavoritePostsPageState extends State<FavoritePostsPage> {
  List<FeedPost> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final posts = await widget.controller.loadFavoritePosts();
    if (!mounted) return;
    setState(() {
      _posts = posts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('お気に入りの投稿')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
          ? Center(
              child: Text(
                'お気に入りにした投稿はまだありません',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _posts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  final uid = widget.controller.currentUserId;
                  final isOwn =
                      uid != null && uid.isNotEmpty && post.userId == uid;
                  return FoodPostCard(
                    post: post,
                    currentUserId: uid,
                    onTap: widget.onOpenPost != null
                        ? () => widget.onOpenPost!(post)
                        : null,
                    onToggleFavorite: isOwn
                        ? null
                        : () async {
                            final updated = await widget.controller
                                .togglePostFavoriteForPost(post);
                            if (!mounted) return;
                            setState(() {
                              _posts = [
                                for (final p in _posts)
                                  if (p.id == post.id) updated else p,
                              ];
                            });
                          },
                  );
                },
              ),
            ),
    );
  }
}
