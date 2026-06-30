/// 地図ピンの表示モード切替（Google Maps zoom）。
abstract final class MapDisplayConfig {
  /// この zoom 以上 → 店ごとの個別ピン（マイクロドット + 3D）。
  static const double individualPinMinZoom = 14;

  /// この zoom 以上（かつ individual 未満）→ 中サイズの数字クラスター。
  static const double mediumClusterMinZoom = 11;

  /// 個別ピン表示 tier。
  static const int tierIndividualPins = 2;

  /// 中域数字クラスター tier。
  static const int tierMediumClusters = 1;

  /// 広域数字クラスター tier。
  static const int tierBroadClusters = 0;

  /// 市境界コロプレスはズームに関係なく常時表示。
  static bool showsChoropleth(double zoom) => true;

  static int tierForZoom(double zoom) {
    if (zoom >= individualPinMinZoom) return tierIndividualPins;
    if (zoom >= mediumClusterMinZoom) return tierMediumClusters;
    return tierBroadClusters;
  }

  static bool showsIndividualPins(double zoom) =>
      tierForZoom(zoom) == tierIndividualPins;

  static bool showsNumberClusters(double zoom) =>
      tierForZoom(zoom) != tierIndividualPins;
}
