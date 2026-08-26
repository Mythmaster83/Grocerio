/// How long a deleted list is kept locally before its tombstone is dropped.
/// Long enough that a device offline for a month still learns about the delete.
const kTombstoneRetention = Duration(days: 30);

class SyncSummary {
  final int pushedLists;
  final int pulledLists;
  final int overwrites;

  const SyncSummary({
    this.pushedLists = 0,
    this.pulledLists = 0,
    this.overwrites = 0,
  });
}

enum SyncPhase {
  /// No backend in this build, or nobody is signed in. Not an error state: the
  /// app is designed to run this way.
  offline,
  syncing,
  synced,
  failed,
}

class SyncState {
  final SyncPhase phase;
  final DateTime? lastSyncedAt;
  final String? error;
  final SyncSummary? lastSummary;

  const SyncState({
    this.phase = SyncPhase.offline,
    this.lastSyncedAt,
    this.error,
    this.lastSummary,
  });

  bool get isSyncing => phase == SyncPhase.syncing;

  /// One line for the account screen. Reads as status, not as a log line.
  String get description {
    switch (phase) {
      case SyncPhase.offline:
        return 'Sign in to sync lists across devices';
      case SyncPhase.syncing:
        return 'Syncing…';
      case SyncPhase.failed:
        return error ?? 'Last sync failed';
      case SyncPhase.synced:
        final at = lastSyncedAt;
        if (at == null) return 'Up to date';
        return 'Last synced ${_ago(DateTime.now().difference(at))}';
    }
  }

  SyncState copyWith({
    SyncPhase? phase,
    DateTime? lastSyncedAt,
    String? error,
    bool clearError = false,
    SyncSummary? lastSummary,
  }) {
    return SyncState(
      phase: phase ?? this.phase,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      error: clearError ? null : (error ?? this.error),
      lastSummary: lastSummary ?? this.lastSummary,
    );
  }
}

String _ago(Duration d) {
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
