import '../../../core/error/exceptions.dart';
import '../../../injector_container.dart';
import '../../pos_account/data/pos_account_repository_impl.dart';
import '../data/birthday_parties_repository.dart';
import '../domain/birthday_party.dart';

/// Server code for a requestId replay whose body differs from the booked one.
const birthdayRequestConflict = 'BIRTHDAY_REQUEST_CONFLICT';

/// A money call that failed without telling us whether the server applied it.
///
/// Only a 4xx carrying a server error code is a clean refusal (the server
/// rolled it back fully). Everything else is unclear: a timeout / dropped
/// connection (no code, or not even a [ServerException]), a requestId
/// conflict, and any 5xx — the money may have been committed before a later
/// step (e.g. re-reading the party) failed.
bool isUnclearFailure(Object error) {
  if (error is! ServerException) return true;
  final status = error.statusCode;
  final refused =
      error.code != null &&
      error.code != birthdayRequestConflict &&
      status != null &&
      status >= 400 &&
      status < 500;
  return !refused;
}

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

/// [lookupParty] for the recovery after an unclear failure. A "not found"
/// is not trusted at once — the original request may still be inside its
/// transaction on the server (it outlives the client's timeout) — so it is
/// re-read up to [rechecks] more times, [delay] apart.
Future<PartyLookup> lookupPartySettled(
  BirthdayPartiesRepository repository,
  String id, {
  int rechecks = 2,
  Duration delay = birthdayRecheckDelay,
}) async {
  var lookup = await lookupParty(repository, id);
  for (var i = 0; i < rechecks && lookup is PartyMissing; i++) {
    await Future<void>.delayed(delay);
    lookup = await lookupParty(repository, id);
  }
  return lookup;
}

/// Pause between the re-reads of [lookupPartySettled].
const birthdayRecheckDelay = Duration(seconds: 3);

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
