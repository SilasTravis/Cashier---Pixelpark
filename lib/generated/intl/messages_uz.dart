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

  static String m0(count) => "${count} ta";

  static String m1(value) => "Balans: ${value}";

  static String m2(value) => "Karta: ${value}";

  static String m3(value) => "Naqd: ${value}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "appTitle": MessageLookupByLibrary.simpleMessage("Bolajon — kassa"),
    "automaticGodex": MessageLookupByLibrary.simpleMessage("Avtomatik — Godex"),
    "automaticSewoo": MessageLookupByLibrary.simpleMessage("Avtomatik — SLK"),
    "branch": MessageLookupByLibrary.simpleMessage("Filial"),
    "cancel": MessageLookupByLibrary.simpleMessage("Bekor qilish"),
    "cartClear": MessageLookupByLibrary.simpleMessage("Tozalash"),
    "cartClearMessage": MessageLookupByLibrary.simpleMessage(
      "Savatdagi barcha mahsulotlar o‘chiriladi. Davom etasizmi?",
    ),
    "cartClearTitle": MessageLookupByLibrary.simpleMessage("Chekni tozalash"),
    "cartEmpty": MessageLookupByLibrary.simpleMessage("Chek bo‘sh"),
    "cartTitle": MessageLookupByLibrary.simpleMessage("Chek"),
    "categoryAll": MessageLookupByLibrary.simpleMessage("Hammasi"),
    "close": MessageLookupByLibrary.simpleMessage("Yopish"),
    "history30Days": MessageLookupByLibrary.simpleMessage("30 kun"),
    "history7Days": MessageLookupByLibrary.simpleMessage("7 kun"),
    "historyAllProducts": MessageLookupByLibrary.simpleMessage(
      "Barcha mahsulotlar",
    ),
    "historyChoose": MessageLookupByLibrary.simpleMessage("Tanlash"),
    "historyChoosePeriod": MessageLookupByLibrary.simpleMessage(
      "Sotuv davrini tanlang",
    ),
    "historyCount": m0,
    "historyDateRange": MessageLookupByLibrary.simpleMessage("Sana oralig‘i"),
    "historyEmpty": MessageLookupByLibrary.simpleMessage(
      "Bu davrda sotuvlar yo‘q",
    ),
    "historyProduct": MessageLookupByLibrary.simpleMessage("Mahsulot"),
    "historySales": MessageLookupByLibrary.simpleMessage("Sotuvlar"),
    "historyToday": MessageLookupByLibrary.simpleMessage("Bugun"),
    "historyYear": MessageLookupByLibrary.simpleMessage("Bu yil"),
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
    "noPrintersFound": MessageLookupByLibrary.simpleMessage(
      "Windows’da o‘rnatilgan printer topilmadi",
    ),
    "pay": MessageLookupByLibrary.simpleMessage("To‘lash"),
    "paymentBalanceValue": m1,
    "paymentCard": MessageLookupByLibrary.simpleMessage("Karta"),
    "paymentCardValue": m2,
    "paymentCash": MessageLookupByLibrary.simpleMessage("Naqd"),
    "paymentCashValue": m3,
    "paymentExcess": MessageLookupByLibrary.simpleMessage("Ortiqcha kiritildi"),
    "paymentMatched": MessageLookupByLibrary.simpleMessage("Summa mos keldi"),
    "paymentMissing": MessageLookupByLibrary.simpleMessage("Yetmayapti"),
    "paymentSplit": MessageLookupByLibrary.simpleMessage("Aralash"),
    "printReceipt": MessageLookupByLibrary.simpleMessage("Chekni chop etish"),
    "printerSettings": MessageLookupByLibrary.simpleMessage("Printerlar"),
    "printing": MessageLookupByLibrary.simpleMessage("Chop etilmoqda…"),
    "productSearchHint": MessageLookupByLibrary.simpleMessage(
      "Mahsulot nomi yoki kategoriya",
    ),
    "qrPrinter": MessageLookupByLibrary.simpleMessage("QR va stiker printeri"),
    "receipt": MessageLookupByLibrary.simpleMessage("Chek"),
    "receiptPrintFailed": MessageLookupByLibrary.simpleMessage(
      "Chek chop etilmadi. Printerni tekshiring.",
    ),
    "receiptPrinter": MessageLookupByLibrary.simpleMessage(
      "Mahsulot cheki printeri",
    ),
    "refresh": MessageLookupByLibrary.simpleMessage("Yangilash"),
    "saleGatePass": MessageLookupByLibrary.simpleMessage("Kirish chiptasi"),
    "saleGeneric": MessageLookupByLibrary.simpleMessage("Sotuv"),
    "saleGoods": MessageLookupByLibrary.simpleMessage("Mahsulot savdosi"),
    "saleTopup": MessageLookupByLibrary.simpleMessage("Hisob to‘ldirish"),
    "shiftRevenue": MessageLookupByLibrary.simpleMessage("Smena tushumi"),
    "tabAccount": MessageLookupByLibrary.simpleMessage("Hisob va QR"),
    "tabHistory": MessageLookupByLibrary.simpleMessage("Sotuv tarixi"),
    "tabSales": MessageLookupByLibrary.simpleMessage("Savdo"),
    "tabSettings": MessageLookupByLibrary.simpleMessage("Sozlamalar"),
    "total": MessageLookupByLibrary.simpleMessage("Jami"),
    "version": MessageLookupByLibrary.simpleMessage("Versiya"),
  };
}
