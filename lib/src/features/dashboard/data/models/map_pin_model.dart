import '../../domain/entities/app_entities.dart';

class MapPinModel {
  const MapPinModel({
    required this.id,
    required this.placeName,
    required this.rating,
    required this.friendComment,
    required this.imageUrl,
    required this.isFriendVisited,
    required this.friendAvatars,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String placeName;
  final double rating;
  final String friendComment;
  final String imageUrl;
  final bool isFriendVisited;
  final List<String> friendAvatars;
  final double? latitude;
  final double? longitude;

  factory MapPinModel.fromJson(Map<String, dynamic> json) {
    final avatarsRaw = json['friendAvatars'] ?? json['friend_avatars'] ?? [];
    return MapPinModel(
      id: (json['id'] ?? '').toString(),
      placeName: (json['placeName'] ?? json['place_name'] ?? '').toString(),
      rating: _asDouble(json['rating']),
      friendComment: (json['friendComment'] ?? json['friend_comment'] ?? '')
          .toString(),
      imageUrl: (json['imageUrl'] ?? json['image_url'] ?? '').toString(),
      isFriendVisited: _asBool(
        json['isFriendVisited'] ?? json['is_friend_visited'],
      ),
      friendAvatars: (avatarsRaw as List).map((e) => e.toString()).toList(),
      latitude: _asNullableDouble(json['latitude'] ?? json['lat']),
      longitude: _asNullableDouble(json['longitude'] ?? json['lng']),
    );
  }

  MapPin toEntity() {
    return MapPin(
      id: id,
      placeName: placeName,
      rating: rating,
      friendComment: friendComment,
      imageUrl: imageUrl,
      isFriendVisited: isFriendVisited,
      friendAvatars: friendAvatars,
      latitude: latitude,
      longitude: longitude,
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = (value ?? '').toString().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
}
