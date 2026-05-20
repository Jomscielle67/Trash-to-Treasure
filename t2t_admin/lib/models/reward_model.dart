import 'package:cloud_firestore/cloud_firestore.dart';

class RewardModel {
  final String id;
  final String name;
  final int cost;
  final int stock;
  final String department;
  final String? imageUrl;
  final String createdBy;
  final Timestamp createdAt;

  RewardModel({
    required this.id,
    required this.name,
    required this.cost,
    required this.stock,
    required this.department,
    this.imageUrl,
    required this.createdBy,
    Timestamp? createdAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  factory RewardModel.fromMap(Map<String, dynamic> map, String docId) {
    return RewardModel(
      id: docId,
      name: map['name'] as String? ?? '',
      cost: (map['cost'] as num?)?.toInt() ?? 0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      department: map['department'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: map['createdAt'] is Timestamp ? map['createdAt'] as Timestamp : Timestamp.fromDate(DateTime.parse(map['createdAt'] as String)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'cost': cost,
      'stock': stock,
      'department': department,
      'imageUrl': imageUrl,
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }

  RewardModel copyWith({
    String? id,
    String? name,
    int? cost,
    int? stock,
    String? department,
    String? imageUrl,
    String? createdBy,
    Timestamp? createdAt,
  }) {
    return RewardModel(
      id: id ?? this.id,
      name: name ?? this.name,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      department: department ?? this.department,
      imageUrl: imageUrl ?? this.imageUrl,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
