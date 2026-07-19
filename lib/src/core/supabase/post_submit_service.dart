import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../map/municipality_resolver.dart';
import '../push/push_notification_service.dart';
import 'supabase_tables.dart';

/// Creates a post row, uploads one image to `post-images`, and links `post_images`.
class PostSubmitService {
  PostSubmitService({SupabaseClient? client, MunicipalityResolver? municipalityResolver})
    : _client = client ?? Supabase.instance.client,
      _municipalityResolver = municipalityResolver ?? MunicipalityResolver();

  final SupabaseClient _client;
  final MunicipalityResolver _municipalityResolver;

  static const _bucket = 'post-images';

  /// Returns new `posts.id`.
  Future<String> submitPhotoPost({
    required File imageFile,
    required String postType,
    required String visibility,
    String? restaurantPlaceGoogleId,
    String? restaurantPlaceName,
    double? restaurantPlaceLatitude,
    double? restaurantPlaceLongitude,
    String? caption,
    int? rating,
    int? priceYen,
    String? mealGroupId,
    List<String> companionUserIds = const [],
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Not signed in');
    }

    final placeId = postType == 'restaurant'
        ? await _resolveOrCreatePlaceId(
            googlePlaceId: restaurantPlaceGoogleId,
            placeName: restaurantPlaceName,
            latitude: restaurantPlaceLatitude,
            longitude: restaurantPlaceLongitude,
          )
        : null;

    final resolvedMealGroupId = mealGroupId?.isNotEmpty == true
        ? mealGroupId
        : (companionUserIds.isNotEmpty
              ? await _client.rpc('new_meal_group_id') as String?
              : null);

    final storagePath =
        '$uid/${DateTime.now().millisecondsSinceEpoch}_${imageFile.uri.pathSegments.isNotEmpty ? imageFile.uri.pathSegments.last : 'photo.jpg'}';

    final ext = storagePath.toLowerCase();
    final contentType = ext.endsWith('.png')
        ? 'image/png'
        : ext.endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';

    await _client.storage.from(_bucket).upload(
      storagePath,
      imageFile,
      fileOptions: FileOptions(contentType: contentType, upsert: false),
    );

    try {
      final insertPayload = <String, dynamic>{
        'user_id': uid,
        'place_id': placeId,
        'post_type': postType,
        'visibility': visibility,
        'caption': caption,
      };
      if (rating != null && rating >= 1 && rating <= 5) {
        insertPayload['rating'] = rating;
      }
      if (priceYen != null && priceYen >= 0) {
        insertPayload['price_yen'] = priceYen;
      }
      if (resolvedMealGroupId != null && resolvedMealGroupId.isNotEmpty) {
        insertPayload['meal_group_id'] = resolvedMealGroupId;
      }

      final postRow = await _client
          .from(SupabaseTables.posts)
          .insert(insertPayload)
          .select('id')
          .single();

      final postId = postRow['id'] as String;

      await _client.from(SupabaseTables.postImages).insert({
        'post_id': postId,
        'storage_path': storagePath,
        'display_order': 0,
      });

      for (final companionId in companionUserIds) {
        if (companionId.isEmpty || companionId == uid) continue;
        try {
          await _client.from(SupabaseTables.postCompanions).insert({
            'post_id': postId,
            'user_id': companionId,
          });
          unawaited(
            _notifyCompanionTagged(
              companionUserId: companionId,
              postId: postId,
            ),
          );
        } on PostgrestException catch (e) {
          if (e.code != '23505') rethrow;
        }
      }

      if (resolvedMealGroupId != null && resolvedMealGroupId.isNotEmpty) {
        final groupPosts = await _client
            .from(SupabaseTables.posts)
            .select('id')
            .eq('meal_group_id', resolvedMealGroupId);
        for (final raw in (groupPosts as List<dynamic>)) {
          final sourcePostId = (raw as Map<String, dynamic>)['id'].toString();
          if (sourcePostId == postId) continue;
          try {
            await _client
                .from(SupabaseTables.postCompanions)
                .update({'joined_post_id': postId})
                .eq('post_id', sourcePostId)
                .eq('user_id', uid);
          } catch (_) {}
        }
      }

      try {
        await _client.rpc('bump_user_streak_on_post');
      } catch (_) {}

      return postId;
    } catch (e) {
      try {
        await _client.storage.from(_bucket).remove([storagePath]);
      } catch (_) {}
      rethrow;
    }
  }

  Future<String> _resolveOrCreatePlaceId({
    required String? googlePlaceId,
    required String? placeName,
    required double? latitude,
    required double? longitude,
  }) async {
    if (googlePlaceId == null || googlePlaceId.isEmpty) {
      throw StateError('restaurant post requires google place id');
    }
    if (placeName == null || placeName.isEmpty || latitude == null || longitude == null) {
      throw StateError('restaurant post requires place metadata');
    }

    final existing = await _client
        .from(SupabaseTables.places)
        .select('id')
        .eq('google_place_id', googlePlaceId)
        .maybeSingle();
    if (existing != null && existing['id'] != null) {
      await _syncPlaceMunicipalityIfNeeded(
        placeId: existing['id'] as String,
        latitude: latitude,
        longitude: longitude,
      );
      return existing['id'] as String;
    }

    final municipality = await _municipalityResolver.resolve(
      latitude: latitude,
      longitude: longitude,
    );

    try {
      final inserted = await _client
          .from(SupabaseTables.places)
          .insert({
            'google_place_id': googlePlaceId,
            'name': placeName,
            'latitude': latitude,
            'longitude': longitude,
            'source': 'google',
            if (municipality != null) ...{
              'prefecture_code': municipality.prefectureCode,
              'city_code': municipality.cityCode,
              'city_name': municipality.cityName,
            },
          })
          .select('id')
          .single();
      return inserted['id'] as String;
    } on PostgrestException {
      final raced = await _client
          .from(SupabaseTables.places)
          .select('id')
          .eq('google_place_id', googlePlaceId)
          .single();
      await _syncPlaceMunicipalityIfNeeded(
        placeId: raced['id'] as String,
        latitude: latitude,
        longitude: longitude,
      );
      return raced['id'] as String;
    }
  }

  Future<void> _notifyCompanionTagged({
    required String companionUserId,
    required String postId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    var actorName = 'ユーザー';
    try {
      final actorRow = await _client
          .from(SupabaseTables.profiles)
          .select('name, user_code')
          .eq('id', uid)
          .maybeSingle();
      final name = (actorRow?['name'] ?? '').toString().trim();
      final code = (actorRow?['user_code'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        actorName = name;
      } else if (code.isNotEmpty) {
        actorName = code;
      }
    } catch (_) {}

    try {
      await _client.rpc(
        'insert_whoeats_notification',
        params: {
          'p_recipient_user_id': companionUserId,
          'p_actor_user_id': uid,
          'p_event_type': 'meal_tag',
          'p_title': '一緒の食事の記録',
          'p_body': '$actorName さんがあなたを一緒の食事に追加しました',
          'p_post_id': postId,
        },
      );
    } catch (_) {}

    try {
      await PushNotificationService.instance.sendEvent(
        targetUserId: companionUserId,
        eventType: 'meal_tag',
        postId: postId,
      );
    } catch (_) {}
  }

  Future<void> _syncPlaceMunicipalityIfNeeded({
    required String placeId,
    required double latitude,
    required double longitude,
  }) async {
    final existing = await _client
        .from(SupabaseTables.places)
        .select('city_code')
        .eq('id', placeId)
        .maybeSingle();
    final currentCode = existing?['city_code'] as String?;
    if (currentCode != null && currentCode.isNotEmpty) return;

    final municipality = await _municipalityResolver.resolve(
      latitude: latitude,
      longitude: longitude,
    );
    if (municipality == null) return;

    await _client.rpc(
      'whoeats_sync_place_municipality',
      params: {
        'p_place_id': placeId,
        'p_prefecture_code': municipality.prefectureCode,
        'p_city_code': municipality.cityCode,
        'p_city_name': municipality.cityName,
      },
    );
  }
}
