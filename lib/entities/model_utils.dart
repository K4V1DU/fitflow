/// Small parsing helpers shared by the FitFlow models.
/// They tolerate loose JSON (e.g. numbers arriving as strings from the AI).

int toInt(Object? v, [int fallback = 0]) =>
    v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

double toDouble(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;

/// Accepts DateTime, ISO-8601 String, or a Firestore Timestamp (anything with
/// a `toDate()` method) so the models stay independent of Firebase.
DateTime toDate(Object? v, [DateTime? fallback]) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? fallback ?? DateTime.now();
  if (v != null) {
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {}
  }
  return fallback ?? DateTime.now();
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

T enumFrom<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

List<Map<String, dynamic>> mapList(Object? v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

List<String> stringList(Object? v) =>
    v is List ? v.map((e) => '$e').toList() : <String>[];
