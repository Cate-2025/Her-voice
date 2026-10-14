import '../core/date_format.dart';
import 'enums.dart';

/// A single item preserved in the Evidence Vault (section 3.2).
///
/// Only metadata travels in list responses; the bytes are fetched separately
/// through the access-controlled download route so that every read can be
/// audited on the server.
class EvidenceItem {
  const EvidenceItem({
    required this.id,
    required this.kind,
    required this.originalName,
    this.mimeType,
    this.sizeBytes,
    this.sha256,
    this.note,
    this.capturedAt,
    this.uploadedAt,
    this.lawfulDeclaration = false,
    this.pendingSync = false,
  });

  final String id;
  final EvidenceKind kind;
  final String originalName;
  final String? mimeType;
  final int? sizeBytes;
  final String? sha256;
  final String? note;
  final DateTime? capturedAt;
  final DateTime? uploadedAt;
  final bool lawfulDeclaration;

  /// True while the item still lives only on this device (offline queue).
  final bool pendingSync;

  factory EvidenceItem.fromJson(Map<String, dynamic> json) {
    return EvidenceItem(
      id: json['id']?.toString() ?? '',
      kind: EvidenceKind.fromWire(json['kind']),
      originalName: json['originalName']?.toString() ?? 'Evidence',
      mimeType: json['mimeType']?.toString(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      sha256: json['sha256']?.toString(),
      note: json['note']?.toString(),
      capturedAt: HerVoiceDate.parse(json['capturedAt']),
      uploadedAt: HerVoiceDate.parse(json['uploadedAt']),
      lawfulDeclaration: json['lawfulDeclaration'] == true,
      pendingSync: json['pendingSync'] == true,
    );
  }

  String get sizeLabel => formatBytes(sizeBytes);

  /// Short integrity fingerprint shown so a student can see that a file was
  /// preserved unaltered.
  String get fingerprint {
    if (sha256 == null || sha256!.length < 12) return 'not hashed yet';
    return '${sha256!.substring(0, 12)}...';
  }
}
