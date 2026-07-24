/// Stable notification id in flutter_local_notifications' 32-bit range.
int notificationIdForList(String listPublicId) {
  // Keep positive and away from 0; FNV-ish hash folded into 31 bits.
  var hash = 0x811c9dc5;
  for (final unit in listPublicId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

/// 09:00 local on the calendar date of [scheduledFor].
DateTime shoppingDayReminderLocal(DateTime scheduledFor) {
  return DateTime(scheduledFor.year, scheduledFor.month, scheduledFor.day, 9);
}
