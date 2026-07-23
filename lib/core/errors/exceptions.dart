/// Low-level exceptions thrown by datasources (data layer only).
/// Repositories catch these and translate to [AppFailure]/[Result] before
/// anything above the data layer ever sees them.
class StorageException implements Exception {
  final String message;
  final Object? cause;
  const StorageException(this.message, {this.cause});

  @override
  String toString() => 'StorageException: $message';
}

class RemoteDataException implements Exception {
  final String message;
  final Object? cause;
  const RemoteDataException(this.message, {this.cause});

  @override
  String toString() => 'RemoteDataException: $message';
}
