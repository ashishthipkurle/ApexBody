class AppUser {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String role;
  final double? weight; // kg
  final double? height; // cm
  final int? age;
  final String? gender;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    required this.role,
    this.weight,
    this.height,
    this.age,
    this.gender,
  });

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'] as String,
        email: m['email'] ?? '',
        name: m['name'] ?? '',
        phone: m['phone'],
        role: m['role'] ?? 'client',
        weight: m['weight'] != null ? (m['weight'] as num).toDouble() : null,
        height: m['height'] != null ? (m['height'] as num).toDouble() : null,
        age: m['age'] != null ? (m['age'] as num).toInt() : null,
        gender: m['gender'],
      );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'role': role,
      'weight': weight,
      'height': height,
      'age': age,
      'gender': gender,
    };
  }
}
