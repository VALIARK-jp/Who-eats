import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/app_entities.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/app_shell_controller.dart';
import 'glass_panel.dart';
import 'segmented_tab.dart';

class PlaceBottomSheet extends StatefulWidget {
  const PlaceBottomSheet({
    super.key,
    required this.pin,
    required this.controller,
    required this.detailFuture,
    required this.scrollController,
    this.onPostTap,
    required this.onClose,
  });

  final MapPin pin;
  final AppShellController controller;
  final Future<PlaceDetail> detailFuture;
  final ScrollController scrollController;

  final ValueChanged<PlacePostPreview>? onPostTap;
  final VoidCallback onClose;

  @override
  State<PlaceBottomSheet> createState() => _PlaceBottomSheetState();
}

class _PlaceBottomSheetState extends State<PlaceBottomSheet> {
  int _tab = 0; // 0: posts, 1: photos, 2: place info
  final Set<String> _followSubmitting = {};

  Future<void> _callPlace(PlaceDetail detail) async {
    final raw = (detail.phoneNumber ?? '').trim();
    if (raw.isEmpty) {
      _showSnack('電話番号がありません');
      return;
    }
    final sanitized = raw.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: sanitized);
    final ok = await launchUrl(uri);
    if (!ok && mounted) _showSnack('電話アプリを開けませんでした');
  }

  Future<void> _openGoogleMaps(PlaceDetail detail) async {
    Uri uri;
    final googleMapsUrl = (detail.googleMapsUrl ?? '').trim();
    final directUri = Uri.tryParse(googleMapsUrl);
    if (directUri != null && directUri.hasScheme) {
      uri = directUri;
    } else if (detail.latitude != null && detail.longitude != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${detail.latitude},${detail.longitude}',
      );
    } else {
      final params = <String, String>{
        'api': '1',
        'query': detail.placeName,
        if (detail.placeId.isNotEmpty) 'query_place_id': detail.placeId,
      };
      uri = Uri.https('www.google.com', '/maps/search/', params);
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _showSnack('Google Mapsを開けませんでした');
  }

  Future<void> _openWebsite(PlaceDetail detail) async {
    final raw = ((detail.websiteUrl ?? '').trim().isNotEmpty
            ? detail.websiteUrl
            : detail.googleMapsUrl)
        ?.trim() ??
        '';
    final uri = Uri.tryParse(raw);
    if (raw.isEmpty || uri == null || !uri.hasScheme) {
      _showSnack('店舗サイトが見つかりません');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _showSnack('店舗サイトを開けませんでした');
  }

  Future<void> _openWalkingDirections(PlaceDetail detail) async {
    Uri uri;
    if (detail.latitude != null && detail.longitude != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${detail.latitude},${detail.longitude}&travelmode=walking',
      );
    } else {
      uri = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': detail.placeName,
        'travelmode': 'walking',
      });
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _showSnack('経路を開けませんでした');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.blackElevated.withValues(alpha: 0.93),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: FutureBuilder<PlaceDetail>(
        future: widget.detailFuture,
        builder: (context, snapshot) {
          final detail = snapshot.data;
          final hasError = snapshot.hasError;
          return ListView(
            controller: widget.scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (hasError)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('店舗詳細の取得に失敗しました')),
                )
              else if (detail == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ..._buildContent(detail),
            ],
          );
        },
      ),
    );
  }

  List<PlaceVisitor> _visitorsFor(PlaceDetail detail) {
    if (detail.visitors.isNotEmpty) return detail.visitors;
    return widget.pin.visitors;
  }

  Future<void> _followVisitor(PlaceVisitor visitor) async {
    if (visitor.isMe || visitor.isFriend) return;
    setState(() => _followSubmitting.add(visitor.userId));
    try {
      final becameFriend = await widget.controller.followUser(visitor.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            becameFriend ? '友達になりました' : '友達申請を送りました',
          ),
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('友達申請に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _followSubmitting.remove(visitor.userId));
      }
    }
  }

  List<Widget> _buildContent(PlaceDetail detail) {
    final postImages = _postImageUrls(detail);
    final heroImageUrl = postImages.isNotEmpty
        ? postImages.first
        : detail.imageUrl.trim();
    final leadPost = detail.posts.isNotEmpty ? detail.posts.first : null;
    final visitors = _visitorsFor(detail);

    return [
      Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
                  aspectRatio: 1.45,
                  child: heroImageUrl.isEmpty
                      ? Container(
                          color: AppColors.cardElevated,
                          alignment: Alignment.center,
                      child: const Icon(Icons.restaurant, size: 34),
                    )
                  : Image.network(
                      heroImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.cardElevated,
                        alignment: Alignment.center,
                        child: const Icon(Icons.restaurant, size: 34),
                      ),
                    ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.76),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: widget.onClose,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.46),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.placeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.02,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (visitors.isNotEmpty)
                      _PlaceStatPill(
                        icon: Icons.people_alt_outlined,
                        label: '${visitors.length}人が訪問',
                      ),
                    if (detail.posts.isNotEmpty)
                      _PlaceStatPill(
                        icon: Icons.auto_awesome,
                        label: '${detail.posts.length}件見られる投稿',
                      ),
                    if (detail.travelMinutes != null)
                      _PlaceStatPill(
                        icon: Icons.directions_walk,
                        label: '徒歩 ${detail.travelMinutes}分',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (leadPost != null)
        GlassPanel(
          padding: const EdgeInsets.all(12),
          borderRadius: 18,
          child: InkWell(
            onTap: () => widget.onPostTap?.call(leadPost),
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 17,
                      color: AppColors.orangeHighlight,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '${leadPost.userName} の投稿',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.orangeHighlight,
                      ),
                    ),
                  ],
                ),
                if (leadPost.comment.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    leadPost.comment,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        )
      else if (visitors.isEmpty)
        GlassPanel(
          padding: const EdgeInsets.all(14),
          borderRadius: 18,
          child: const Text(
            'このお店の投稿はまだありません。最初の投稿を作るとここに表示されます。',
            style: TextStyle(fontWeight: FontWeight.w800, height: 1.35),
          ),
        ),
      if (visitors.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text(
          '訪問した人',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        ...visitors.map(_buildVisitorRow),
      ],
      const SizedBox(height: 14),
      Container(
        decoration: BoxDecoration(
          color: AppColors.blackElevated.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border2),
        ),
        child: Row(
          children: [
            Expanded(
              child: _PlaceActionButton(
                icon: Icons.call_outlined,
                label: '電話',
                onTap: () => _callPlace(detail),
              ),
            ),
            Expanded(
              child: _PlaceActionButton(
                icon: Icons.directions_walk,
                label: '経路',
                subLabel: '徒歩',
                onTap: () => _openWalkingDirections(detail),
              ),
            ),
            Expanded(
              child: _PlaceActionButton(
                icon: Icons.map_outlined,
                label: '地図',
                subLabel: 'で見る',
                onTap: () => _openGoogleMaps(detail),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SegmentedTab<int>(
        items: const [
          SegmentedTabItem(value: 0, label: '投稿'),
          SegmentedTabItem(value: 1, label: '写真'),
          SegmentedTabItem(value: 2, label: '店舗情報'),
        ],
        selected: _tab,
        onChanged: (v) => setState(() => _tab = v),
      ),
      const SizedBox(height: 12),
      if (_tab == 0) ..._buildPosts(detail),
      if (_tab == 1) ..._buildPhotos(detail),
      if (_tab == 2) ..._buildPlaceInfo(detail),
      const SizedBox(height: 10),
    ];
  }

  Widget _buildVisitorRow(PlaceVisitor visitor) {
    final social = widget.controller.socialStateForUser(visitor.userId);
    final isFriend = visitor.isFriend || (social?.isFriend ?? false);
    final isMe = visitor.isMe;
    final canFollow = !isMe && !isFriend && (social?.canFollow ?? true);
    final pending = social?.iFollowThem ?? false;
    final submitting = _followSubmitting.contains(visitor.userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.blackElevated.withValues(alpha: 0.67),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.gray,
            child: Text(
              visitor.userName.isNotEmpty
                  ? visitor.userName.characters.first.toUpperCase()
                  : '?',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visitor.userName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  isMe
                      ? 'あなた'
                      : isFriend
                      ? '友達'
                      : '友達以外（投稿は非公開）',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          if (canFollow)
            FilledButton.tonal(
              onPressed: submitting ? null : () => _followVisitor(visitor),
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('友達申請'),
            )
          else if (pending)
            const Text('申請中', style: TextStyle(color: Colors.white54))
          else if (isFriend)
            const Text('友達', style: TextStyle(color: AppColors.orangeHighlight)),
        ],
      ),
    );
  }

  List<Widget> _buildPosts(PlaceDetail detail) {
    final visitors = _visitorsFor(detail);
    final hiddenVisitorCount = visitors.where((v) => !v.isMe && !v.isFriend).length;

    return [
      Text(
        detail.posts.isEmpty ? 'この店の投稿' : 'この店の投稿 ${detail.posts.length}件',
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
      ),
      const SizedBox(height: 8),
      if (detail.posts.isEmpty)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.blackElevated.withValues(alpha: 0.67),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            hiddenVisitorCount > 0
                ? '友達以外の人も訪問していますが、投稿は友達のみ表示されます。'
                : 'まだ見られる投稿がありません',
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
          ),
        )
      else
        ...detail.posts.map(
          (post) => InkWell(
            onTap: () => widget.onPostTap?.call(post),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.blackElevated.withValues(alpha: 0.67),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: post.imageUrl == null || post.imageUrl!.isEmpty
                            ? Container(
                                width: 82,
                                height: 82,
                                color: AppColors.cardElevated,
                                alignment: Alignment.center,
                                child: const Icon(Icons.photo_outlined, size: 22),
                              )
                            : Image.network(
                                post.imageUrl!,
                                width: 82,
                                height: 82,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 82,
                                  height: 82,
                                  color: AppColors.cardElevated,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.photo_outlined, size: 22),
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              post.comment.trim().isEmpty ? '一言なし' : post.comment,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: post.comment.trim().isEmpty
                                    ? AppColors.textSubtle.withValues(alpha: 0.72)
                                    : AppColors.white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w700,
                                height: 1.32,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.restaurant_menu,
                        size: 15,
                        color: AppColors.orangeHighlight,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'この店での投稿',
                        style: TextStyle(
                          color: AppColors.textSubtle.withValues(alpha: 0.86),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right, color: Colors.white54),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 6),
      if (visitors.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          '訪問した人',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        const SizedBox(height: 6),
        ...visitors.map(_buildVisitorRow),
      ],
    ];
  }

  List<Widget> _buildPlaceInfo(PlaceDetail detail) {
    return [
      _PlaceInfoPanel(
        detail: detail,
        onOpenWebsite: () => _openWebsite(detail),
        onOpenGoogleMaps: () => _openGoogleMaps(detail),
      ),
    ];
  }

  List<Widget> _buildPhotos(PlaceDetail detail) {
    final photoUrls = _postImageUrls(detail);
    final padded = List<String>.from(photoUrls);
    if (padded.isEmpty) {
      padded.length = 3;
    }

    return [
      Text(
        photoUrls.isEmpty ? '投稿写真' : '投稿写真 ${photoUrls.length}枚',
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
      ),
      const SizedBox(height: 8),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: padded.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemBuilder: (_, i) {
          final url = padded[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: url.isEmpty
                ? Container(
                    color: AppColors.cardElevated,
                    alignment: Alignment.center,
                    child: const Icon(Icons.photo_outlined),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.cardElevated,
                      alignment: Alignment.center,
                      child: const Icon(Icons.photo_outlined),
                    ),
                  ),
          );
        },
      ),
      const SizedBox(height: 12),
    ];
  }

  List<String> _postImageUrls(PlaceDetail detail) {
    return detail.posts
        .map((p) => p.imageUrl ?? '')
        .where((u) => u.isNotEmpty)
        .toList(growable: false);
  }
}

class _PlaceStatPill extends StatelessWidget {
  const _PlaceStatPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.orangeHighlight),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _PlaceInfoPanel extends StatelessWidget {
  const _PlaceInfoPanel({
    required this.detail,
    required this.onOpenWebsite,
    required this.onOpenGoogleMaps,
  });

  final PlaceDetail detail;
  final VoidCallback onOpenWebsite;
  final VoidCallback onOpenGoogleMaps;

  @override
  Widget build(BuildContext context) {
    final websiteHost = _hostLabel(detail.websiteUrl);
    final openLabel = detail.openNow == null
        ? null
        : detail.openNow!
            ? '営業中'
            : '営業時間外';

    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('店舗情報', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 12),
          if ((detail.address ?? '').isNotEmpty)
            _InfoLine(icon: Icons.place_outlined, text: detail.address!),
          if ((detail.phoneNumber ?? '').isNotEmpty)
            _InfoLine(icon: Icons.call_outlined, text: detail.phoneNumber!),
          if (openLabel != null)
            _InfoLine(
              icon: Icons.schedule,
              text: openLabel,
              color: detail.openNow! ? AppColors.orangeHighlight : Colors.white70,
            ),
          if (websiteHost != null)
            _InfoLine(icon: Icons.language, text: websiteHost),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenWebsite,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('店舗サイト'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenGoogleMaps,
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('地図で見る'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _hostLabel(String? raw) {
    final uri = Uri.tryParse((raw ?? '').trim());
    final host = uri?.host;
    if (host == null || host.isEmpty) return null;
    return host.startsWith('www.') ? host.substring(4) : host;
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color ?? AppColors.textSubtle),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color ?? AppColors.white.withValues(alpha: 0.86),
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceActionButton extends StatelessWidget {
  const _PlaceActionButton({
    required this.icon,
    required this.label,
    this.subLabel,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.orange),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subLabel != null && subLabel!.isNotEmpty)
              Text(
                subLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textSubtle),
              ),
          ],
        ),
      ),
    );
  }
}
