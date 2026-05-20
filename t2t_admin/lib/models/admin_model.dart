import 'package:cloud_firestore/cloud_firestore.dart';

class AdminModel {
  final String id;
  final String name;
  final String email;
  final String? imageUrl;
  final String department;
  final String role;
  final List<String>? permissions;
  final Timestamp createdAt;

  AdminModel({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
    this.imageUrl,
    this.role = 'admin',
    this.permissions,
    Timestamp? createdAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  factory AdminModel.fromMap(Map<String, dynamic> map) {
    return AdminModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      department: map['department'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      role: map['role'] as String? ?? 'admin',
      permissions: map['permissions'] != null ? List<String>.from(map['permissions']) : null,
      createdAt: map['createdAt'] is Timestamp ? map['createdAt'] as Timestamp : Timestamp.fromDate(DateTime.parse(map['createdAt'] as String)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'department': department,
      'imageUrl': imageUrl,
      'role': role,
      'permissions': permissions,
      'createdAt': createdAt,
    };
  }

  AdminModel copyWith({
    String? id,
    String? name,
    String? email,
    String? department,
    String? imageUrl,
    String? role,
    List<String>? permissions,
    Timestamp? createdAt,
  }) {
    return AdminModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      department: department ?? this.department,
      imageUrl: imageUrl ?? this.imageUrl,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
