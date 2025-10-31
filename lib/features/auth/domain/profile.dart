class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String fullName;
  final String role;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isAdmin => role == 'admin';
  bool get isActive => status == 'active';

  Profile copyWith({
    String? fullName,
    String? role,
    String? status,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static Profile fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      fullName: (map['full_name'] as String?) ?? '',
      role: map['role'] as String? ?? 'collector',
      status: map['status'] as String? ?? 'inactive',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'role': role,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
