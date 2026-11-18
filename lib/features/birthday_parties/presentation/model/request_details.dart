import '../../../../generated/l10n.dart';
import '../../domain/birthday_party.dart';
import 'event_groups.dart';

/// Where the money a parent already paid in the app came from, so'm. Same
/// rule as [requestRefundUzs]: payments only, and an online part already
/// reversed to the card no longer counts.
class RequestPaidSplit {
  const RequestPaidSplit({
    required this.balanceUzs,
    required this.cardUzs,
    required this.clickUzs,
    required this.paymeUzs,
    required this.otherOnlineUzs,
  });

  factory RequestPaidSplit.of(BirthdayParty party) {
    var balance = 0, card = 0, click = 0, payme = 0, other = 0;
    for (final p in party.payments) {
      if (p.kind != BirthdayPaymentKind.payment) continue;
      balance += p.fromBalanceUzs;
      final online = p.onlineReversedAt == null ? p.onlineUzs : 0;
      if (online == 0) continue;
      switch (p.onlineProvider) {
        case 'card':
          card += online;
        case 'click':
          click += online;
        case 'payme':
          payme += online;
        default:
          other += online;
      }
    }
    return RequestPaidSplit(
      balanceUzs: balance,
      cardUzs: card,
      clickUzs: click,
      paymeUzs: payme,
      otherOnlineUzs: other,
    );
  }

  final int balanceUzs;
  final int cardUzs;
  final int clickUzs;
  final int paymeUzs;

  /// Online money with a provider this build does not know.
  final int otherOnlineUzs;

  int get totalUzs =>
      balanceUzs + cardUzs + clickUzs + paymeUzs + otherOnlineUzs;
}

/// "25 daqiqa oldin" from [createdAt] to [now].
String agoLabel(AppLocalization l10n, DateTime createdAt, DateTime now) {
  final d = now.difference(createdAt);
  if (d.inMinutes < 1) return l10n.bdAgoJustNow;
  if (d.inHours < 1) return l10n.bdAgoMinutes(d.inMinutes);
  if (d.inDays < 1) return l10n.bdAgoHours(d.inHours);
  return l10n.bdAgoDays(d.inDays);
}

/// Calendar parts of a `YYYY-MM-DD` day; null when unreadable.
({int year, int month, int day, int weekday})? ymdParts(String ymd) {
  final v = parseYmd(ymd);
  if (v == null) return null;
  final d = DateTime.utc(
    int.parse(v.substring(0, 4)),
    int.parse(v.substring(5, 7)),
    int.parse(v.substring(8, 10)),
  );
  return (year: d.year, month: d.month, day: d.day, weekday: d.weekday);
}

List<String> _split(String csv) => csv.split(',');

/// "NOY" — the calendar tile's month.
String monthShort(AppLocalization l10n, int month) =>
    _split(l10n.bdMonthsShort)[month - 1];

/// "Shanba, 22-noyabr"; the raw string when unreadable.
String weekdayDateLabel(AppLocalization l10n, String ymd) {
  final d = ymdParts(ymd);
  if (d == null) return ymd;
  final weekday = _split(l10n.bdWeekdays)[d.weekday - 1];
  final month = _split(l10n.bdMonthsLong)[d.month - 1];
  return '$weekday, ${l10n.bdDayMonth('${d.day}', month)}';
}

/// "Bugun" / "Ertaga" / "4 kundan keyin" / "2 kun oldin", against today in
/// Tashkent ([today] `YYYY-MM-DD`, defaults to now).
String daysAwayLabel(AppLocalization l10n, String ymd, [String? today]) {
  final a = ymdParts(today ?? tashkentToday());
  final b = ymdParts(ymd);
  if (a == null || b == null) return '';
  final days = DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  if (days == 0) return l10n.eventsToday;
  if (days == 1) return l10n.eventsTomorrow;
  if (days > 1) return l10n.bdInDays(days);
  return l10n.bdAgoDays(-days);
}
