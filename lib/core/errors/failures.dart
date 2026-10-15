/// Base failure class representing a controlled error in functional programming.
sealed class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Failure occurring during match storage/retrieval.
final class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Local storage operation failed']);
}

/// Failure occurring when attempting an invalid Ludo move.
final class InvalidMoveFailure extends Failure {
  const InvalidMoveFailure([super.message = 'The requested move is invalid']);
}

/// General fallback failure.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'An unexpected error occurred']);
}
