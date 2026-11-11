import '../../domain/birthday_party.dart';

/// Today's calendar day in Tashkent (UTC+5) as `YYYY-MM-DD` — the same day
/// the backend stores party dates in.
String tashkentToday([DateTime? nowUtc]) {
  final t = (nowUtc ?? DateTime.now()).toUtc().add(const Duration(hours: 5));
  return _fmt(t);
}

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _parse(String ymd) => DateTime.utc(
  int.parse(ymd.substring(0, 4)),
  int.parse(ymd.substring(5, 7)),
  int.parse(ymd.substring(8, 10)),
);

enum EventGroupKind { overdue, today, tomorrow, thisWeek, nextWeek, later, all }

class EventGroup {
  const EventGroup(this.kind, this.parties);
  final EventGroupKind kind;
  final List<BirthdayParty> parties;
}

/// Booked parties grouped by how soon they are (weeks run Monday–Sunday);
/// empty groups are omitted. Completed/cancelled lists stay one group in the
/// server's order (newest first).
List<EventGroup> groupEvents(List<BirthdayParty> parties, String today) {
  if (parties.isNotEmpty &&
      parties.first.status != BirthdayPartyStatus.booked) {
    return [EventGroup(EventGroupKind.all, parties)];
  }
  final base = _parse(today);
  final thisSunday = base.add(Duration(days: 7 - base.weekday));
  final nextSunday = thisSunday.add(const Duration(days: 7));
  final tomorrow = _fmt(base.add(const Duration(days: 1)));
  final thisSundayStr = _fmt(thisSunday);
  final nextSundayStr = _fmt(nextSunday);

  EventGroupKind kindOf(String date) {
    if (date.compareTo(today) < 0) return EventGroupKind.overdue;
    if (date == today) return EventGroupKind.today;
    if (date == tomorrow) return EventGroupKind.tomorrow;
    if (date.compareTo(thisSundayStr) <= 0) return EventGroupKind.thisWeek;
    if (date.compareTo(nextSundayStr) <= 0) return EventGroupKind.nextWeek;
    return EventGroupKind.later;
  }

  final buckets = {for (final k in EventGroupKind.values) k: <BirthdayParty>[]};
  for (final p in parties) {
    buckets[kindOf(p.partyDate)]!.add(p);
  }
  return [
    for (final k in EventGroupKind.values)
      if (buckets[k]!.isNotEmpty) EventGroup(k, buckets[k]!),
  ];
}
