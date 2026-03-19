import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/share_models.dart';
import '../data/remote/share_remote_data_source_impl.dart';
import '../data/repository/share_repository_impl.dart';
import 'bloc/share_bloc.dart';
import 'bloc/share_event.dart';
import 'bloc/share_state.dart';
import '../../../core/network/dio_client.dart';

class ShareRequestsPage extends StatelessWidget {
  const ShareRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ShareBloc(
        ShareRepositoryImpl(
          ShareRemoteDataSourceImpl(DioClient.instance),
        ),
      )..add(const LoadShareRequests()),
      child: const _ShareRequestsView(),
    );
  }
}

class _ShareRequestsView extends StatefulWidget {
  const _ShareRequestsView();

  @override
  State<_ShareRequestsView> createState() => _ShareRequestsViewState();
}

class _ShareRequestsViewState extends State<_ShareRequestsView> {
  int? _selectedRequestId;
  ShareRequestDetailModel? _selectedDetail;
  bool _loadingDetail = false;
  List<ShareRequestListModel> _requests = [];

  void _selectRequest(BuildContext context, int id) {
    setState(() {
      _selectedRequestId = id;
      _selectedDetail = null;
      _loadingDetail = true;
    });
    context.read<ShareBloc>().add(LoadShareRequestDetail(id: id));
  }

  void _copyLink(String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ссылка скопирована'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Share Requests',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: cs.onSurface),
            onPressed: () =>
                context.read<ShareBloc>().add(const LoadShareRequests()),
          ),
        ],
      ),
      body: BlocConsumer<ShareBloc, ShareState>(
        listener: (context, state) {
          if (state is ShareRequestsLoaded) {
            setState(() => _requests = state.requests);
          } else if (state is ShareRequestDetailLoaded) {
            setState(() {
              _selectedDetail = state.detail;
              _loadingDetail = false;
            });
          } else if (state is PermissionStatusUpdated) {
            if (_selectedRequestId != null) {
              context
                  .read<ShareBloc>()
                  .add(LoadShareRequestDetail(id: _selectedRequestId!));
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.permission.status == 'approved'
                    ? 'Доступ одобрен'
                    : 'Доступ отклонён'),
                backgroundColor: state.permission.status == 'approved'
                    ? Colors.green
                    : Colors.red,
              ),
            );
          } else if (state is ShareError) {
            setState(() => _loadingDetail = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ShareLoading && _requests.isEmpty && _selectedDetail == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_requests.isEmpty && state is! ShareLoading) {
            return _buildEmpty(cs);
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<ShareBloc>().add(const LoadShareRequests());
            },
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.link_rounded,
                              color: Colors.blue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Share Requests',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: cs.onSurface,
                                ),
                              ),
                              Text(
                                'Review links and approve access',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_requests.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_requests.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Requests list
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                        final req = _requests[i];
                        final isSelected = req.id == _selectedRequestId;
                        return _RequestCard(
                          request: req,
                          isSelected: isSelected,
                          onTap: () => _selectRequest(context, req.id),
                        );
                      },
                      childCount: _requests.length,
                    ),
                  ),
                ),

                // Detail loading
                if (_loadingDetail)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_selectedDetail != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _DetailPanel(
                        detail: _selectedDetail!,
                        isDark: isDark,
                        cs: cs,
                        onCopy: _copyLink,
                        onUpdatePermission: (permId, status) {
                          context.read<ShareBloc>().add(
                            UpdatePermissionStatus(
                              permissionId: permId,
                              status: status,
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          );
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child:
            const Icon(Icons.link_off_rounded, size: 48, color: Colors.blue),
          ),
          const SizedBox(height: 16),
          Text(
            'Нет share requests',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Поделитесь файлами по ссылке\nи они появятся здесь',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Request Card ──────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final ShareRequestListModel request;
  final bool isSelected;
  final VoidCallback onTap;

  const _RequestCard({
    required this.request,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.08)
              : cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : cs.onSurface.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
              const Icon(Icons.link_rounded, color: Colors.blue, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'https://cloud.zerodev.uz/share-content/${request.link}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isSelected ? Colors.blue : cs.onSurface.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Detail Panel ──────────────────────────────────────────────────────────────
class _DetailPanel extends StatefulWidget {
  final ShareRequestDetailModel detail;
  final bool isDark;
  final ColorScheme cs;
  final void Function(String) onCopy;
  final void Function(int permId, String status) onUpdatePermission;

  const _DetailPanel({
    required this.detail,
    required this.isDark,
    required this.cs,
    required this.onCopy,
    required this.onUpdatePermission,
  });

  @override
  State<_DetailPanel> createState() => _DetailPanelState();
}

class _DetailPanelState extends State<_DetailPanel> {
  String _permFilter = 'all';

  List<ShareRequestPermission> get _filteredPerms {
    if (_permFilter == 'all') return widget.detail.permissions;
    return widget.detail.permissions
        .where((p) => p.status == _permFilter)
        .toList();
  }

  int _count(String status) => status == 'all'
      ? widget.detail.permissions.length
      : widget.detail.permissions.where((p) => p.status == status).length;

  @override
  Widget build(BuildContext context) {
    final link =
        'https://cloud.zerodev.uz/share-content/${widget.detail.link}';
    final cs = widget.cs;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share request details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  'Request #${widget.detail.id}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),

          // Link name + owner
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LINK NAME',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.4),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.detail.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue,
                        child: Text(
                          widget.detail.owner.fullName.isNotEmpty
                              ? widget.detail.owner.fullName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.detail.owner.fullName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        widget.detail.owner.phoneNumber,
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Share link
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHARE LINK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.4),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: cs.onSurface.withValues(alpha: 0.08)),
                        ),
                        child: Text(
                          link,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.blue),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => widget.onCopy(link),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                        Icon(Icons.copy_rounded, size: 18, color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Permission requests
          if (widget.detail.permissions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Text(
                    'PERMISSION REQUESTS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.4),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.detail.permissions.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filter tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _PermFilterTab(
                      label: 'All',
                      count: _count('all'),
                      isActive: _permFilter == 'all',
                      onTap: () => setState(() => _permFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _PermFilterTab(
                      label: 'Pending',
                      count: _count('pending'),
                      isActive: _permFilter == 'pending',
                      color: Colors.orange,
                      onTap: () => setState(() => _permFilter = 'pending'),
                    ),
                    const SizedBox(width: 8),
                    _PermFilterTab(
                      label: 'Approved',
                      count: _count('approved'),
                      isActive: _permFilter == 'approved',
                      color: Colors.green,
                      onTap: () => setState(() => _permFilter = 'approved'),
                    ),
                    const SizedBox(width: 8),
                    _PermFilterTab(
                      label: 'Rejected',
                      count: _count('rejected'),
                      isActive: _permFilter == 'rejected',
                      color: Colors.red,
                      onTap: () => setState(() => _permFilter = 'rejected'),
                    ),
                  ],
                ),
              ),
            ),

            // Permission cards
            ..._filteredPerms.map(
                  (perm) => _PermissionCard(
                permission: perm,
                cs: cs,
                isDark: widget.isDark,
                onUpdate: widget.onUpdatePermission,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ── Perm Filter Tab ───────────────────────────────────────────────────────────
class _PermFilterTab extends StatelessWidget {
  final String label;
  final int count;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _PermFilterTab({
    required this.label,
    required this.count,
    required this.isActive,
    this.color = Colors.blue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? color : Colors.grey,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                color: isActive ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Permission Card ───────────────────────────────────────────────────────────
class _PermissionCard extends StatelessWidget {
  final ShareRequestPermission permission;
  final ColorScheme cs;
  final bool isDark;
  final void Function(int permId, String status) onUpdate;

  const _PermissionCard({
    required this.permission,
    required this.cs,
    required this.isDark,
    required this.onUpdate,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  void _showReviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Review access request',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose whether this user should get access to the shared content.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue,
                    child: Text(
                      permission.requester.fullName.length >= 2
                          ? permission.requester.fullName
                          .substring(0, 2)
                          .toUpperCase()
                          : permission.requester.fullName
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          permission.requester.fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          permission.requester.phoneNumber,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(permission.status)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel(permission.status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(permission.status),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              onUpdate(permission.id, 'rejected');
            },
            icon: const Icon(Icons.close, size: 16, color: Colors.red),
            label: const Text('Reject',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              onUpdate(permission.id, 'approved');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon:
            const Icon(Icons.check, size: 16, color: Colors.white),
            label: const Text('Approve',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blue.withValues(alpha: 0.15),
                child: Text(
                  permission.requester.fullName.length >= 2
                      ? permission.requester.fullName
                      .substring(0, 2)
                      .toUpperCase()
                      : permission.requester.fullName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      permission.requester.fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined,
                            size: 12,
                            color: cs.onSurface.withValues(alpha: 0.4)),
                        const SizedBox(width: 4),
                        Text(
                          permission.requester.phoneNumber,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                  _statusColor(permission.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(permission.status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(permission.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showReviewDialog(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: BorderSide(color: cs.onSurface.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Review',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}