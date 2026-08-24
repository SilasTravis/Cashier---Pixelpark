// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
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
  String get localeName => 'en';

  static String m0(phone) => "No account exists for +998 ${phone}.";

  static String m1(value) =>
      "${value} will be debited for time already played.";

  static String m2(value) =>
      "Insufficient balance — at least ${value} must be paid.";

  static String m3(name) => "Cash desk · ${name}";

  static String m4(count) => "${count} children";

  static String m5(price) => "${price} each — unrestricted like parent QR";

  static String m6(value) => "Current balance: ${value}";

  static String m7(child, plan, inside) =>
      "«${child}» is on the «${plan}» tariff today${inside}.";

  static String m8(count) => "${count} customers";

  static String m9(count) => "Enter (${count})";

  static String m10(plan, time, minutes) =>
      "${plan} · entered ${time} · ${minutes} min";

  static String m11(message) => "Failed to enter: ${message}";

  static String m12(value) =>
      "Insufficient balance — top up at least ${value} to exit.";

  static String m13(count) => "${count}";

  static String m14(count) => "Inside: ${count}";

  static String m15(child, amount) =>
      "${child} will be marked as exited now. The visit will close at ${amount} and be debited from the parent\'s balance. Continue?";

  static String m16(count) => "${count} min";

  static String m17(value) => "Balance: ${value}";

  static String m18(value) => "Card: ${value}";

  static String m19(value) => "Cash: ${value}";

  static String m20(value) =>
      "At least ${value} — excess remains on the balance";

  static String m21(plan) =>
      "Switch to the «${plan}» tariff? The old sticker will be cancelled and a new QR printed.";

  static String m22(plan, price) =>
      "Switch to the «${plan}» tariff? The ${plan} price (${price}) will be debited immediately. The old sticker will be cancelled and a new QR printed.";

  static String m23(value) => "from ${value} / min";

  static String m24(value) => "${value} / day";

  static String m25(count) => "selected: ${count}";

  static String m26(time) => "Shift opened at ${time}";

  static String m27(version) => "New version available: ${version}";

  static String m28(name) =>
      "«${name}» already has an active VIP tariff — no second charge.";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "accountNotFoundForPhone": m0,
    "accruedAmount": MessageLookupByLibrary.simpleMessage("Current charge"),
    "accruedDue": m1,
    "add": MessageLookupByLibrary.simpleMessage("Add"),
    "addCustomer": MessageLookupByLibrary.simpleMessage("Add customer"),
    "allCustomers": MessageLookupByLibrary.simpleMessage("All customers"),
    "amount": MessageLookupByLibrary.simpleMessage("Amount"),
    "appTitle": MessageLookupByLibrary.simpleMessage("Bolajon — kassa"),
    "automaticGodex": MessageLookupByLibrary.simpleMessage("Automatic — Godex"),
    "automaticSewoo": MessageLookupByLibrary.simpleMessage("Automatic — SLK"),
    "balance": MessageLookupByLibrary.simpleMessage("Balance"),
    "balanceInsufficient": m2,
    "balanceSalesNotIncome": MessageLookupByLibrary.simpleMessage(
      "Balance-funded sales (not income)",
    ),
    "birthdayFreeOnlyToday": MessageLookupByLibrary.simpleMessage(
      "Available only on the birthday",
    ),
    "branch": MessageLookupByLibrary.simpleMessage("Branch"),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "cartClear": MessageLookupByLibrary.simpleMessage("Clear"),
    "cartClearMessage": MessageLookupByLibrary.simpleMessage(
      "All products will be removed from the cart. Continue?",
    ),
    "cartClearTitle": MessageLookupByLibrary.simpleMessage("Clear cart"),
    "cartEmpty": MessageLookupByLibrary.simpleMessage("Cart is empty"),
    "cartTitle": MessageLookupByLibrary.simpleMessage("Receipt"),
    "cashDesk": MessageLookupByLibrary.simpleMessage("Cash desk"),
    "cashDeskCashier": m3,
    "categoryAll": MessageLookupByLibrary.simpleMessage("All"),
    "childCount": m4,
    "childName": MessageLookupByLibrary.simpleMessage("Child name"),
    "children": MessageLookupByLibrary.simpleMessage("Children"),
    "close": MessageLookupByLibrary.simpleMessage("Close"),
    "companionDescription": m5,
    "currentBalanceValue": m6,
    "currentPlanToday": m7,
    "currentShiftOnly": MessageLookupByLibrary.simpleMessage(
      "Current shift only",
    ),
    "currentlyInside": MessageLookupByLibrary.simpleMessage("Currently inside"),
    "customerCount": m8,
    "customerDirectorySearchHint": MessageLookupByLibrary.simpleMessage(
      "Search by name or the last phone digits",
    ),
    "downgradeForbidden": MessageLookupByLibrary.simpleMessage(
      "This tariff cannot be downgraded — if the sticker was lost, reprint the current tariff.",
    ),
    "elapsedTime": MessageLookupByLibrary.simpleMessage("Elapsed"),
    "enter": MessageLookupByLibrary.simpleMessage("Enter"),
    "enterCount": m9,
    "enteredAt": MessageLookupByLibrary.simpleMessage("Entered at"),
    "enteredAtMinutes": m10,
    "entryFailed": m11,
    "exitBalanceInsufficient": m12,
    "findCustomerHint": MessageLookupByLibrary.simpleMessage(
      "Enter a phone number to find a customer",
    ),
    "free": MessageLookupByLibrary.simpleMessage("Free"),
    "freeEntryReasons": MessageLookupByLibrary.simpleMessage(
      "Free-entry reasons",
    ),
    "freeReasonAile": MessageLookupByLibrary.simpleMessage("AILE"),
    "freeReasonBirthday": MessageLookupByLibrary.simpleMessage("Birthday"),
    "freeReasonDisabled": MessageLookupByLibrary.simpleMessage("Disability"),
    "freeReasonSubscription": MessageLookupByLibrary.simpleMessage(
      "Subscription",
    ),
    "fullName": MessageLookupByLibrary.simpleMessage("Full name"),
    "history30Days": MessageLookupByLibrary.simpleMessage("30 days"),
    "history7Days": MessageLookupByLibrary.simpleMessage("7 days"),
    "historyAllProducts": MessageLookupByLibrary.simpleMessage("All products"),
    "historyChoose": MessageLookupByLibrary.simpleMessage("Select"),
    "historyChoosePeriod": MessageLookupByLibrary.simpleMessage(
      "Choose sales period",
    ),
    "historyCount": m13,
    "historyDateRange": MessageLookupByLibrary.simpleMessage("Date range"),
    "historyEmpty": MessageLookupByLibrary.simpleMessage(
      "No sales in this period",
    ),
    "historyProduct": MessageLookupByLibrary.simpleMessage("Product"),
    "historySales": MessageLookupByLibrary.simpleMessage("Sales"),
    "historyToday": MessageLookupByLibrary.simpleMessage("Today"),
    "historyYear": MessageLookupByLibrary.simpleMessage("This year"),
    "insideCount": m14,
    "insideEmpty": MessageLookupByLibrary.simpleMessage(
      "There are no children inside the park",
    ),
    "insideSearchEmpty": MessageLookupByLibrary.simpleMessage(
      "No child matches your search",
    ),
    "insideSearchHint": MessageLookupByLibrary.simpleMessage(
      "Search by child, parent or phone",
    ),
    "insideSuffix": MessageLookupByLibrary.simpleMessage(" (currently inside)"),
    "keypadHint": MessageLookupByLibrary.simpleMessage(
      "Enter a number to see results on the right. Select a customer to open details.",
    ),
    "language": MessageLookupByLibrary.simpleMessage("Language"),
    "languageRussian": MessageLookupByLibrary.simpleMessage("Russian"),
    "languageUzbek": MessageLookupByLibrary.simpleMessage("Uzbek"),
    "loginButton": MessageLookupByLibrary.simpleMessage("Kirish"),
    "loginError": MessageLookupByLibrary.simpleMessage(
      "Incorrect username or password",
    ),
    "loginPassword": MessageLookupByLibrary.simpleMessage("Parol"),
    "loginSubtitle": MessageLookupByLibrary.simpleMessage(
      "Enter your username and password to access the register",
    ),
    "loginTitle": MessageLookupByLibrary.simpleMessage("Kassaga kirish"),
    "loginUsername": MessageLookupByLibrary.simpleMessage("Login"),
    "logout": MessageLookupByLibrary.simpleMessage("Log out"),
    "manualExitQuestion": m15,
    "manualExitSucceeded": MessageLookupByLibrary.simpleMessage(
      "The child was successfully marked as exited",
    ),
    "manualExitTitle": MessageLookupByLibrary.simpleMessage("Lost QR code?"),
    "markExited": MessageLookupByLibrary.simpleMessage("Mark as exited"),
    "menuClose": MessageLookupByLibrary.simpleMessage("Close menu"),
    "menuOpen": MessageLookupByLibrary.simpleMessage("Open menu"),
    "minutesCount": m16,
    "newBalance": MessageLookupByLibrary.simpleMessage("New balance"),
    "noChildren": MessageLookupByLibrary.simpleMessage("no children"),
    "noPaymentNow": MessageLookupByLibrary.simpleMessage(
      "Nothing is due now — played time will be debited from the balance at exit.",
    ),
    "noPrintersFound": MessageLookupByLibrary.simpleMessage(
      "No installed Windows printers found",
    ),
    "parentQr": MessageLookupByLibrary.simpleMessage("Parent QR"),
    "pay": MessageLookupByLibrary.simpleMessage("Pay"),
    "payFromBalance": MessageLookupByLibrary.simpleMessage("Pay from balance"),
    "paymentAmount": MessageLookupByLibrary.simpleMessage("Payment amount"),
    "paymentAndPrint": MessageLookupByLibrary.simpleMessage("Pay and print"),
    "paymentBalance": MessageLookupByLibrary.simpleMessage(
      "Balance-funded sales",
    ),
    "paymentBalanceValue": m17,
    "paymentCard": MessageLookupByLibrary.simpleMessage("Card"),
    "paymentCardValue": m18,
    "paymentCash": MessageLookupByLibrary.simpleMessage("Cash"),
    "paymentCashValue": m19,
    "paymentExcess": MessageLookupByLibrary.simpleMessage(
      "Amount exceeds total",
    ),
    "paymentMatched": MessageLookupByLibrary.simpleMessage("Amount matched"),
    "paymentMinimumHint": m20,
    "paymentMissing": MessageLookupByLibrary.simpleMessage("Amount remaining"),
    "paymentSplit": MessageLookupByLibrary.simpleMessage("Split"),
    "phoneNotFound": MessageLookupByLibrary.simpleMessage("Number not found"),
    "planSwitch": MessageLookupByLibrary.simpleMessage("Switch tariff"),
    "planSwitchQuestion": m21,
    "planSwitchVipQuestion": m22,
    "priceFromPerMinute": m23,
    "pricePerDay": m24,
    "printParentQr": MessageLookupByLibrary.simpleMessage(
      "Also print parent QR",
    ),
    "printReceipt": MessageLookupByLibrary.simpleMessage("Print receipt"),
    "printerSettings": MessageLookupByLibrary.simpleMessage("Printers"),
    "printing": MessageLookupByLibrary.simpleMessage("Printing…"),
    "productNotFound": MessageLookupByLibrary.simpleMessage(
      "Product not found",
    ),
    "productSearchHint": MessageLookupByLibrary.simpleMessage(
      "Product name or category",
    ),
    "products": MessageLookupByLibrary.simpleMessage("Products"),
    "qrPrinter": MessageLookupByLibrary.simpleMessage("QR and label printer"),
    "quickAdd": MessageLookupByLibrary.simpleMessage("Quick add"),
    "receipt": MessageLookupByLibrary.simpleMessage("Receipt"),
    "receiptCount": MessageLookupByLibrary.simpleMessage("Receipt count"),
    "receiptPrintFailed": MessageLookupByLibrary.simpleMessage(
      "Receipt could not be printed. Check the printer.",
    ),
    "receiptPrinter": MessageLookupByLibrary.simpleMessage(
      "Product receipt printer",
    ),
    "recentCustomers": MessageLookupByLibrary.simpleMessage("Recent customers"),
    "refresh": MessageLookupByLibrary.simpleMessage("Refresh"),
    "reprint": MessageLookupByLibrary.simpleMessage("Reprint"),
    "saleGatePass": MessageLookupByLibrary.simpleMessage("Entry ticket"),
    "saleGeneric": MessageLookupByLibrary.simpleMessage("Sale"),
    "saleGoods": MessageLookupByLibrary.simpleMessage("Product sale"),
    "saleTopup": MessageLookupByLibrary.simpleMessage("Account top-up"),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "searchHistory": MessageLookupByLibrary.simpleMessage("Search history"),
    "searchResult": MessageLookupByLibrary.simpleMessage("Search results"),
    "selectForQr": MessageLookupByLibrary.simpleMessage("Select for QR"),
    "selectedCount": m25,
    "shiftClose": MessageLookupByLibrary.simpleMessage("Close shift"),
    "shiftClosed": MessageLookupByLibrary.simpleMessage("Shift closed"),
    "shiftOpen": MessageLookupByLibrary.simpleMessage("Open shift"),
    "shiftOpenedAt": m26,
    "shiftOpeningCash": MessageLookupByLibrary.simpleMessage(
      "Opening cash (UZS)",
    ),
    "shiftRevenue": MessageLookupByLibrary.simpleMessage("Shift revenue"),
    "shiftStart": MessageLookupByLibrary.simpleMessage("Start shift"),
    "shiftStartHint": MessageLookupByLibrary.simpleMessage(
      "Enter the opening cash amount in the register",
    ),
    "shiftTotalIncome": MessageLookupByLibrary.simpleMessage(
      "Total shift income",
    ),
    "stickerPrintFailed": MessageLookupByLibrary.simpleMessage(
      "Sticker was not printed — check the printer",
    ),
    "switchAndPrint": MessageLookupByLibrary.simpleMessage("Switch and print"),
    "tabAccount": MessageLookupByLibrary.simpleMessage("Account & QR"),
    "tabHistory": MessageLookupByLibrary.simpleMessage("Sales history"),
    "tabInside": MessageLookupByLibrary.simpleMessage("Inside park"),
    "tabSales": MessageLookupByLibrary.simpleMessage("Sales"),
    "tabSettings": MessageLookupByLibrary.simpleMessage("Settings"),
    "tabVisitHistory": MessageLookupByLibrary.simpleMessage(
      "Entry/exit history",
    ),
    "tariff": MessageLookupByLibrary.simpleMessage("Tariff"),
    "tariffNotFound": MessageLookupByLibrary.simpleMessage("No tariffs found."),
    "topup": MessageLookupByLibrary.simpleMessage("Top up"),
    "topupBalance": MessageLookupByLibrary.simpleMessage("Top up balance"),
    "total": MessageLookupByLibrary.simpleMessage("Total"),
    "totalBill": MessageLookupByLibrary.simpleMessage("Total bill"),
    "unlimitedFreeEntry": MessageLookupByLibrary.simpleMessage(
      "Free — unrestricted entry and exit",
    ),
    "updateAvailable": m27,
    "updateCancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "updateCheck": MessageLookupByLibrary.simpleMessage("Check for updates"),
    "updateConfirm": MessageLookupByLibrary.simpleMessage("Continue"),
    "updateConfirmMessage": MessageLookupByLibrary.simpleMessage(
      "The app will close and reopen on the new version. Your shift stays open. Continue?",
    ),
    "updateConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Update the app",
    ),
    "updateDownload": MessageLookupByLibrary.simpleMessage(
      "Download & install",
    ),
    "updateDownloading": MessageLookupByLibrary.simpleMessage("Downloading…"),
    "updateFailed": MessageLookupByLibrary.simpleMessage("Update failed"),
    "updateFailedGeneric": MessageLookupByLibrary.simpleMessage(
      "Update failed. Check the internet connection and try again.",
    ),
    "updateFailureChecksumMismatch": MessageLookupByLibrary.simpleMessage(
      "The downloaded file failed its checksum check",
    ),
    "updateFailureChecksumUnreadable": MessageLookupByLibrary.simpleMessage(
      "Could not read the published checksum — refusing to install an unverified update",
    ),
    "updateFailureExecutableMissing": MessageLookupByLibrary.simpleMessage(
      "The downloaded archive is missing the app program",
    ),
    "updateFailureIncompleteExtraction": MessageLookupByLibrary.simpleMessage(
      "The update did not unpack completely. The download was discarded — please try again",
    ),
    "updateManualHint": MessageLookupByLibrary.simpleMessage(
      "To download manually:",
    ),
    "updateReady": MessageLookupByLibrary.simpleMessage("Update ready"),
    "updateRestart": MessageLookupByLibrary.simpleMessage("Restart now"),
    "updateTitle": MessageLookupByLibrary.simpleMessage("Update"),
    "updateUpToDate": MessageLookupByLibrary.simpleMessage(
      "You\'re on the latest version",
    ),
    "updateWindowsOnly": MessageLookupByLibrary.simpleMessage(
      "Automatic updates work on Windows only",
    ),
    "version": MessageLookupByLibrary.simpleMessage("Version"),
    "vipAlreadyActive": m28,
    "vipChargedImmediately": MessageLookupByLibrary.simpleMessage(
      "The VIP tariff is debited from the balance immediately when printed.",
    ),
    "vipTariff": MessageLookupByLibrary.simpleMessage("VIP tariff"),
    "visitEntered": MessageLookupByLibrary.simpleMessage("Entered"),
    "visitEntries": MessageLookupByLibrary.simpleMessage("Entries"),
    "visitExited": MessageLookupByLibrary.simpleMessage("Exited"),
    "visitExits": MessageLookupByLibrary.simpleMessage("Exits"),
    "visitHistoryEmpty": MessageLookupByLibrary.simpleMessage(
      "No entries or exits in the current shift",
    ),
    "visitHistorySearchHint": MessageLookupByLibrary.simpleMessage(
      "Search by child, parent or phone",
    ),
    "visitInside": MessageLookupByLibrary.simpleMessage("Inside"),
    "visitManualExit": MessageLookupByLibrary.simpleMessage("Manually exited"),
    "visitStillInside": MessageLookupByLibrary.simpleMessage("Still inside"),
  };
}
