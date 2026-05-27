import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_tables.dart';

/// Creates a post row, uploads one image to `post-images`, and links `post_images`.
class PostSubmitService {
  PostSubmitService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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
      final postRow = await _client
          .from(SupabaseTables.posts)
          .insert({
            'user_id': uid,
            'place_id': placeId,
            'post_type': postType,
            'visibility': visibility,
            'caption': caption,
          })
          .select('id')
          .single();

      final postId = postRow['id'] as String;

      await _client.from(SupabaseTables.postImages).insert({
        'post_id': postId,
        'storage_path': storagePath,
        'display_order': 0,
      });

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
      return existing['id'] as String;
    }

    try {
      final inserted = await _client
          .from(SupabaseTables.places)
          .insert({
            'google_place_id': googlePlaceId,
            'name': placeName,
            'latitude': latitude,
            'longitude': longitude,
            'source': 'google',
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
      return raced['id'] as String;
    }
  }
}
