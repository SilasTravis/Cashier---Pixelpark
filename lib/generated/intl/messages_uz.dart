// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a uz locale. All the
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
  String get localeName => 'uz';

  static String m0(phone) => "+998 ${phone} bo‘yicha hisob yo‘q.";

  static String m1(value) =>
      "O‘ynagan vaqti uchun ${value} balansdan yechiladi.";

  static String m2(value) =>
      "Balansdan yechishga yetarli emas — kamida ${value} to‘lov kerak.";

  static String m3(name) => "Kassa · ${name}";

  static String m4(count) => "${count} farzand";

  static String m5(price) => "${price} / dona — ota-ona QR kabi cheklovsiz";

  static String m6(value) => "Joriy balans: ${value}";

  static String m7(child, plan, inside) =>
      "«${child}» bugun «${plan}» rejasida${inside}.";

  static String m8(count) => "${count} ta mijoz";

  static String m9(count) => "Kirish (${count})";

  static String m10(plan, time, minutes) =>
      "${plan} · kirdi ${time} · ${minutes} daq";

  static String m11(message) => "Kirmadi: ${message}";

  static String m12(value) =>
      "Balans yetarli emas — chiqish uchun kamida ${value} to‘ldirish kerak.";

  static String m13(count) => "${count} ta";

  static String m14(count) => "Ichkarida: ${count}";

  static String m15(child, amount) =>
      "${child} chiqarildi deb belgilanadi. Hozirgi hisob ${amount} bo‘yicha yopilib, ota-ona balansidan yechiladi. Davom etilsinmi?";

  static String m16(count) => "${count} daqiqa";

  static String m17(value) => "Balans: ${value}";

  static String m18(value) => "Karta: ${value}";

  static String m19(value) => "Naqd: ${value}";

  static String m20(value) => "Kamida ${value} — ortig‘i balansda qoladi";

  static String m21(plan) =>
      "«${plan}» rejasiga almashtirilsinmi? Eski stiker bekor qilinadi va yangi QR chop etiladi.";

  static String m22(plan, price) =>
      "«${plan}» rejasiga almashtirilsinmi? ${plan} narxi (${price}) balansdan darhol yechiladi. Eski stiker bekor qilinadi va yangi QR chop etiladi.";

  static String m23(value) => "${value} / daq dan";

  static String m24(value) => "${value} / kun";

  static String m25(date, name) => "${date} · ${name}";

  static String m26(amount, method) =>
      "${amount} ${method} orqali qaytariladi. Bu amal audit tarixida saqlanadi va o‘chirib bo‘lmaydi.";

  static String m27(balance) => "Mijoz balansi: ${balance}";

  static String m28(amount) => "${amount} muvaffaqiyatli qaytarildi";

  static String m29(count) => "tanlangan: ${count}";

  static String m30(time) => "Smena ${time} da ochildi";

  static String m31(version) => "Yangi versiya mavjud: ${version}";

  static String m32(name) =>
      "«${name}» allaqachon faol VIP tarifda — qayta to‘lov olinmaydi.";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "accountId": MessageLookupByLibrary.simpleMessage("Hisob ID"),
    "accountNotFoundForPhone": m0,
    "accountOwner": MessageLookupByLibrary.simpleMessage("Hisob egasi"),
    "accruedAmount": MessageLookupByLibrary.simpleMessage("Joriy hisob"),
    "accruedDue": m1,
    "add": MessageLookupByLibrary.simpleMessage("Qo‘shish"),
    "addCustomer": MessageLookupByLibrary.simpleMessage("Mijoz qo‘shish"),
    "allCustomers": MessageLookupByLibrary.simpleMessage("Barcha mijozlar"),
    "amount": MessageLookupByLibrary.simpleMessage("Summa"),
    "appTitle": MessageLookupByLibrary.simpleMessage("Bolajon — kassa"),
    "automaticGodex": MessageLookupByLibrary.simpleMessage("Avtomatik — Godex"),
    "automaticSewoo": MessageLookupByLibrary.simpleMessage("Avtomatik — SLK"),
    "balance": MessageLookupByLibrary.simpleMessage("Balans"),
    "balanceInsufficient": m2,
    "balanceSalesNotIncome": MessageLookupByLibrary.simpleMessage(
      "Balansdan savdo (tushum emas)",
    ),
    "birthdayFreeOnlyToday": MessageLookupByLibrary.simpleMessage(
      "Faqat tug‘ilgan kunida tanlanadi",
    ),
    "branch": MessageLookupByLibrary.simpleMessage("Filial"),
    "cancel": MessageLookupByLibrary.simpleMessage("Bekor qilish"),
    "cartClear": MessageLookupByLibrary.simpleMessage("Tozalash"),
    "cartClearMessage": MessageLookupByLibrary.simpleMessage(
      "Savatdagi barcha mahsulotlar o‘chiriladi. Davom etasizmi?",
    ),
    "cartClearTitle": MessageLookupByLibrary.simpleMessage("Chekni tozalash"),
    "cartEmpty": MessageLookupByLibrary.simpleMessage("Chek bo‘sh"),
    "cartTitle": MessageLookupByLibrary.simpleMessage("Chek"),
    "cashDesk": MessageLookupByLibrary.simpleMessage("Kassa"),
    "cashDeskCashier": m3,
    "categoryAll": MessageLookupByLibrary.simpleMessage("Hammasi"),
    "childCount": m4,
    "childName": MessageLookupByLibrary.simpleMessage("Bola ismi"),
    "children": MessageLookupByLibrary.simpleMessage("Farzandlar"),
    "close": MessageLookupByLibrary.simpleMessage("Yopish"),
    "companionDescription": m5,
    "currentBalanceValue": m6,
    "currentPlanToday": m7,
    "currentShiftOnly": MessageLookupByLibrary.simpleMessage(
      "Faqat joriy smena",
    ),
    "currentlyInside": MessageLookupByLibrary.simpleMessage("Hozir ichkarida"),
    "customerCount": m8,
    "customerDirectorySearchHint": MessageLookupByLibrary.simpleMessage(
      "Ism yoki telefonning oxirgi raqamlari bo‘yicha qidiring",
    ),
    "date": MessageLookupByLibrary.simpleMessage("Sana"),
    "downgradeForbidden": MessageLookupByLibrary.simpleMessage(
      "Bu rejadan pasaytirish mumkin emas — stiker yo‘qolgan bo‘lsa, mavjud rejani qayta chop eting.",
    ),
    "elapsedTime": MessageLookupByLibrary.simpleMessage("O‘tgan vaqt"),
    "enter": MessageLookupByLibrary.simpleMessage("Kirish"),
    "enterCount": m9,
    "enteredAt": MessageLookupByLibrary.simpleMessage("Kirgan vaqti"),
    "enteredAtMinutes": m10,
    "entryFailed": m11,
    "exitBalanceInsufficient": m12,
    "findCustomerHint": MessageLookupByLibrary.simpleMessage(
      "Mijozni topish uchun telefon raqamini kiriting",
    ),
    "free": MessageLookupByLibrary.simpleMessage("Bepul"),
    "freeEntryReasons": MessageLookupByLibrary.simpleMessage(
      "Bepul kirish sabablari",
    ),
    "freeReasonAile": MessageLookupByLibrary.simpleMessage("AILE"),
    "freeReasonBirthday": MessageLookupByLibrary.simpleMessage("Tug‘ilgan kun"),
    "freeReasonDisabled": MessageLookupByLibrary.simpleMessage("Nogiron"),
    "freeReasonSubscription": MessageLookupByLibrary.simpleMessage("Obuna"),
    "fullName": MessageLookupByLibrary.simpleMessage("Ism familiya"),
    "history30Days": MessageLookupByLibrary.simpleMessage("30 kun"),
    "history7Days": MessageLookupByLibrary.simpleMessage("7 kun"),
    "historyAllProducts": MessageLookupByLibrary.simpleMessage(
      "Barcha mahsulotlar",
    ),
    "historyChoose": MessageLookupByLibrary.simpleMessage("Tanlash"),
    "historyChoosePeriod": MessageLookupByLibrary.simpleMessage(
      "Sotuv davrini tanlang",
    ),
    "historyCount": m13,
    "historyDateRange": MessageLookupByLibrary.simpleMessage("Sana oralig‘i"),
    "historyEmpty": MessageLookupByLibrary.simpleMessage(
      "Bu davrda sotuvlar yo‘q",
    ),
    "historyProduct": MessageLookupByLibrary.simpleMessage("Mahsulot"),
    "historySales": MessageLookupByLibrary.simpleMessage("Sotuvlar"),
    "historyToday": MessageLookupByLibrary.simpleMessage("Bugun"),
    "historyYear": MessageLookupByLibrary.simpleMessage("Bu yil"),
    "insideCount": m14,
    "insideEmpty": MessageLookupByLibrary.simpleMessage(
      "Hozir park ichida bolalar yo‘q",
    ),
    "insideSearchEmpty": MessageLookupByLibrary.simpleMessage(
      "Qidiruv bo‘yicha bola topilmadi",
    ),
    "insideSearchHint": MessageLookupByLibrary.simpleMessage(
      "Bola, ota-ona yoki telefon bo‘yicha qidirish",
    ),
    "insideSuffix": MessageLookupByLibrary.simpleMessage(" (hozir ichkarida)"),
    "keypadHint": MessageLookupByLibrary.simpleMessage(
      "Raqamni kiritganda o‘ngda natija chiqadi. Mijozni bosib, tafsilotlarni ochasiz.",
    ),
    "language": MessageLookupByLibrary.simpleMessage("Til"),
    "languageRussian": MessageLookupByLibrary.simpleMessage("Русский"),
    "languageUzbek": MessageLookupByLibrary.simpleMessage("O‘zbekcha"),
    "loginButton": MessageLookupByLibrary.simpleMessage("Kirish"),
    "loginError": MessageLookupByLibrary.simpleMessage(
      "Login yoki parol noto\'g\'ri",
    ),
    "loginPassword": MessageLookupByLibrary.simpleMessage("Parol"),
    "loginSubtitle": MessageLookupByLibrary.simpleMessage(
      "Kassaga kirish uchun login va parolni kiriting",
    ),
    "loginTitle": MessageLookupByLibrary.simpleMessage("Kassaga kirish"),
    "loginUsername": MessageLookupByLibrary.simpleMessage("Login"),
    "logout": MessageLookupByLibrary.simpleMessage("Chiqish"),
    "manualExitQuestion": m15,
    "manualExitSucceeded": MessageLookupByLibrary.simpleMessage(
      "Bola muvaffaqiyatli chiqarildi deb belgilandi",
    ),
    "manualExitTitle": MessageLookupByLibrary.simpleMessage("QR yo‘qolganmi?"),
    "markExited": MessageLookupByLibrary.simpleMessage(
      "Chiqarildi deb belgilash",
    ),
    "menuClose": MessageLookupByLibrary.simpleMessage("Menyuni yopish"),
    "menuOpen": MessageLookupByLibrary.simpleMessage("Menyuni ochish"),
    "minutesCount": m16,
    "newBalance": MessageLookupByLibrary.simpleMessage("Yangi balans"),
    "noChildren": MessageLookupByLibrary.simpleMessage("farzand yo‘q"),
    "noPaymentNow": MessageLookupByLibrary.simpleMessage(
      "Hozir hech narsa to‘lanmaydi — chiqishda balansdan vaqtiga qarab yechiladi.",
    ),
    "noPrintersFound": MessageLookupByLibrary.simpleMessage(
      "Windows’da o‘rnatilgan printer topilmadi",
    ),
    "openCustomerProfile": MessageLookupByLibrary.simpleMessage(
      "User profiliga kirish",
    ),
    "parentQr": MessageLookupByLibrary.simpleMessage("Ota-ona QR"),
    "pay": MessageLookupByLibrary.simpleMessage("To‘lash"),
    "payFromBalance": MessageLookupByLibrary.simpleMessage("Balansdan yechish"),
    "paymentAmount": MessageLookupByLibrary.simpleMessage("To‘lov summasi"),
    "paymentAndPrint": MessageLookupByLibrary.simpleMessage(
      "To‘lov va chop etish",
    ),
    "paymentBalance": MessageLookupByLibrary.simpleMessage("Balansdan savdo"),
    "paymentBalanceValue": m17,
    "paymentCard": MessageLookupByLibrary.simpleMessage("Karta"),
    "paymentCardValue": m18,
    "paymentCash": MessageLookupByLibrary.simpleMessage("Naqd"),
    "paymentCashValue": m19,
    "paymentExcess": MessageLookupByLibrary.simpleMessage("Ortiqcha kiritildi"),
    "paymentMatched": MessageLookupByLibrary.simpleMessage("Summa mos keldi"),
    "paymentMinimumHint": m20,
    "paymentMissing": MessageLookupByLibrary.simpleMessage("Yetmayapti"),
    "paymentSplit": MessageLookupByLibrary.simpleMessage("Aralash"),
    "phoneNotFound": MessageLookupByLibrary.simpleMessage("Bu raqam topilmadi"),
    "phoneNumber": MessageLookupByLibrary.simpleMessage("Telefon raqami"),
    "planSwitch": MessageLookupByLibrary.simpleMessage("Reja almashtirish"),
    "planSwitchQuestion": m21,
    "planSwitchVipQuestion": m22,
    "priceFromPerMinute": m23,
    "pricePerDay": m24,
    "printParentQr": MessageLookupByLibrary.simpleMessage(
      "Ota-ona QR ham chop etish",
    ),
    "printReceipt": MessageLookupByLibrary.simpleMessage("Chekni chop etish"),
    "printerSettings": MessageLookupByLibrary.simpleMessage("Printerlar"),
    "printing": MessageLookupByLibrary.simpleMessage("Chop etilmoqda…"),
    "productNotFound": MessageLookupByLibrary.simpleMessage(
      "Mahsulot topilmadi",
    ),
    "productSearchHint": MessageLookupByLibrary.simpleMessage(
      "Mahsulot nomi yoki kategoriya",
    ),
    "products": MessageLookupByLibrary.simpleMessage("Mahsulotlar"),
    "qrPrinter": MessageLookupByLibrary.simpleMessage("QR va stiker printeri"),
    "quickAdd": MessageLookupByLibrary.simpleMessage("Tez qo‘shish"),
    "receipt": MessageLookupByLibrary.simpleMessage("Chek"),
    "receiptCount": MessageLookupByLibrary.simpleMessage("Cheklar soni"),
    "receiptPrintFailed": MessageLookupByLibrary.simpleMessage(
      "Chek chop etilmadi. Printerni tekshiring.",
    ),
    "receiptPrinter": MessageLookupByLibrary.simpleMessage(
      "Mahsulot cheki printeri",
    ),
    "recentCustomers": MessageLookupByLibrary.simpleMessage("So‘nggi mijozlar"),
    "refresh": MessageLookupByLibrary.simpleMessage("Yangilash"),
    "refundAction": MessageLookupByLibrary.simpleMessage("Qaytarish"),
    "refundAlreadyAmount": MessageLookupByLibrary.simpleMessage("Qaytarilgan"),
    "refundAmount": MessageLookupByLibrary.simpleMessage(
      "Qaytariladigan summa",
    ),
    "refundAuditBy": m25,
    "refundBalanceLimitNote": MessageLookupByLibrary.simpleMessage(
      "To‘ldirishni qaytarish puli balansdan yechiladi, shuning uchun balansda qolgan summadan ortiq qaytarib bo‘lmaydi.",
    ),
    "refundBalanceMethod": MessageLookupByLibrary.simpleMessage("Balansga"),
    "refundCardWarning": MessageLookupByLibrary.simpleMessage(
      "Karta orqali qaytarish terminalda ham alohida bajarilishi kerak. Ilovadagi amal terminal tranzaksiyasini avtomatik bekor qilmaydi.",
    ),
    "refundConfirmMessage": m26,
    "refundConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Qaytarishni tasdiqlang",
    ),
    "refundCustomerBalance": m27,
    "refundFullBadge": MessageLookupByLibrary.simpleMessage(
      "To‘liq qaytarilgan",
    ),
    "refundHistory": MessageLookupByLibrary.simpleMessage("Qaytarish tarixi"),
    "refundMax": MessageLookupByLibrary.simpleMessage("Hammasini tanlash"),
    "refundMethod": MessageLookupByLibrary.simpleMessage("Qaytarish usuli"),
    "refundNoRefundablePasses": MessageLookupByLibrary.simpleMessage(
      "Bu chekda qaytariladigan chipta qolmagan",
    ),
    "refundOriginalAmount": MessageLookupByLibrary.simpleMessage("Asl to‘lov"),
    "refundPartialBadge": MessageLookupByLibrary.simpleMessage(
      "Qisman qaytarilgan",
    ),
    "refundPassUsed": MessageLookupByLibrary.simpleMessage("Ishlatilgan"),
    "refundPassVoided": MessageLookupByLibrary.simpleMessage("Bekor qilingan"),
    "refundReason": MessageLookupByLibrary.simpleMessage("Qaytarish sababi"),
    "refundReasonHint": MessageLookupByLibrary.simpleMessage(
      "Masalan: mahsulot qaytarildi yoki buyurtma xato kiritildi",
    ),
    "refundReasonValidation": MessageLookupByLibrary.simpleMessage(
      "Sabab kamida 5 ta belgidan iborat bo‘lishi kerak",
    ),
    "refundRemainingAmount": MessageLookupByLibrary.simpleMessage(
      "Qolgan summa",
    ),
    "refundSelectPasses": MessageLookupByLibrary.simpleMessage(
      "Qaytarilayotgan chiptalarni tanlang",
    ),
    "refundSelectPassesValidation": MessageLookupByLibrary.simpleMessage(
      "Kamida bitta chipta tanlang",
    ),
    "refundSelectedPassesTotal": MessageLookupByLibrary.simpleMessage(
      "Tanlangan chiptalar summasi",
    ),
    "refundSuccess": m28,
    "refundTitle": MessageLookupByLibrary.simpleMessage("To‘lovdan qaytarish"),
    "refundedTotal": MessageLookupByLibrary.simpleMessage("Qaytarilgan"),
    "reprint": MessageLookupByLibrary.simpleMessage("Qayta chop etish"),
    "saleGatePass": MessageLookupByLibrary.simpleMessage("Kirish chiptasi"),
    "saleGeneric": MessageLookupByLibrary.simpleMessage("Sotuv"),
    "saleGoods": MessageLookupByLibrary.simpleMessage("Mahsulot savdosi"),
    "saleTopup": MessageLookupByLibrary.simpleMessage("Hisob to‘ldirish"),
    "save": MessageLookupByLibrary.simpleMessage("Saqlash"),
    "searchHistory": MessageLookupByLibrary.simpleMessage("Qidiruv tarixi"),
    "searchResult": MessageLookupByLibrary.simpleMessage("Qidiruv natijasi"),
    "selectForQr": MessageLookupByLibrary.simpleMessage("QR uchun tanlang"),
    "selectedCount": m29,
    "shiftClose": MessageLookupByLibrary.simpleMessage("Smenani yopish"),
    "shiftClosed": MessageLookupByLibrary.simpleMessage("Smena yopildi"),
    "shiftOpen": MessageLookupByLibrary.simpleMessage("Smenani ochish"),
    "shiftOpenedAt": m30,
    "shiftOpeningCash": MessageLookupByLibrary.simpleMessage(
      "Boshlang‘ich naqd (so‘m)",
    ),
    "shiftRevenue": MessageLookupByLibrary.simpleMessage("Smena tushumi"),
    "shiftStart": MessageLookupByLibrary.simpleMessage("Smenani boshlash"),
    "shiftStartHint": MessageLookupByLibrary.simpleMessage(
      "Ishni boshlash uchun kassadagi boshlang‘ich naqd summani kiriting",
    ),
    "shiftTotalIncome": MessageLookupByLibrary.simpleMessage(
      "Jami smena tushumi",
    ),
    "stickerPrintFailed": MessageLookupByLibrary.simpleMessage(
      "Stiker chop etilmadi — printerni tekshiring",
    ),
    "switchAndPrint": MessageLookupByLibrary.simpleMessage(
      "Almashtirish va chop etish",
    ),
    "tabAccount": MessageLookupByLibrary.simpleMessage("Hisob va QR"),
    "tabHistory": MessageLookupByLibrary.simpleMessage("Sotuv tarixi"),
    "tabInside": MessageLookupByLibrary.simpleMessage("Park ichida"),
    "tabSales": MessageLookupByLibrary.simpleMessage("Savdo"),
    "tabSettings": MessageLookupByLibrary.simpleMessage("Sozlamalar"),
    "tabVisitHistory": MessageLookupByLibrary.simpleMessage(
      "Kirdi-chiqdi tarixi",
    ),
    "tariff": MessageLookupByLibrary.simpleMessage("Tarif"),
    "tariffNotFound": MessageLookupByLibrary.simpleMessage("Tarif topilmadi."),
    "topup": MessageLookupByLibrary.simpleMessage("To‘ldirish"),
    "topupBalance": MessageLookupByLibrary.simpleMessage("Balansni to‘ldirish"),
    "topupDetails": MessageLookupByLibrary.simpleMessage(
      "Hisob to‘ldirish tafsilotlari",
    ),
    "total": MessageLookupByLibrary.simpleMessage("Jami"),
    "totalBill": MessageLookupByLibrary.simpleMessage("Jami hisob"),
    "transactionId": MessageLookupByLibrary.simpleMessage("Tranzaksiya ID"),
    "unlimitedFreeEntry": MessageLookupByLibrary.simpleMessage(
      "Bepul — kirish-chiqishga cheklovsiz",
    ),
    "updateAvailable": m31,
    "updateCancel": MessageLookupByLibrary.simpleMessage("Bekor qilish"),
    "updateCheck": MessageLookupByLibrary.simpleMessage(
      "Yangilanishni tekshirish",
    ),
    "updateConfirm": MessageLookupByLibrary.simpleMessage("Davom etish"),
    "updateConfirmMessage": MessageLookupByLibrary.simpleMessage(
      "Ilova yopiladi va yangi versiyada qayta ochiladi. Smena ochiq qoladi. Davom etasizmi?",
    ),
    "updateConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Ilovani yangilash",
    ),
    "updateDownload": MessageLookupByLibrary.simpleMessage(
      "Yuklab olish va o‘rnatish",
    ),
    "updateDownloading": MessageLookupByLibrary.simpleMessage("Yuklanmoqda…"),
    "updateFailed": MessageLookupByLibrary.simpleMessage("Yangilanmadi"),
    "updateFailedGeneric": MessageLookupByLibrary.simpleMessage(
      "Yangilanmadi. Internet aloqasini tekshiring va qayta urinib ko‘ring.",
    ),
    "updateFailureChecksumMismatch": MessageLookupByLibrary.simpleMessage(
      "Yuklab olingan fayl buzilgan chiqdi — tekshiruv summasi mos kelmadi",
    ),
    "updateFailureChecksumUnreadable": MessageLookupByLibrary.simpleMessage(
      "Nashr etilgan tekshiruv summasini o‘qib bo‘lmadi — tasdiqlanmagan yangilanish o‘rnatilmaydi",
    ),
    "updateFailureExecutableMissing": MessageLookupByLibrary.simpleMessage(
      "Yuklab olingan arxivda ilova dasturi topilmadi",
    ),
    "updateFailureIncompleteExtraction": MessageLookupByLibrary.simpleMessage(
      "Yangilanish to‘liq yozilmadi. Yuklangan fayl bekor qilindi — qaytadan urinib ko‘ring",
    ),
    "updateManualHint": MessageLookupByLibrary.simpleMessage(
      "Qo‘lda yuklab olish uchun:",
    ),
    "updateReady": MessageLookupByLibrary.simpleMessage("Yangilanish tayyor"),
    "updateRestart": MessageLookupByLibrary.simpleMessage(
      "Qayta ishga tushirish",
    ),
    "updateTitle": MessageLookupByLibrary.simpleMessage("Yangilanish"),
    "updateUpToDate": MessageLookupByLibrary.simpleMessage(
      "Eng so‘nggi versiya o‘rnatilgan",
    ),
    "updateWindowsOnly": MessageLookupByLibrary.simpleMessage(
      "Avtomatik yangilash faqat Windows’da ishlaydi",
    ),
    "version": MessageLookupByLibrary.simpleMessage("Versiya"),
    "vipAlreadyActive": m32,
    "vipChargedImmediately": MessageLookupByLibrary.simpleMessage(
      "VIP tarif puli chop etilganda balansdan darhol yechiladi.",
    ),
    "vipTariff": MessageLookupByLibrary.simpleMessage("VIP tarif"),
    "visitChild": MessageLookupByLibrary.simpleMessage(
      "Ushbu tashrifdagi bola",
    ),
    "visitDetails": MessageLookupByLibrary.simpleMessage(
      "Kirdi-chiqdi tafsilotlari",
    ),
    "visitEntered": MessageLookupByLibrary.simpleMessage("Kirdi"),
    "visitEntries": MessageLookupByLibrary.simpleMessage("Kirishlar"),
    "visitExited": MessageLookupByLibrary.simpleMessage("Chiqdi"),
    "visitExits": MessageLookupByLibrary.simpleMessage("Chiqishlar"),
    "visitHistoryEmpty": MessageLookupByLibrary.simpleMessage(
      "Joriy smenada kirdi-chiqdi mavjud emas",
    ),
    "visitHistorySearchHint": MessageLookupByLibrary.simpleMessage(
      "Bola, ota-ona yoki telefon bo‘yicha qidirish",
    ),
    "visitInside": MessageLookupByLibrary.simpleMessage("Ichkarida"),
    "visitManualExit": MessageLookupByLibrary.simpleMessage(
      "Qo‘lda chiqarilgan",
    ),
    "visitStillInside": MessageLookupByLibrary.simpleMessage("Hali ichkarida"),
  };
}
