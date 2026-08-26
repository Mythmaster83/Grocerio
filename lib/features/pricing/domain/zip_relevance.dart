/// How much of a ZIP is enough to treat two shoppers as "in the same area".
///
/// Three digits is roughly a metro (303xx Atlanta) — tighter than a state,
/// looser than a street, which is the granularity a grocery comparison needs.
const kZipPrefixLength = 3;

/// Digits only, first five. ZIP+4 is more precise than the app can use, and
/// collecting it would be more location than we have a reason to store.
String? normalizeZip(String? raw) {
  if (raw == null) return null;
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < kZipPrefixLength) return null;
  return digits.substring(0, digits.length < 5 ? digits.length : 5);
}

String? zipPrefix(String? zip) {
  final normalized = normalizeZip(zip);
  if (normalized == null) return null;
  return normalized.substring(0, kZipPrefixLength);
}

/// Whether a report belongs in this shopper's comparison.
///
/// No prefix on either side means "unknown area", and unknown areas are not
/// mixed in: that is how an Ohio gallon of milk stays out of a Georgia list
/// even when the reporter forgot to set a ZIP.
bool reportMatchesArea({required String? reportZip, required String? userZip}) {
  final user = zipPrefix(userZip);
  final report = zipPrefix(reportZip);
  if (user == null || report == null) return false;
  return user == report;
}
