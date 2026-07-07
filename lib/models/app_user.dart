enum UserRole { user, helpdesk, admin }

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool isActive;
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
    this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id']?.toString() ?? '',
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      role: UserRoleX.fromValue((map['role'] ?? 'user') as String),
      isActive: map['is_active'] != false,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.value,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

extension UserRoleX on UserRole {
  String get value => switch (this) {
    UserRole.user => 'user',
    UserRole.helpdesk => 'helpdesk',
    UserRole.admin => 'admin',
  };

  static UserRole fromValue(String value) {
    switch (value.toLowerCase()) {
      case 'helpdesk':
        return UserRole.helpdesk;
      case 'admin':
        return UserRole.admin;
      case 'user':
      default:
        return UserRole.user;
    }
  }
}
