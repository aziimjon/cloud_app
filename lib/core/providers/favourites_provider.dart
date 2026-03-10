import 'package:flutter/material.dart';
import '../../features/home/data/home_repository.dart';
import '../../features/home/data/models/file_model.dart';

class FavouritesProvider extends ChangeNotifier {
  static final FavouritesProvider instance = FavouritesProvider._();
  FavouritesProvider._();

  final HomeRepository _repo = HomeRepository();

  final Set<String> _favouriteIds = {};
  List<FileModel> _favouriteFiles = [];
  bool _isLoading = false;
  String? _error;

  Set<String> get favouriteIds => _favouriteIds;
  List<FileModel> get favouriteFiles => _favouriteFiles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool isFavourite(String fileId) => _favouriteIds.contains(fileId);

  Future<void> loadFavourites() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final favList = await _repo.getFavouriteFiles();
      final List<FileModel> files = [];
      final Set<String> newIds = {};

      for (final item in favList) {
        if (item is Map<String, dynamic>) {
          final fileData = item['file'];
          if (fileData is Map<String, dynamic>) {
            final fm = FileModel.fromJson(fileData);
            files.add(
              fm.copyWith(
                isFavourite: true,
                favouriteId: item['id']?.toString(), // the record ID
              ),
            );
            newIds.add(fm.id); // the file UUID
          }
        }
      }

      _favouriteFiles = files;
      _favouriteIds.clear();
      _favouriteIds.addAll(newIds);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavourite(FileModel file) async {
    final bool wasFav = _favouriteIds.contains(file.id);

    // Optimistic update
    if (wasFav) {
      _favouriteIds.remove(file.id);
      _favouriteFiles.removeWhere((f) => f.id == file.id);
    } else {
      _favouriteIds.add(file.id);
      _favouriteFiles.add(file.copyWith(isFavourite: true));
    }
    notifyListeners();

    try {
      if (wasFav) {
        // Send file ID (UUID) not the record ID, as per backend expectation
        await _repo.removeFromFavourites(file.id);
        await loadFavourites();
      } else {
        await _repo.addToFavourites(file.id);
        // We probably need the new favouriteId record, so we reload to sync state
        await loadFavourites();
      }
    } catch (e) {
      // Revert optimistic update on failure
      if (wasFav) {
        _favouriteIds.add(file.id);
        _favouriteFiles.add(file.copyWith(isFavourite: true));
      } else {
        _favouriteIds.remove(file.id);
        _favouriteFiles.removeWhere((f) => f.id == file.id);
      }
      notifyListeners();
      rethrow;
    }
  }
}
