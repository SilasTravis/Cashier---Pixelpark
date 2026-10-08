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

  static String m0(count) => "${count} y.o.";

  static String m1(value) => "Fully covered by balance · ${value} left";

  static String m2(value) => "${value} goes to the balance";

  static String m3(count) => "${count} inside";

  static String m4(minutes) => "Inside · ${minutes} min";

  static String m5(phone) => "No account exists for +998 ${phone}.";

  static String m6(plan, count) => "${plan} × ${count}";

  static String m7(count) => "${count}";

  static String m8(from, to, total) => "${from}–${to} / ${total}";

  static String m9(time) => "until ${time}";

  static String m10(value) =>
      "${value} will be debited for time already played.";

  static String m11(value) =>
      "Insufficient balance — at least ${value} must be paid.";

  static String m12(name) => "Cash desk · ${name}";

  static String m13(count) => "${count} children";

  static String m14(count) =>
      "${count} sales failed to sync. Contact support before closing the shift.";

  static String m15(price) => "${price} each — unrestricted like parent QR";

  static String m16(amount, from, to) => "${amount}: ${from} → ${to}";

  static String m17(amount, from, to) =>
      "${amount} moves from ${from} to ${to}. The change is kept in the audit history.";

  static String m18(cash, card) => "Result: cash ${cash}, card ${card}";

  static String m19(value) => "Current balance: ${value}";

  static String m20(child, plan, inside) =>
      "«${child}» is on the «${plan}» tariff today${inside}.";

  static String m21(count) => "${count} customers";

  static String m22(cash, card) => "Now: ${cash} cash + ${card} card";

  static String m23(amount, from, to) =>
      "${amount} moves from ${from} to ${to}";

  static String m24(amount, method) =>
      "${amount} is handed back to the customer in ${method}";

  static String m25(count) => "Enter (${count})";

  static String m26(plan, time, minutes) =>
      "${plan} · entered ${time} · ${minutes} min";

  static String m27(message) => "Failed to enter: ${message}";

  static String m28(value) =>
      "Insufficient balance — top up at least ${value} to exit.";

  static String m29(count) => "${count}";

  static String m30(name) =>
      "«${name}» already has an active 1 hour tariff — no second charge.";

  static String m31(count) => "Inside: ${count}";

  static String m32(count) =>
      "${count} sales are not synced. Sync them in online mode before signing out.";

  static String m33(count) =>
      "${count} sales failed to sync. They stay saved on this till. Sign out anyway?";

  static String m34(child, amount) =>
      "${child} will be marked as exited now. The visit will close at ${amount} and be debited from the parent\'s balance. Continue?";

  static String m35(count) => "${count} min";

  static String m36(count) => "OFFLINE · ${count} sales waiting";

  static String m37(count) => "Switch to online mode and sync ${count} sales?";

  static String m38(value) => "Balance: ${value}";

  static String m39(value) => "Card: ${value}";

  static String m40(value) => "Cash: ${value}";

  static String m41(value) =>
      "At least ${value} — excess remains on the balance";

  static String m42(name, plan) =>
      "«${name}» already has an active «${plan}» tariff — no second charge.";

  static String m43(plan) =>
      "The «${plan}» tariff is debited from the balance immediately when printed.";

  static String m44(plan) =>
      "Switch to the «${plan}» tariff? The old sticker will be cancelled and a new QR printed.";

  static String m45(plan, price) =>
      "Switch to the «${plan}» tariff? The ${plan} price (${price}) will be debited immediately. The old sticker will be cancelled and a new QR printed.";

  static String m46(value) => "from ${value} / min";

  static String m47(value) => "${value} / day";

  static String m48(value) => "${value} / hour";

  static String m49(code) =>
      "Blogger promo code ${code} accepted — select a customer";

  static String m50(reason) =>
      "Promo code not applied, code returned: ${reason}";

  static String m51(date, name) => "${date} · ${name}";

  static String m52(amount, method) =>
      "${amount} will be refunded via ${method}. This action is permanently stored in the audit history.";

  static String m53(balance) => "Customer balance: ${balance}";

  static String m54(amount) => "${amount} was refunded successfully";

  static String m55(count) => "selected: ${count}";

  static String m56(time) => "Shift opened at ${time}";

  static String m57(synced, failed) =>
      "${synced} sales synced, ${failed} failed.";

  static String m58(reason) => "Could not sync: ${reason}. Staying offline.";

  static String m59(code) => "Code: ${code}";

  static String m60(version) => "New version available: ${version}";

  static String m61(name) =>
      "«${name}» already has an active VIP tariff — no second charge.";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "accountAgeYears": m0,
    "accountAtExit": MessageLookupByLibrary.simpleMessage("at exit"),
    "accountColChild": MessageLookupByLibrary.simpleMessage("Child"),
    "accountColSoFar": MessageLookupByLibrary.simpleMessage("So far"),
    "accountColTime": MessageLookupByLibrary.simpleMessage("Time"),
    "accountCoveredByBalance": m1,
    "accountDueFull": MessageLookupByLibrary.simpleMessage("Customer pays"),
    "accountDueShortfall": MessageLookupByLibrary.simpleMessage(
      "Amount still due",
    ),
    "accountExcessToBalance": m2,
    "accountFromBalance": MessageLookupByLibrary.simpleMessage(
      "Taken from balance",
    ),
    "accountFromBalanceLine": MessageLookupByLibrary.simpleMessage(
      "From balance",
    ),
    "accountId": MessageLookupByLibrary.simpleMessage("Account ID"),
    "accountInsideCount": m3,
    "accountInsideMinutes": m4,
    "accountLeftOnBalance": MessageLookupByLibrary.simpleMessage(
      "Left on balance",
    ),
    "accountNoCheckDiscounts": MessageLookupByLibrary.simpleMessage(
      "No active check discounts",
    ),
    "accountNotFoundForPhone": m5,
    "accountOptional": MessageLookupByLibrary.simpleMessage("optional"),
    "accountOtherAmount": MessageLookupByLibrary.simpleMessage(
      "Take a different amount",
    ),
    "accountOwner": MessageLookupByLibrary.simpleMessage("Account owner"),
    "accountPayAtExit": MessageLookupByLibrary.simpleMessage("Billed at exit"),
    "accountPayNow": MessageLookupByLibrary.simpleMessage("Paid now"),
    "accountPickChildFirst": MessageLookupByLibrary.simpleMessage(
      "Select a child first",
    ),
    "accountPlanTimesKids": m6,
    "accountStepExtras": MessageLookupByLibrary.simpleMessage("Extras"),
    "accountStepWho": MessageLookupByLibrary.simpleMessage("Who\'s entering?"),
    "accountToPay": MessageLookupByLibrary.simpleMessage("To pay"),
    "accountTodayQrs": MessageLookupByLibrary.simpleMessage(
      "Today\'s QR codes",
    ),
    "accountTodayQrsHint": MessageLookupByLibrary.simpleMessage(
      "Reprint a lost or damaged sticker: nothing is charged and the old sticker keeps working.",
    ),
    "accountTxCount": m7,
    "accountTxEmpty": MessageLookupByLibrary.simpleMessage(
      "No transactions for this customer yet",
    ),
    "accountTxFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t load the transactions",
    ),
    "accountTxMore": MessageLookupByLibrary.simpleMessage("Other"),
    "accountTxNext": MessageLookupByLibrary.simpleMessage("Next"),
    "accountTxPrev": MessageLookupByLibrary.simpleMessage("Previous"),
    "accountTxRange": m8,
    "accountTxTitle": MessageLookupByLibrary.simpleMessage(
      "Transaction history",
    ),
    "accountValidUntil": m9,
    "accruedAmount": MessageLookupByLibrary.simpleMessage("Current charge"),
    "accruedDue": m10,
    "add": MessageLookupByLibrary.simpleMessage("Add"),
    "addCustomer": MessageLookupByLibrary.simpleMessage("Add customer"),
    "allCustomers": MessageLookupByLibrary.simpleMessage("All customers"),
    "amount": MessageLookupByLibrary.simpleMessage("Amount"),
    "appTitle": MessageLookupByLibrary.simpleMessage("Bolajon — kassa"),
    "automaticGodex": MessageLookupByLibrary.simpleMessage("Automatic — Godex"),
    "automaticSewoo": MessageLookupByLibrary.simpleMessage("Automatic — SLK"),
    "balance": MessageLookupByLibrary.simpleMessage("Balance"),
    "balanceInsufficient": m11,
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
    "cashDeskCashier": m12,
    "categoryAll": MessageLookupByLibrary.simpleMessage("All"),
    "checkDiscount": MessageLookupByLibrary.simpleMessage("Check discount"),
    "checkDiscountLocked": MessageLookupByLibrary.simpleMessage(
      "Check discount selected — child discounts and promo code are off",
    ),
    "checkDiscountNone": MessageLookupByLibrary.simpleMessage("None"),
    "checkOnline": MessageLookupByLibrary.simpleMessage("Check connection"),
    "childCount": m13,
    "childName": MessageLookupByLibrary.simpleMessage("Child name"),
    "children": MessageLookupByLibrary.simpleMessage("Children"),
    "close": MessageLookupByLibrary.simpleMessage("Close"),
    "closeShiftOffline": MessageLookupByLibrary.simpleMessage(
      "A shift can\'t be closed in offline mode",
    ),
    "closeShiftUnsyncedWarning": m14,
    "companionDescription": m15,
    "correctPaymentAction": MessageLookupByLibrary.simpleMessage(
      "Correct payment method",
    ),
    "correctPaymentAmount": MessageLookupByLibrary.simpleMessage(
      "Amount to move",
    ),
    "correctPaymentAudit": m16,
    "correctPaymentConfirmMessage": m17,
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
    "correctPaymentResult": m18,
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
    "currentBalanceValue": m19,
    "currentPlanToday": m20,
    "currentShiftOnly": MessageLookupByLibrary.simpleMessage(
      "Current shift only",
    ),
    "currentlyInside": MessageLookupByLibrary.simpleMessage("Currently inside"),
    "customerCount": m21,
    "customerDirectorySearchHint": MessageLookupByLibrary.simpleMessage(
      "Search by name or the last phone digits",
    ),
    "date": MessageLookupByLibrary.simpleMessage("Date"),
    "discount": MessageLookupByLibrary.simpleMessage("Discount"),
    "discountGroupFixed": MessageLookupByLibrary.simpleMessage("Fixed amount"),
    "discountGroupFree": MessageLookupByLibrary.simpleMessage("Free (100%)"),
    "discountGroupPercent": MessageLookupByLibrary.simpleMessage("Percentage"),
    "discountSearchHint": MessageLookupByLibrary.simpleMessage(
      "Search by name",
    ),
    "discountUnavailableMessage": MessageLookupByLibrary.simpleMessage(
      "The discount is no longer available — pick again",
    ),
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
    "editSaleCurrent": m22,
    "editSaleHint": MessageLookupByLibrary.simpleMessage(
      "Enter the correct total and the correct payment method. The steps are worked out for you: a changed method moves the columns, a lower total hands back the difference.",
    ),
    "editSaleMethod": MessageLookupByLibrary.simpleMessage(
      "Correct payment method",
    ),
    "editSalePartialFailure": MessageLookupByLibrary.simpleMessage(
      "The edit did not finish. Reopen the receipt and edit again — only what is still missing will run.",
    ),
    "editSalePlanCorrection": m23,
    "editSalePlanNoop": MessageLookupByLibrary.simpleMessage(
      "Nothing changes — the receipt already says this",
    ),
    "editSalePlanRefund": m24,
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
    "enterCount": m25,
    "enteredAt": MessageLookupByLibrary.simpleMessage("Entered at"),
    "enteredAtMinutes": m26,
    "entryFailed": m27,
    "exitBalanceInsufficient": m28,
    "findCustomerHint": MessageLookupByLibrary.simpleMessage(
      "Enter a phone number to find a customer",
    ),
    "free": MessageLookupByLibrary.simpleMessage("Free"),
    "fullName": MessageLookupByLibrary.simpleMessage("Full name"),
    "history30Days": MessageLookupByLibrary.simpleMessage("30 days"),
    "history7Days": MessageLookupByLibrary.simpleMessage("7 days"),
    "historyAllProducts": MessageLookupByLibrary.simpleMessage("All products"),
    "historyChoose": MessageLookupByLibrary.simpleMessage("Select"),
    "historyChoosePeriod": MessageLookupByLibrary.simpleMessage(
      "Choose sales period",
    ),
    "historyCount": m29,
    "historyDateRange": MessageLookupByLibrary.simpleMessage("Date range"),
    "historyEmpty": MessageLookupByLibrary.simpleMessage(
      "No sales in this period",
    ),
    "historyOfflineNotice": MessageLookupByLibrary.simpleMessage(
      "Offline mode: only sales not yet synced are shown",
    ),
    "historyProduct": MessageLookupByLibrary.simpleMessage("Product"),
    "historySales": MessageLookupByLibrary.simpleMessage("Sales"),
    "historyToday": MessageLookupByLibrary.simpleMessage("Today"),
    "historyYear": MessageLookupByLibrary.simpleMessage("This year"),
    "hourAlreadyActive": m30,
    "hourChargedImmediately": MessageLookupByLibrary.simpleMessage(
      "The 1 hour tariff is debited from the balance immediately when printed.",
    ),
    "hourTariff": MessageLookupByLibrary.simpleMessage("1 hour tariff"),
    "insideCount": m31,
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
    "logoutAnyway": MessageLookupByLibrary.simpleMessage("Sign out anyway"),
    "logoutBlockedUnsynced": m32,
    "logoutFailedSalesConfirm": m33,
    "manualExitQuestion": m34,
    "manualExitSucceeded": MessageLookupByLibrary.simpleMessage(
      "The child was successfully marked as exited",
    ),
    "manualExitTitle": MessageLookupByLibrary.simpleMessage("Lost QR code?"),
    "markExited": MessageLookupByLibrary.simpleMessage("Mark as exited"),
    "menuClose": MessageLookupByLibrary.simpleMessage("Close menu"),
    "menuOpen": MessageLookupByLibrary.simpleMessage("Open menu"),
    "minutesCount": m35,
    "needsInternet": MessageLookupByLibrary.simpleMessage("Needs internet"),
    "newBalance": MessageLookupByLibrary.simpleMessage("New balance"),
    "noChildren": MessageLookupByLibrary.simpleMessage("no children"),
    "noDiscount": MessageLookupByLibrary.simpleMessage("No discount"),
    "noPaymentNow": MessageLookupByLibrary.simpleMessage(
      "Nothing is due now — played time will be debited from the balance at exit.",
    ),
    "noPrintersFound": MessageLookupByLibrary.simpleMessage(
      "No installed Windows printers found",
    ),
    "notSyncedBadge": MessageLookupByLibrary.simpleMessage("Not synced"),
    "offlineBanner": m36,
    "offlineBannerSyncing": MessageLookupByLibrary.simpleMessage("Syncing…"),
    "offlinePromptAccept": MessageLookupByLibrary.simpleMessage(
      "Yes, go offline",
    ),
    "offlinePromptBody": MessageLookupByLibrary.simpleMessage(
      "The connection to the server was lost. Switch to offline mode and keep selling? Sales are saved on this till and sent to the server when the internet is back.",
    ),
    "offlinePromptDecline": MessageLookupByLibrary.simpleMessage("No"),
    "offlinePromptTitle": MessageLookupByLibrary.simpleMessage(
      "No internet connection",
    ),
    "onlinePromptAccept": MessageLookupByLibrary.simpleMessage("Yes, sync"),
    "onlinePromptBody": m37,
    "onlinePromptLater": MessageLookupByLibrary.simpleMessage("Later"),
    "onlinePromptTitle": MessageLookupByLibrary.simpleMessage(
      "Internet is back",
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
    "paymentBalanceValue": m38,
    "paymentCard": MessageLookupByLibrary.simpleMessage("Card"),
    "paymentCardValue": m39,
    "paymentCash": MessageLookupByLibrary.simpleMessage("Cash"),
    "paymentCashValue": m40,
    "paymentExcess": MessageLookupByLibrary.simpleMessage(
      "Amount exceeds total",
    ),
    "paymentMatched": MessageLookupByLibrary.simpleMessage("Amount matched"),
    "paymentMinimumHint": m41,
    "paymentMissing": MessageLookupByLibrary.simpleMessage("Amount remaining"),
    "paymentSplit": MessageLookupByLibrary.simpleMessage("Split"),
    "phoneNotFound": MessageLookupByLibrary.simpleMessage("Number not found"),
    "phoneNumber": MessageLookupByLibrary.simpleMessage("Phone number"),
    "planAlreadyActive": m42,
    "planChargedImmediately": m43,
    "planSwitch": MessageLookupByLibrary.simpleMessage("Switch tariff"),
    "planSwitchHourToVipNote": MessageLookupByLibrary.simpleMessage(
      "The 1 hour tariff price is not refunded.",
    ),
    "planSwitchQuestion": m44,
    "planSwitchVipQuestion": m45,
    "priceFromPerMinute": m46,
    "pricePerDay": m47,
    "pricePerHour": m48,
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
    "promoCode": MessageLookupByLibrary.simpleMessage("Promo code"),
    "promoCodeAlreadyUsedByCustomer": MessageLookupByLibrary.simpleMessage(
      "This customer has already used this promo code",
    ),
    "promoCodeBlogger": MessageLookupByLibrary.simpleMessage("Blogger"),
    "promoCodeBloggerPending": m49,
    "promoCodeCheck": MessageLookupByLibrary.simpleMessage("Check"),
    "promoCodeChildHasPass": MessageLookupByLibrary.simpleMessage(
      "This child already has a pass today — the promo code only applies to a new entry or a VIP upgrade",
    ),
    "promoCodeForChild": MessageLookupByLibrary.simpleMessage("For child"),
    "promoCodeHint": MessageLookupByLibrary.simpleMessage("Scan or type"),
    "promoCodeInvalid": MessageLookupByLibrary.simpleMessage(
      "Invalid promo code — check the code",
    ),
    "promoCodeLimitReached": MessageLookupByLibrary.simpleMessage(
      "This promo code has reached its usage limit",
    ),
    "promoCodeNoChild": MessageLookupByLibrary.simpleMessage(
      "Select a child for the promo code",
    ),
    "promoCodeNotStarted": MessageLookupByLibrary.simpleMessage(
      "This promo code is not active yet",
    ),
    "promoCodeOwnerNotFound": MessageLookupByLibrary.simpleMessage(
      "The promo code owner was not found",
    ),
    "promoCodeReleased": m50,
    "promoCodeRemove": MessageLookupByLibrary.simpleMessage(
      "Remove promo code",
    ),
    "promoCodeWrongCustomer": MessageLookupByLibrary.simpleMessage(
      "This promo code belongs to another customer",
    ),
    "qrPrinter": MessageLookupByLibrary.simpleMessage("QR and label printer"),
    "qrPrinterFallbackNotice": MessageLookupByLibrary.simpleMessage(
      "QR printer not found, so the QR code was printed with the receipt",
    ),
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
    "refundAuditBy": m51,
    "refundBalanceLimitNote": MessageLookupByLibrary.simpleMessage(
      "Reversing a top-up takes the money back off the balance, so you cannot return more than it still holds.",
    ),
    "refundBalanceMethod": MessageLookupByLibrary.simpleMessage("To balance"),
    "refundCardWarning": MessageLookupByLibrary.simpleMessage(
      "A card refund must also be completed on the payment terminal. This action does not automatically reverse the terminal transaction.",
    ),
    "refundConfirmMessage": m52,
    "refundConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Confirm refund",
    ),
    "refundCustomerBalance": m53,
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
    "refundSuccess": m54,
    "refundTitle": MessageLookupByLibrary.simpleMessage("Refund payment"),
    "refundedTotal": MessageLookupByLibrary.simpleMessage("Refunded"),
    "reprint": MessageLookupByLibrary.simpleMessage("Reprint"),
    "reprintAll": MessageLookupByLibrary.simpleMessage("Reprint all"),
    "saleGatePass": MessageLookupByLibrary.simpleMessage("Entry ticket"),
    "saleGeneric": MessageLookupByLibrary.simpleMessage("Sale"),
    "saleGoods": MessageLookupByLibrary.simpleMessage("Product sale"),
    "saleTopup": MessageLookupByLibrary.simpleMessage("Account top-up"),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "searchHistory": MessageLookupByLibrary.simpleMessage("Search history"),
    "searchResult": MessageLookupByLibrary.simpleMessage("Search results"),
    "selectForQr": MessageLookupByLibrary.simpleMessage("Select for QR"),
    "selectedCount": m55,
    "shiftClose": MessageLookupByLibrary.simpleMessage("Close shift"),
    "shiftClosed": MessageLookupByLibrary.simpleMessage("Shift closed"),
    "shiftOpen": MessageLookupByLibrary.simpleMessage("Open shift"),
    "shiftOpenedAt": m56,
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
    "stillOffline": MessageLookupByLibrary.simpleMessage("Still no internet"),
    "switchAndPrint": MessageLookupByLibrary.simpleMessage("Switch and print"),
    "syncResultBody": m57,
    "syncResultTitle": MessageLookupByLibrary.simpleMessage("Sync result"),
    "syncTransportFailed": m58,
    "syncViewFailures": MessageLookupByLibrary.simpleMessage("View"),
    "tabAccount": MessageLookupByLibrary.simpleMessage("Account & QR"),
    "tabHistory": MessageLookupByLibrary.simpleMessage("Sales history"),
    "tabInside": MessageLookupByLibrary.simpleMessage("Inside park"),
    "tabSales": MessageLookupByLibrary.simpleMessage("Sales"),
    "tabSettings": MessageLookupByLibrary.simpleMessage("Settings"),
    "tabUnsynced": MessageLookupByLibrary.simpleMessage("Unsynced"),
    "tabVisitHistory": MessageLookupByLibrary.simpleMessage(
      "Entry/exit history",
    ),
    "tariff": MessageLookupByLibrary.simpleMessage("Tariff"),
    "tariffNotFound": MessageLookupByLibrary.simpleMessage("No tariffs found."),
    "themeDay": MessageLookupByLibrary.simpleMessage("Day mode"),
    "themeNight": MessageLookupByLibrary.simpleMessage("Night mode"),
    "themeNightHint": MessageLookupByLibrary.simpleMessage(
      "A soft dark-blue background that is easy on the eyes. Remembered on this till.",
    ),
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
    "txBonus": MessageLookupByLibrary.simpleMessage("Bonus"),
    "txCashierTopup": MessageLookupByLibrary.simpleMessage("Cash-desk top-up"),
    "txCashierTopupRefund": MessageLookupByLibrary.simpleMessage(
      "Top-up refunded",
    ),
    "txGameReward": MessageLookupByLibrary.simpleMessage("Game reward"),
    "txKidsCharge": MessageLookupByLibrary.simpleMessage("Tariff (entry)"),
    "txLegacy": MessageLookupByLibrary.simpleMessage("Legacy record"),
    "txManualAdjustment": MessageLookupByLibrary.simpleMessage(
      "Manual adjustment",
    ),
    "txMarketPurchase": MessageLookupByLibrary.simpleMessage("Market purchase"),
    "txMarketRefund": MessageLookupByLibrary.simpleMessage("Market refund"),
    "txPayment": MessageLookupByLibrary.simpleMessage("App top-up"),
    "txPosPurchase": MessageLookupByLibrary.simpleMessage("Cash-desk purchase"),
    "txPosPurchaseRefund": MessageLookupByLibrary.simpleMessage(
      "Purchase refunded",
    ),
    "txStatusCancelled": MessageLookupByLibrary.simpleMessage("Cancelled"),
    "txStatusFailed": MessageLookupByLibrary.simpleMessage("Failed"),
    "txStatusPending": MessageLookupByLibrary.simpleMessage("Pending"),
    "unlimitedFreeEntry": MessageLookupByLibrary.simpleMessage(
      "Free — unrestricted entry and exit",
    ),
    "unsyncedCodeCopied": MessageLookupByLibrary.simpleMessage("Code copied"),
    "unsyncedEmpty": MessageLookupByLibrary.simpleMessage(
      "All sales are synced",
    ),
    "unsyncedFailed": MessageLookupByLibrary.simpleMessage("Failed"),
    "unsyncedHint": MessageLookupByLibrary.simpleMessage(
      "For a failed sale, call support and read them the code.",
    ),
    "unsyncedPending": MessageLookupByLibrary.simpleMessage("Waiting"),
    "unsyncedRetry": MessageLookupByLibrary.simpleMessage("Retry"),
    "unsyncedRetryAll": MessageLookupByLibrary.simpleMessage("Resend all"),
    "unsyncedRetryNeedsOnline": MessageLookupByLibrary.simpleMessage(
      "Switch to online mode to resend",
    ),
    "unsyncedSupportCode": m59,
    "updateAvailable": m60,
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
    "vipAlreadyActive": m61,
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
