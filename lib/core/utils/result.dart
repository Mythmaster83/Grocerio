/// A Result type so failures are values, not exceptions bubbling into the UI.
///
/// Every repository / usecase method returns Result<T> instead of throwing.
/// This is the single most important architectural rule in this codebase:
/// it prevents "UI catches everything with try/catch and shows a generic
/// SnackBar" and instead forces every call site to consciously handle
/// success and failure.
sealed class Result<T> {
  const Result();

  // `const factory` (not just `factory`) so call sites may write
  // `const Result.err(...)` — a plain factory can't be invoked with `const`.
  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(AppFailure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  R when<R>({
    required R Function(T value) ok,
    required R Function(AppFailure failure) err,
  }) {
    final self = this;
    if (self is Ok<T>) return ok(self.value);
    if (self is Err<T>) return err((self).failure);
    throw StateError('Unreachable');
  }
}

final class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

final class Err<T> extends Result<T> {
  final AppFailure failure;
  const Err(this.failure);
}

/// Base failure type. Keep [message] coarse-grained and user-safe — never
/// put raw exception text, stack traces, or API response bodies in it,
/// since it may be rendered directly in the UI. Put the raw detail in
/// [cause] for logging only.
sealed class AppFailure {
  final String message;
  final Object? cause;
  const AppFailure(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}

class StorageFailure extends AppFailure {
  const StorageFailure(super.message, {super.cause});
}

class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.cause});
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {super.cause});
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message, {super.cause});
}

class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure(super.message, {super.cause});
}

class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message, {super.cause});
}
