import 'dart:typed_data';

/// Implementations must isolate both server and account, and fail closed on
/// unreadable data rather than replacing a saved submission with an empty draft.
abstract interface class DraftVault {
  Future<Map<String, dynamic>?> load(String scope);
  Future<void> save(String scope, Map<String, dynamic> state);
  Future<void> putFile(String scope, String id, Uint8List bytes);
  Future<Uint8List> readFile(String scope, String id);
  Future<void> removeFile(String scope, String id);
}
