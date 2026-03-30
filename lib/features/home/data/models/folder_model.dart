class FolderModel {
  final String id;
  final String name;
  final String? parentId;
  final bool isSystem;
  final bool isSync;

  const FolderModel({
    required this.id,
    required this.name,
    this.parentId,
    this.isSystem = false,
    this.isSync = false,
  });

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      parentId: json['parent']?.toString(),
      isSystem: json['is_system'] as bool? ?? false,
      isSync: json['is_sync'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parent': parentId,
      'is_system': isSystem,
      'is_sync': isSync,
    };
  }

  FolderModel copyWith({
    String? id,
    String? name,
    String? parentId,
    bool? isSystem,
    bool? isSync,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      isSystem: isSystem ?? this.isSystem,
      isSync: isSync ?? this.isSync,
    );
  }
}
