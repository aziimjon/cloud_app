import '../models/share_models.dart';

/// Abstract repository for share feature.
abstract class ShareRepository {
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
      int userId,
      String folderId,
      );

  Future<List<SharedWithMeUserModel>> getSharedWithMe();

  Future<ControllerDefaultResponseModel> getSharedWithMeUser(int userId);

  Future<ControllerDefaultResponseModel> getSharedWithMeUserFolder(
      int userId,
      String folderId,
      );

  // ================= NEW SHARE REQUEST METHODS =================

  Future<ShareRequestListModel> createShareRequest(
      ShareRequestCreateModel body,
      );

  Future<List<ShareRequestListModel>> getShareRequests();

  Future<ShareRequestDetailModel> getShareRequestDetail(int id);

  Future<ShareRequestPermission> updatePermissionStatus({
    required int permissionId,
    required String status,
  });
}