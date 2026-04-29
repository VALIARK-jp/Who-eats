import '../../domain/entities/app_entities.dart';

class PlaceDetailModel {
  const PlaceDetailModel({
    required this.placeId,
    required this.placeName,
    required this.rating,
    required this.friendComment,
    required this.imageUrl,
    required this.posts,
    this.address,
    this.phoneNumber,
    this.openNow,
    this.travelMinutes,
    this.latitude,
    this.longitude,
  });

  final String placeId;
  final String placeName;
  final double rating;
  final String friendComment;
  final String imageUrl;
  final List<PlacePostPreviewModel> posts;
  final String? address;
  final String? phoneNumber;
  final bool? openNow;
  final int? travelMinutes;
  final double? latitude;
  final double? longitude;

  factory PlaceDetailModel.fromJson(Map<String, dynamic> json) {
    final postsRaw = json['posts'] as List<dynamic>? ?? [];
    return PlaceDetailModel(
      placeId: (json['placeId'] ?? json['place_id'] ?? '').toString(),
      placeName: (json['placeName'] ?? json['place_name'] ?? '').toString(),
      rating: _asDouble(json['rating']),
      friendComment: (json['friendComment'] ?? json['friend_comment'] ?? '')
          .toString(),
      imageUrl: (json['imageUrl'] ?? json['image_url'] ?? '').toString(),
      posts: postsRaw
          .whereType<Map<String, dynamic>>()
          .map(PlacePostPreviewModel.fromJson)
          .toList(),
      address: (json['address'] ?? json['formatted_address'])?.toString(),
      phoneNumber:
          (json['phoneNumber'] ?? json['phone_number'] ?? json['formatted_phone_number'])
              ?.toString(),
      openNow: json['openNow'] as bool? ?? json['open_now'] as bool?,
      travelMinutes: (json['travelMinutes'] as num?)?.toInt(),
      latitude: _asNullableDouble(json['latitude'] ?? json['lat']),
      longitude: _asNullableDouble(json['longitude'] ?? json['lng']),
    );
  }

  PlaceDetail toEntity() {
    return PlaceDetail(
      placeId: placeId,
      placeName: placeName,
      rating: rating,
      friendComment: friendComment,
      imageUrl: imageUrl,
      posts: posts.map((e) => e.toEntity()).toList(),
      address: address,
      phoneNumber: phoneNumber,
      openNow: openNow,
      travelMinutes: travelMinutes,
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
}

class PlacePostPreviewModel {
  const PlacePostPreviewModel({
    required this.id,
    required this.userName,
    required this.comment,
    this.imageUrl,
  });

  final String id;
  final String userName;
  final String comment;
  final String? imageUrl;

  factory PlacePostPreviewModel.fromJson(Map<String, dynamic> json) {
    return PlacePostPreviewModel(
      id: (json['id'] ?? '').toString(),
      userName: (json['userName'] ?? json['user_name'] ?? '').toString(),
      comment: (json['comment'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? json['image_url'])?.toString(),
    );
  }

  PlacePostPreview toEntity() {
    return PlacePostPreview(
      id: id,
      userName: userName,
      comment: comment,
      imageUrl: imageUrl,
    );
  }
}
