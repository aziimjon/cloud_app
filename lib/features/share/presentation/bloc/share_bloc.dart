import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repository/share_repository.dart';
import 'share_event.dart';
import 'share_state.dart';

/// BLoC for share feature — handles 9 events mapping to Swagger endpoints.
class ShareBloc extends Bloc<ShareEvent, ShareState> {
  final ShareRepository _repository;

  ShareBloc(this._repository) : super(const ShareInitial()) {
    on<LoadSharedByMe>(_onLoadSharedByMe);
    on<ShareFilesEvent>(_onShareFiles);
    on<RevokeShare>(_onRevokeShare);
    on<LoadSharedByMeUsers>(_onLoadSharedByMeUsers);
    on<LoadSharedByMeUser>(_onLoadSharedByMeUser);
    on<LoadSharedByMeUserFolder>(_onLoadSharedByMeUserFolder);
    on<LoadSharedWithMe>(_onLoadSharedWithMe);
    on<LoadSharedWithMeUser>(_onLoadSharedWithMeUser);
    on<LoadSharedWithMeUserFolder>(_onLoadSharedWithMeUserFolder);
  }

  Future<void> _onLoadSharedByMe(
      LoadSharedByMe event, Emitter<ShareState> emit) async {
    emit(const ShareLoading());
    try {
      final shares = await _repository.getSharedByMe();
      emit(SharedByMeLoaded(shares: shares));
    } catch (e) {
      emit(ShareError(message: e.toString()));
    }
  }

  Future<void> _onShareFiles(
      ShareFilesEvent event, Emitter<ShareState> emit) async {
    emit(const ShareLoading());
    try {
      final share = await _repository.shareFiles(event.body);
      emit(ShareSuccess(share: share));
    } catch (e) {
      emit(ShareError(message: e.toString()));
    }
  }

  Future<void> _onRevokeShare(
      RevokeShare event, Emitter<ShareState> emit) async {
    emit(const ShareLoading());
    try {
      final share = await _repository.revokeShare(
        fileIds: event.fileIds,
        folderIds: event.folderIds,
        phoneNumbers: event.phoneNumbers,
      );
      emit(ShareSuccess(share: share));
    } catch (e) {
      emit(ShareError(message: e.toString()));
    }
  }

  Future<void> _onLoadSharedByMeUsers(
      LoadSharedByMeUsers event, Emitter<ShareState> emit) async {
    emit(const ShareLoading());
    try {
      final users = await _repository.getSharedByMeUsers();
      emit(SharedByMeUsersLoaded(users: users));
    } catch (e) {
      emit(ShareError(message: e.toString()));
    }
  }

  Future<void> _onLoadSharedByMeUser(
      LoadSharedByMeUser event, Emitter<ShareState> emit) async {
    emit(const ShareLoading());
    try {
      final response = await _repository.getSharedByMeUser(event.userId);
      emit(SharedUserFilesLoaded(response: response));
    } catch (e) {
      emit(ShareError(message: e.toString()));
    }
  }

  Future<void> _onLoadSharedByMeUserFolder(
      LoadSharedByMeUserFolder event, Emitter<ShareState> emit) async {
    emit(const ShareLoading());
    try {
      final response = await _repository.getSharedByMeUserFolder(
          event.userId, event.folderId);
      emit(SharedUserFilesLoaded(response: response));
    } catch (e) {
      emit(ShareError(message: e.toString()));
    }
  }

  Future<void> _onLoadSharedWithMe(
      LoadSharedWithMe event, Emitter<ShareState> emit) async {
    emit(const ShareLoading());
    try {
      final users = await _repository.getSharedWithMe();
      emit(SharedWithMeLoaded(users: users));
    } catch (e) {
      emit(ShareError(message: e.toString()));
    }
  }

  Future<void> _onLoadSharedWithMeUser(
      LoadSharedWithMeUser event, Emitter<ShareState> emit) async {
    emit(const ShareLoading());
    try {
      final response = await _repository.getSharedWithMeUser(event.userId);
      emit(SharedUserFilesLoaded(response: response));
    } catch (e) {
      emit(ShareError(message: e.toString()));
    }
  }

  Future<void> _onLoadSharedWithMeUserFolder(
      LoadSharedWithMeUserFolder event, Emitter<ShareState> emit) async {
    emit(const ShareLoading());
    try {
      final response = await _repository.getSharedWithMeUserFolder(
          event.userId, event.folderId);
      emit(SharedUserFilesLoaded(response: response));
    } catch (e) {
      emit(ShareError(message: e.toString()));
    }
  }
}
