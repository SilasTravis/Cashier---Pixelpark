import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../generated/l10n.dart';
import 'birthday_ui.dart';

const _uzDays = [
  'Dushanba',
  'Seshanba',
  'Chorshanba',
  'Payshanba',
  'Juma',
  'Shanba',
  'Yakshanba',
];
const _uzMonths = [
  'yanvar',
  'fevral',
  'mart',
  'aprel',
  'may',
  'iyun',
  'iyul',
  'avgust',
  'sentabr',
  'oktabr',
  'noyabr',
  'dekabr',
];
const _ruDays = [
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];
const _ruMonths = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];
const _enDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _enMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Shanba, 14-noyabr" / "Суббота, 14 ноября" / "Saturday, 14 November" —
/// spelled out so the cashier reads the day, not a number. No intl date data
/// needed (works before any locale data is loaded).
String birthdayDayLabel(DateTime d, String languageCode) {
  final wd = d.weekday - 1;
  final m = d.month - 1;
  return switch (languageCode) {
    'ru' => '${_ruDays[wd]}, ${d.day} ${_ruMonths[m]}',
    'en' => '${_enDays[wd]}, ${d.day} ${_enMonths[m]}',
    _ => '${_uzDays[wd]}, ${d.day}-${_uzMonths[m]}',
  };
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Step "Bayram kuni": the picked day spelled out in a big field (tap = the
/// calendar) and quick chips for today, tomorrow and a week from today.
class BirthdayDateField extends StatelessWidget {
  const BirthdayDateField({
    super.key,
    required this.date,
    required this.today,
    required this.onPick,
    required this.onDate,
  });

  final DateTime date;
  final DateTime today;

  /// Opens the calendar.
  final VoidCallback onPick;
  final ValueChanged<DateTime> onDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final base = DateTime(today.year, today.month, today.day);
    final quick = [
      (l10n.eventsToday, base),
      (l10n.eventsTomorrow, base.add(const Duration(days: 1))),
      (l10n.birthdayInAWeek, base.add(const Duration(days: 7))),
    ];
    final radius = BorderRadius.circular(16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          key: const ValueKey('birthday-date'),
          color: p.surfaceMuted,
          borderRadius: radius,
          child: InkWell(
            onTap: onPick,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      PhosphorIconsRegular.calendarBlank,
                      size: 20,
                      color: p.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          birthdayDayLabel(date, lang),
                          key: const ValueKey('birthday-date-label'),
                          overflow: TextOverflow.ellipsis,
                          style: p.heading.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${date.year}',
                          style: tabular(p.bodyMuted.copyWith(fontSize: 12.5)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.birthdayOtherDate,
                    style: p.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    PhosphorIconsRegular.caretDown,
                    size: 15,
                    color: p.accent,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (label, day) in quick) ...[
              if (day != base) const SizedBox(width: 8),
              Expanded(
                child: SoftChoicePill(
                  key: ValueKey('birthday-date-${day.difference(base).inDays}'),
                  label: label,
                  selected: _sameDay(date, day),
                  onTap: () => onDate(day),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
