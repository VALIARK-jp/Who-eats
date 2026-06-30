import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../map/municipality_resolver.dart';
import 'supabase_tables.dart';

/// ログインユーザーの過去投稿先店舗で city_code 未設定のものを補完する。
class PlaceMunicipalityBackfill {
  PlaceMunicipalityBackfill({
    SupabaseClient? client,
    MunicipalityResolver? resolver,
  }) : _client = client ?? Supabase.instance.client,
       _resolver = resolver ?? MunicipalityResolver();

  final SupabaseClient _client;
  final MunicipalityResolver _resolver;

  Future<int> backfillForCurrentUser() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;

    try {
      final postRows = await _client
          .from(SupabaseTables.posts)
          .select('place_id')
          .eq('user_id', uid)
          .eq('post_type', 'restaurant')
          .isFilter('deleted_at', null);

      final placeIds = <String>{};
      for (final raw in (postRows as List<dynamic>)) {
        final placeId = (raw as Map<String, dynamic>)['place_id']?.toString();
        if (placeId != null && placeId.isNotEmpty) placeIds.add(placeId);
      }
      if (placeIds.isEmpty) return 0;

      var updated = 0;
      for (final placeId in placeIds) {
        final place = await _client
            .from(SupabaseTables.places)
            .select('id, latitude, longitude, city_code')
            .eq('id', placeId)
            .maybeSingle();
        if (place == null) continue;
        final cityCode = (place['city_code'] ?? '').toString();
        if (cityCode.isNotEmpty) continue;

        final lat = (place['latitude'] as num?)?.toDouble();
        final lng = (place['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final municipality = await _resolver.resolve(
          latitude: lat,
          longitude: lng,
        );
        if (municipality == null) continue;

        await _client.rpc(
          'whoeats_sync_place_municipality',
          params: {
            'p_place_id': placeId,
            'p_prefecture_code': municipality.prefectureCode,
            'p_city_code': municipality.cityCode,
            'p_city_name': municipality.cityName,
          },
        );
        updated++;
      }
      return updated;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[PlaceMunicipalityBackfill] failed: $e\n$st');
      }
      return 0;
    }
  }
}
