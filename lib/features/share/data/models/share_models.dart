import 'package:cloud_app/core/config/app_config.dart';

// Share feature models — strictly matching Swagger definitions.

class UserModel {
  final int id;
  final String fullName;
  final String phoneNumber;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      fullName: json['full_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'phone_number': phoneNumber,
      };
}

class FileModel {
  final String id;
  final String name;
  final UserModel owner;
  final int? size;
  final String? mimeType;
  final String? minioPath;
  final String? uploadStatus;
  final String? createdAt;
  final bool isFavourite;
  final String thumbnailPath;

  const FileModel({
    required this.id,
    required this.name,
    required this.owner,
    this.size,
    this.mimeType,
    this.minioPath,
    this.uploadStatus,
    this.createdAt,
    this.isFavourite = false,
    this.thumbnailPath = '',
  });

  factory FileModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['uuid'] ?? json['file_id'] ?? json['file_uuid'];
    return FileModel(
      id: rawId?.toString() ?? '',
      name: json['name'] as String? ?? '',
      owner: UserModel.fromJson(json['owner'] as Map<String, dynamic>? ?? {}),
      size: json['size'] as int?,
      mimeType: json['mime_type'] as String?,
      minioPath: json['minio_path'] as String?,
      uploadStatus: json['upload_status'] as String?,
      createdAt: json['created_at'] as String?,
      isFavourite: json['is_favourite'] as bool? ?? false,
      thumbnailPath: _normalizeUrl(json['thumbnail_path'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner': owner.toJson(),
        'size': size,
        'mime_type': mimeType,
        'minio_path': minioPath,
        'upload_status': uploadStatus,
        'created_at': createdAt,
        'is_favourite': isFavourite,
        'thumbnail_path': thumbnailPath,
      };

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
}

class FolderModel {
  final String id;
  final String name;
  final UserModel owner;
  final String? parent;
  final String? createdAt;

  const FolderModel({
    required this.id,
    required this.name,
    required this.owner,
    this.parent,
    this.createdAt,
  });

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      owner: UserModel.fromJson(json['owner'] as Map<String, dynamic>? ?? {}),
      parent: json['parent'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner': owner.toJson(),
        'parent': parent,
        'created_at': createdAt,
      };
}

class FileShareModel {
  final int id;
  final UserModel sharedWith;
  final FileModel? file;
  final FolderModel? folder;
  final String? createdAt;

  const FileShareModel({
    required this.id,
    required this.sharedWith,
    this.file,
    this.folder,
    this.createdAt,
  });

  factory FileShareModel.fromJson(Map<String, dynamic> json) {
    return FileShareModel(
      id: json['id'] as int? ?? 0,
      sharedWith: UserModel.fromJson(
          json['shared_with'] as Map<String, dynamic>? ?? {}),
      file: json['file'] != null
          ? FileModel.fromJson(json['file'] as Map<String, dynamic>)
          : null,
      folder: json['folder'] != null
          ? FolderModel.fromJson(json['folder'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'shared_with': sharedWith.toJson(),
        'file': file?.toJson(),
        'folder': folder?.toJson(),
        'created_at': createdAt,
      };
}

class FileShareCreateModel {
  final List<String> phoneNumbers;
  final List<String> fileIds;
  final List<String> folderIds;

  const FileShareCreateModel({
    required this.phoneNumbers,
    this.fileIds = const [],
    this.folderIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'phone_numbers': phoneNumbers,
        'file_ids': fileIds,
        'folder_ids': folderIds,
      };
}

class SharedByMeUserModel {
  final UserModel sharedWith;
  final int sharedCount;

  const SharedByMeUserModel({
    required this.sharedWith,
    required this.sharedCount,
  });

  factory SharedByMeUserModel.fromJson(Map<String, dynamic> json) {
    return SharedByMeUserModel(
      sharedWith: UserModel.fromJson(
          json['shared_with'] as Map<String, dynamic>? ?? {}),
      sharedCount: json['shared_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'shared_with': sharedWith.toJson(),
        'shared_count': sharedCount,
      };
}

class SharedWithMeUserModel {
  final UserModel owner;
  final int sharedCount;

  const SharedWithMeUserModel({
    required this.owner,
    required this.sharedCount,
  });

  factory SharedWithMeUserModel.fromJson(Map<String, dynamic> json) {
    return SharedWithMeUserModel(
      owner:
          UserModel.fromJson(json['owner'] as Map<String, dynamic>? ?? {}),
      sharedCount: json['shared_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'owner': owner.toJson(),
        'shared_count': sharedCount,
      };
}

class ControllerDefaultResponseModel {
  final String message;
  final dynamic result;

  const ControllerDefaultResponseModel({
    required this.message,
    this.result,
  });

  factory ControllerDefaultResponseModel.fromJson(Map<String, dynamic> json) {
    return ControllerDefaultResponseModel(
      message: json['message'] as String? ?? 'Ok',
      result: json['result'],
    );
  }

  Map<String, dynamic> toJson() => {
        'message': message,
        'result': result,
      };
}

class RevokeShareRequestModel {
  final List<String> fileIds;
  final List<String> folderIds;
  final List<String> phoneNumbers;

  const RevokeShareRequestModel({
    this.fileIds = const [],
    this.folderIds = const [],
    this.phoneNumbers = const [],
  });

  Map<String, dynamic> toJson() => {
        'file_ids': fileIds,
        'folder_ids': folderIds,
        if (phoneNumbers.isNotEmpty) 'phone_numbers': phoneNumbers,
      };
}
