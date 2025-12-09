class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.contact,
    this.deviceId,
    this.locationId,
    this.departmentId,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String email;
  final String role; // 'admin' atau 'employee'
  final String? contact;
  final String? deviceId;
  final String? locationId;
  final String? departmentId;
  final String? photoUrl;

  factory AppUser.fromMap(String id, Map<String, dynamic> data) {
    return AppUser(
      id: id,
      name: (data['name'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      role: (data['role'] ?? '') as String,
      contact: data['contact'] as String?,
      deviceId: data['deviceId'] as String?,
      locationId: data['locationId'] as String?,
      departmentId: data['departmentId'] as String?,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'contact': contact,
      'deviceId': deviceId,
      'locationId': locationId,
      'departmentId': departmentId,
      'photoUrl': photoUrl,
    };
  }
}

