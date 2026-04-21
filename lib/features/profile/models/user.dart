class User {
  final int id;
  final String email;
  final String? username;
  final String firstName;
  final String lastName;
  final bool isStaff;

  User({
    required this.id,
    required this.email,
    this.username,
    required this.firstName,
    required this.lastName,
    this.isStaff = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      isStaff: json['is_staff'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'is_staff': isStaff,
    };
  }
  
  String get displayName => (username != null && username!.isNotEmpty) 
      ? username! 
      : (firstName.isNotEmpty ? firstName : email.split('@')[0]);
}
