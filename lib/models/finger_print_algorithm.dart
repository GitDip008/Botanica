import 'dart:math';

/// Đại diện cho 1 điểm khảo sát (fingerprint) đã thu thập sẵn trong database.
class SurveyPoint {
  final String id;
  final double x;
  final double y;
  final Map<String, double?> rssi; // beaconId -> rssi (null = không thấy)

  SurveyPoint({
    required this.id,
    required this.x,
    required this.y,
    required this.rssi,
  });

  factory SurveyPoint.fromJson(Map<String, dynamic> json) {
    final rssiMap = <String, double?>{};
    (json['rssi'] as Map<String, dynamic>).forEach((key, value) {
      rssiMap[key] = value == null ? null : (value as num).toDouble();
    });
    return SurveyPoint(
      id: json['id'].toString(),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      rssi: rssiMap,
    );
  }
}

/// Kết quả trả về sau khi định vị.
class LocationResult {
  final double x;
  final double y;
  final double confidence; // 0.0 - 1.0, càng cao càng đáng tin
  final List<_ScoredPoint> nearestPoints; // để debug / hiển thị

  LocationResult({
    required this.x,
    required this.y,
    required this.confidence,
    required this.nearestPoints,
  });

  @override
  String toString() =>
      'LocationResult(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, '
      'confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
}

class _ScoredPoint {
  final SurveyPoint point;
  final double signalDistance; // càng nhỏ càng giống
  _ScoredPoint(this.point, this.signalDistance);
}

/// Class chính: tìm vị trí user dựa trên RSSI hiện tại, so khớp với
/// tập fingerprint đã khảo sát trước (weighted KNN).
class FingerprintLocator {
  final List<SurveyPoint> surveyPoints;

  /// Giá trị RSSI gán khi 1 bên có tín hiệu còn bên kia null (không thấy).
  /// Nên đặt thấp hơn (âm hơn) giá trị RSSI thấp nhất từng đo được.
  final double missingRssiPenalty;

  /// Số điểm gần nhất dùng để nội suy vị trí (K).
  final int k;

  /// Ngưỡng signal distance tối đa để 1 điểm được coi là "hợp lệ"
  /// (dùng để tính confidence, không bắt buộc).
  final double maxReasonableDistance;

  FingerprintLocator({
    required this.surveyPoints,
    this.missingRssiPenalty = -100.0,
    this.k = 4,
    this.maxReasonableDistance = 40.0,
  });

  /// Hàm chính: đưa vào RSSI hiện tại đọc từ BLE scan, trả về vị trí ước lượng.
  ///
  /// [liveRssi]: map beaconId -> rssi hiện tại (null nếu không thấy beacon đó).
  LocationResult? locate(Map<String, double?> liveRssi) {
    if (surveyPoints.isEmpty) return null;

    // 1. Tính signal distance từ live RSSI tới từng survey point
    final scored = surveyPoints.map((point) {
      final dist = _signalDistance(liveRssi, point.rssi);
      return _ScoredPoint(point, dist);
    }).toList();

    // 2. Sắp xếp tăng dần theo signal distance, lấy K điểm gần nhất
    scored.sort((a, b) => a.signalDistance.compareTo(b.signalDistance));
    final nearestK = scored.take(k).toList();

    if (nearestK.isEmpty) return null;

    // 3. Weighted average tọa độ theo nghịch đảo khoảng cách
    //    (điểm càng giống tín hiệu hiện tại càng có trọng số cao)
    double totalWeight = 0;
    double weightedX = 0;
    double weightedY = 0;

    for (final sp in nearestK) {
      // Cộng epsilon để tránh chia cho 0 khi signalDistance = 0 (khớp tuyệt đối)
      final weight = 1 / (sp.signalDistance + 0.5);
      weightedX += sp.point.x * weight;
      weightedY += sp.point.y * weight;
      totalWeight += weight;
    }

    final estimatedX = weightedX / totalWeight;
    final estimatedY = weightedY / totalWeight;

    // 4. Tính confidence dựa trên độ khớp trung bình của K điểm gần nhất
    final avgDistance =
        nearestK.map((e) => e.signalDistance).reduce((a, b) => a + b) /
            nearestK.length;
    final confidence =
        (1 - (avgDistance / maxReasonableDistance)).clamp(0.0, 1.0);

    return LocationResult(
      x: estimatedX,
      y: estimatedY,
      confidence: confidence,
      nearestPoints: nearestK,
    );
  }

  /// Tính "khoảng cách tín hiệu" (Euclidean distance trong không gian RSSI)
  /// giữa live RSSI và 1 fingerprint đã khảo sát.
  double _signalDistance(
    Map<String, double?> live,
    Map<String, double?> reference,
  ) {
    // Gộp tất cả beacon xuất hiện ở 1 trong 2 phía
    final allBeacons = {...live.keys, ...reference.keys};

    double sumSquares = 0;
    for (final beaconId in allBeacons) {
      final liveVal = live[beaconId];
      final refVal = reference[beaconId];

      // Cả 2 đều không thấy beacon này -> không đóng góp gì, bỏ qua
      if (liveVal == null && refVal == null) continue;

      final liveNum = liveVal ?? missingRssiPenalty;
      final refNum = refVal ?? missingRssiPenalty;

      final diff = liveNum - refNum;
      sumSquares += diff * diff;
    }

    return sqrt(sumSquares);
  }
}

/// ------------------------------------------------------------------
/// VÍ DỤ SỬ DỤNG
/// ------------------------------------------------------------------
void exampleUsage() {
  // 1. Load dữ liệu survey đã khảo sát (từ JSON/DB)
  final surveyData = [
    SurveyPoint(id: '1', x: -156.9031, y: 9.3709, rssi: {
      'romeoE': -90, 'juliaE': -85, 'mainEntrance': -92,
      'juliaC': -83, 'juliaE2': -97, 'juliaF': -98, 'romeoB': -96,
    }),
    SurveyPoint(id: '6', x: -156.9031, y: 1.4283, rssi: {
      'romeoE': null, 'juliaE': -57, 'mainEntrance': null,
      'juliaC': -80, 'juliaE2': -97, 'juliaF': -88, 'romeoB': null,
    }),
    // ... thêm các node còn lại (2-28)
  ];

  final locator = FingerprintLocator(
    surveyPoints: surveyData,
    k: 3, // dùng 3 điểm gần nhất, tăng lên 4-5 nếu data dày hơn
  );

  // 2. RSSI hiện tại đọc được từ BLE scan (đã qua filter/Kalman)
  final currentRssi = <String, double?>{
    'romeoE': null,
    'juliaE': -59,
    'mainEntrance': null,
    'juliaC': -81,
    'juliaE2': -95,
    'juliaF': -87,
    'romeoB': null,
  };

  // 3. Định vị
  final result = locator.locate(currentRssi);

  if (result != null) {
    print(result);
    print('Các node gần nhất được dùng để nội suy:');
    for (final sp in result.nearestPoints) {
      print('  Node ${sp.point.id}: signal distance = '
          '${sp.signalDistance.toStringAsFixed(2)}');
    }
  } else {
    print('Không thể định vị (chưa có dữ liệu khảo sát).');
  }
}