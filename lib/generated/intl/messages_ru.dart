// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ru locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'ru';

  static String m0(count) => "${count} лет";

  static String m1(value) => "Полностью с баланса · останется ${value}";

  static String m2(value) => "${value} зачислится на баланс";

  static String m3(count) => "${count} внутри";

  static String m4(minutes) => "Внутри · ${minutes} мин";

  static String m5(phone) => "Для ${phone} аккаунт не найден.";

  static String m6(plan, count) => "${plan} × ${count} дет.";

  static String m7(count) => "${count}";

  static String m8(from, to, total) => "${from}–${to} / ${total}";

  static String m9(time) => "до ${time}";

  static String m10(value) =>
      "За проведённое время с баланса будет списано ${value}.";

  static String m11(value) =>
      "Недостаточно средств — необходимо оплатить минимум ${value}.";

  static String m12(amount) => "+${amount} сум";

  static String m13(reason) => "Причина: ${reason}";

  static String m14(max) => "Наличными не больше ${max}";

  static String m15(amount) =>
      "Остался долг: ${amount} сум. Всё равно завершить?";

  static String m16(date) => "Завершить можно ${date}";

  static String m17(amount) => "С баланса −${amount}";

  static String m18(amount) => "Остаётся: ${amount}";

  static String m19(amount) => "Удержано ${amount}";

  static String m20(amount) => "Оплачено (нетто): ${amount}";

  static String m21(cash, card) => "Смешанно ${cash} + ${card}";

  static String m22(net) => "Всего не больше ${net}";

  static String m23(age) => "Возраст: ${age}";

  static String m24(name) =>
      "Сегодня день рождения: ${name}. Выберите возраст — дата сохранится у ребёнка.";

  static String m25(amount) =>
      "Цена изменена вручную — в отчёте скидка ${amount}.";

  static String m26(size, plan, price) =>
      "${plan} на ${size} · каждый ${price}";

  static String m27(price) => "+1 ребёнок ${price}";

  static String m28(price) => "от ${price}";

  static String m29(name) => "Касса · ${name}";

  static String m30(count) => "Детей: ${count}";

  static String m31(count) =>
      "Продаж с ошибкой синхронизации: ${count}. Перед закрытием смены обратитесь в поддержку.";

  static String m32(price) =>
      "${price} / шт. — без ограничений, как QR родителя";

  static String m33(amount, from, to) => "${amount}: ${from} → ${to}";

  static String m34(amount, from, to) =>
      "${amount} переносится с «${from}» на «${to}». Операция сохранится в истории аудита.";

  static String m35(cash, card) => "Итог: наличные ${cash}, карта ${card}";

  static String m36(value) => "Текущий баланс: ${value}";

  static String m37(child, plan, inside) =>
      "Сегодня «${child}» на тарифе «${plan}»${inside}.";

  static String m38(count) => "Клиентов: ${count}";

  static String m39(cash, card) => "Сейчас: ${cash} наличные + ${card} карта";

  static String m40(amount, from, to) =>
      "${amount} — перенос с «${from}» на «${to}»";

  static String m41(amount, method) =>
      "${amount} — возврат клиенту (${method})";

  static String m42(count) => "Вход (${count})";

  static String m43(plan, time, minutes) =>
      "${plan} · вход ${time} · ${minutes} мин";

  static String m44(message) => "Не вошли: ${message}";

  static String m45(amount) => "Долг ${amount}";

  static String m46(value) =>
      "Недостаточно средств — для выхода пополните минимум на ${value}.";

  static String m47(count) => "${count}";

  static String m48(name) =>
      "«${name}» уже на активном тарифе «1 час» — повторная оплата не взимается.";

  static String m49(count) =>
      "У ${count} детей закончилось время — позовите родителей";

  static String m50(count) => "+${count} мин";

  static String m51(count) => "осталось ${count} мин";

  static String m52(count) => "Внутри: ${count}";

  static String m53(count) =>
      "Несинхронизированных продаж: ${count}. Перед выходом синхронизируйте их в онлайн-режиме.";

  static String m54(count) =>
      "${count} продаж не синхронизированы (ошибка). Они сохранятся на кассе. Всё равно выйти?";

  static String m55(child, amount) =>
      "Выход ребёнка ${child} будет отмечен сейчас. Сессия закроется по текущей сумме ${amount}, которая спишется с баланса родителя. Продолжить?";

  static String m56(count) => "${count} мин";

  static String m57(count) => "OFFLINE · ожидают продаж: ${count}";

  static String m58(count) =>
      "Перейти в онлайн-режим и синхронизировать продажи (${count})?";

  static String m59(value) => "Баланс: ${value}";

  static String m60(value) => "Карта: ${value}";

  static String m61(value) => "Наличные: ${value}";

  static String m62(value) => "Минимум ${value} — остаток останется на балансе";

  static String m63(name, plan) =>
      "У «${name}» уже действует тариф «${plan}» — повторная оплата не взимается.";

  static String m64(plan) =>
      "Тариф «${plan}» списывается с баланса сразу при печати.";

  static String m65(name, from, to) =>
      "«${name}»: нельзя перейти ${from} → ${to}";

  static String m66(plan) =>
      "Переключить на тариф «${plan}»? Старый стикер будет отменён, новый QR напечатан.";

  static String m67(plan, price) =>
      "Перевести на тариф «${plan}»? Сейчас берётся только доплата (${price}) — наличными или картой, на баланс ничего лишнего не попадёт. Старый стикер будет остановлен, новый QR напечатается как «апгрейд».";

  static String m68(plan, price) =>
      "Перевести на тариф «${plan}»? С баланса спишется только доплата (${price}). Старый стикер будет остановлен, новый QR напечатается как «апгрейд».";

  static String m69(plan, price) =>
      "Переключить на тариф «${plan}»? Стоимость ${plan} (${price}) будет сразу списана с баланса. Старый стикер будет отменён, новый QR напечатан.";

  static String m70(child, from, to, paid, due) =>
      "${child}: ${from} → ${to}. ${paid} уже оплачено — доплата: ${due}";

  static String m71(value) => "от ${value} / мин";

  static String m72(value) => "${value} / день";

  static String m73(value) => "${value} / час";

  static String m74(code) =>
      "Промокод блогера ${code} принят — выберите клиента";

  static String m75(reason) => "Промокод не применён, код возвращён: ${reason}";

  static String m76(date, name) => "${date} · ${name}";

  static String m77(amount, method) =>
      "${amount} будет возвращено способом «${method}». Действие навсегда сохранится в истории аудита.";

  static String m78(balance) => "Баланс клиента: ${balance}";

  static String m79(count) =>
      "Также будет аннулировано пропусков: ${count} — они перестанут работать на входе.";

  static String m80(amount) => "Успешно возвращено ${amount}";

  static String m81(count) => "выбрано: ${count}";

  static String m82(count) => "${count} шт.";

  static String m83(time) => "Смена открыта в ${time}";

  static String m84(synced, failed) =>
      "Синхронизировано: ${synced}, с ошибкой: ${failed}.";

  static String m85(reason) =>
      "Не удалось синхронизировать: ${reason}. Офлайн-режим продолжается.";

  static String m86(code) => "Код: ${code}";

  static String m87(version) => "Доступна новая версия: ${version}";

  static String m88(paid, due) => "Уже оплачено ${paid} — доплата: ${due}.";

  static String m89(name) =>
      "«${name}» уже на активном VIP-тарифе — повторная оплата не взимается.";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "accountAgeYears": m0,
    "accountAtExit": MessageLookupByLibrary.simpleMessage("на выходе"),
    "accountColChild": MessageLookupByLibrary.simpleMessage("Ребёнок"),
    "accountColSoFar": MessageLookupByLibrary.simpleMessage("Сейчас"),
    "accountColTime": MessageLookupByLibrary.simpleMessage("Время"),
    "accountCoveredByBalance": m1,
    "accountDueFull": MessageLookupByLibrary.simpleMessage("Клиент платит"),
    "accountDueShortfall": MessageLookupByLibrary.simpleMessage("Не хватает"),
    "accountExcessToBalance": m2,
    "accountFromBalance": MessageLookupByLibrary.simpleMessage(
      "Списывается с баланса",
    ),
    "accountFromBalanceLine": MessageLookupByLibrary.simpleMessage("С баланса"),
    "accountId": MessageLookupByLibrary.simpleMessage("ID счёта"),
    "accountInsideCount": m3,
    "accountInsideMinutes": m4,
    "accountLeftOnBalance": MessageLookupByLibrary.simpleMessage(
      "Останется на балансе",
    ),
    "accountNoCheckDiscounts": MessageLookupByLibrary.simpleMessage(
      "Нет активных скидок на чек",
    ),
    "accountNotFoundForPhone": m5,
    "accountOptional": MessageLookupByLibrary.simpleMessage("необязательно"),
    "accountOtherAmount": MessageLookupByLibrary.simpleMessage(
      "Принять другую сумму",
    ),
    "accountOwner": MessageLookupByLibrary.simpleMessage("Владелец счёта"),
    "accountPayAtExit": MessageLookupByLibrary.simpleMessage(
      "Считается на выходе",
    ),
    "accountPayNow": MessageLookupByLibrary.simpleMessage("Оплата сейчас"),
    "accountPickChildFirst": MessageLookupByLibrary.simpleMessage(
      "Сначала выберите ребёнка",
    ),
    "accountPlanTimesKids": m6,
    "accountStepExtras": MessageLookupByLibrary.simpleMessage("Дополнительно"),
    "accountStepWho": MessageLookupByLibrary.simpleMessage("Кто входит?"),
    "accountToPay": MessageLookupByLibrary.simpleMessage("К оплате"),
    "accountTodayQrs": MessageLookupByLibrary.simpleMessage(
      "QR-коды на сегодня",
    ),
    "accountTodayQrsHint": MessageLookupByLibrary.simpleMessage(
      "Перепечатайте потерянный или испорченный стикер: оплата не списывается, старый стикер тоже работает.",
    ),
    "accountTxCount": m7,
    "accountTxEmpty": MessageLookupByLibrary.simpleMessage(
      "У клиента пока нет операций",
    ),
    "accountTxFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось загрузить операции",
    ),
    "accountTxMore": MessageLookupByLibrary.simpleMessage("Другое"),
    "accountTxNext": MessageLookupByLibrary.simpleMessage("Далее"),
    "accountTxPrev": MessageLookupByLibrary.simpleMessage("Назад"),
    "accountTxRange": m8,
    "accountTxTitle": MessageLookupByLibrary.simpleMessage("История операций"),
    "accountValidUntil": m9,
    "accruedAmount": MessageLookupByLibrary.simpleMessage("Текущий счёт"),
    "accruedDue": m10,
    "add": MessageLookupByLibrary.simpleMessage("Добавить"),
    "addCustomer": MessageLookupByLibrary.simpleMessage("Добавить клиента"),
    "allCustomers": MessageLookupByLibrary.simpleMessage("Все клиенты"),
    "amount": MessageLookupByLibrary.simpleMessage("Сумма"),
    "appTitle": MessageLookupByLibrary.simpleMessage("Bolajon — касса"),
    "automaticGodex": MessageLookupByLibrary.simpleMessage(
      "Автоматически — Godex",
    ),
    "automaticSewoo": MessageLookupByLibrary.simpleMessage(
      "Автоматически — SLK",
    ),
    "balance": MessageLookupByLibrary.simpleMessage("Баланс"),
    "balanceInsufficient": m11,
    "balanceSalesNotIncome": MessageLookupByLibrary.simpleMessage(
      "Продажи с баланса (не выручка)",
    ),
    "bdAddChildPrice": m12,
    "bdAddChildSubmit": MessageLookupByLibrary.simpleMessage("Добавить"),
    "bdAddChildTitle": MessageLookupByLibrary.simpleMessage(
      "Дополнительные дети",
    ),
    "bdAddPaymentFull": MessageLookupByLibrary.simpleMessage(
      "+ Добавить оплату",
    ),
    "bdBack": MessageLookupByLibrary.simpleMessage("Назад"),
    "bdBalanceUnknown": MessageLookupByLibrary.simpleMessage(
      "Баланс неизвестен",
    ),
    "bdCancelConfirm": MessageLookupByLibrary.simpleMessage("Отменить"),
    "bdCancelParty": MessageLookupByLibrary.simpleMessage("Отменить"),
    "bdCancelReason": MessageLookupByLibrary.simpleMessage("Причина"),
    "bdCancelReasonShort": MessageLookupByLibrary.simpleMessage(
      "Минимум 3 символа",
    ),
    "bdCancelTitle": MessageLookupByLibrary.simpleMessage("Отмена события"),
    "bdCancelledChip": MessageLookupByLibrary.simpleMessage("Отменено"),
    "bdCancelledReason": m13,
    "bdCashTooLarge": m14,
    "bdChangeDate": MessageLookupByLibrary.simpleMessage("Изменить дату"),
    "bdClose": MessageLookupByLibrary.simpleMessage("Закрыть"),
    "bdCommentHint": MessageLookupByLibrary.simpleMessage("Напишите заметку"),
    "bdComments": MessageLookupByLibrary.simpleMessage("Заметки"),
    "bdCompleteAnyway": MessageLookupByLibrary.simpleMessage("Завершить"),
    "bdCompleteDebt": m15,
    "bdCompleteFrom": m16,
    "bdFromBalanceLine": m17,
    "bdKept": m18,
    "bdKeptChip": m19,
    "bdKeptLabel": MessageLookupByLibrary.simpleMessage("Удержано"),
    "bdLeft": MessageLookupByLibrary.simpleMessage("Осталось"),
    "bdMoreChild": MessageLookupByLibrary.simpleMessage("+ ребёнок"),
    "bdNetPaid": m20,
    "bdNoComments": MessageLookupByLibrary.simpleMessage("Заметок нет"),
    "bdNoPayments": MessageLookupByLibrary.simpleMessage("Оплат ещё нет"),
    "bdNoRefund": MessageLookupByLibrary.simpleMessage("Не возвращать"),
    "bdOfflineHint": MessageLookupByLibrary.simpleMessage(
      "Нет сети — повторите попытку",
    ),
    "bdPaidNet": MessageLookupByLibrary.simpleMessage("Оплачено"),
    "bdPayAmount": MessageLookupByLibrary.simpleMessage("Сумма оплаты"),
    "bdPayOverDebt": MessageLookupByLibrary.simpleMessage(
      "Сумма не должна превышать долг",
    ),
    "bdPaySubmit": MessageLookupByLibrary.simpleMessage("Принять оплату"),
    "bdPayTitle": MessageLookupByLibrary.simpleMessage("Добавить оплату"),
    "bdPayments": MessageLookupByLibrary.simpleMessage("Оплаты"),
    "bdRefund": MessageLookupByLibrary.simpleMessage("Вернуть"),
    "bdRefundEmpty": MessageLookupByLibrary.simpleMessage("Введите сумму"),
    "bdRefundToBalance": MessageLookupByLibrary.simpleMessage(
      "Возврат на баланс",
    ),
    "bdRefundToCash": MessageLookupByLibrary.simpleMessage("Возврат наличными"),
    "bdRequestConflict": MessageLookupByLibrary.simpleMessage(
      "Это действие уже выполнено — событие обновлено",
    ),
    "bdSplitMethod": m21,
    "bdTakeNow": MessageLookupByLibrary.simpleMessage("Берётся сейчас"),
    "bdToBalance": MessageLookupByLibrary.simpleMessage("На баланс"),
    "bdToCash": MessageLookupByLibrary.simpleMessage("Наличными"),
    "bdTotalTooLarge": m22,
    "bdUnclearHint": MessageLookupByLibrary.simpleMessage(
      "Ответ не получен. Суммы заблокированы — повторите попытку или закройте.",
    ),
    "birthdayAgeChip": m23,
    "birthdayAgeHint": m24,
    "birthdayAgeTitle": MessageLookupByLibrary.simpleMessage(
      "Сколько исполнилось?",
    ),
    "birthdayBookAndReceipt": MessageLookupByLibrary.simpleMessage(
      "Забронировать и чек",
    ),
    "birthdayChildCount": MessageLookupByLibrary.simpleMessage(
      "Количество детей",
    ),
    "birthdayChildrenUnit": MessageLookupByLibrary.simpleMessage("детей"),
    "birthdayDate": MessageLookupByLibrary.simpleMessage("Дата праздника"),
    "birthdayDeposit": MessageLookupByLibrary.simpleMessage("Залог"),
    "birthdayDepositAmount": MessageLookupByLibrary.simpleMessage(
      "Сумма залога",
    ),
    "birthdayDiscountNote": m25,
    "birthdayErrCompleteTooEarly": MessageLookupByLibrary.simpleMessage(
      "Нельзя завершить до даты праздника",
    ),
    "birthdayErrGeneric": MessageLookupByLibrary.simpleMessage(
      "Операция не выполнена",
    ),
    "birthdayErrNotBooked": MessageLookupByLibrary.simpleMessage(
      "Праздник уже завершён или отменён",
    ),
    "birthdayErrPartyNotFound": MessageLookupByLibrary.simpleMessage(
      "Праздник не найден",
    ),
    "birthdayErrPaymentEmpty": MessageLookupByLibrary.simpleMessage(
      "Сумма оплаты не указана",
    ),
    "birthdayErrPlanNotAvailable": MessageLookupByLibrary.simpleMessage(
      "Тариф недоступен в этом филиале",
    ),
    "birthdayErrSizeNotFound": MessageLookupByLibrary.simpleMessage(
      "Такого количества детей нет в тарифе",
    ),
    "birthdayExtraChild": MessageLookupByLibrary.simpleMessage(
      "Дополнительный ребёнок",
    ),
    "birthdayExtraHint": m26,
    "birthdayExtraPlusPrice": m27,
    "birthdayFreeOnlyToday": MessageLookupByLibrary.simpleMessage(
      "Доступно только в день рождения",
    ),
    "birthdayFromPrice": m28,
    "birthdayIncludes": MessageLookupByLibrary.simpleMessage("Входит в тариф"),
    "birthdayNoPlans": MessageLookupByLibrary.simpleMessage(
      "В этом филиале нет тарифов дня рождения",
    ),
    "birthdayOffline": MessageLookupByLibrary.simpleMessage(
      "Продажа дня рождения работает только онлайн",
    ),
    "birthdayPaidBeforeParty": MessageLookupByLibrary.simpleMessage(
      "Доплатить до праздника",
    ),
    "birthdayPayFull": MessageLookupByLibrary.simpleMessage("Полная оплата"),
    "birthdayPayment": MessageLookupByLibrary.simpleMessage("Оплата"),
    "birthdayPickPlanFirst": MessageLookupByLibrary.simpleMessage(
      "Сначала выберите тариф",
    ),
    "birthdayPlan": MessageLookupByLibrary.simpleMessage("Тариф"),
    "birthdayResetExtra": MessageLookupByLibrary.simpleMessage("Сбросить до 0"),
    "birthdaySell": MessageLookupByLibrary.simpleMessage(
      "Продажа дня рождения",
    ),
    "birthdayTotal": MessageLookupByLibrary.simpleMessage("Итого"),
    "branch": MessageLookupByLibrary.simpleMessage("Филиал"),
    "cancel": MessageLookupByLibrary.simpleMessage("Отмена"),
    "cartClear": MessageLookupByLibrary.simpleMessage("Очистить"),
    "cartClearMessage": MessageLookupByLibrary.simpleMessage(
      "Все товары будут удалены из корзины. Продолжить?",
    ),
    "cartClearTitle": MessageLookupByLibrary.simpleMessage("Очистить корзину"),
    "cartEmpty": MessageLookupByLibrary.simpleMessage("Корзина пуста"),
    "cartTitle": MessageLookupByLibrary.simpleMessage("Чек"),
    "cashDesk": MessageLookupByLibrary.simpleMessage("Касса"),
    "cashDeskCashier": m29,
    "cashback": MessageLookupByLibrary.simpleMessage("Кешбэк"),
    "categoryAll": MessageLookupByLibrary.simpleMessage("Все"),
    "checkDiscount": MessageLookupByLibrary.simpleMessage("Скидка на чек"),
    "checkDiscountLocked": MessageLookupByLibrary.simpleMessage(
      "Выбрана скидка на чек — скидки детей и промокод отключены",
    ),
    "checkDiscountNone": MessageLookupByLibrary.simpleMessage("Не выбрана"),
    "checkOnline": MessageLookupByLibrary.simpleMessage("Проверить связь"),
    "childCount": m30,
    "childName": MessageLookupByLibrary.simpleMessage("Имя ребёнка"),
    "children": MessageLookupByLibrary.simpleMessage("Дети"),
    "close": MessageLookupByLibrary.simpleMessage("Закрыть"),
    "closeShiftOffline": MessageLookupByLibrary.simpleMessage(
      "В офлайн-режиме смену закрыть нельзя",
    ),
    "closeShiftUnsyncedWarning": m31,
    "companionDescription": m32,
    "correctPaymentAction": MessageLookupByLibrary.simpleMessage(
      "Исправить способ оплаты",
    ),
    "correctPaymentAmount": MessageLookupByLibrary.simpleMessage(
      "Сумма переноса",
    ),
    "correctPaymentAudit": m33,
    "correctPaymentConfirmMessage": m34,
    "correctPaymentConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Подтвердите исправление",
    ),
    "correctPaymentFrom": MessageLookupByLibrary.simpleMessage(
      "Записано неверно как",
    ),
    "correctPaymentHint": MessageLookupByLibrary.simpleMessage(
      "Итоговая сумма чека не меняется. Исправляется только то, в какой колонке — наличные или карта — записаны деньги, чтобы сверка смены совпала с кассой.",
    ),
    "correctPaymentHistory": MessageLookupByLibrary.simpleMessage(
      "Исправления способа оплаты",
    ),
    "correctPaymentReason": MessageLookupByLibrary.simpleMessage(
      "Причина исправления",
    ),
    "correctPaymentReasonHint": MessageLookupByLibrary.simpleMessage(
      "Например: деньги взяты наличными, отмечено как карта",
    ),
    "correctPaymentResult": m35,
    "correctPaymentSuccess": MessageLookupByLibrary.simpleMessage(
      "Способ оплаты исправлен",
    ),
    "correctPaymentTitle": MessageLookupByLibrary.simpleMessage(
      "Исправление способа оплаты",
    ),
    "correctPaymentTo": MessageLookupByLibrary.simpleMessage(
      "Правильный способ",
    ),
    "correctPaymentUnavailable": MessageLookupByLibrary.simpleMessage(
      "Нельзя исправить способ оплаты по чеку с возвратом",
    ),
    "currentBalanceValue": m36,
    "currentPlanToday": m37,
    "currentShiftOnly": MessageLookupByLibrary.simpleMessage(
      "Только текущая смена",
    ),
    "currentTariff": MessageLookupByLibrary.simpleMessage("Текущий тариф"),
    "currentlyInside": MessageLookupByLibrary.simpleMessage("Сейчас внутри"),
    "customerCount": m38,
    "customerDirectorySearchHint": MessageLookupByLibrary.simpleMessage(
      "Поиск по имени или последним цифрам телефона",
    ),
    "date": MessageLookupByLibrary.simpleMessage("Дата"),
    "discount": MessageLookupByLibrary.simpleMessage("Скидка"),
    "discountGroupFixed": MessageLookupByLibrary.simpleMessage(
      "Фиксированная сумма",
    ),
    "discountGroupFree": MessageLookupByLibrary.simpleMessage(
      "Бесплатно (100%)",
    ),
    "discountGroupPercent": MessageLookupByLibrary.simpleMessage("В процентах"),
    "discountSearchHint": MessageLookupByLibrary.simpleMessage(
      "Поиск по названию",
    ),
    "discountUnavailableMessage": MessageLookupByLibrary.simpleMessage(
      "Скидка больше недоступна — выберите заново",
    ),
    "downgradeForbidden": MessageLookupByLibrary.simpleMessage(
      "Переход на более низкий тариф невозможен — если стикер потерян, повторно напечатайте текущий.",
    ),
    "editSaleAction": MessageLookupByLibrary.simpleMessage("Редактировать"),
    "editSaleBlockedBalance": MessageLookupByLibrary.simpleMessage(
      "На балансе клиента недостаточно средств — такую сумму вернуть нельзя.",
    ),
    "editSaleBlockedIncrease": MessageLookupByLibrary.simpleMessage(
      "Сумму нельзя увеличить. Если взяли больше, оформите отдельный новый платёж.",
    ),
    "editSaleBlockedMethod": MessageLookupByLibrary.simpleMessage(
      "По этому чеку был возврат, поэтому способ оплаты изменить нельзя. Можно только уменьшить сумму.",
    ),
    "editSaleBlockedNotEditable": MessageLookupByLibrary.simpleMessage(
      "Этот чек здесь редактировать нельзя.",
    ),
    "editSaleCurrent": m39,
    "editSaleHint": MessageLookupByLibrary.simpleMessage(
      "Введите правильную сумму и правильный способ оплаты. Система сама рассчитает действия: при смене способа переносятся колонки, при уменьшении суммы возвращается разница.",
    ),
    "editSaleMethod": MessageLookupByLibrary.simpleMessage(
      "Правильный способ оплаты",
    ),
    "editSalePartialFailure": MessageLookupByLibrary.simpleMessage(
      "Операция выполнена не полностью. Откройте чек и повторите редактирование — будет выполнено только оставшееся.",
    ),
    "editSalePlanCorrection": m40,
    "editSalePlanNoop": MessageLookupByLibrary.simpleMessage(
      "Ничего не изменится — чек уже такой",
    ),
    "editSalePlanRefund": m41,
    "editSalePlanTitle": MessageLookupByLibrary.simpleMessage(
      "Будут выполнены действия",
    ),
    "editSaleReason": MessageLookupByLibrary.simpleMessage(
      "Причина редактирования",
    ),
    "editSaleReasonHint": MessageLookupByLibrary.simpleMessage(
      "Например: сумма введена неверно, деньги взяты наличными",
    ),
    "editSaleSuccess": MessageLookupByLibrary.simpleMessage(
      "Чек отредактирован",
    ),
    "editSaleTitle": MessageLookupByLibrary.simpleMessage(
      "Редактирование чека",
    ),
    "editSaleTotal": MessageLookupByLibrary.simpleMessage("Правильная сумма"),
    "elapsedTime": MessageLookupByLibrary.simpleMessage("Прошло"),
    "enter": MessageLookupByLibrary.simpleMessage("Вход"),
    "enterCount": m42,
    "enteredAt": MessageLookupByLibrary.simpleMessage("Время входа"),
    "enteredAtMinutes": m43,
    "entryFailed": m44,
    "eventsAddPayment": MessageLookupByLibrary.simpleMessage("+ Оплата"),
    "eventsBooked": MessageLookupByLibrary.simpleMessage("Ожидаются"),
    "eventsCancelled": MessageLookupByLibrary.simpleMessage("Отменённые"),
    "eventsChildUnit": MessageLookupByLibrary.simpleMessage("дет."),
    "eventsComplete": MessageLookupByLibrary.simpleMessage("Завершить"),
    "eventsCompleted": MessageLookupByLibrary.simpleMessage("Завершённые"),
    "eventsDebt": m45,
    "eventsEmpty": MessageLookupByLibrary.simpleMessage("Мероприятий нет"),
    "eventsLater": MessageLookupByLibrary.simpleMessage("Позже"),
    "eventsLoadError": MessageLookupByLibrary.simpleMessage(
      "Не удалось загрузить события",
    ),
    "eventsNextWeek": MessageLookupByLibrary.simpleMessage(
      "На следующей неделе",
    ),
    "eventsOverdue": MessageLookupByLibrary.simpleMessage("Просроченные"),
    "eventsPaid": MessageLookupByLibrary.simpleMessage("Оплачено"),
    "eventsRetry": MessageLookupByLibrary.simpleMessage("Повторить"),
    "eventsThisWeek": MessageLookupByLibrary.simpleMessage("На этой неделе"),
    "eventsToday": MessageLookupByLibrary.simpleMessage("Сегодня"),
    "eventsTomorrow": MessageLookupByLibrary.simpleMessage("Завтра"),
    "eventsUnpaid": MessageLookupByLibrary.simpleMessage("Не оплачено"),
    "exitBalanceInsufficient": m46,
    "findCustomerHint": MessageLookupByLibrary.simpleMessage(
      "Введите номер телефона для поиска клиента",
    ),
    "foreignPhone": MessageLookupByLibrary.simpleMessage("Иностранный номер"),
    "foreignPhoneHint": MessageLookupByLibrary.simpleMessage(
      "Введите номер с кодом страны, например 7 916 123 45 67. На иностранные номера SMS не отправляются.",
    ),
    "foreignPhoneIsUzbek": MessageLookupByLibrary.simpleMessage(
      "998… — это узбекский номер. Выключите «Иностранный номер» и введите его после +998.",
    ),
    "free": MessageLookupByLibrary.simpleMessage("Бесплатно"),
    "fullName": MessageLookupByLibrary.simpleMessage("Имя и фамилия"),
    "history30Days": MessageLookupByLibrary.simpleMessage("30 дней"),
    "history7Days": MessageLookupByLibrary.simpleMessage("7 дней"),
    "historyAllProducts": MessageLookupByLibrary.simpleMessage("Все товары"),
    "historyChoose": MessageLookupByLibrary.simpleMessage("Выбрать"),
    "historyChoosePeriod": MessageLookupByLibrary.simpleMessage(
      "Выберите период продаж",
    ),
    "historyCount": m47,
    "historyDateRange": MessageLookupByLibrary.simpleMessage("Период"),
    "historyEmpty": MessageLookupByLibrary.simpleMessage(
      "За этот период продаж нет",
    ),
    "historyOfflineNotice": MessageLookupByLibrary.simpleMessage(
      "Офлайн-режим: показаны только несинхронизированные продажи",
    ),
    "historyProduct": MessageLookupByLibrary.simpleMessage("Товар"),
    "historySales": MessageLookupByLibrary.simpleMessage("Продажи"),
    "historyToday": MessageLookupByLibrary.simpleMessage("Сегодня"),
    "historyYear": MessageLookupByLibrary.simpleMessage("Этот год"),
    "hourAlreadyActive": m48,
    "hourChargedImmediately": MessageLookupByLibrary.simpleMessage(
      "Стоимость тарифа «1 час» списывается с баланса сразу при печати.",
    ),
    "hourEndedAtLabel": MessageLookupByLibrary.simpleMessage("Закончился"),
    "hourEndsAtLabel": MessageLookupByLibrary.simpleMessage("Заканчивается"),
    "hourOvertimeBanner": m49,
    "hourOvertimeBy": m50,
    "hourOvertimeShow": MessageLookupByLibrary.simpleMessage("Показать"),
    "hourRemaining": m51,
    "hourTariff": MessageLookupByLibrary.simpleMessage("Тариф «1 час»"),
    "insideCount": m52,
    "insideEmpty": MessageLookupByLibrary.simpleMessage(
      "Сейчас в парке нет детей",
    ),
    "insideFilterAll": MessageLookupByLibrary.simpleMessage("Все"),
    "insideFilterHour": MessageLookupByLibrary.simpleMessage("По времени"),
    "insideFilterOvertime": MessageLookupByLibrary.simpleMessage("Время вышло"),
    "insideHourEmpty": MessageLookupByLibrary.simpleMessage(
      "Сейчас нет детей на тарифах по времени",
    ),
    "insideHourEndingSoon": MessageLookupByLibrary.simpleMessage(
      "Заканчивается за 10 мин",
    ),
    "insideHourInside": MessageLookupByLibrary.simpleMessage(
      "По времени внутри",
    ),
    "insideNoTurnstileNote": MessageLookupByLibrary.simpleMessage(
      "Нет турникета: ребёнок с билетом по времени (1 час и др.) отмечается внутри при печати билета, время идёт с этого момента — отмечайте выход здесь, когда он уходит.",
    ),
    "insideOvertimeEmpty": MessageLookupByLibrary.simpleMessage(
      "Нет детей с истёкшим временем",
    ),
    "insideSearchEmpty": MessageLookupByLibrary.simpleMessage(
      "По вашему запросу ничего не найдено",
    ),
    "insideSearchHint": MessageLookupByLibrary.simpleMessage(
      "Поиск по ребёнку, родителю или телефону",
    ),
    "insideSoldHour": MessageLookupByLibrary.simpleMessage(
      "По времени продано сегодня",
    ),
    "insideSoldVip": MessageLookupByLibrary.simpleMessage(
      "VIP продано сегодня",
    ),
    "insideSuffix": MessageLookupByLibrary.simpleMessage(" (сейчас внутри)"),
    "keypadHint": MessageLookupByLibrary.simpleMessage(
      "Введите номер — результаты появятся справа. Нажмите на клиента, чтобы открыть детали.",
    ),
    "language": MessageLookupByLibrary.simpleMessage("Язык"),
    "languageRussian": MessageLookupByLibrary.simpleMessage("Русский"),
    "languageUzbek": MessageLookupByLibrary.simpleMessage("O‘zbekcha"),
    "loginButton": MessageLookupByLibrary.simpleMessage("Войти"),
    "loginError": MessageLookupByLibrary.simpleMessage(
      "Неверный логин или пароль",
    ),
    "loginPassword": MessageLookupByLibrary.simpleMessage("Пароль"),
    "loginSubtitle": MessageLookupByLibrary.simpleMessage(
      "Введите логин и пароль для входа в кассу",
    ),
    "loginTitle": MessageLookupByLibrary.simpleMessage("Вход в кассу"),
    "loginUsername": MessageLookupByLibrary.simpleMessage("Логин"),
    "logout": MessageLookupByLibrary.simpleMessage("Выйти"),
    "logoutAnyway": MessageLookupByLibrary.simpleMessage("Всё равно выйти"),
    "logoutBlockedUnsynced": m53,
    "logoutFailedSalesConfirm": m54,
    "manualExitQuestion": m55,
    "manualExitSucceeded": MessageLookupByLibrary.simpleMessage(
      "Выход ребёнка успешно отмечен",
    ),
    "manualExitTitle": MessageLookupByLibrary.simpleMessage("QR-код потерян?"),
    "markExited": MessageLookupByLibrary.simpleMessage("Отметить выход"),
    "menuClose": MessageLookupByLibrary.simpleMessage("Закрыть меню"),
    "menuOpen": MessageLookupByLibrary.simpleMessage("Открыть меню"),
    "minutesCount": m56,
    "needsInternet": MessageLookupByLibrary.simpleMessage("Нужен интернет"),
    "newBalance": MessageLookupByLibrary.simpleMessage("Новый баланс"),
    "noChildren": MessageLookupByLibrary.simpleMessage("детей нет"),
    "noDiscount": MessageLookupByLibrary.simpleMessage("Без скидки"),
    "noPaymentNow": MessageLookupByLibrary.simpleMessage(
      "Сейчас оплата не требуется — при выходе стоимость времени спишется с баланса.",
    ),
    "noPrintersFound": MessageLookupByLibrary.simpleMessage(
      "В Windows не найдено установленных принтеров",
    ),
    "notSyncedBadge": MessageLookupByLibrary.simpleMessage(
      "Не синхронизировано",
    ),
    "offlineBanner": m57,
    "offlineBannerSyncing": MessageLookupByLibrary.simpleMessage(
      "Синхронизация…",
    ),
    "offlinePromptAccept": MessageLookupByLibrary.simpleMessage(
      "Да, офлайн-режим",
    ),
    "offlinePromptBody": MessageLookupByLibrary.simpleMessage(
      "Связь с сервером потеряна. Перейти в офлайн-режим и продолжить продажи? Продажи сохранятся на кассе и отправятся на сервер, когда интернет вернётся.",
    ),
    "offlinePromptDecline": MessageLookupByLibrary.simpleMessage("Нет"),
    "offlinePromptTitle": MessageLookupByLibrary.simpleMessage(
      "Нет подключения к интернету",
    ),
    "onlinePromptAccept": MessageLookupByLibrary.simpleMessage(
      "Да, синхронизировать",
    ),
    "onlinePromptBody": m58,
    "onlinePromptLater": MessageLookupByLibrary.simpleMessage("Позже"),
    "onlinePromptTitle": MessageLookupByLibrary.simpleMessage(
      "Интернет вернулся",
    ),
    "openCustomerProfile": MessageLookupByLibrary.simpleMessage(
      "Открыть профиль клиента",
    ),
    "paidLabel": MessageLookupByLibrary.simpleMessage("оплачено"),
    "parentQr": MessageLookupByLibrary.simpleMessage("QR родителя"),
    "pay": MessageLookupByLibrary.simpleMessage("Оплатить"),
    "payFromBalance": MessageLookupByLibrary.simpleMessage("Списать с баланса"),
    "paymentAmount": MessageLookupByLibrary.simpleMessage("Сумма оплаты"),
    "paymentAndPrint": MessageLookupByLibrary.simpleMessage(
      "Оплатить и напечатать",
    ),
    "paymentBalance": MessageLookupByLibrary.simpleMessage("Продажи с баланса"),
    "paymentBalanceValue": m59,
    "paymentCard": MessageLookupByLibrary.simpleMessage("Карта"),
    "paymentCardValue": m60,
    "paymentCash": MessageLookupByLibrary.simpleMessage("Наличные"),
    "paymentCashValue": m61,
    "paymentExcess": MessageLookupByLibrary.simpleMessage(
      "Введена лишняя сумма",
    ),
    "paymentMatched": MessageLookupByLibrary.simpleMessage("Сумма совпадает"),
    "paymentMinimumHint": m62,
    "paymentMissing": MessageLookupByLibrary.simpleMessage(
      "Суммы недостаточно",
    ),
    "paymentSplit": MessageLookupByLibrary.simpleMessage("Смешанная"),
    "phoneNotFound": MessageLookupByLibrary.simpleMessage("Номер не найден"),
    "phoneNumber": MessageLookupByLibrary.simpleMessage("Номер телефона"),
    "planAlreadyActive": m63,
    "planChargedImmediately": m64,
    "planSwitch": MessageLookupByLibrary.simpleMessage("Смена тарифа"),
    "planSwitchBlocked": m65,
    "planSwitchCollectNow": MessageLookupByLibrary.simpleMessage(
      "К оплате сейчас",
    ),
    "planSwitchContinue": MessageLookupByLibrary.simpleMessage("Продолжить"),
    "planSwitchHourToVipNote": MessageLookupByLibrary.simpleMessage(
      "Стоимость тарифа «1 час» не возвращается.",
    ),
    "planSwitchPayInDialog": MessageLookupByLibrary.simpleMessage(
      "У выбранного ребёнка сегодня другой тариф — сумма к оплате (только доплата) будет в следующем окне.",
    ),
    "planSwitchQuestion": m66,
    "planSwitchUpgradeCollectQuestion": m67,
    "planSwitchUpgradeQuestion": m68,
    "planSwitchVipQuestion": m69,
    "planUpgradeAndPrint": MessageLookupByLibrary.simpleMessage(
      "Обновить тариф",
    ),
    "planUpgradeLine": m70,
    "priceFromPerMinute": m71,
    "pricePerDay": m72,
    "pricePerHour": m73,
    "printParentQr": MessageLookupByLibrary.simpleMessage(
      "Также напечатать QR родителя",
    ),
    "printReceipt": MessageLookupByLibrary.simpleMessage("Распечатать чек"),
    "printerSettings": MessageLookupByLibrary.simpleMessage("Принтеры"),
    "printing": MessageLookupByLibrary.simpleMessage("Печать…"),
    "productNotFound": MessageLookupByLibrary.simpleMessage("Товар не найден"),
    "productSearchHint": MessageLookupByLibrary.simpleMessage(
      "Название или категория товара",
    ),
    "products": MessageLookupByLibrary.simpleMessage("Товары"),
    "promoCode": MessageLookupByLibrary.simpleMessage("Промокод"),
    "promoCodeAlreadyUsedByCustomer": MessageLookupByLibrary.simpleMessage(
      "Этот клиент уже использовал этот промокод",
    ),
    "promoCodeBlogger": MessageLookupByLibrary.simpleMessage("Блогер"),
    "promoCodeBloggerPending": m74,
    "promoCodeCheck": MessageLookupByLibrary.simpleMessage("Проверить"),
    "promoCodeChildHasPass": MessageLookupByLibrary.simpleMessage(
      "У ребёнка уже есть пропуск на сегодня — промокод действует только на новый вход или переход на VIP",
    ),
    "promoCodeForChild": MessageLookupByLibrary.simpleMessage("Какому ребёнку"),
    "promoCodeHint": MessageLookupByLibrary.simpleMessage(
      "Сканируйте или введите",
    ),
    "promoCodeInvalid": MessageLookupByLibrary.simpleMessage(
      "Неверный промокод — проверьте код",
    ),
    "promoCodeLimitReached": MessageLookupByLibrary.simpleMessage(
      "Лимит использований промокода исчерпан",
    ),
    "promoCodeNoChild": MessageLookupByLibrary.simpleMessage(
      "Выберите ребёнка для промокода",
    ),
    "promoCodeNotStarted": MessageLookupByLibrary.simpleMessage(
      "Промокод ещё не действует",
    ),
    "promoCodeOwnerNotFound": MessageLookupByLibrary.simpleMessage(
      "Владелец промокода не найден",
    ),
    "promoCodeReleased": m75,
    "promoCodeRemove": MessageLookupByLibrary.simpleMessage("Убрать промокод"),
    "promoCodeWrongCustomer": MessageLookupByLibrary.simpleMessage(
      "Этот промокод принадлежит другому клиенту",
    ),
    "qrPrinter": MessageLookupByLibrary.simpleMessage("Принтер QR и наклеек"),
    "qrPrinterFallbackNotice": MessageLookupByLibrary.simpleMessage(
      "QR-принтер не найден, поэтому QR-код напечатан вместе с чеком",
    ),
    "quickAdd": MessageLookupByLibrary.simpleMessage("Быстро добавить"),
    "receipt": MessageLookupByLibrary.simpleMessage("Чек"),
    "receiptCount": MessageLookupByLibrary.simpleMessage("Количество чеков"),
    "receiptPrintFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось распечатать чек. Проверьте принтер.",
    ),
    "receiptPrinter": MessageLookupByLibrary.simpleMessage(
      "Принтер товарных чеков",
    ),
    "recentCustomers": MessageLookupByLibrary.simpleMessage("Недавние клиенты"),
    "refresh": MessageLookupByLibrary.simpleMessage("Обновить"),
    "refundAction": MessageLookupByLibrary.simpleMessage("Возврат"),
    "refundAlreadyAmount": MessageLookupByLibrary.simpleMessage("Возвращено"),
    "refundAmount": MessageLookupByLibrary.simpleMessage("Сумма возврата"),
    "refundAuditBy": m76,
    "refundBalanceLimitNote": MessageLookupByLibrary.simpleMessage(
      "Возврат пополнения списывается с баланса, поэтому вернуть больше, чем на нём осталось, нельзя.",
    ),
    "refundBalanceMethod": MessageLookupByLibrary.simpleMessage("На баланс"),
    "refundCardWarning": MessageLookupByLibrary.simpleMessage(
      "Возврат на карту также нужно отдельно выполнить на платёжном терминале. Это действие не отменяет транзакцию терминала автоматически.",
    ),
    "refundConfirmMessage": m77,
    "refundConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Подтвердите возврат",
    ),
    "refundCustomerBalance": m78,
    "refundFullBadge": MessageLookupByLibrary.simpleMessage("Полный возврат"),
    "refundFundedConfirm": m79,
    "refundFundedHint": MessageLookupByLibrary.simpleMessage(
      "Отметьте пропуска, которые клиент возвращает: их стоимость сначала вернётся на баланс, затем будет выдана наличными или картой. Отмеченные пропуска сразу аннулируются.",
    ),
    "refundFundedTitle": MessageLookupByLibrary.simpleMessage(
      "Пропуска, купленные с этого пополнения",
    ),
    "refundHistory": MessageLookupByLibrary.simpleMessage("История возвратов"),
    "refundMax": MessageLookupByLibrary.simpleMessage("Выбрать всю сумму"),
    "refundMethod": MessageLookupByLibrary.simpleMessage("Способ возврата"),
    "refundNoRefundablePasses": MessageLookupByLibrary.simpleMessage(
      "В этом чеке не осталось пропусков для возврата",
    ),
    "refundOriginalAmount": MessageLookupByLibrary.simpleMessage(
      "Исходный платёж",
    ),
    "refundPartialBadge": MessageLookupByLibrary.simpleMessage(
      "Частичный возврат",
    ),
    "refundPassUsed": MessageLookupByLibrary.simpleMessage("Использован"),
    "refundPassVoided": MessageLookupByLibrary.simpleMessage("Аннулирован"),
    "refundReason": MessageLookupByLibrary.simpleMessage("Причина возврата"),
    "refundReasonHint": MessageLookupByLibrary.simpleMessage(
      "Например: возврат товара или ошибка в заказе",
    ),
    "refundReasonValidation": MessageLookupByLibrary.simpleMessage(
      "Причина должна содержать не менее 5 символов",
    ),
    "refundRemainingAmount": MessageLookupByLibrary.simpleMessage("Остаток"),
    "refundSelectPasses": MessageLookupByLibrary.simpleMessage(
      "Выберите возвращаемые пропуска",
    ),
    "refundSelectPassesValidation": MessageLookupByLibrary.simpleMessage(
      "Выберите хотя бы один пропуск",
    ),
    "refundSelectedPassesTotal": MessageLookupByLibrary.simpleMessage(
      "Сумма выбранных пропусков",
    ),
    "refundSuccess": m80,
    "refundTitle": MessageLookupByLibrary.simpleMessage("Возврат платежа"),
    "refundedTotal": MessageLookupByLibrary.simpleMessage("Возвращено"),
    "reprint": MessageLookupByLibrary.simpleMessage("Повторная печать"),
    "reprintAll": MessageLookupByLibrary.simpleMessage("Перепечатать все"),
    "saleGatePass": MessageLookupByLibrary.simpleMessage("Входной билет"),
    "saleGeneric": MessageLookupByLibrary.simpleMessage("Продажа"),
    "saleGoods": MessageLookupByLibrary.simpleMessage("Продажа товара"),
    "saleTopup": MessageLookupByLibrary.simpleMessage("Пополнение счёта"),
    "save": MessageLookupByLibrary.simpleMessage("Сохранить"),
    "searchHistory": MessageLookupByLibrary.simpleMessage("История поиска"),
    "searchResult": MessageLookupByLibrary.simpleMessage("Результаты поиска"),
    "selectForQr": MessageLookupByLibrary.simpleMessage("Выберите для QR"),
    "selectedCount": m81,
    "shiftBirthdayIncome": MessageLookupByLibrary.simpleMessage(
      "Из них дни рождения",
    ),
    "shiftBirthdayRefunded": MessageLookupByLibrary.simpleMessage(
      "Возврат по дню рождения",
    ),
    "shiftClose": MessageLookupByLibrary.simpleMessage("Закрыть смену"),
    "shiftClosed": MessageLookupByLibrary.simpleMessage("Смена закрыта"),
    "shiftCountUnit": m82,
    "shiftEnteredChildren": MessageLookupByLibrary.simpleMessage(
      "Зашли внутрь",
    ),
    "shiftOpen": MessageLookupByLibrary.simpleMessage("Открыть смену"),
    "shiftOpenedAt": m83,
    "shiftOpeningCash": MessageLookupByLibrary.simpleMessage(
      "Начальные наличные (сум)",
    ),
    "shiftPrintReport": MessageLookupByLibrary.simpleMessage(
      "Распечатать чек смены",
    ),
    "shiftRevenue": MessageLookupByLibrary.simpleMessage("Выручка смены"),
    "shiftStart": MessageLookupByLibrary.simpleMessage("Начать смену"),
    "shiftStartHint": MessageLookupByLibrary.simpleMessage(
      "Введите начальную сумму наличных в кассе",
    ),
    "shiftTicketsSold": MessageLookupByLibrary.simpleMessage("Продано билетов"),
    "shiftTotalIncome": MessageLookupByLibrary.simpleMessage(
      "Итого выручка смены",
    ),
    "shiftUniqueChildren": MessageLookupByLibrary.simpleMessage(
      "Уникальных детей",
    ),
    "shiftVipTickets": MessageLookupByLibrary.simpleMessage("Из них VIP"),
    "stickerPrintFailed": MessageLookupByLibrary.simpleMessage(
      "Стикер не напечатан — проверьте принтер",
    ),
    "stillOffline": MessageLookupByLibrary.simpleMessage(
      "Интернета всё ещё нет",
    ),
    "switchAndPrint": MessageLookupByLibrary.simpleMessage(
      "Сменить и напечатать",
    ),
    "syncResultBody": m84,
    "syncResultTitle": MessageLookupByLibrary.simpleMessage(
      "Результат синхронизации",
    ),
    "syncTransportFailed": m85,
    "syncViewFailures": MessageLookupByLibrary.simpleMessage("Открыть"),
    "tabAccount": MessageLookupByLibrary.simpleMessage("Счёт и QR"),
    "tabEvents": MessageLookupByLibrary.simpleMessage("Мероприятия"),
    "tabHistory": MessageLookupByLibrary.simpleMessage("История продаж"),
    "tabInside": MessageLookupByLibrary.simpleMessage("В парке"),
    "tabSales": MessageLookupByLibrary.simpleMessage("Продажи"),
    "tabSettings": MessageLookupByLibrary.simpleMessage("Настройки"),
    "tabUnsynced": MessageLookupByLibrary.simpleMessage("Не синхронизировано"),
    "tabVisitHistory": MessageLookupByLibrary.simpleMessage("История входов"),
    "tariff": MessageLookupByLibrary.simpleMessage("Тариф"),
    "tariffNotFound": MessageLookupByLibrary.simpleMessage(
      "Тарифы не найдены.",
    ),
    "themeDay": MessageLookupByLibrary.simpleMessage("Дневной режим"),
    "themeNight": MessageLookupByLibrary.simpleMessage("Ночной режим"),
    "themeNightHint": MessageLookupByLibrary.simpleMessage(
      "Мягкий тёмно-синий фон, не утомляющий глаза. Запоминается на этой кассе.",
    ),
    "topup": MessageLookupByLibrary.simpleMessage("Пополнить"),
    "topupBalance": MessageLookupByLibrary.simpleMessage("Пополнить баланс"),
    "topupConfirmAction": MessageLookupByLibrary.simpleMessage("Пополнить"),
    "topupConfirmAmount": MessageLookupByLibrary.simpleMessage(
      "Сумма пополнения",
    ),
    "topupConfirmCustomer": MessageLookupByLibrary.simpleMessage("Клиент"),
    "topupConfirmMethod": MessageLookupByLibrary.simpleMessage("Способ оплаты"),
    "topupConfirmNewBalance": MessageLookupByLibrary.simpleMessage(
      "Новый баланс",
    ),
    "topupConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Подтвердите пополнение",
    ),
    "topupConfirmWarning": MessageLookupByLibrary.simpleMessage(
      "После подтверждения сумма зачислится на баланс клиента. Если она неверна, чек можно исправить через «Редактировать».",
    ),
    "topupDetails": MessageLookupByLibrary.simpleMessage(
      "Детали пополнения счёта",
    ),
    "total": MessageLookupByLibrary.simpleMessage("Итого"),
    "totalBill": MessageLookupByLibrary.simpleMessage("Общий счёт"),
    "transactionId": MessageLookupByLibrary.simpleMessage("ID транзакции"),
    "txBonus": MessageLookupByLibrary.simpleMessage("Бонус"),
    "txCashierTopup": MessageLookupByLibrary.simpleMessage(
      "Пополнение на кассе",
    ),
    "txCashierTopupRefund": MessageLookupByLibrary.simpleMessage(
      "Возврат пополнения",
    ),
    "txGameReward": MessageLookupByLibrary.simpleMessage("Награда за игру"),
    "txKidsCharge": MessageLookupByLibrary.simpleMessage("Тариф (вход)"),
    "txLegacy": MessageLookupByLibrary.simpleMessage("Старая запись"),
    "txManualAdjustment": MessageLookupByLibrary.simpleMessage(
      "Ручная корректировка",
    ),
    "txMarketPurchase": MessageLookupByLibrary.simpleMessage(
      "Покупка в маркете",
    ),
    "txMarketRefund": MessageLookupByLibrary.simpleMessage("Возврат в маркете"),
    "txPayment": MessageLookupByLibrary.simpleMessage(
      "Пополнение через приложение",
    ),
    "txPosPurchase": MessageLookupByLibrary.simpleMessage("Покупка на кассе"),
    "txPosPurchaseRefund": MessageLookupByLibrary.simpleMessage(
      "Возврат покупки",
    ),
    "txStatusCancelled": MessageLookupByLibrary.simpleMessage("Отменено"),
    "txStatusFailed": MessageLookupByLibrary.simpleMessage("Не выполнено"),
    "txStatusPending": MessageLookupByLibrary.simpleMessage("В ожидании"),
    "unlimitedFreeEntry": MessageLookupByLibrary.simpleMessage(
      "Бесплатно — вход и выход без ограничений",
    ),
    "unsyncedCodeCopied": MessageLookupByLibrary.simpleMessage(
      "Код скопирован",
    ),
    "unsyncedEmpty": MessageLookupByLibrary.simpleMessage(
      "Все продажи синхронизированы",
    ),
    "unsyncedFailed": MessageLookupByLibrary.simpleMessage("Ошибка"),
    "unsyncedHint": MessageLookupByLibrary.simpleMessage(
      "По продаже с ошибкой позвоните в поддержку и назовите код.",
    ),
    "unsyncedPending": MessageLookupByLibrary.simpleMessage("Ожидает"),
    "unsyncedRetry": MessageLookupByLibrary.simpleMessage("Повторить"),
    "unsyncedRetryAll": MessageLookupByLibrary.simpleMessage(
      "Отправить все заново",
    ),
    "unsyncedRetryNeedsOnline": MessageLookupByLibrary.simpleMessage(
      "Чтобы отправить заново, перейдите в онлайн-режим",
    ),
    "unsyncedSupportCode": m86,
    "updateAvailable": m87,
    "updateCancel": MessageLookupByLibrary.simpleMessage("Отмена"),
    "updateCheck": MessageLookupByLibrary.simpleMessage("Проверить обновления"),
    "updateConfirm": MessageLookupByLibrary.simpleMessage("Продолжить"),
    "updateConfirmMessage": MessageLookupByLibrary.simpleMessage(
      "Приложение закроется и снова откроется на новой версии. Смена останется открытой. Продолжить?",
    ),
    "updateConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Обновление приложения",
    ),
    "updateDownload": MessageLookupByLibrary.simpleMessage(
      "Скачать и установить",
    ),
    "updateDownloading": MessageLookupByLibrary.simpleMessage("Загрузка…"),
    "updateFailed": MessageLookupByLibrary.simpleMessage("Не удалось обновить"),
    "updateFailedGeneric": MessageLookupByLibrary.simpleMessage(
      "Не удалось обновить. Проверьте подключение к интернету и попробуйте снова.",
    ),
    "updateFailureChecksumMismatch": MessageLookupByLibrary.simpleMessage(
      "Скачанный файл повреждён — контрольная сумма не совпала",
    ),
    "updateFailureChecksumUnreadable": MessageLookupByLibrary.simpleMessage(
      "Не удалось прочитать опубликованную контрольную сумму — обновление с непроверенным файлом не устанавливается",
    ),
    "updateFailureExecutableMissing": MessageLookupByLibrary.simpleMessage(
      "В скачанном архиве не найдена программа приложения",
    ),
    "updateFailureIncompleteExtraction": MessageLookupByLibrary.simpleMessage(
      "Обновление распаковалось не полностью. Файл был удалён — попробуйте ещё раз",
    ),
    "updateManualHint": MessageLookupByLibrary.simpleMessage(
      "Для ручной загрузки:",
    ),
    "updateReady": MessageLookupByLibrary.simpleMessage("Обновление готово"),
    "updateRestart": MessageLookupByLibrary.simpleMessage("Перезапустить"),
    "updateTitle": MessageLookupByLibrary.simpleMessage("Обновление"),
    "updateUpToDate": MessageLookupByLibrary.simpleMessage(
      "Установлена последняя версия",
    ),
    "updateWindowsOnly": MessageLookupByLibrary.simpleMessage(
      "Автообновление работает только в Windows",
    ),
    "upgradeCredit": m88,
    "version": MessageLookupByLibrary.simpleMessage("Версия"),
    "vipAlreadyActive": m89,
    "vipChargedImmediately": MessageLookupByLibrary.simpleMessage(
      "Стоимость VIP-тарифа списывается с баланса сразу при печати.",
    ),
    "vipTariff": MessageLookupByLibrary.simpleMessage("VIP-тариф"),
    "visitChild": MessageLookupByLibrary.simpleMessage(
      "Ребёнок в этом посещении",
    ),
    "visitDetails": MessageLookupByLibrary.simpleMessage(
      "Детали входа и выхода",
    ),
    "visitEntered": MessageLookupByLibrary.simpleMessage("Вошёл"),
    "visitEntries": MessageLookupByLibrary.simpleMessage("Входы"),
    "visitExited": MessageLookupByLibrary.simpleMessage("Вышел"),
    "visitExits": MessageLookupByLibrary.simpleMessage("Выходы"),
    "visitHistoryEmpty": MessageLookupByLibrary.simpleMessage(
      "В текущей смене входов и выходов нет",
    ),
    "visitHistorySearchHint": MessageLookupByLibrary.simpleMessage(
      "Поиск по ребенку, родителю или телефону",
    ),
    "visitInside": MessageLookupByLibrary.simpleMessage("Внутри"),
    "visitManualExit": MessageLookupByLibrary.simpleMessage("Выведен вручную"),
    "visitStillInside": MessageLookupByLibrary.simpleMessage("Ещё внутри"),
  };
}
