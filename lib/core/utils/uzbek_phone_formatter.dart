import 'package:flutter/services.dart';

class UzbekPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    String digits;
    if (digitsOnly.startsWith('998')) {
      digits = digitsOnly;
    } else if (digitsOnly.length <= 3) {
      digits = '998';
    } else {
      digits = '998${digitsOnly.substring(3)}';
    }

    if (digits.length > 12) digits = digits.substring(0, 12);

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

    if (formatted.length < 5) {
      return const TextEditingValue(
        text: '+998 ',
        selection: TextSelection.collapsed(offset: 5),
      );
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String extractDigits(String formatted) =>
      formatted.replaceAll(RegExp(r'[^\d]'), '');

  static bool isValid(String formatted) =>
      extractDigits(formatted).length == 12;
}
