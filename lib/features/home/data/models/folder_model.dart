class FolderModel {
  final String id;
  final String name;
  final String? parentId;
  final bool isSystem;

  const FolderModel({
    required this.id,
    required this.name,
    this.parentId,
    this.isSystem = false,
  });

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      parentId: json['parent']?.toString(),
      isSystem: json['is_system'] as bool? ?? false,
    );
  }
}
