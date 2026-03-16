import 'package:equatable/equatable.dart';
import '../../data/models/share_models.dart';

/// States for ShareBloc.
abstract class ShareState extends Equatable {
  const ShareState();

  @override
  List<Object?> get props => [];
}

class ShareInitial extends ShareState {
  const ShareInitial();
}

class ShareLoading extends ShareState {
  const ShareLoading();
}

class SharedByMeLoaded extends ShareState {
  final List<FileShareModel> shares;

  const SharedByMeLoaded({required this.shares});

  @override
  List<Object?> get props => [shares];
}

class SharedByMeUsersLoaded extends ShareState {
  final List<SharedByMeUserModel> users;

  const SharedByMeUsersLoaded({required this.users});

  @override
  List<Object?> get props => [users];
}

class SharedWithMeLoaded extends ShareState {
  final List<SharedWithMeUserModel> users;

  const SharedWithMeLoaded({required this.users});

  @override
  List<Object?> get props => [users];
}

class SharedUserFilesLoaded extends ShareState {
  final ControllerDefaultResponseModel response;

  const SharedUserFilesLoaded({required this.response});

  @override
  List<Object?> get props => [response.message, response.result];
}

class ShareSuccess extends ShareState {
  final FileShareModel share;

  const ShareSuccess({required this.share});

  @override
  List<Object?> get props => [share.id];
}

class ShareError extends ShareState {
  final String message;

  const ShareError({required this.message});

  @override
  List<Object?> get props => [message];
}
