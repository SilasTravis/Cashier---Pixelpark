import '../../domain/birthday_party.dart';

/// The day the confirm dialog shows: 10:00 to 21:00.
const dayStartMinutes = 10 * 60;
const dayEndMinutes = 21 * 60;

/// How long a party is drawn on the day strip (only a picture: the server
/// stores just the start time).
const partyDrawnMinutes = 120;

/// A slot this close (minutes, either side) to another party's start is
/// "near".
const nearMinutes = 60;

/// The 30-minute buttons: 10:00, 10:30 … 20:30.
List<int> daySlots() => [
  for (var m = dayStartMinutes; m < dayEndMinutes; m += 30) m,
];

/// `HH:MM` -> minutes since midnight; null when not a valid 00:00–23:59.
/// One-digit hours (`9:05`) are accepted.
int? parseHhmm(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
  if (m == null) return null;
  final h = int.parse(m[1]!);
  final min = int.parse(m[2]!);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

/// Minutes since midnight -> `HH:MM`.
String formatHhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

enum SlotState { free, near, busy }

/// [time] (minutes) against the other parties' starts: `busy` when one
/// starts in the same half hour, `near` when one starts within
/// [nearMinutes], else `free`.
SlotState slotState(int time, Iterable<int> starts) {
  var near = false;
  for (final s in starts) {
    if (s ~/ 30 == time ~/ 30) return SlotState.busy;
    if ((s - time).abs() <= nearMinutes) near = true;
  }
  return near ? SlotState.near : SlotState.free;
}

/// Another booked party on the same day and branch, as the strip shows it.
class DayParty {
  const DayParty({
    required this.startMinutes,
    required this.time,
    required this.planName,
    required this.planColor,
    required this.surname,
  });

  final int startMinutes;
  final String time;
  final String planName;
  final String planColor;
  final String surname;

  /// "11:00 MAX · Aliyev".
  String get label => '$time $planName · $surname';
}

/// The last word of the parent's name ("Dilnoza Karimova" -> "Karimova"),
/// the phone when there is no name.
String surnameOf(BirthdayParty party) {
  final words = party.customerName.trim().split(RegExp(r'\s+'));
  final last = words.isEmpty ? '' : words.last;
  return last.isEmpty ? party.customerPhone : last;
}

/// The booked parties of [request]'s branch on its date, with a time, by
/// start; the request itself is never among them.
List<DayParty> dayPartiesFor(
  BirthdayParty request,
  Iterable<BirthdayParty> booked,
) {
  final out = <DayParty>[];
  for (final p in booked) {
    if (p.id == request.id ||
        p.status != BirthdayPartyStatus.booked ||
        p.partyDate != request.partyDate ||
        p.branchId != request.branchId) {
      continue;
    }
    final start = parseHhmm(p.partyTime);
    if (start == null) continue;
    out.add(
      DayParty(
        startMinutes: start,
        time: formatHhmm(start),
        planName: p.planName,
        planColor: p.planColor,
        surname: surnameOf(p),
      ),
    );
  }
  out.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  return out;
}
