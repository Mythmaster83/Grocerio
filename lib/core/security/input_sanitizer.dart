/// Centralized input validation/sanitization for anything a user types that
/// gets persisted. Isar being NoSQL/typed removes classic SQL injection risk,
/// but we still guard against:
/// - unbounded string length (storage bloat / UI overflow / DoS-by-paste)
/// - control characters breaking layout or Isar full-text indices
class InputSanitizer {
  InputSanitizer._();

  static const int maxItemNameLength = 120;
  static const int maxListNameLength = 80;

  /// Custom units are shown inline next to a quantity, so they must stay short
  /// enough not to push the item name off the row.
  static const int maxUnitLabelLength = 16;
  static const double maxQuantityValue = 999999.0;

  static String sanitizeFreeText(String input, {required int maxLength}) {
    final stripped = input
        .trim()
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), ''); // control chars
    return stripped.length > maxLength
        ? stripped.substring(0, maxLength)
        : stripped;
  }

  /// Validates and clamps a quantity value entered via inline edit / voice.
  static double? parseQuantity(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.');
    final value = double.tryParse(cleaned);
    if (value == null || value.isNaN || value.isInfinite) return null;
    if (value < 0) return null;
    return value > maxQuantityValue ? maxQuantityValue : value;
  }
}
