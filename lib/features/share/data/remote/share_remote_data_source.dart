import '../models/share_models.dart';

/// Abstract data source for share-related API calls.
abstract class ShareRemoteDataSource {
  Future<List<FileShareModel>> getSharedByMe();
  Future<FileShareModel> shareFiles(FileShareCreateModel body);
  Future<FileShareModel> revokeShare({
    List<String> fileIds = const [],
    List<String> folderIds = const [],
    List<String> phoneNumbers = const [],
  });
  Future<List<SharedByMeUserModel>> getSharedByMeUsers();
  Future<ControllerDefaultResponseModel> getSharedByMeUser(int userId);
  Future<ControllerDefaultResponseModel> getSharedByMeUserFolder(
      int userId, String folderId);
  Future<List<SharedWithMeUserModel>> getSharedWithMe();
  Future<ControllerDefaultResponseModel> getSharedWithMeUser(int userId);
  Future<ControllerDefaultResponseModel> getSharedWithMeUserFolder(
      int userId, String folderId);
}
