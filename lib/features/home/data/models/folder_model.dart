class FolderModel {
  final String id;
  final String name;
  final String? parentId;

  const FolderModel({required this.id, required this.name, this.parentId});

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      parentId: json['parent']?.toString(),
    );
  }
}
