import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String id;
  final String fullName;
  final String studentID;
  final String email;
  final String department;
  final int points;
  final int bottles;
  final String role; // always 'student'
  final Timestamp createdAt;
  final String? profileImageUrl;

  StudentModel({
    required this.id,
    required this.fullName,
    required this.studentID,
    required this.email,
    required this.department,
    this.points = 0,
    this.bottles = 0,
    this.role = 'student',
    Timestamp? createdAt,
    this.profileImageUrl,
  }) : createdAt = createdAt ?? Timestamp.now();

  factory StudentModel.fromMap(Map<String, dynamic> map, String docId) {
    return StudentModel(
      id: docId,
      fullName: map['fullName'] as String? ?? '',
      studentID: map['studentID'] as String? ?? '',
      email: map['email'] as String? ?? '',
      department: map['department'] as String? ?? '',
      points: (map['points'] as num?)?.toInt() ?? 0,
      bottles: (map['bottles'] as num?)?.toInt() ?? 0,
      role: map['role'] as String? ?? 'student',
      createdAt: map['createdAt'] is Timestamp ? map['createdAt'] as Timestamp : Timestamp.fromDate(DateTime.parse(map['createdAt'] as String)),
      profileImageUrl: map['profileImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'studentID': studentID,
      'email': email,
      'department': department,
      'points': points,
      'bottles': bottles,
      'role': role,
      'createdAt': createdAt,
      'profileImageUrl': profileImageUrl,
    };
  }

  StudentModel copyWith({
    String? id,
    String? fullName,
    String? studentID,
    String? email,
    String? department,
    int? points,
    int? bottles,
    String? role,
    Timestamp? createdAt,
    String? profileImageUrl,
  }) {
    return StudentModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      studentID: studentID ?? this.studentID,
      email: email ?? this.email,
      department: department ?? this.department,
      points: points ?? this.points,
      bottles: bottles ?? this.bottles,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}
