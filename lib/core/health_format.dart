/// Formatting helpers for health values.
///
/// One rule: a null metric formats as [noData], never as "0". If a number
/// reaches the screen, it came from the payload.
library;

const String noData = 'NO DATA';

String formatHours(double? hours) {
  if (hours == null) return noData;
  final total = (hours * 60).round();
  final h = total ~/ 60;
  final m = total % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

String formatBpm(double? value) =>
    value == null ? noData : '${value.round()} bpm';

String formatMs(double? value) =>
    value == null ? noData : '${value.round()} ms';

String formatSteps(double? value) {
  if (value == null) return noData;
  final n = value.round();
  final text = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return buffer.toString();
}

String formatKcal(double? value) =>
    value == null ? noData : '${value.round()} kcal';

String formatMinutes(double? value) =>
    value == null ? noData : '${value.round()} min';

String formatKm(double? value) =>
    value == null ? noData : '${value.toStringAsFixed(2)} km';

String formatClock(DateTime? time) {
  if (time == null) return noData;
  final local = time.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "22 Sep, 00:35" — readable, never an ISO string with a T in it.
String formatDayAndTime(DateTime? time) {
  if (time == null) return noData;
  final local = time.toLocal();
  return '${local.day} ${_months[local.month - 1]}, ${formatClock(local)}';
}

/// "18 metrics" / "7 days". A null count is NO DATA, and so is zero: a count
/// of nothing is the absence of data, not a measurement of nothing.
String formatCount(int? value, String singular, String plural) {
  if (value == null || value == 0) return noData;
  return '$value ${value == 1 ? singular : plural}';
}

/// "just now" / "12 min ago" / "3 h ago" / "2 d ago".
String formatAge(Duration? age) {
  if (age == null) return noData;
  if (age.inMinutes < 1) return 'just now';
  if (age.inMinutes < 60) return '${age.inMinutes} min ago';
  if (age.inHours < 48) return '${age.inHours} h ago';
  return '${age.inDays} d ago';
}

/// "+42 min vs 7-day average" style deltas. Null-safe and sign-aware.
String? formatSleepDelta(double? deltaHours) {
  if (deltaHours == null) return null;
  final minutes = (deltaHours * 60).round();
  if (minutes.abs() < 10) return 'in line with your 7-day average';
  final sign = minutes > 0 ? '+' : '−';
  final abs = minutes.abs();
  final text = abs >= 60 ? '${abs ~/ 60}h ${abs % 60}m' : '${abs}m';
  return '$sign$text vs your 7-day average';
}
