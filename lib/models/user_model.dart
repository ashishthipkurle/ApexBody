class AppUser {
  final String id;
  final String email;
  final String? name;
  final String? phone;
  final String role;
  final double? weight; // kg
  final double? height; // cm
  final int? age;
  final String? gender;
  final String? profilePictureUrl;

  AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.name,
    this.phone,
    this.weight,
    this.height,
    this.age,
    this.gender,
    this.profilePictureUrl,
  });

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'] as String,
        email: m['email'] ?? '',
        name: m['name'],
        phone: m['phone'],
        role: m['role'] ?? 'client',
        weight: m['weight'] != null ? (m['weight'] as num).toDouble() : null,
        height: m['height'] != null ? (m['height'] as num).toDouble() : null,
        age: m['age'] != null ? (m['age'] as num).toInt() : null,
        gender: m['gender'],
        profilePictureUrl: m['profile_picture_url'],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'name': name,
        'phone': phone,
        'role': role,
        'weight': weight,
        'height': height,
        'age': age,
        'gender': gender,
        'profile_picture_url': profilePictureUrl,
      };

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? role,
    double? weight,
    double? height,
    int? age,
    String? gender,
    String? profilePictureUrl,
  }) =>
      AppUser(
        id: id ?? this.id,
        email: email ?? this.email,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        weight: weight ?? this.weight,
        height: height ?? this.height,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      );
}
