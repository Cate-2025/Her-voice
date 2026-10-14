import 'package:intl/intl.dart';

/// Date and time helpers for the incident timeline (section 3.3).
///
/// The concept paper shows timeline entries in the form
/// "12 September, 4:30 PM", so these formatters are used everywhere a case
/// event is displayed.
class HerVoiceDate {
  const HerVoiceDate._();

  static final DateFormat _timelineFormat = DateFormat('d MMMM, h:mm a');
  static final DateFormat _dayFormat = DateFormat('d MMM yyyy');
  static final DateFormat _dayTimeFormat = DateFormat('d MMM yyyy, h:mm a');

  /// e.g. "12 September, 4:30 PM"
  static String timeline(DateTime? value) {
    if (value == null) return 'Date not recorded';
    return _timelineFormat.format(value.toLocal());
  }

  /// e.g. "12 Sep 2026"
  static String day(DateTime? value) {
    if (value == null) return 'Not recorded';
    return _dayFormat.format(value.toLocal());
  }

  /// e.g. "12 Sep 2026, 4:30 PM"
  static String dayTime(DateTime? value) {
    if (value == null) return 'Not recorded';
    return _dayTimeFormat.format(value.toLocal());
  }

  /// Human relative age used in case lists.
  static String relative(DateTime? value) {
    if (value == null) return 'unknown';
    final Duration difference = DateTime.now().difference(value.toLocal());
    if (difference.isNegative) return 'just now';
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} h ago';
    if (difference.inDays < 30) return '${difference.inDays} d ago';
    return day(value);
  }

  /// Parses the ISO-8601 strings produced by the backend, tolerating nulls.
  static DateTime? parse(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.tryParse(value.toString());
  }
}

/// Formats a byte count for the evidence list.
String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return 'unknown size';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
