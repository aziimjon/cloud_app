enum SyncStatus { pending, uploading, done, failed }

class SyncTask {
  final int? id;
  final String localId;
  final String filePath;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String? sha256;
  final SyncStatus status;
  final int retryCount;
  final String? serverUuid;
  final int createdAt;
  final int updatedAt;

  const SyncTask({
    this.id,
    required this.localId,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    this.sha256,
    this.status = SyncStatus.pending,
    this.retryCount = 0,
    this.serverUuid,
    required this.createdAt,
    required this.updatedAt,
  });

  SyncTask copyWith({
    int? id,
    String? localId,
    String? filePath,
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? sha256,
    SyncStatus? status,
    int? retryCount,
    String? serverUuid,
    int? createdAt,
    int? updatedAt,
  }) {
    return SyncTask(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      sha256: sha256 ?? this.sha256,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      serverUuid: serverUuid ?? this.serverUuid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'local_id': localId,
      'file_path': filePath,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'sha256': sha256,
      'status': status.name,
      'retry_count': retryCount,
      'server_uuid': serverUuid,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory SyncTask.fromMap(Map<String, dynamic> map) {
    return SyncTask(
      id: map['id'] as int?,
      localId: map['local_id'] as String,
      filePath: map['file_path'] as String,
      fileName: map['file_name'] as String,
      fileSize: map['file_size'] as int,
      mimeType: map['mime_type'] as String,
      sha256: map['sha256'] as String?,
      status: SyncStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String),
        orElse: () => SyncStatus.pending,
      ),
      retryCount: map['retry_count'] as int? ?? 0,
      serverUuid: map['server_uuid'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }
}
