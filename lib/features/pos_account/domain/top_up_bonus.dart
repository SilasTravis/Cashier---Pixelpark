/// Mirrors the backend's top-up bonus ladder (`top-up-bonus.ts` in
/// maestro_backend) and the mobile app's `TopUpBonusCalculator`. The backend
/// is the source of truth for what is credited; this copy only previews it
/// before the cashier confirms, so keep all three tables in sync.
///
/// A top-up at or above a tier's threshold earns that tier's flat bonus, up to
/// (but not including) the next tier. Below the lowest threshold: no bonus.
const List<({int minAmount, int bonus})> topUpBonusTiers = [
  (minAmount: 300000, bonus: 50000),
  (minAmount: 500000, bonus: 200000),
  (minAmount: 1000000, bonus: 500000),
  (minAmount: 2000000, bonus: 2000000),
];

int topUpBonusFor(int amountUzs) {
  var bonus = 0;
  for (final tier in topUpBonusTiers) {
    if (amountUzs < tier.minAmount) break;
    bonus = tier.bonus;
  }
  return bonus;
}
