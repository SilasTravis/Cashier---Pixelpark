import '../../../core/error/exceptions.dart';
import '../../../injector_container.dart';
import '../../pos_account/data/pos_account_repository_impl.dart';
import '../data/birthday_parties_repository.dart';
import '../domain/birthday_party.dart';

/// Server code for a requestId replay whose body differs from the booked one.
const birthdayRequestConflict = 'BIRTHDAY_REQUEST_CONFLICT';

/// A money call that failed without telling us whether the server applied it:
/// a timeout / dropped connection (no server error code, or not even a
/// [ServerException]) or a requestId conflict. Every other 4xx rolled back
/// fully, so those are plain refusals.
bool isUnclearFailure(Object error) => error is ServerException
    ? (error.code == null || error.code == birthdayRequestConflict)
    : true;

/// The party as the server has it now, null when it cannot be read (or does
/// not exist).
Future<BirthdayParty?> refetchParty(
  BirthdayPartiesRepository repository,
  String id,
) async {
  try {
    return await repository.get(id);
  } catch (_) {
    return null;
  }
}

/// What re-reading a party told us. Only [PartyMissing] is a confirmed "the
/// server has no such party"; [PartyUnreachable] says nothing about it.
sealed class PartyLookup {
  const PartyLookup();
}

class PartyFound extends PartyLookup {
  const PartyFound(this.party);
  final BirthdayParty party;
}

class PartyMissing extends PartyLookup {
  const PartyMissing();
}

class PartyUnreachable extends PartyLookup {
  const PartyUnreachable();
}

Future<PartyLookup> lookupParty(
  BirthdayPartiesRepository repository,
  String id,
) async {
  try {
    return PartyFound(await repository.get(id));
  } on ServerException catch (e) {
    return e.code == 'BIRTHDAY_PARTY_NOT_FOUND'
        ? const PartyMissing()
        : const PartyUnreachable();
  } catch (_) {
    return const PartyUnreachable();
  }
}

/// Did the payment sent under [requestId] ([money]) land between [before] and
/// [fresh]? Rows that carry a requestId are matched on it exactly; only rows
/// without one (older servers) fall back to "a new row with the same split".
bool paymentReflected(
  BirthdayParty before,
  BirthdayParty fresh,
  BirthdayMoney money, {
  String? requestId,
}) {
  final known = before.payments.map((p) => p.id).toSet();
  return fresh.payments.any((p) {
    if (p.kind != BirthdayPaymentKind.payment) return false;
    final sent = p.requestId;
    if (sent != null && requestId != null) return sent == requestId;
    return !known.contains(p.id) &&
        p.fromBalanceUzs == money.fromBalanceUzs &&
        p.cashUzs == money.cashUzs &&
        p.cardUzs == money.cardUzs;
  });
}

/// The customer's current balance, null when it cannot be looked up.
Future<int?> lookupCustomerBalance(int customerId, String phone) async {
  try {
    final result = await sl<PosAccountRepository>().searchCustomers(phone);
    return result.fold<int?>(
      (_) => null,
      (list) => list.where((c) => c.id == customerId).firstOrNull?.balance,
    );
  } catch (_) {
    return null;
  }
}
