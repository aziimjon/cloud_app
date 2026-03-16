import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/share_models.dart';
import '../bloc/share_bloc.dart';
import '../bloc/share_event.dart';
import '../bloc/share_state.dart';

/// Formats phone input as: "XX XXX XX XX" (9 digits max).
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

/// Crystal-style dialog for sharing files/folders with users by phone numbers.
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

  void _share() {
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
                  // 1. Header
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
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Phone input + add button
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
                            hintStyle: TextStyle(
                              color: textColor.withValues(alpha: 0.35),
                            ),
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
                              horizontal: 14,
                              vertical: 14,
                            ),
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
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                    ],
                  ),

                  // 3. Phone chips
                  if (_phoneNumbers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _phoneNumbers
                            .map(
                              (n) => Chip(
                                label: Text(
                                  n,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1A73E8),
                                  ),
                                ),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () =>
                                    setState(() => _phoneNumbers.remove(n)),
                                backgroundColor: const Color(0xFF1A73E8)
                                    .withValues(alpha: 0.12),
                                deleteIconColor: const Color(0xFF1A73E8),
                                side: BorderSide(
                                  color: const Color(0xFF1A73E8)
                                      .withValues(alpha: 0.3),
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.10),
                  ),
                  const SizedBox(height: 8),

                  // 4. Info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_fileIds.length} файлов, ${_folderIds.length} папок',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed:
                              _isSending ? null : () => Navigator.pop(context),
                          child: Text(
                            'Отмена',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSending ? null : _share,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A73E8),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
