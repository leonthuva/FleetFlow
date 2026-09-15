class UserRole {
  static const String admin = 'admin';
  static const String dispatcher = 'dispatcher';
  static const String driver = 'driver';

  static const List<String> all = [admin, dispatcher, driver];
}

class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String role;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isDispatcher => role == UserRole.dispatcher;
  bool get isManager => role == UserRole.admin || role == UserRole.dispatcher;
  bool get isDriver => role == UserRole.driver;

  factory AppUser.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return AppUser(
      id: documentId ?? map['id'] as String? ?? map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      role: map['role'] as String? ?? UserRole.driver,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': id,
      'email': email,
      'displayName': displayName,
      'role': role,
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? role,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
    );
  }
}