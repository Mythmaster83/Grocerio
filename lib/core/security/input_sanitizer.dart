/// Centralized input validation/sanitization for anything a user types that
/// crosses a trust boundary (gets persisted, sent over the network, or used
/// to build a query/URL). Isar being NoSQL/typed removes classic SQL
/// injection risk, but we still guard against:
/// - unbounded string length (storage bloat / UI overflow / DoS-by-paste)
/// - control characters breaking layout or Isar full-text indices
/// - values used directly as URL query params (Pexels search)
class InputSanitizer {
  InputSanitizer._();

  static const int maxItemNameLength = 120;
  static const int maxListNameLength = 80;
  static const int maxQuantityDigits = 6; // caps at 999999

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
    const maxValue = 999999.0;
    return value > maxValue ? maxValue : value;
  }

  /// Safe for use as a URL query parameter (Pexels image search term).
  static String sanitizeSearchTerm(String input) {
    final cleaned = sanitizeFreeText(input, maxLength: 60);
    return Uri.encodeQueryComponent(cleaned);
  }
}
