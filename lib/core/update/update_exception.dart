/// Thrown by the update layer when something about a release, its checksum,
/// or its download cannot be trusted enough to proceed. The message is
/// written to be shown directly to the cashier in a failure card.
class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
