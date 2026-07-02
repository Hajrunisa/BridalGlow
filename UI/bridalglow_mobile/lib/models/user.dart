class User {  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String username;
  final String? phone;
  final String role;
  final String roleName;
  final bool isActive;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.username,
    this.phone,
    required this.role,
    required this.roleName,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      phone: json['phone'],
      role: json['role']?.toString() ?? json['roleName'] ?? '',
      roleName: json['roleName'] ?? json['role']?.toString() ?? '',
      isActive: json['isActive'] ?? true,
    );
  }

  bool get isAdmin => roleName == 'Admin' || role == '1';
  bool get isCustomer => roleName == 'Customer' || role == '3';
  bool get isSalonStaff => roleName == 'SalonStaff' || role == '2';

  String get fullName => '$firstName $lastName'.trim();
}

class AuthSession {
  final User user;
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAtUtc;
  final DateTime refreshTokenExpiresAtUtc;

  AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAtUtc,
    required this.refreshTokenExpiresAtUtc,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: User.fromJson(json['user']),
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
      accessTokenExpiresAtUtc: DateTime.parse(json['accessTokenExpiresAtUtc']),
      refreshTokenExpiresAtUtc: DateTime.parse(json['refreshTokenExpiresAtUtc']),
    );
  }

  Map<String, dynamic> toJson() => {
        'user': {
          'id': user.id,
          'firstName': user.firstName,
          'lastName': user.lastName,
          'email': user.email,
          'username': user.username,
          'phone': user.phone,
          'role': user.role,
          'roleName': user.roleName,
          'isActive': user.isActive,
        },
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'accessTokenExpiresAtUtc': accessTokenExpiresAtUtc.toIso8601String(),
        'refreshTokenExpiresAtUtc': refreshTokenExpiresAtUtc.toIso8601String(),
      };
}
