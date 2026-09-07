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

  static String m6(amount, from, to) => "${amount}: ${from} → ${to}";

  static String m7(amount, from, to) =>
      "${amount} moves from ${from} to ${to}. The change is kept in the audit history.";

  static String m8(cash, card) => "Result: cash ${cash}, card ${card}";

  static String m9(value) => "Current balance: ${value}";

  static String m10(child, plan, inside) =>
      "«${child}» is on the «${plan}» tariff today${inside}.";

  static String m11(count) => "${count} customers";

  static String m12(cash, card) => "Now: ${cash} cash + ${card} card";

  static String m13(amount, from, to) =>
      "${amount} moves from ${from} to ${to}";

  static String m14(amount, method) =>
      "${amount} is handed back to the customer in ${method}";

  static String m15(count) => "Enter (${count})";

  static String m16(plan, time, minutes) =>
      "${plan} · entered ${time} · ${minutes} min";

  static String m17(message) => "Failed to enter: ${message}";

  static String m18(value) =>
      "Insufficient balance — top up at least ${value} to exit.";

  static String m19(count) => "${count}";

  static String m20(count) => "Inside: ${count}";

  static String m21(child, amount) =>
      "${child} will be marked as exited now. The visit will close at ${amount} and be debited from the parent\'s balance. Continue?";

  static String m22(count) => "${count} min";

  static String m23(value) => "Balance: ${value}";

  static String m24(value) => "Card: ${value}";

  static String m25(value) => "Cash: ${value}";

  static String m26(value) =>
      "At least ${value} — excess remains on the balance";

  static String m27(plan) =>
      "Switch to the «${plan}» tariff? The old sticker will be cancelled and a new QR printed.";

  static String m28(plan, price) =>
      "Switch to the «${plan}» tariff? The ${plan} price (${price}) will be debited immediately. The old sticker will be cancelled and a new QR printed.";

  static String m29(value) => "from ${value} / min";

  static String m30(value) => "${value} / day";

  static String m31(date, name) => "${date} · ${name}";

  static String m32(amount, method) =>
      "${amount} will be refunded via ${method}. This action is permanently stored in the audit history.";

  static String m33(balance) => "Customer balance: ${balance}";

  static String m34(amount) => "${amount} was refunded successfully";

  static String m35(count) => "selected: ${count}";

  static String m36(time) => "Shift opened at ${time}";

  static String m37(version) => "New version available: ${version}";

  static String m38(name) =>
      "«${name}» already has an active VIP tariff — no second charge.";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "accountId": MessageLookupByLibrary.simpleMessage("Account ID"),
    "accountNotFoundForPhone": m0,
    "accountOwner": MessageLookupByLibrary.simpleMessage("Account owner"),
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
    "correctPaymentAction": MessageLookupByLibrary.simpleMessage(
      "Correct payment method",
    ),
    "correctPaymentAmount": MessageLookupByLibrary.simpleMessage(
      "Amount to move",
    ),
    "correctPaymentAudit": m6,
    "correctPaymentConfirmMessage": m7,
    "correctPaymentConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Confirm the correction",
    ),
    "correctPaymentFrom": MessageLookupByLibrary.simpleMessage(
      "Recorded wrongly as",
    ),
    "correctPaymentHint": MessageLookupByLibrary.simpleMessage(
      "The receipt total does not change. Only which column the money sits in — cash or card — is corrected, so the shift cash-up matches the drawer.",
    ),
    "correctPaymentHistory": MessageLookupByLibrary.simpleMessage(
      "Payment method corrections",
    ),
    "correctPaymentReason": MessageLookupByLibrary.simpleMessage(
      "Reason for the correction",
    ),
    "correctPaymentReasonHint": MessageLookupByLibrary.simpleMessage(
      "For example: money taken in cash, rung up as card",
    ),
    "correctPaymentResult": m8,
    "correctPaymentSuccess": MessageLookupByLibrary.simpleMessage(
      "Payment method corrected",
    ),
    "correctPaymentTitle": MessageLookupByLibrary.simpleMessage(
      "Correct payment method",
    ),
    "correctPaymentTo": MessageLookupByLibrary.simpleMessage("Correct method"),
    "correctPaymentUnavailable": MessageLookupByLibrary.simpleMessage(
      "A receipt with a refund cannot have its payment method corrected",
    ),
    "currentBalanceValue": m9,
    "currentPlanToday": m10,
    "currentShiftOnly": MessageLookupByLibrary.simpleMessage(
      "Current shift only",
    ),
    "currentlyInside": MessageLookupByLibrary.simpleMessage("Currently inside"),
    "customerCount": m11,
    "customerDirectorySearchHint": MessageLookupByLibrary.simpleMessage(
      "Search by name or the last phone digits",
    ),
    "date": MessageLookupByLibrary.simpleMessage("Date"),
    "downgradeForbidden": MessageLookupByLibrary.simpleMessage(
      "This tariff cannot be downgraded — if the sticker was lost, reprint the current tariff.",
    ),
    "editSaleAction": MessageLookupByLibrary.simpleMessage("Edit"),
    "editSaleBlockedBalance": MessageLookupByLibrary.simpleMessage(
      "The customer\'s balance no longer holds that much — it cannot be returned.",
    ),
    "editSaleBlockedIncrease": MessageLookupByLibrary.simpleMessage(
      "The total cannot go up. If more money was taken, ring it up as its own payment.",
    ),
    "editSaleBlockedMethod": MessageLookupByLibrary.simpleMessage(
      "Money has been handed back on this receipt, so the payment method can no longer change. Only the total can come down.",
    ),
    "editSaleBlockedNotEditable": MessageLookupByLibrary.simpleMessage(
      "This receipt cannot be edited here.",
    ),
    "editSaleCurrent": m12,
    "editSaleHint": MessageLookupByLibrary.simpleMessage(
      "Enter the correct total and the correct payment method. The steps are worked out for you: a changed method moves the columns, a lower total hands back the difference.",
    ),
    "editSaleMethod": MessageLookupByLibrary.simpleMessage(
      "Correct payment method",
    ),
    "editSalePartialFailure": MessageLookupByLibrary.simpleMessage(
      "The edit did not finish. Reopen the receipt and edit again — only what is still missing will run.",
    ),
    "editSalePlanCorrection": m13,
    "editSalePlanNoop": MessageLookupByLibrary.simpleMessage(
      "Nothing changes — the receipt already says this",
    ),
    "editSalePlanRefund": m14,
    "editSalePlanTitle": MessageLookupByLibrary.simpleMessage(
      "What will happen",
    ),
    "editSaleReason": MessageLookupByLibrary.simpleMessage(
      "Reason for the edit",
    ),
    "editSaleReasonHint": MessageLookupByLibrary.simpleMessage(
      "For example: wrong amount typed, money taken in cash",
    ),
    "editSaleSuccess": MessageLookupByLibrary.simpleMessage("Receipt edited"),
    "editSaleTitle": MessageLookupByLibrary.simpleMessage("Edit receipt"),
    "editSaleTotal": MessageLookupByLibrary.simpleMessage("Correct total"),
    "elapsedTime": MessageLookupByLibrary.simpleMessage("Elapsed"),
    "enter": MessageLookupByLibrary.simpleMessage("Enter"),
    "enterCount": m15,
    "enteredAt": MessageLookupByLibrary.simpleMessage("Entered at"),
    "enteredAtMinutes": m16,
    "entryFailed": m17,
    "exitBalanceInsufficient": m18,
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
    "historyCount": m19,
    "historyDateRange": MessageLookupByLibrary.simpleMessage("Date range"),
    "historyEmpty": MessageLookupByLibrary.simpleMessage(
      "No sales in this period",
    ),
    "historyProduct": MessageLookupByLibrary.simpleMessage("Product"),
    "historySales": MessageLookupByLibrary.simpleMessage("Sales"),
    "historyToday": MessageLookupByLibrary.simpleMessage("Today"),
    "historyYear": MessageLookupByLibrary.simpleMessage("This year"),
    "insideCount": m20,
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
    "manualExitQuestion": m21,
    "manualExitSucceeded": MessageLookupByLibrary.simpleMessage(
      "The child was successfully marked as exited",
    ),
    "manualExitTitle": MessageLookupByLibrary.simpleMessage("Lost QR code?"),
    "markExited": MessageLookupByLibrary.simpleMessage("Mark as exited"),
    "menuClose": MessageLookupByLibrary.simpleMessage("Close menu"),
    "menuOpen": MessageLookupByLibrary.simpleMessage("Open menu"),
    "minutesCount": m22,
    "newBalance": MessageLookupByLibrary.simpleMessage("New balance"),
    "noChildren": MessageLookupByLibrary.simpleMessage("no children"),
    "noPaymentNow": MessageLookupByLibrary.simpleMessage(
      "Nothing is due now — played time will be debited from the balance at exit.",
    ),
    "noPrintersFound": MessageLookupByLibrary.simpleMessage(
      "No installed Windows printers found",
    ),
    "openCustomerProfile": MessageLookupByLibrary.simpleMessage(
      "Open customer profile",
    ),
    "parentQr": MessageLookupByLibrary.simpleMessage("Parent QR"),
    "pay": MessageLookupByLibrary.simpleMessage("Pay"),
    "payFromBalance": MessageLookupByLibrary.simpleMessage("Pay from balance"),
    "paymentAmount": MessageLookupByLibrary.simpleMessage("Payment amount"),
    "paymentAndPrint": MessageLookupByLibrary.simpleMessage("Pay and print"),
    "paymentBalance": MessageLookupByLibrary.simpleMessage(
      "Balance-funded sales",
    ),
    "paymentBalanceValue": m23,
    "paymentCard": MessageLookupByLibrary.simpleMessage("Card"),
    "paymentCardValue": m24,
    "paymentCash": MessageLookupByLibrary.simpleMessage("Cash"),
    "paymentCashValue": m25,
    "paymentExcess": MessageLookupByLibrary.simpleMessage(
      "Amount exceeds total",
    ),
    "paymentMatched": MessageLookupByLibrary.simpleMessage("Amount matched"),
    "paymentMinimumHint": m26,
    "paymentMissing": MessageLookupByLibrary.simpleMessage("Amount remaining"),
    "paymentSplit": MessageLookupByLibrary.simpleMessage("Split"),
    "phoneNotFound": MessageLookupByLibrary.simpleMessage("Number not found"),
    "phoneNumber": MessageLookupByLibrary.simpleMessage("Phone number"),
    "planSwitch": MessageLookupByLibrary.simpleMessage("Switch tariff"),
    "planSwitchQuestion": m27,
    "planSwitchVipQuestion": m28,
    "priceFromPerMinute": m29,
    "pricePerDay": m30,
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
    "refundAction": MessageLookupByLibrary.simpleMessage("Refund"),
    "refundAlreadyAmount": MessageLookupByLibrary.simpleMessage("Refunded"),
    "refundAmount": MessageLookupByLibrary.simpleMessage("Amount to refund"),
    "refundAuditBy": m31,
    "refundBalanceLimitNote": MessageLookupByLibrary.simpleMessage(
      "Reversing a top-up takes the money back off the balance, so you cannot return more than it still holds.",
    ),
    "refundBalanceMethod": MessageLookupByLibrary.simpleMessage("To balance"),
    "refundCardWarning": MessageLookupByLibrary.simpleMessage(
      "A card refund must also be completed on the payment terminal. This action does not automatically reverse the terminal transaction.",
    ),
    "refundConfirmMessage": m32,
    "refundConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Confirm refund",
    ),
    "refundCustomerBalance": m33,
    "refundFullBadge": MessageLookupByLibrary.simpleMessage("Fully refunded"),
    "refundHistory": MessageLookupByLibrary.simpleMessage("Refund history"),
    "refundMax": MessageLookupByLibrary.simpleMessage("Select all"),
    "refundMethod": MessageLookupByLibrary.simpleMessage("Refund method"),
    "refundNoRefundablePasses": MessageLookupByLibrary.simpleMessage(
      "No refundable passes remain on this receipt",
    ),
    "refundOriginalAmount": MessageLookupByLibrary.simpleMessage(
      "Original payment",
    ),
    "refundPartialBadge": MessageLookupByLibrary.simpleMessage(
      "Partially refunded",
    ),
    "refundPassUsed": MessageLookupByLibrary.simpleMessage("Used"),
    "refundPassVoided": MessageLookupByLibrary.simpleMessage("Voided"),
    "refundReason": MessageLookupByLibrary.simpleMessage("Refund reason"),
    "refundReasonHint": MessageLookupByLibrary.simpleMessage(
      "For example: returned item or incorrect order",
    ),
    "refundReasonValidation": MessageLookupByLibrary.simpleMessage(
      "The reason must contain at least 5 characters",
    ),
    "refundRemainingAmount": MessageLookupByLibrary.simpleMessage(
      "Remaining amount",
    ),
    "refundSelectPasses": MessageLookupByLibrary.simpleMessage(
      "Select the passes being handed back",
    ),
    "refundSelectPassesValidation": MessageLookupByLibrary.simpleMessage(
      "Select at least one pass",
    ),
    "refundSelectedPassesTotal": MessageLookupByLibrary.simpleMessage(
      "Selected passes total",
    ),
    "refundSuccess": m34,
    "refundTitle": MessageLookupByLibrary.simpleMessage("Refund payment"),
    "refundedTotal": MessageLookupByLibrary.simpleMessage("Refunded"),
    "reprint": MessageLookupByLibrary.simpleMessage("Reprint"),
    "saleGatePass": MessageLookupByLibrary.simpleMessage("Entry ticket"),
    "saleGeneric": MessageLookupByLibrary.simpleMessage("Sale"),
    "saleGoods": MessageLookupByLibrary.simpleMessage("Product sale"),
    "saleTopup": MessageLookupByLibrary.simpleMessage("Account top-up"),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "searchHistory": MessageLookupByLibrary.simpleMessage("Search history"),
    "searchResult": MessageLookupByLibrary.simpleMessage("Search results"),
    "selectForQr": MessageLookupByLibrary.simpleMessage("Select for QR"),
    "selectedCount": m35,
    "shiftClose": MessageLookupByLibrary.simpleMessage("Close shift"),
    "shiftClosed": MessageLookupByLibrary.simpleMessage("Shift closed"),
    "shiftOpen": MessageLookupByLibrary.simpleMessage("Open shift"),
    "shiftOpenedAt": m36,
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
    "topupConfirmAction": MessageLookupByLibrary.simpleMessage("Top up"),
    "topupConfirmAmount": MessageLookupByLibrary.simpleMessage("Top-up amount"),
    "topupConfirmCustomer": MessageLookupByLibrary.simpleMessage("Customer"),
    "topupConfirmMethod": MessageLookupByLibrary.simpleMessage(
      "Payment method",
    ),
    "topupConfirmNewBalance": MessageLookupByLibrary.simpleMessage(
      "New balance",
    ),
    "topupConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Confirm the top-up",
    ),
    "topupConfirmWarning": MessageLookupByLibrary.simpleMessage(
      "Once confirmed the amount is credited to the customer\'s balance. If it is wrong, the receipt can be put right with Edit.",
    ),
    "topupDetails": MessageLookupByLibrary.simpleMessage(
      "Account top-up details",
    ),
    "total": MessageLookupByLibrary.simpleMessage("Total"),
    "totalBill": MessageLookupByLibrary.simpleMessage("Total bill"),
    "transactionId": MessageLookupByLibrary.simpleMessage("Transaction ID"),
    "unlimitedFreeEntry": MessageLookupByLibrary.simpleMessage(
      "Free — unrestricted entry and exit",
    ),
    "updateAvailable": m37,
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
    "vipAlreadyActive": m38,
    "vipChargedImmediately": MessageLookupByLibrary.simpleMessage(
      "The VIP tariff is debited from the balance immediately when printed.",
    ),
    "vipTariff": MessageLookupByLibrary.simpleMessage("VIP tariff"),
    "visitChild": MessageLookupByLibrary.simpleMessage("Child in this visit"),
    "visitDetails": MessageLookupByLibrary.simpleMessage(
      "Entry and exit details",
    ),
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
