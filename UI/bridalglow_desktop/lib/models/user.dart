class User {  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String username;
  final String? phone;
  final String roleName;
  final bool isActive;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.username,
    this.phone,
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
      roleName: json['roleName']?.toString() ?? json['role']?.toString() ?? '',
      isActive: json['isActive'] ?? true,
    );
  }

  bool get isAdmin => roleName == 'Admin';
  bool get isSalonStaff => roleName == 'SalonStaff';
  bool get isCustomer => roleName == 'Customer';
  String get fullName => '$firstName $lastName'.trim();
}

class AuthSession {
  final User user;
  final String accessToken;
  final String refreshToken;

  AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: User.fromJson(json['user']),
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
    );
  }
}
