import 'package:equatable/equatable.dart';
import '../../data/models/share_models.dart';

/// Events for ShareBloc.
abstract class ShareEvent extends Equatable {
  const ShareEvent();

  @override
  List<Object?> get props => [];
}

class LoadSharedByMe extends ShareEvent {
  const LoadSharedByMe();
}

class ShareFilesEvent extends ShareEvent {
  final FileShareCreateModel body;

  const ShareFilesEvent({required this.body});

  @override
  List<Object?> get props => [body.phoneNumbers, body.fileIds, body.folderIds];
}

class RevokeShare extends ShareEvent {
  final List<String> fileIds;
  final List<String> folderIds;
  final List<String> phoneNumbers;

  const RevokeShare({
    this.fileIds = const [],
    this.folderIds = const [],
    this.phoneNumbers = const [],
  });

  @override
  List<Object?> get props => [fileIds, folderIds, phoneNumbers];
}

class LoadSharedByMeUsers extends ShareEvent {
  const LoadSharedByMeUsers();
}

class LoadSharedByMeUser extends ShareEvent {
  final int userId;

  const LoadSharedByMeUser({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class LoadSharedByMeUserFolder extends ShareEvent {
  final int userId;
  final String folderId;

  const LoadSharedByMeUserFolder({
    required this.userId,
    required this.folderId,
  });

  @override
  List<Object?> get props => [userId, folderId];
}

class LoadSharedWithMe extends ShareEvent {
  const LoadSharedWithMe();
}

class LoadSharedWithMeUser extends ShareEvent {
  final int userId;

  const LoadSharedWithMeUser({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class LoadSharedWithMeUserFolder extends ShareEvent {
  final int userId;
  final String folderId;

  const LoadSharedWithMeUserFolder({
    required this.userId,
    required this.folderId,
  });

  @override
  List<Object?> get props => [userId, folderId];
}
