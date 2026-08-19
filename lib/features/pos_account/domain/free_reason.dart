/// Why a child's day pass is issued FREE — mirrors the backend's
/// `free-reason.ts`. Optional per child at checkout: picking one zeroes that
/// child's tariff everywhere (no VIP debit at print, 0 at every exit) and is
/// recorded on the pass for the admin statistics.
enum FreeReason {
  disabled('disabled', 'Nogiron'),
  aile('aile', 'AILE'),
  subscription('subscription', 'Obuna'),
  birthday('birthday', 'Tug‘ilgan kun');

  const FreeReason(this.key, this.label);

  /// Wire value sent to / received from the backend.
  final String key;

  /// Uzbek label shown in the 3-dots menu and the row badge.
  final String label;

  static FreeReason? fromKey(String? key) {
    for (final reason in values) {
      if (reason.key == key) return reason;
    }
    return null;
  }
}

bool isBirthdayInTashkent(DateTime birthDate, {DateTime? now}) {
  final tashkent = (now ?? DateTime.now()).toUtc().add(
    const Duration(hours: 5),
  );
  return birthDate.month == tashkent.month && birthDate.day == tashkent.day;
}
