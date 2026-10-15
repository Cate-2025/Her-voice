import 'enums.dart';

/// Authenticated account. Only the minimum personal information is retained
/// (section 3.12 VII): the email doubles as the login identifier.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    this.displayName,
  });

  final String id;
  final String email;
  final String? displayName;
  final UserRole role;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['displayName']?.toString(),
      role: UserRole.fromWire(json['role']),
    );
  }

  /// Friendly label, falling back to the local part of the email address.
  String get shortName {
    if (displayName != null && displayName!.trim().isNotEmpty) return displayName!.trim();
    final int at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }

  bool get isStaff => role.isStaff;
  bool get isAdmin => role == UserRole.admin;
}
