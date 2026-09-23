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

  static String m0(phone) => "Для +998 ${phone} аккаунт не найден.";

  static String m1(value) =>
      "За проведённое время с баланса будет списано ${value}.";

  static String m2(value) =>
      "Недостаточно средств — необходимо оплатить минимум ${value}.";

  static String m3(name) => "Касса · ${name}";

  static String m4(count) => "Детей: ${count}";

  static String m5(count) =>
      "Продаж с ошибкой синхронизации: ${count}. Перед закрытием смены обратитесь в поддержку.";

  static String m6(price) =>
      "${price} / шт. — без ограничений, как QR родителя";

  static String m7(amount, from, to) => "${amount}: ${from} → ${to}";

  static String m8(amount, from, to) =>
      "${amount} переносится с «${from}» на «${to}». Операция сохранится в истории аудита.";

  static String m9(cash, card) => "Итог: наличные ${cash}, карта ${card}";

  static String m10(value) => "Текущий баланс: ${value}";

  static String m11(child, plan, inside) =>
      "Сегодня «${child}» на тарифе «${plan}»${inside}.";

  static String m12(count) => "Клиентов: ${count}";

  static String m13(cash, card) => "Сейчас: ${cash} наличные + ${card} карта";

  static String m14(amount, from, to) =>
      "${amount} — перенос с «${from}» на «${to}»";

  static String m15(amount, method) =>
      "${amount} — возврат клиенту (${method})";

  static String m16(count) => "Вход (${count})";

  static String m17(plan, time, minutes) =>
      "${plan} · вход ${time} · ${minutes} мин";

  static String m18(message) => "Не вошли: ${message}";

  static String m19(value) =>
      "Недостаточно средств — для выхода пополните минимум на ${value}.";

  static String m20(count) => "${count}";

  static String m21(count) => "Внутри: ${count}";

  static String m22(count) =>
      "Несинхронизированных продаж: ${count}. Перед выходом синхронизируйте их в онлайн-режиме.";

  static String m23(count) =>
      "${count} продаж не синхронизированы (ошибка). Они сохранятся на кассе. Всё равно выйти?";

  static String m24(child, amount) =>
      "Выход ребёнка ${child} будет отмечен сейчас. Сессия закроется по текущей сумме ${amount}, которая спишется с баланса родителя. Продолжить?";

  static String m25(count) => "${count} мин";

  static String m26(count) => "OFFLINE · ожидают продаж: ${count}";

  static String m27(count) =>
      "Перейти в онлайн-режим и синхронизировать продажи (${count})?";

  static String m28(value) => "Баланс: ${value}";

  static String m29(value) => "Карта: ${value}";

  static String m30(value) => "Наличные: ${value}";

  static String m31(value) => "Минимум ${value} — остаток останется на балансе";

  static String m32(plan) =>
      "Переключить на тариф «${plan}»? Старый стикер будет отменён, новый QR напечатан.";

  static String m33(plan, price) =>
      "Переключить на тариф «${plan}»? Стоимость ${plan} (${price}) будет сразу списана с баланса. Старый стикер будет отменён, новый QR напечатан.";

  static String m34(value) => "от ${value} / мин";

  static String m35(value) => "${value} / день";

  static String m36(date, name) => "${date} · ${name}";

  static String m37(amount, method) =>
      "${amount} будет возвращено способом «${method}». Действие навсегда сохранится в истории аудита.";

  static String m38(balance) => "Баланс клиента: ${balance}";

  static String m39(amount) => "Успешно возвращено ${amount}";

  static String m40(count) => "выбрано: ${count}";

  static String m41(time) => "Смена открыта в ${time}";

  static String m42(synced, failed) =>
      "Синхронизировано: ${synced}, с ошибкой: ${failed}.";

  static String m43(reason) =>
      "Не удалось синхронизировать: ${reason}. Офлайн-режим продолжается.";

  static String m44(code) => "Код: ${code}";

  static String m45(version) => "Доступна новая версия: ${version}";

  static String m46(name) =>
      "«${name}» уже на активном VIP-тарифе — повторная оплата не взимается.";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "accountId": MessageLookupByLibrary.simpleMessage("ID счёта"),
    "accountNotFoundForPhone": m0,
    "accountOwner": MessageLookupByLibrary.simpleMessage("Владелец счёта"),
    "accruedAmount": MessageLookupByLibrary.simpleMessage("Текущий счёт"),
    "accruedDue": m1,
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
    "balanceInsufficient": m2,
    "balanceSalesNotIncome": MessageLookupByLibrary.simpleMessage(
      "Продажи с баланса (не выручка)",
    ),
    "birthdayFreeOnlyToday": MessageLookupByLibrary.simpleMessage(
      "Доступно только в день рождения",
    ),
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
    "cashDeskCashier": m3,
    "categoryAll": MessageLookupByLibrary.simpleMessage("Все"),
    "checkOnline": MessageLookupByLibrary.simpleMessage("Проверить связь"),
    "childCount": m4,
    "childName": MessageLookupByLibrary.simpleMessage("Имя ребёнка"),
    "children": MessageLookupByLibrary.simpleMessage("Дети"),
    "close": MessageLookupByLibrary.simpleMessage("Закрыть"),
    "closeShiftOffline": MessageLookupByLibrary.simpleMessage(
      "В офлайн-режиме смену закрыть нельзя",
    ),
    "closeShiftUnsyncedWarning": m5,
    "companionDescription": m6,
    "correctPaymentAction": MessageLookupByLibrary.simpleMessage(
      "Исправить способ оплаты",
    ),
    "correctPaymentAmount": MessageLookupByLibrary.simpleMessage(
      "Сумма переноса",
    ),
    "correctPaymentAudit": m7,
    "correctPaymentConfirmMessage": m8,
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
    "correctPaymentResult": m9,
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
    "currentBalanceValue": m10,
    "currentPlanToday": m11,
    "currentShiftOnly": MessageLookupByLibrary.simpleMessage(
      "Только текущая смена",
    ),
    "currentlyInside": MessageLookupByLibrary.simpleMessage("Сейчас внутри"),
    "customerCount": m12,
    "customerDirectorySearchHint": MessageLookupByLibrary.simpleMessage(
      "Поиск по имени или последним цифрам телефона",
    ),
    "date": MessageLookupByLibrary.simpleMessage("Дата"),
    "discount": MessageLookupByLibrary.simpleMessage("Скидка"),
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
    "editSaleCurrent": m13,
    "editSaleHint": MessageLookupByLibrary.simpleMessage(
      "Введите правильную сумму и правильный способ оплаты. Система сама рассчитает действия: при смене способа переносятся колонки, при уменьшении суммы возвращается разница.",
    ),
    "editSaleMethod": MessageLookupByLibrary.simpleMessage(
      "Правильный способ оплаты",
    ),
    "editSalePartialFailure": MessageLookupByLibrary.simpleMessage(
      "Операция выполнена не полностью. Откройте чек и повторите редактирование — будет выполнено только оставшееся.",
    ),
    "editSalePlanCorrection": m14,
    "editSalePlanNoop": MessageLookupByLibrary.simpleMessage(
      "Ничего не изменится — чек уже такой",
    ),
    "editSalePlanRefund": m15,
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
    "enterCount": m16,
    "enteredAt": MessageLookupByLibrary.simpleMessage("Время входа"),
    "enteredAtMinutes": m17,
    "entryFailed": m18,
    "exitBalanceInsufficient": m19,
    "findCustomerHint": MessageLookupByLibrary.simpleMessage(
      "Введите номер телефона для поиска клиента",
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
    "historyCount": m20,
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
    "insideCount": m21,
    "insideEmpty": MessageLookupByLibrary.simpleMessage(
      "Сейчас в парке нет детей",
    ),
    "insideSearchEmpty": MessageLookupByLibrary.simpleMessage(
      "По вашему запросу ничего не найдено",
    ),
    "insideSearchHint": MessageLookupByLibrary.simpleMessage(
      "Поиск по ребёнку, родителю или телефону",
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
    "logoutBlockedUnsynced": m22,
    "logoutFailedSalesConfirm": m23,
    "manualExitQuestion": m24,
    "manualExitSucceeded": MessageLookupByLibrary.simpleMessage(
      "Выход ребёнка успешно отмечен",
    ),
    "manualExitTitle": MessageLookupByLibrary.simpleMessage("QR-код потерян?"),
    "markExited": MessageLookupByLibrary.simpleMessage("Отметить выход"),
    "menuClose": MessageLookupByLibrary.simpleMessage("Закрыть меню"),
    "menuOpen": MessageLookupByLibrary.simpleMessage("Открыть меню"),
    "minutesCount": m25,
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
    "offlineBanner": m26,
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
    "onlinePromptBody": m27,
    "onlinePromptLater": MessageLookupByLibrary.simpleMessage("Позже"),
    "onlinePromptTitle": MessageLookupByLibrary.simpleMessage(
      "Интернет вернулся",
    ),
    "openCustomerProfile": MessageLookupByLibrary.simpleMessage(
      "Открыть профиль клиента",
    ),
    "parentQr": MessageLookupByLibrary.simpleMessage("QR родителя"),
    "pay": MessageLookupByLibrary.simpleMessage("Оплатить"),
    "payFromBalance": MessageLookupByLibrary.simpleMessage("Списать с баланса"),
    "paymentAmount": MessageLookupByLibrary.simpleMessage("Сумма оплаты"),
    "paymentAndPrint": MessageLookupByLibrary.simpleMessage(
      "Оплатить и напечатать",
    ),
    "paymentBalance": MessageLookupByLibrary.simpleMessage("Продажи с баланса"),
    "paymentBalanceValue": m28,
    "paymentCard": MessageLookupByLibrary.simpleMessage("Карта"),
    "paymentCardValue": m29,
    "paymentCash": MessageLookupByLibrary.simpleMessage("Наличные"),
    "paymentCashValue": m30,
    "paymentExcess": MessageLookupByLibrary.simpleMessage(
      "Введена лишняя сумма",
    ),
    "paymentMatched": MessageLookupByLibrary.simpleMessage("Сумма совпадает"),
    "paymentMinimumHint": m31,
    "paymentMissing": MessageLookupByLibrary.simpleMessage(
      "Суммы недостаточно",
    ),
    "paymentSplit": MessageLookupByLibrary.simpleMessage("Смешанная"),
    "phoneNotFound": MessageLookupByLibrary.simpleMessage("Номер не найден"),
    "phoneNumber": MessageLookupByLibrary.simpleMessage("Номер телефона"),
    "planSwitch": MessageLookupByLibrary.simpleMessage("Смена тарифа"),
    "planSwitchQuestion": m32,
    "planSwitchVipQuestion": m33,
    "priceFromPerMinute": m34,
    "pricePerDay": m35,
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
    "qrPrinter": MessageLookupByLibrary.simpleMessage("Принтер QR и наклеек"),
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
    "refundAuditBy": m36,
    "refundBalanceLimitNote": MessageLookupByLibrary.simpleMessage(
      "Возврат пополнения списывается с баланса, поэтому вернуть больше, чем на нём осталось, нельзя.",
    ),
    "refundBalanceMethod": MessageLookupByLibrary.simpleMessage("На баланс"),
    "refundCardWarning": MessageLookupByLibrary.simpleMessage(
      "Возврат на карту также нужно отдельно выполнить на платёжном терминале. Это действие не отменяет транзакцию терминала автоматически.",
    ),
    "refundConfirmMessage": m37,
    "refundConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Подтвердите возврат",
    ),
    "refundCustomerBalance": m38,
    "refundFullBadge": MessageLookupByLibrary.simpleMessage("Полный возврат"),
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
    "refundSuccess": m39,
    "refundTitle": MessageLookupByLibrary.simpleMessage("Возврат платежа"),
    "refundedTotal": MessageLookupByLibrary.simpleMessage("Возвращено"),
    "reprint": MessageLookupByLibrary.simpleMessage("Повторная печать"),
    "saleGatePass": MessageLookupByLibrary.simpleMessage("Входной билет"),
    "saleGeneric": MessageLookupByLibrary.simpleMessage("Продажа"),
    "saleGoods": MessageLookupByLibrary.simpleMessage("Продажа товара"),
    "saleTopup": MessageLookupByLibrary.simpleMessage("Пополнение счёта"),
    "save": MessageLookupByLibrary.simpleMessage("Сохранить"),
    "searchHistory": MessageLookupByLibrary.simpleMessage("История поиска"),
    "searchResult": MessageLookupByLibrary.simpleMessage("Результаты поиска"),
    "selectForQr": MessageLookupByLibrary.simpleMessage("Выберите для QR"),
    "selectedCount": m40,
    "shiftClose": MessageLookupByLibrary.simpleMessage("Закрыть смену"),
    "shiftClosed": MessageLookupByLibrary.simpleMessage("Смена закрыта"),
    "shiftOpen": MessageLookupByLibrary.simpleMessage("Открыть смену"),
    "shiftOpenedAt": m41,
    "shiftOpeningCash": MessageLookupByLibrary.simpleMessage(
      "Начальные наличные (сум)",
    ),
    "shiftRevenue": MessageLookupByLibrary.simpleMessage("Выручка смены"),
    "shiftStart": MessageLookupByLibrary.simpleMessage("Начать смену"),
    "shiftStartHint": MessageLookupByLibrary.simpleMessage(
      "Введите начальную сумму наличных в кассе",
    ),
    "shiftTotalIncome": MessageLookupByLibrary.simpleMessage(
      "Итого выручка смены",
    ),
    "stickerPrintFailed": MessageLookupByLibrary.simpleMessage(
      "Стикер не напечатан — проверьте принтер",
    ),
    "stillOffline": MessageLookupByLibrary.simpleMessage(
      "Интернета всё ещё нет",
    ),
    "switchAndPrint": MessageLookupByLibrary.simpleMessage(
      "Сменить и напечатать",
    ),
    "syncResultBody": m42,
    "syncResultTitle": MessageLookupByLibrary.simpleMessage(
      "Результат синхронизации",
    ),
    "syncTransportFailed": m43,
    "syncViewFailures": MessageLookupByLibrary.simpleMessage("Открыть"),
    "tabAccount": MessageLookupByLibrary.simpleMessage("Счёт и QR"),
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
    "unsyncedSupportCode": m44,
    "updateAvailable": m45,
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
    "version": MessageLookupByLibrary.simpleMessage("Версия"),
    "vipAlreadyActive": m46,
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
