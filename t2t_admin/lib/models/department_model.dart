class DepartmentModel {
  final String id;
  final String name;
  final String? adminId;
  final int? bottleRate;
  final String? location;

  DepartmentModel({
    required this.id,
    required this.name,
    this.adminId,
    this.bottleRate,
    this.location,
  });

  factory DepartmentModel.fromMap(Map<String, dynamic> map, String docId) {
    return DepartmentModel(
      id: docId,
      name: map['name'] as String? ?? '',
      adminId: map['adminId'] as String?,
      bottleRate: (map['bottleRate'] as num?)?.toInt(),
      location: map['location'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'adminId': adminId,
      'bottleRate': bottleRate,
      'location': location,
    };
  }

  DepartmentModel copyWith({
    String? id,
    String? name,
    String? adminId,
    int? bottleRate,
    String? location,
  }) {
    return DepartmentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      adminId: adminId ?? this.adminId,
      bottleRate: bottleRate ?? this.bottleRate,
      location: location ?? this.location,
    );
  }
}
