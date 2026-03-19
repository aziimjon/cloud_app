import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../features/home/data/home_repository.dart';
import '../../../../features/home/presentation/photo_viewer_page.dart';
import '../../../../features/home/presentation/video_player_page.dart';
import '../../data/remote/share_remote_data_source_impl.dart';
import '../../data/repository/share_repository_impl.dart';
import '../bloc/share_bloc.dart';
import '../bloc/share_event.dart';
import '../bloc/share_state.dart';

/// Page showing files/folders shared with/by a specific user.
class ShareUserFilesPage extends StatefulWidget {
  final int userId;
  final String userName;
  final bool isSharedByMe;

  const ShareUserFilesPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.isSharedByMe,
  });

  @override
  State<ShareUserFilesPage> createState() => _ShareUserFilesPageState();
}

class _ShareUserFilesPageState extends State<ShareUserFilesPage> {
  final _homeRepo = HomeRepository();
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final token = await SecureStorage.getAccessToken();
    if (mounted) setState(() => _authToken = token);
  }

  Future<void> _openImage(
      BuildContext ctx,
      List<Map<String, dynamic>> allItems,
      String fileId,
      ) async {
    final imageItems = allItems
        .where((item) => _mimeOf(item).startsWith('image/'))
        .toList();

    final files = imageItems
        .map((item) {
      final id = item['id']?.toString() ?? '';
      return (
      // FIX: pass empty url — PhotoViewerPage will load full URL via
      // onNeedFullUrl. This prevents thumbnail→full flicker.
      // Thumbnail is only used as fallback when fileId is empty.
      url: id.isNotEmpty ? '' : (_normalizeUrl(item['thumbnail_path']?.toString()) ?? ''),
      name: _nameOf(item),
      fileId: id,
      );
    })
        .toList();

    final idx = files.indexWhere((f) => f.fileId == fileId);
    if (!mounted) return;

    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => PhotoViewerPage(
          files: files,
          initialIndex: idx < 0 ? 0 : idx,
          authToken: _authToken,
          onNeedFullUrl: (id) => _homeRepo.getPreviewUrl(id),
        ),
      ),
    );
  }

  Future<void> _openVideo(BuildContext ctx, String fileId, String name) async {
    final url = await _homeRepo.getPreviewUrl(fileId);
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть видео')),
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          videoUrl: url,
          fileName: name,
          authToken: _authToken,
        ),
      ),
    );
  }

  String? _normalizeUrl(String? raw) {
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

  String _mimeOf(Map<String, dynamic> item) {
    final raw = item['mime_type']?.toString() ?? '';
    try {
      return utf8.decode(base64.decode(raw)).toLowerCase();
    } catch (_) {
      return raw.toLowerCase();
    }
  }

  String _nameOf(Map<String, dynamic> item) {
    final raw = item['name']?.toString() ?? '';
    try {
      return utf8.decode(base64.decode(raw));
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = ShareBloc(
          ShareRepositoryImpl(
            ShareRemoteDataSourceImpl(DioClient.instance),
          ),
        );
        if (widget.isSharedByMe) {
          bloc.add(LoadSharedByMeUser(userId: widget.userId));
        } else {
          bloc.add(LoadSharedWithMeUser(userId: widget.userId));
        }
        return bloc;
      },
      child: Builder(
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          return Scaffold(
            backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: cs.surface,
              elevation: 0,
              iconTheme: IconThemeData(color: cs.onSurface),
              title: Text(
                widget.userName,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.refresh, color: cs.onSurface),
                  onPressed: () {
                    if (widget.isSharedByMe) {
                      ctx
                          .read<ShareBloc>()
                          .add(LoadSharedByMeUser(userId: widget.userId));
                    } else {
                      ctx
                          .read<ShareBloc>()
                          .add(LoadSharedWithMeUser(userId: widget.userId));
                    }
                  },
                ),
              ],
            ),
            body: BlocBuilder<ShareBloc, ShareState>(
              builder: (ctx2, state) {
                if (state is ShareLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is ShareError) {
                  return _buildError(ctx2, state.message);
                }
                if (state is SharedUserFilesLoaded) {
                  return _buildContent(ctx2, cs, state.response.result);
                }
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext ctx, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              if (widget.isSharedByMe) {
                ctx
                    .read<ShareBloc>()
                    .add(LoadSharedByMeUser(userId: widget.userId));
              } else {
                ctx
                    .read<ShareBloc>()
                    .add(LoadSharedWithMeUser(userId: widget.userId));
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext ctx, ColorScheme cs, dynamic result) {
    List<dynamic> items = [];
    if (result is List) {
      items = result;
    } else if (result is Map) {
      items = (result['results'] as List<dynamic>?) ?? [];
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Здесь пока пусто',
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    final rawItems = items.map((e) => e as Map<String, dynamic>).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rawItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = rawItems[i];
        final isFolder = item['type'] == 'folder';
        return _buildItemCard(ctx, cs, item, isFolder, rawItems);
      },
    );
  }

  Widget _buildItemCard(
      BuildContext ctx,
      ColorScheme cs,
      Map<String, dynamic> item,
      bool isFolder,
      List<Map<String, dynamic>> allItems,
      ) {
    final name = _nameOf(item);
    final id = item['id']?.toString() ?? '';
    final mimeType = _mimeOf(item);
    final thumbUrl = _normalizeUrl(item['thumbnail_path']?.toString());
    final isImage = mimeType.startsWith('image/');
    final isVideo = mimeType.startsWith('video/');

    return GestureDetector(
      onTap: () {
        if (isFolder) {
          if (widget.isSharedByMe) {
            ctx.read<ShareBloc>().add(
                LoadSharedByMeUserFolder(userId: widget.userId, folderId: id));
          } else {
            ctx.read<ShareBloc>().add(LoadSharedWithMeUserFolder(
                userId: widget.userId, folderId: id));
          }
        } else if (isImage) {
          _openImage(ctx, allItems, id);
        } else if (isVideo) {
          _openVideo(ctx, id, name);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          leading: _buildLeading(isFolder, isImage, isVideo, thumbUrl),
          title: Text(
            name,
            style:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isFolder
              ? const Icon(Icons.chevron_right, color: Colors.grey)
              : (isImage || isVideo)
              ? Icon(
            isVideo
                ? Icons.play_circle_outline_rounded
                : Icons.open_in_new_rounded,
            color: Colors.grey[400],
            size: 20,
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildLeading(
      bool isFolder, bool isImage, bool isVideo, String? thumbUrl) {
    if (isFolder) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.folder_rounded, color: Colors.amber, size: 22),
      );
    }

    if (thumbUrl != null && thumbUrl.isNotEmpty && (isImage || isVideo)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: thumbUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => _iconBox(isVideo),
                errorWidget: (_, __, ___) => _iconBox(isVideo),
              ),
              if (isVideo)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEA4335),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 10),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return _iconBox(isVideo, isImage: isImage);
  }

  Widget _iconBox(bool isVideo, {bool isImage = false}) {
    final color = isVideo
        ? const Color(0xFFEA4335)
        : isImage
        ? const Color(0xFF34A853)
        : const Color(0xFF1A73E8);
    final icon = isVideo
        ? Icons.videocam_rounded
        : isImage
        ? Icons.image_rounded
        : Icons.insert_drive_file_rounded;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}