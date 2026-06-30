/// 円表示（例: ¥1,280）。
String formatYen(int? yen, {bool includeSymbol = true}) {
  if (yen == null) return '';
  final digits = yen.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return includeSymbol ? '¥${buffer.toString()}' : buffer.toString();
}

int? parseYenInput(String raw) {
  final normalized = raw.replaceAll(RegExp(r'[,\s¥￥]'), '').trim();
  if (normalized.isEmpty) return null;
  final value = int.tryParse(normalized);
  if (value == null || value < 0) return null;
  return value;
}
