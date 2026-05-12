import 'dart:async';

/// Wraps a future with a timeout. If it exceeds [timeout], throws
/// [TimeoutException] — callers should catch and surface a friendly
/// "connection is slow" message instead of letting the UI hang.
Future<T> withTimeout<T>(
  Future<T> future, {
  Duration timeout = const Duration(seconds: 15),
}) {
  return future.timeout(timeout);
}
