import 'dart:convert';
import 'package:cloud_app/core/config/app_config.dart';

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
    final rawId = json['id'] ?? json['uuid'] ?? json['file_id'] ?? json['file_uuid'];
    return FileModel(
      id: rawId?.toString() ?? '',
      name: _decodeBase64(json['name'] ?? ''),
      size: json['size'] ?? 0,
      mimeType: _decodeBase64(json['mime_type'] ?? ''),
      uploadStatus: json['upload_status'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      isFavourite: json['is_favourite'] ?? false,
      favouriteId: json['favourite_id']?.toString(),
      thumbnailPath: _normalizeUrl(json['thumbnail_path']?.toString()),
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

  static String? _normalizeUrl(String? raw) {
    if (raw == null || raw.isEmpty) return raw;
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) return raw;

    final base = Uri.parse(AppConfig.instance.baseUrl);
    final origin = base.replace(path: '/', query: '', fragment: '');

    if (raw.startsWith('/media/') || raw.startsWith('/static/')) {
      return origin.resolve(raw).toString();
    }
    if (raw.startsWith('/api/')) {
      return origin.resolve(raw).toString();
    }
    if (raw.startsWith('/content/')) {
      return base.resolve(raw.substring(1)).toString();
    }
    if (raw.startsWith('/')) {
      return origin.resolve(raw).toString();
    }
    return base.resolve(raw).toString();
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
