import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/models/share_models.dart';
import '../../data/remote/share_remote_data_source_impl.dart';
import '../../data/repository/share_repository_impl.dart';
import '../bloc/share_bloc.dart';
import '../bloc/share_event.dart';
import '../bloc/share_state.dart';
import 'share_user_files_page.dart';
import '../widgets/share_dialog.dart';

/// Page showing users with whom I shared files (Shared by me → users list).
class SharedByMePage extends StatelessWidget {
  const SharedByMePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = ShareBloc(
          ShareRepositoryImpl(
            ShareRemoteDataSourceImpl(DioClient.instance),
          ),
        );
        bloc.add(const LoadSharedByMeUsers());
        return bloc;
      },
      child: const _SharedByMeView(),
    );
  }
}

class _SharedByMeView extends StatelessWidget {
  const _SharedByMeView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          'Shared by me',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: cs.onSurface),
            onPressed: () => context
                .read<ShareBloc>()
                .add(const LoadSharedByMeUsers()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A73E8),
        child: const Icon(Icons.share, color: Colors.white),
        onPressed: () => showDialog(
          context: context,
          builder: (_) => BlocProvider.value(
            value: context.read<ShareBloc>(),
            child: const ShareDialog(),
          ),
        ),
      ),
      body: BlocBuilder<ShareBloc, ShareState>(
        builder: (context, state) {
          if (state is ShareLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ShareError) {
            return _buildError(context, state.message);
          }
          if (state is SharedByMeUsersLoaded) {
            if (state.users.isEmpty) {
              return _buildEmpty(cs);
            }
            return RefreshIndicator(
              onRefresh: () async => context
                  .read<ShareBloc>()
                  .add(const LoadSharedByMeUsers()),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _buildUserCard(context, cs, state.users[i]),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.people_rounded,
              size: 40,
              color: Color(0xFF1A73E8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Вы ещё ни с кем не делились',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Нажмите + чтобы поделиться файлами',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ],
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
          Text(message, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context
                .read<ShareBloc>()
                .add(const LoadSharedByMeUsers()),
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

  Widget _buildUserCard(
      BuildContext context, ColorScheme cs, SharedByMeUserModel user) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShareUserFilesPage(
              userId: user.sharedWith.id,
              userName: user.sharedWith.fullName,
              isSharedByMe: true,
            ),
          ),
        );
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A73E8), Color(0xFF4A90E2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                user.sharedWith.fullName.isNotEmpty
                    ? user.sharedWith.fullName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          title: Text(
            user.sharedWith.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            '${user.sharedWith.phoneNumber} · ${user.sharedCount} файлов',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Открыть',
              style: TextStyle(
                color: Color(0xFF1A73E8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
