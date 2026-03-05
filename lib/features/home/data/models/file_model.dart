import 'dart:convert';

// Sentinel объект для различия "не передан" vs "передан null"
const _absent = Object();

class FileModel {
  final String id;
  final String name;
  final int size;
  final String mimeType;
  final String uploadStatus;
  final DateTime createdAt;
  final bool isFavourite;
  final String? favouriteId;
  final String? thumbnailPath;

  const FileModel({
    required this.id,
    required this.name,
    required this.size,
    required this.mimeType,
    required this.uploadStatus,
    required this.createdAt,
    this.isFavourite = false,
    this.favouriteId,
    this.thumbnailPath,
  });

  factory FileModel.fromJson(Map<String, dynamic> json) {
    return FileModel(
      id: json['id'].toString(),
      name: _decodeBase64(json['name'] ?? ''),
      size: json['size'] ?? 0,
      mimeType: _decodeBase64(json['mime_type'] ?? ''),
      uploadStatus: json['upload_status'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      isFavourite: json['is_favourite'] ?? false,
      favouriteId: json['favourite_id']?.toString(),
      thumbnailPath: json['thumbnail_path']?.toString(),
    );
  }

  // ✅ FIX: sentinel позволяет явно передать favouriteId: null
  // Без этого copyWith(favouriteId: null) возвращал бы старое значение
  FileModel copyWith({
    String? id,
    String? name,
    int? size,
    String? mimeType,
    String? uploadStatus,
    DateTime? createdAt,
    bool? isFavourite,
    Object? favouriteId = _absent, // ← Object? вместо String?
    String? thumbnailPath,
  }) {
    return FileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      mimeType: mimeType ?? this.mimeType,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      createdAt: createdAt ?? this.createdAt,
      isFavourite: isFavourite ?? this.isFavourite,
      // Если передан _absent — берём старое значение
      // Если передан null или String — берём новое
      favouriteId: identical(favouriteId, _absent)
          ? this.favouriteId
          : favouriteId as String?,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  static String _decodeBase64(String value) {
    if (value.isEmpty) return value;
    try {
      return utf8.decode(base64.decode(value));
    } catch (_) {
      return value;
    }
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
