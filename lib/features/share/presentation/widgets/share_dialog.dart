import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/share_models.dart';
import '../bloc/share_bloc.dart';
import '../bloc/share_event.dart';
import '../bloc/share_state.dart';

/// Dialog for sharing files/folders with users by phone numbers.
class ShareDialog extends StatefulWidget {
  final List<String> initialFileIds;
  final List<String> initialFolderIds;

  const ShareDialog({
    super.key,
    this.initialFileIds = const [],
    this.initialFolderIds = const [],
  });

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  final _phoneController = TextEditingController();
  late List<String> _fileIds;
  late List<String> _folderIds;
  final List<String> _phoneNumbers = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fileIds = List.from(widget.initialFileIds);
    _folderIds = List.from(widget.initialFolderIds);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _addPhone() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    if (_phoneNumbers.contains(phone)) return;
    setState(() {
      _phoneNumbers.add(phone);
      _phoneController.clear();
    });
  }

  void _removePhone(String phone) {
    setState(() => _phoneNumbers.remove(phone));
  }

  void _share() {
    if (_phoneNumbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы один номер'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    context.read<ShareBloc>().add(
          ShareFilesEvent(
            body: FileShareCreateModel(
              phoneNumbers: _phoneNumbers,
              fileIds: _fileIds,
              folderIds: _folderIds,
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalItems = _fileIds.length + _folderIds.length;

    return BlocListener<ShareBloc, ShareState>(
      listener: (context, state) {
        if (state is ShareSuccess) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Поделились успешно'),
              backgroundColor: Color(0xFF34A853),
            ),
          );
        } else if (state is ShareError) {
          setState(() => _isSending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: cs.surface,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.share_rounded,
                color: Color(0xFF1A73E8),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                totalItems > 0
                    ? 'Поделиться ($totalItems)'
                    : 'Поделиться',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Phone input + add button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: cs.onSurface),
                      onSubmitted: (_) => _addPhone(),
                      decoration: InputDecoration(
                        hintText: '+998 ...',
                        hintStyle: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.4)),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF1A73E8),
                            width: 1.5,
                          ),
                        ),
                        prefixIcon:
                            const Icon(Icons.phone, color: Color(0xFF1A73E8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _addPhone,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('+',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),

              // Phone chips
              if (_phoneNumbers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Номера телефонов:',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _phoneNumbers
                      .map((phone) => Chip(
                            label: Text(phone,
                                style: const TextStyle(fontSize: 12)),
                            deleteIcon:
                                const Icon(Icons.close, size: 16),
                            onDeleted: () => _removePhone(phone),
                            backgroundColor: cs.surfaceContainerHighest,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],

              // Selected items info
              if (totalItems > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16,
                          color: cs.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_fileIds.length} файлов, ${_folderIds.length} папок',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSending ? null : () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: _isSending ? null : _share,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Поделиться',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }
}
