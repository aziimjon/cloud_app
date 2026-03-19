import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/share_models.dart';
import '../bloc/share_bloc.dart';
import '../bloc/share_event.dart';
import '../bloc/share_state.dart';

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digits = newValue.text.replaceAll(' ', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 9; i++) {
      if (i == 2 || i == 5 || i == 7) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final result = buffer.toString();
    return newValue.copyWith(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

enum _ShareMode { byPhone, byLink }

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
  final _linkNameController = TextEditingController();
  late List<String> _fileIds;
  late List<String> _folderIds;
  final List<String> _phoneNumbers = [];
  bool _isSending = false;
  _ShareMode _mode = _ShareMode.byPhone;

  // После генерации ссылки
  String? _generatedLink;

  @override
  void initState() {
    super.initState();
    _fileIds = List.from(widget.initialFileIds);
    _folderIds = List.from(widget.initialFolderIds);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _linkNameController.dispose();
    super.dispose();
  }

  void _addPhone() {
    final digits = _phoneController.text.replaceAll(' ', '');
    if (digits.length != 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите 9 цифр номера'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final number = '+998$digits';
    if (_phoneNumbers.contains(number)) return;
    setState(() {
      _phoneNumbers.add(number);
      _phoneController.clear();
    });
  }

  void _shareByPhone() {
    if (_phoneNumbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы один номер телефона'),
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

  void _generateLink() {
    final name = _linkNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите название ссылки'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _isSending = true);
    context.read<ShareBloc>().add(
      CreateShareRequestEvent(
        body: ShareRequestCreateModel(
          name: name,
          files: _fileIds,
          folders: _folderIds,
        ),
      ),
    );
  }

  void _copyLink() {
    if (_generatedLink == null) return;
    Clipboard.setData(ClipboardData(text: _generatedLink!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ссылка скопирована'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

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
        } else if (state is ShareRequestCreated) {
          setState(() {
            _isSending = false;
            _generatedLink =
            'https://cloud.zerodev.uz/share-content/${state.request.link}';
          });
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
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.80),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A73E8).withValues(alpha: 0.15),
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
                          'Поделиться (${_fileIds.length + _folderIds.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: textColor,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: textColor, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Mode switcher ────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ModeTab(
                            label: 'По номеру',
                            icon: Icons.phone_rounded,
                            isActive: _mode == _ShareMode.byPhone,
                            isDark: isDark,
                            onTap: () => setState(() {
                              _mode = _ShareMode.byPhone;
                              _generatedLink = null;
                            }),
                          ),
                        ),
                        Expanded(
                          child: _ModeTab(
                            label: 'По ссылке',
                            icon: Icons.link_rounded,
                            isActive: _mode == _ShareMode.byLink,
                            isDark: isDark,
                            onTap: () => setState(() {
                              _mode = _ShareMode.byLink;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Content by mode ──────────────────────────────────────
                  if (_mode == _ShareMode.byPhone)
                    _buildPhoneMode(isDark, textColor)
                  else
                    _buildLinkMode(isDark, textColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── По номеру ──────────────────────────────────────────────────────────────
  Widget _buildPhoneMode(bool isDark, Color textColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: textColor, fontSize: 16),
                onSubmitted: (_) => _addPhone(),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                  _PhoneInputFormatter(),
                ],
                decoration: InputDecoration(
                  prefixText: '+998 ',
                  prefixStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: textColor,
                  ),
                  hintText: '98 765 43 21',
                  hintStyle:
                  TextStyle(color: textColor.withValues(alpha: 0.35)),
                  counterText: '',
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: ElevatedButton(
                onPressed: _addPhone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ),
        if (_phoneNumbers.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _phoneNumbers
                  .map((n) => Chip(
                label: Text(n,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A73E8))),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () =>
                    setState(() => _phoneNumbers.remove(n)),
                backgroundColor:
                const Color(0xFF1A73E8).withValues(alpha: 0.12),
                deleteIconColor: const Color(0xFF1A73E8),
                side: BorderSide(
                    color: const Color(0xFF1A73E8)
                        .withValues(alpha: 0.3)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ))
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _buildInfoRow(isDark),
        const SizedBox(height: 16),
        _buildActionButtons(
          isDark: isDark,
          onAction: _shareByPhone,
          actionLabel: 'Поделиться',
        ),
      ],
    );
  }

  // ── По ссылке ──────────────────────────────────────────────────────────────
  Widget _buildLinkMode(bool isDark, Color textColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Link name field
        TextField(
          controller: _linkNameController,
          style: TextStyle(color: textColor, fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Link name *',
            labelStyle:
            TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 14),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
              const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),

        // Generated link block
        if (_generatedLink != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF1A73E8).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generated link',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _generatedLink!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1A73E8),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _copyLink,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A73E8).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded,
                                size: 14, color: Color(0xFF1A73E8)),
                            SizedBox(width: 4),
                            Text('Copy',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1A73E8),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),
        _buildInfoRow(isDark),
        const SizedBox(height: 16),
        _buildActionButtons(
          isDark: isDark,
          onAction: _generatedLink == null ? _generateLink : _copyLink,
          actionLabel: _generatedLink == null ? 'Generate' : 'Copy link',
          actionIcon: _generatedLink == null
              ? Icons.link_rounded
              : Icons.copy_rounded,
        ),
      ],
    );
  }

  Widget _buildInfoRow(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '${_fileIds.length} файлов, ${_folderIds.length} папок',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons({
    required bool isDark,
    required VoidCallback onAction,
    required String actionLabel,
    IconData? actionIcon,
  }) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _isSending ? null : () => Navigator.pop(context),
            child: Text('Отмена', style: TextStyle(color: textColor)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSending ? null : onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSending
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (actionIcon != null) ...[
                  Icon(actionIcon, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                ],
                Text(actionLabel,
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Mode Tab ──────────────────────────────────────────────────────────────────
class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF1A73E8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? Colors.white
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
