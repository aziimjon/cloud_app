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

/// Page showing users who shared files with me (Shared with me → users list).
class SharedWithMePage extends StatelessWidget {
  const SharedWithMePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = ShareBloc(
          ShareRepositoryImpl(
            ShareRemoteDataSourceImpl(DioClient.instance),
          ),
        );
        bloc.add(const LoadSharedWithMe());
        return bloc;
      },
      child: const _SharedWithMeView(),
    );
  }
}

class _SharedWithMeView extends StatelessWidget {
  const _SharedWithMeView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          'Shared with me',
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
                .add(const LoadSharedWithMe()),
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
          if (state is SharedWithMeLoaded) {
            if (state.users.isEmpty) {
              return _buildEmpty(cs);
            }
            return RefreshIndicator(
              onRefresh: () async => context
                  .read<ShareBloc>()
                  .add(const LoadSharedWithMe()),
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
            'Никто не делился файлами',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Когда кто-то поделится файлом — они появятся здесь',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
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
                .add(const LoadSharedWithMe()),
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
      BuildContext context, ColorScheme cs, SharedWithMeUserModel user) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShareUserFilesPage(
              userId: user.owner.id,
              userName: user.owner.fullName,
              isSharedByMe: false,
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
                colors: [Color(0xFF34A853), Color(0xFF4CAF50)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                user.owner.fullName.isNotEmpty
                    ? user.owner.fullName[0].toUpperCase()
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
            user.owner.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            '${user.owner.phoneNumber} · ${user.sharedCount} файлов',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF34A853).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Открыть',
              style: TextStyle(
                color: Color(0xFF34A853),
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
