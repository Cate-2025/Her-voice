import 'dart:convert';

/// Frozen request and operation key survive retries and process restarts.
class SubmissionIntent {
  SubmissionIntent(Map<String, dynamic> value)
    : payload = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  final Map<String, dynamic> payload;
  String? serverId;
}
