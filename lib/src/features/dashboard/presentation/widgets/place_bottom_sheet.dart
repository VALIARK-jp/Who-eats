import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/app_entities.dart';
import '../../../../core/theme/app_theme.dart';
import 'friend_avatar.dart';
import 'friend_avatar_stack.dart';
import 'glass_panel.dart';
import 'segmented_tab.dart';

class PlaceBottomSheet extends StatefulWidget {
  const PlaceBottomSheet({
    super.key,
    required this.pin,
    required this.detailFuture,
    required this.scrollController,
    this.onPostTap,
    required this.onClose,
  });

  final MapPin pin;
  final Future<PlaceDetail> detailFuture;
  final ScrollController scrollController;

  final ValueChanged<PlacePostPreview>? onPostTap;
  final VoidCallback onClose;

  @override
  State<PlaceBottomSheet> createState() => _PlaceBottomSheetState();
}

class _PlaceBottomSheetState extends State<PlaceBottomSheet> {
  int _tab = 0; // 0: overview, 1: posts, 2: menu, 3: photos

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

  List<Widget> _buildContent(PlaceDetail detail) {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: detail.imageUrl.isEmpty
                ? Container(
                    width: 112,
                    height: 92,
                    color: AppColors.cardElevated,
                    alignment: Alignment.center,
                    child: const Icon(Icons.restaurant, size: 28),
                  )
                : Image.network(
                    detail.imageUrl,
                    width: 112,
                    height: 92,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 112,
                      height: 92,
                      color: AppColors.cardElevated,
                      alignment: Alignment.center,
                      child: const Icon(Icons.restaurant, size: 28),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        detail.placeName,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: widget.onClose,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '★ ${detail.rating.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: AppColors.orange,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if ((detail.address ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      detail.address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSubtle.withValues(alpha: 0.95),
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (detail.openNow != null)
                      Text(
                        detail.openNow! ? '営業中' : '営業時間外',
                        style: TextStyle(
                          color: detail.openNow! ? AppColors.orange : Colors.white70,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    if (detail.travelMinutes != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '徒歩 ${detail.travelMinutes}分',
                        style: TextStyle(
                          color: AppColors.textSubtle.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
                label: 'Google Maps',
                subLabel: 'で開く',
                onTap: () => _openGoogleMaps(detail),
              ),
            ),
            Expanded(
              child: _PlaceActionButton(
                icon: Icons.language,
                label: '店舗サイト',
                onTap: () => _openWebsite(detail),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SegmentedTab<int>(
        items: const [
          SegmentedTabItem(value: 0, label: '概要'),
          SegmentedTabItem(value: 1, label: '投稿'),
          SegmentedTabItem(value: 2, label: 'メニュー'),
          SegmentedTabItem(value: 3, label: '写真'),
        ],
        selected: _tab,
        onChanged: (v) => setState(() => _tab = v),
      ),
      const SizedBox(height: 12),
      if (_tab == 0) ..._buildOverview(detail),
      if (_tab == 1) ..._buildPosts(detail),
      if (_tab == 2) ..._buildMenu(),
      if (_tab == 3) ..._buildPhotos(detail),
      const SizedBox(height: 10),
    ];
  }

  List<Widget> _buildOverview(PlaceDetail detail) {
    return [
      Row(
        children: [
          const Text(
            '友達が行っています',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const Spacer(),
          Text(
            '${widget.pin.friendAvatars.length} 人',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w800),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: widget.pin.friendAvatars.isEmpty ? 1 : widget.pin.friendAvatars.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            if (widget.pin.friendAvatars.isEmpty) {
              return const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.cardElevated,
                child: Icon(Icons.person_outline),
              );
            }
            return FriendAvatar(
              displayName: widget.pin.friendAvatars[i],
              radius: 20,
            );
          },
        ),
      ),
      const SizedBox(height: 14),
      _PlaceInfoPanel(
        detail: detail,
        onOpenWebsite: () => _openWebsite(detail),
        onOpenGoogleMaps: () => _openGoogleMaps(detail),
      ),
      const SizedBox(height: 14),
      const Text('写真', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
      const SizedBox(height: 8),
      SizedBox(
        height: 86,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: (detail.posts.isNotEmpty ? detail.posts.length : 5).clamp(1, 6),
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final imageUrl =
                i < detail.posts.length ? (detail.posts[i].imageUrl ?? '') : '';
            if (imageUrl.isEmpty) {
              return Container(
                width: 108,
                decoration: BoxDecoration(
                  color: AppColors.cardElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.photo_outlined),
              );
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                width: 108,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 108,
                  decoration: BoxDecoration(
                    color: AppColors.cardElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.photo_outlined),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _buildPosts(PlaceDetail detail) {
    return [
      const Text('みんなの投稿', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
      const SizedBox(height: 8),
      if (detail.posts.isEmpty)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.blackElevated.withValues(alpha: 0.67),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Text('レビューはまだありません', style: TextStyle(fontWeight: FontWeight.w700)),
        )
      else
        ...detail.posts.map(
          (post) => InkWell(
            onTap: () => widget.onPostTap?.call(post),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.blackElevated.withValues(alpha: 0.67),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: post.imageUrl == null || post.imageUrl!.isEmpty
                        ? Container(
                            width: 56,
                            height: 56,
                            color: AppColors.cardElevated,
                            alignment: Alignment.center,
                            child: const Icon(Icons.photo_outlined, size: 18),
                          )
                        : Image.network(
                            post.imageUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 56,
                              height: 56,
                              color: AppColors.cardElevated,
                              alignment: Alignment.center,
                              child: const Icon(Icons.photo_outlined, size: 18),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              post.userName,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.orange.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
                              ),
                              child: const Text(
                                '外食',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.orangeHighlight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          post.comment,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textSubtle.withValues(alpha: 0.95)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 6),
      FriendAvatarStack(
        avatarDisplays: widget.pin.friendAvatars,
        maxVisible: 4,
        avatarRadius: 16,
      ),
    ];
  }

  List<Widget> _buildMenu() {
    return [
      const Text('メニュー', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
      const SizedBox(height: 8),
      _MenuCard(
        title: '名物',
        items: const ['名物プレート', '半熟卵のオムライス', '季節のデザート'],
      ),
      const SizedBox(height: 10),
      _MenuCard(
        title: 'ドリンク',
        items: const ['オレンジハイ', '炭酸水', 'アイスコーヒー'],
      ),
      const SizedBox(height: 10),
    ];
  }

  List<Widget> _buildPhotos(PlaceDetail detail) {
    final photoUrls = detail.posts
        .map((p) => p.imageUrl ?? '')
        .where((u) => u.isNotEmpty)
        .toList(growable: false);
    final padded = List<String>.from(photoUrls);
    if (padded.isEmpty) {
      padded.length = 5; // show empty slots
    }

    return [
      const Text('写真', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
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
                    errorBuilder: (_, __, ___) => Container(
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
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.title, required this.items});
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                item,
                style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
              ),
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
