import 'dart:math';

/// Customer tracking codes: 12 characters from an unambiguous base32 alphabet
/// (60 bits of randomness), shown as XXXX-XXXX-XXXX. The code is the only
/// credential for the public tracking view, so it must stay unguessable.
class TrackingCode {
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int length = 12;
  static final RegExp _valid = RegExp(r'^[A-HJ-NP-Z2-9]{12}$');

  static String generate([Random? random]) {
    final r = random ?? Random.secure();
    return List.generate(length, (_) => _alphabet[r.nextInt(_alphabet.length)])
        .join();
  }

  /// Upper-cases and strips spaces/dashes so "abcd-efgh-jklm" matches.
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  static bool isValid(String normalized) => _valid.hasMatch(normalized);

  static String format(String code) => code.length == length
      ? '${code.substring(0, 4)}-${code.substring(4, 8)}-${code.substring(8)}'
      : code;
}
