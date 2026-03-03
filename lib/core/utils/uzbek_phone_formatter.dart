import 'package:flutter/services.dart';

/// Formatter for Uzbek phone numbers.
/// Format: +998 XX XXX XX XX
/// - Prefix "+998 " is non-editable
/// - Accepts exactly 9 digits after prefix (12 total)
/// - Auto-inserts spaces at correct positions
class UzbekPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Извлекаем только цифры
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Гарантируем что начинается с 998
    String digits;
    if (digitsOnly.startsWith('998')) {
      digits = digitsOnly;
    } else if (digitsOnly.length <= 3) {
      digits = '998';
    } else {
      digits = '998${digitsOnly.substring(3)}';
    }

    // Максимум 12 цифр: 998 + 9 цифр
    if (digits.length > 12) {
      digits = digits.substring(0, 12);
    }

    // Форматируем: +998 XX XXX XX XX
    final buffer = StringBuffer('+998');
    final afterPrefix = digits.length > 3 ? digits.substring(3) : '';

    if (afterPrefix.isNotEmpty) {
      buffer.write(' ');
      buffer.write(afterPrefix.substring(0, afterPrefix.length.clamp(0, 2)));
    }
    if (afterPrefix.length > 2) {
      buffer.write(' ');
      buffer.write(afterPrefix.substring(2, afterPrefix.length.clamp(2, 5)));
    }
    if (afterPrefix.length > 5) {
      buffer.write(' ');
      buffer.write(afterPrefix.substring(5, afterPrefix.length.clamp(5, 7)));
    }
    if (afterPrefix.length > 7) {
      buffer.write(' ');
      buffer.write(afterPrefix.substring(7, afterPrefix.length.clamp(7, 9)));
    }

    final formatted = buffer.toString();

    // Не даём удалить префикс +998
    if (formatted.length < 5) {
      return const TextEditingValue(
        text: '+998 ',
        selection: TextSelection.collapsed(offset: 5),
      );
    }

    // Курсор не может быть раньше позиции 5 (после "+998 ")
    int cursorPos = formatted.length;
    if (newValue.selection.baseOffset >= 0) {
      cursorPos = newValue.selection.baseOffset.clamp(5, formatted.length);
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPos),
    );
  }

  /// Извлекает чистые цифры из отформатированного номера.
  /// "+998 90 123 45 67" → "998901234567"
  static String extractDigits(String formatted) {
    return formatted.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Проверяет валидность номера (12 цифр: 998 + 9).
  static bool isValid(String formatted) {
    return extractDigits(formatted).length == 12;
  }
}
