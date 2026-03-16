import '../models/share_models.dart';
import '../remote/share_remote_data_source.dart';
import 'share_repository.dart';

/// Repository implementation that delegates to [ShareRemoteDataSource].
class ShareRepositoryImpl implements ShareRepository {
  final ShareRemoteDataSource _remoteDataSource;

  ShareRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<FileShareModel>> getSharedByMe() async {
    try {
      return await _remoteDataSource.getSharedByMe();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<FileShareModel> shareFiles(FileShareCreateModel body) async {
    try {
      return await _remoteDataSource.shareFiles(body);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<FileShareModel> revokeShare({
    List<String> fileIds = const [],
    List<String> folderIds = const [],
    List<String> phoneNumbers = const [],
  }) async {
    try {
      return await _remoteDataSource.revokeShare(
        fileIds: fileIds,
        folderIds: folderIds,
        phoneNumbers: phoneNumbers,
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<List<SharedByMeUserModel>> getSharedByMeUsers() async {
    try {
      return await _remoteDataSource.getSharedByMeUsers();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<ControllerDefaultResponseModel> getSharedByMeUser(int userId) async {
    try {
      return await _remoteDataSource.getSharedByMeUser(userId);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<ControllerDefaultResponseModel> getSharedByMeUserFolder(
      int userId, String folderId) async {
    try {
      return await _remoteDataSource.getSharedByMeUserFolder(userId, folderId);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<List<SharedWithMeUserModel>> getSharedWithMe() async {
    try {
      return await _remoteDataSource.getSharedWithMe();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<ControllerDefaultResponseModel> getSharedWithMeUser(
      int userId) async {
    try {
      return await _remoteDataSource.getSharedWithMeUser(userId);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<ControllerDefaultResponseModel> getSharedWithMeUserFolder(
      int userId, String folderId) async {
    try {
      return await _remoteDataSource.getSharedWithMeUserFolder(
          userId, folderId);
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
