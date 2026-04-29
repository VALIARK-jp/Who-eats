import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String _env(String key) {
    final value = dotenv.env[key];
    return value == null ? '' : value.trim();
  }

  static String get mapPinsApiUrl => _env('WHOEATS_MAP_PINS_API_URL');
  static String get placeDetailApiTemplate =>
      _env('WHOEATS_PLACE_DETAIL_API_TEMPLATE');
  static String get googleMapsWebApiKey =>
      _env('WHOEATS_GOOGLE_MAPS_WEB_API_KEY');
  static String get postedPinPlaceId => _env('WHOEATS_POSTED_PIN_PLACE_ID');
  static String get postedPinPlaceName =>
      _env('WHOEATS_POSTED_PIN_PLACE_NAME');
  static String get supabaseUrl => _env('WHOEATS_SUPABASE_URL');
  static String get supabasePublishableKey =>
      _env('WHOEATS_SUPABASE_PUBLISHABLE_KEY');

  /// Matches seeded row in `0002_post_images_bucket_dev_place.sql` when env unset.
  static const String fallbackDevPlaceUuid =
      '00000000-0000-4000-8000-000000000001';

  static String get defaultDevPlaceUuid {
    final v = _env('WHOEATS_DEFAULT_DEV_PLACE_UUID');
    return v.isNotEmpty ? v : fallbackDevPlaceUuid;
  }

  static bool get hasMapApi =>
      mapPinsApiUrl.isNotEmpty && placeDetailApiTemplate.isNotEmpty;
  static bool get hasGooglePlacesApi => googleMapsWebApiKey.isNotEmpty;
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
