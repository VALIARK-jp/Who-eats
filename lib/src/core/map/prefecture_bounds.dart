/// 都道府県のおおよその外接矩形（lat/lng → 都道府県コードの推定用）。
abstract final class PrefectureBounds {
  static const _entries = <String, ({double south, double north, double west, double east, String name})>{
    '01': (south: 41.3, north: 45.6, west: 139.3, east: 145.9, name: '北海道'),
    '02': (south: 40.2, north: 41.6, west: 139.5, east: 141.7, name: '青森県'),
    '03': (south: 38.9, north: 40.5, west: 140.6, east: 142.1, name: '岩手県'),
    '04': (south: 37.7, north: 39.0, west: 140.4, east: 141.7, name: '宮城県'),
    '05': (south: 39.1, north: 40.5, west: 139.7, east: 140.9, name: '秋田県'),
    '06': (south: 37.5, north: 39.2, west: 139.6, east: 140.6, name: '山形県'),
    '07': (south: 36.8, north: 37.9, west: 139.3, east: 141.1, name: '福島県'),
    '08': (south: 35.7, north: 36.9, west: 139.7, east: 140.9, name: '茨城県'),
    '09': (south: 36.2, north: 37.2, west: 138.9, east: 140.3, name: '栃木県'),
    '10': (south: 36.0, north: 36.7, west: 138.4, east: 139.5, name: '群馬県'),
    '11': (south: 35.7, north: 36.3, west: 138.9, east: 140.0, name: '埼玉県'),
    '12': (south: 34.9, north: 36.1, west: 139.7, east: 140.9, name: '千葉県'),
    '13': (south: 24.0, north: 35.9, west: 138.9, east: 153.9, name: '東京都'),
    '14': (south: 35.1, north: 35.7, west: 138.9, east: 139.8, name: '神奈川県'),
    '15': (south: 36.8, north: 38.6, west: 137.6, east: 139.9, name: '新潟県'),
    '16': (south: 36.3, north: 36.9, west: 136.9, east: 137.8, name: '富山県'),
    '17': (south: 36.0, north: 37.9, west: 136.2, east: 137.4, name: '石川県'),
    '18': (south: 35.4, north: 36.4, west: 135.8, east: 136.9, name: '福井県'),
    '19': (south: 35.1, north: 35.9, west: 138.2, east: 139.2, name: '山梨県'),
    '20': (south: 35.2, north: 36.9, west: 137.3, east: 138.9, name: '長野県'),
    '21': (south: 35.2, north: 36.4, west: 136.5, east: 137.8, name: '岐阜県'),
    '22': (south: 34.6, north: 35.4, west: 137.5, east: 139.2, name: '静岡県'),
    '23': (south: 34.6, north: 35.4, west: 136.7, east: 137.8, name: '愛知県'),
    '24': (south: 33.7, north: 35.2, west: 136.0, east: 136.9, name: '三重県'),
    '25': (south: 34.8, north: 35.7, west: 135.8, east: 136.4, name: '滋賀県'),
    '26': (south: 34.7, north: 35.8, west: 135.0, east: 136.0, name: '京都府'),
    '27': (south: 34.3, north: 35.7, west: 135.1, east: 135.8, name: '大阪府'),
    '28': (south: 34.2, north: 35.7, west: 134.2, east: 135.5, name: '兵庫県'),
    '29': (south: 33.9, north: 34.8, west: 135.6, east: 136.1, name: '奈良県'),
    '30': (south: 33.4, north: 34.4, west: 135.0, east: 136.0, name: '和歌山県'),
    '31': (south: 35.0, north: 35.6, west: 133.2, east: 134.5, name: '鳥取県'),
    '32': (south: 34.3, north: 36.3, west: 131.7, east: 133.5, name: '島根県'),
    '33': (south: 34.3, north: 35.3, west: 133.2, east: 134.4, name: '岡山県'),
    '34': (south: 34.0, north: 35.0, west: 132.0, east: 133.5, name: '広島県'),
    '35': (south: 33.7, north: 34.6, west: 130.8, east: 132.1, name: '山口県'),
    '36': (south: 33.5, north: 34.3, west: 133.5, east: 134.8, name: '徳島県'),
    '37': (south: 34.0, north: 34.5, west: 133.4, east: 134.5, name: '香川県'),
    '38': (south: 32.9, north: 34.3, west: 132.3, east: 133.2, name: '愛媛県'),
    '39': (south: 32.7, north: 34.0, west: 132.5, east: 134.3, name: '高知県'),
    '40': (south: 33.0, north: 33.9, west: 129.9, east: 131.2, name: '福岡県'),
    '41': (south: 33.0, north: 33.6, west: 129.7, east: 130.5, name: '佐賀県'),
    '42': (south: 32.5, north: 33.4, west: 128.7, east: 130.4, name: '長崎県'),
    '43': (south: 32.0, north: 33.2, west: 130.0, east: 131.2, name: '熊本県'),
    '44': (south: 32.7, north: 33.6, west: 130.8, east: 132.0, name: '大分県'),
    '45': (south: 31.3, north: 32.8, west: 130.7, east: 131.9, name: '宮崎県'),
    '46': (south: 27.0, north: 32.3, west: 128.4, east: 131.3, name: '鹿児島県'),
    '47': (south: 24.0, north: 28.5, west: 122.9, east: 131.3, name: '沖縄県'),
  };

  static String? prefectureCodeFor(double lat, double lng) {
    final codes = prefectureCodesFor(lat, lng);
    return codes.isEmpty ? null : codes.first;
  }

  /// 地図の表示範囲と交差する都道府県コード（全国対応）。
  static List<String> prefectureCodesInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) {
    final matches = <String>[];
    for (final entry in _entries.entries) {
      final b = entry.value;
      if (maxLat < b.south || minLat > b.north) continue;
      if (maxLng < b.west || minLng > b.east) continue;
      matches.add(entry.key);
    }
    matches.sort();
    return matches;
  }

  static List<String> allPrefectureCodes() =>
      _entries.keys.toList(growable: false);

  /// 外接矩形に含まれる都道府県を面積の小さい順に返す（境界付近の誤判定フォールバック用）。
  static List<String> prefectureCodesFor(double lat, double lng) {
    final matches = <({String code, double area})>[];
    for (final entry in _entries.entries) {
      final b = entry.value;
      if (lat < b.south || lat > b.north || lng < b.west || lng > b.east) {
        continue;
      }
      matches.add((
        code: entry.key,
        area: (b.north - b.south) * (b.east - b.west),
      ));
    }
    matches.sort((a, b) => a.area.compareTo(b.area));
    return matches.map((m) => m.code).toList(growable: false);
  }

  static String? prefectureNameFor(String code) =>
      _entries[code.padLeft(2, '0')]?.name;
}
