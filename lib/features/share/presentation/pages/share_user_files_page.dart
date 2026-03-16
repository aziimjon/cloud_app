import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/remote/share_remote_data_source_impl.dart';
import '../../data/repository/share_repository_impl.dart';
import '../bloc/share_bloc.dart';
import '../bloc/share_event.dart';
import '../bloc/share_state.dart';

/// Page showing files/folders shared with/by a specific user.
class ShareUserFilesPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = ShareBloc(
          ShareRepositoryImpl(
            ShareRemoteDataSourceImpl(DioClient.instance),
          ),
        );
        if (isSharedByMe) {
          bloc.add(LoadSharedByMeUser(userId: userId));
        } else {
          bloc.add(LoadSharedWithMeUser(userId: userId));
        }
        return bloc;
      },
      child: _ShareUserFilesView(
        userId: userId,
        userName: userName,
        isSharedByMe: isSharedByMe,
      ),
    );
  }
}

class _ShareUserFilesView extends StatelessWidget {
  final int userId;
  final String userName;
  final bool isSharedByMe;

  const _ShareUserFilesView({
    required this.userId,
    required this.userName,
    required this.isSharedByMe,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: cs.onSurface),
        title: Text(
          userName,
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: cs.onSurface),
            onPressed: () {
              if (isSharedByMe) {
                context
                    .read<ShareBloc>()
                    .add(LoadSharedByMeUser(userId: userId));
              } else {
                context
                    .read<ShareBloc>()
                    .add(LoadSharedWithMeUser(userId: userId));
              }
            },
          ),
        ],
      ),
      body: BlocBuilder<ShareBloc, ShareState>(
        builder: (context, state) {
          if (state is ShareLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ShareError) {
            return _buildError(context, state.message);
          }
          if (state is SharedUserFilesLoaded) {
            return _buildContent(context, cs, state.response.result);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
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
              if (isSharedByMe) {
                context
                    .read<ShareBloc>()
                    .add(LoadSharedByMeUser(userId: userId));
              } else {
                context
                    .read<ShareBloc>()
                    .add(LoadSharedWithMeUser(userId: userId));
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

  Widget _buildContent(
      BuildContext context, ColorScheme cs, dynamic result) {
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
            Text(
              'Здесь пока пусто',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = items[i] as Map<String, dynamic>;
        final isFolder = item['type'] == 'folder';
        return _buildItemCard(context, cs, item, isFolder);
      },
    );
  }

  Widget _buildItemCard(BuildContext context, ColorScheme cs,
      Map<String, dynamic> item, bool isFolder) {
    final rawName = item['name'] ?? '';
    String name = rawName;
    try {
      name = utf8.decode(base64.decode(rawName));
    } catch (_) {
      name = rawName;
    }
    final id = item['id']?.toString() ?? '';

    return GestureDetector(
      onTap: isFolder
          ? () {
              if (isSharedByMe) {
                context.read<ShareBloc>().add(
                    LoadSharedByMeUserFolder(userId: userId, folderId: id));
              } else {
                context.read<ShareBloc>().add(
                    LoadSharedWithMeUserFolder(userId: userId, folderId: id));
              }
            }
          : null,
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
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isFolder
                  ? Colors.amber.withValues(alpha: 0.15)
                  : const Color(0xFF1A73E8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isFolder ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
              color: isFolder ? Colors.amber : const Color(0xFF1A73E8),
              size: 22,
            ),
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isFolder
              ? const Icon(Icons.chevron_right, color: Colors.grey)
              : null,
        ),
      ),
    );
  }
}
