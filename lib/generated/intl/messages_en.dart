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

  static String m5(phone) => "No account exists for ${phone}.";

  static String m6(plan, count) => "${plan} × ${count}";

  static String m7(count) => "${count}";

  static String m8(from, to, total) => "${from}–${to} / ${total}";

  static String m9(time) => "until ${time}";

  static String m10(value) =>
      "${value} will be debited for time already played.";

  static String m11(value) =>
      "Insufficient balance — at least ${value} must be paid.";

  static String m12(amount) => "+${amount} UZS";

  static String m13(count) => "${count} days ago";

  static String m14(count) => "${count} h ago";

  static String m15(count) => "${count} min ago";

  static String m16(reason) => "Reason: ${reason}";

  static String m17(max) => "Cash cannot exceed ${max}";

  static String m18(date) => "Born ${date}";

  static String m19(amount) => "Debt left: ${amount} UZS. Complete anyway?";

  static String m20(date) => "Can be completed on ${date}";

  static String m21(day, month) => "${month} ${day}";

  static String m22(count, price) => "Extra kids ${count} × ${price}";

  static String m23(amount) => "From balance −${amount}";

  static String m24(count) => "in ${count} days";

  static String m25(amount) => "Kept: ${amount}";

  static String m26(amount) => "Kept ${amount}";

  static String m27(count) => "${count} kids";

  static String m28(count, extra) => "${count} kids + ${extra} extra";

  static String m29(amount) => "Net paid: ${amount}";

  static String m30(count) => "Package (${count} kids)";

  static String m31(amount) =>
      "${amount} will be returned to the customer’s balance";

  static String m32(cash, card) => "Split ${cash} + ${card}";

  static String m33(party) => "Another party at this time: ${party}";

  static String m34(time) => "Confirm for ${time}";

  static String m35(branch) => "That day at ${branch}";

  static String m36(count) => "${count} parties";

  static String m37(net) => "Total cannot exceed ${net}";

  static String m38(age) => "turns ${age}";

  static String m39(amount) => "Bonus ${amount} — can’t be used";

  static String m40(amount) => "Balance: ${amount} usable";

  static String m41(age) => "${age} y.o.";

  static String m42(name) =>
      "It\'s ${name}\'s birthday. Pick the age — the date is saved on the child.";

  static String m43(amount) =>
      "Price changed by hand — reported as a ${amount} discount.";

  static String m44(price) => "each ${price}";

  static String m45(size, plan, price) => "${plan} for ${size} · each ${price}";

  static String m46(price) => "+1 child: ${price}";

  static String m47(price) => "from ${price}";

  static String m48(plan) => "${plan} includes";

  static String m49(name) => "Cash desk · ${name}";

  static String m50(count) => "${count} children";

  static String m51(count) =>
      "${count} sales failed to sync. Contact support before closing the shift.";

  static String m52(price) => "${price} each — unrestricted like parent QR";

  static String m53(amount, from, to) => "${amount}: ${from} → ${to}";

  static String m54(amount, from, to) =>
      "${amount} moves from ${from} to ${to}. The change is kept in the audit history.";

  static String m55(cash, card) => "Result: cash ${cash}, card ${card}";

  static String m56(value) => "Current balance: ${value}";

  static String m57(child, plan, inside) =>
      "«${child}» is on the «${plan}» tariff today${inside}.";

  static String m58(count) => "${count} customers";

  static String m59(cash, card) => "Now: ${cash} cash + ${card} card";

  static String m60(amount, from, to) =>
      "${amount} moves from ${from} to ${to}";

  static String m61(amount, method) =>
      "${amount} is handed back to the customer in ${method}";

  static String m62(count) => "Enter (${count})";

  static String m63(plan, time, minutes) =>
      "${plan} · entered ${time} · ${minutes} min";

  static String m64(message) => "Failed to enter: ${message}";

  static String m65(amount) => "Debt ${amount}";

  static String m66(value) =>
      "Insufficient balance — top up at least ${value} to exit.";

  static String m67(count) => "Group: ${count} kids";

  static String m68(count) => "${count}";

  static String m69(name) =>
      "«${name}» already has an active 1 hour tariff — no second charge.";

  static String m70(count) =>
      "${count} children are past their time — call the parents";

  static String m71(count) => "+${count} min over";

  static String m72(count) => "${count} min left";

  static String m73(count) => "Inside: ${count}";

  static String m74(count) =>
      "${count} sales are not synced. Sync them in online mode before signing out.";

  static String m75(count) =>
      "${count} sales failed to sync. They stay saved on this till. Sign out anyway?";

  static String m76(child, amount) =>
      "${child} will be marked as exited now. The visit will close at ${amount} and be debited from the parent\'s balance. Continue?";

  static String m77(count) => "${count} min";

  static String m78(count) => "OFFLINE · ${count} sales waiting";

  static String m79(count) => "Switch to online mode and sync ${count} sales?";

  static String m80(value) => "Balance: ${value}";

  static String m81(value) => "Card: ${value}";

  static String m82(value) => "Cash: ${value}";

  static String m83(value) =>
      "At least ${value} — excess remains on the balance";

  static String m84(name, plan) =>
      "«${name}» already has an active «${plan}» tariff — no second charge.";

  static String m85(plan) =>
      "The «${plan}» tariff is debited from the balance immediately when printed.";

  static String m86(name, from, to) =>
      "«${name}»: can\'t switch ${from} → ${to}";

  static String m87(plan) =>
      "Switch to the «${plan}» tariff? The old sticker will be cancelled and a new QR printed.";

  static String m88(plan, price) =>
      "Switch to «${plan}»? Only the surcharge (${price}) is collected now, in cash or by card — nothing extra lands on the balance. The old sticker is stopped and the new QR prints as an upgrade.";

  static String m89(plan, price) =>
      "Switch to «${plan}»? Only the surcharge (${price}) is debited from the balance. The old sticker is stopped and the new QR prints as an upgrade.";

  static String m90(plan, price) =>
      "Switch to the «${plan}» tariff? The ${plan} price (${price}) will be debited immediately. The old sticker will be cancelled and a new QR printed.";

  static String m91(child, from, to, paid, due) =>
      "${child}: ${from} → ${to}. ${paid} already paid — surcharge: ${due}";

  static String m92(value) => "from ${value} / min";

  static String m93(value) => "${value} / day";

  static String m94(value) => "${value} / hour";

  static String m95(code) =>
      "Blogger promo code ${code} accepted — select a customer";

  static String m96(reason) =>
      "Promo code not applied, code returned: ${reason}";

  static String m97(date) => "until ${date}";

  static String m98(date, name) => "${date} · ${name}";

  static String m99(amount, method) =>
      "${amount} will be refunded via ${method}. This action is permanently stored in the audit history.";

  static String m100(balance) => "Customer balance: ${balance}";

  static String m101(count) =>
      "${count} pass(es) will also be voided and stop working at the gate.";

  static String m102(amount) => "${amount} was refunded successfully";

  static String m103(count) => "selected: ${count}";

  static String m104(count) => "${count}";

  static String m105(time) => "Shift opened at ${time}";

  static String m106(count) => "Activates today → ${count} days";

  static String m107(name, left, total) => "${name} · ${left}/${total} left";

  static String m108(count) => "${count} days";

  static String m109(name, from, to) => "${name} ${from} → ${to} left";

  static String m110(count) => "${count} entries";

  static String m111(left, total) => "has · ${left}/${total}";

  static String m112(plan) => "here: ${plan}";

  static String m113(count) => "${count} a week";

  static String m114(reason) =>
      "Subscription sold, but today\'s entry failed: ${reason}";

  static String m115(price) => "1 entry ${price}";

  static String m116(amount) => "Sell · collect ${amount}";

  static String m117(names) =>
      "${names} — on subscription (0 so\'m). No tariff needed.";

  static String m118(names, others) =>
      "${names} — on subscription (0 so\'m). Tariff only for: ${others}.";

  static String m119(date) => "until ${date} · free today";

  static String m120(synced, failed) =>
      "${synced} sales synced, ${failed} failed.";

  static String m121(reason) => "Could not sync: ${reason}. Staying offline.";

  static String m122(code) => "Code: ${code}";

  static String m123(version) => "New version available: ${version}";

  static String m124(paid, due) => "${paid} already paid — surcharge: ${due}.";

  static String m125(name) =>
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
    "bdAddChildPrice": m12,
    "bdAddChildSubmit": MessageLookupByLibrary.simpleMessage("Add"),
    "bdAddChildTitle": MessageLookupByLibrary.simpleMessage("Extra children"),
    "bdAddPaymentFull": MessageLookupByLibrary.simpleMessage("+ Add payment"),
    "bdAgoDays": m13,
    "bdAgoHours": m14,
    "bdAgoJustNow": MessageLookupByLibrary.simpleMessage("just now"),
    "bdAgoMinutes": m15,
    "bdBack": MessageLookupByLibrary.simpleMessage("Back"),
    "bdBalanceUnknown": MessageLookupByLibrary.simpleMessage("Balance unknown"),
    "bdCancelConfirm": MessageLookupByLibrary.simpleMessage("Cancel party"),
    "bdCancelParty": MessageLookupByLibrary.simpleMessage("Cancel party"),
    "bdCancelReason": MessageLookupByLibrary.simpleMessage("Reason"),
    "bdCancelReasonShort": MessageLookupByLibrary.simpleMessage(
      "At least 3 characters",
    ),
    "bdCancelTitle": MessageLookupByLibrary.simpleMessage("Cancel the party"),
    "bdCancelledChip": MessageLookupByLibrary.simpleMessage("Cancelled"),
    "bdCancelledReason": m16,
    "bdCashAtTill": MessageLookupByLibrary.simpleMessage("Cash at the till"),
    "bdCashTooLarge": m17,
    "bdChangeDate": MessageLookupByLibrary.simpleMessage("Change date"),
    "bdChildBirthDate": m18,
    "bdClose": MessageLookupByLibrary.simpleMessage("Close"),
    "bdCommentHint": MessageLookupByLibrary.simpleMessage("Write a comment"),
    "bdComments": MessageLookupByLibrary.simpleMessage("Comments"),
    "bdCompleteAnyway": MessageLookupByLibrary.simpleMessage("Complete"),
    "bdCompleteDebt": m19,
    "bdCompleteFrom": m20,
    "bdDayMonth": m21,
    "bdDetailsAwaiting": MessageLookupByLibrary.simpleMessage(
      "Awaiting confirmation",
    ),
    "bdDetailsFromApp": MessageLookupByLibrary.simpleMessage("from the app"),
    "bdDetailsFromTill": MessageLookupByLibrary.simpleMessage("from the till"),
    "bdDetailsNote": MessageLookupByLibrary.simpleMessage("Note"),
    "bdDetailsPackage": MessageLookupByLibrary.simpleMessage("Package"),
    "bdDetailsParty": MessageLookupByLibrary.simpleMessage("Party"),
    "bdDetailsPayment": MessageLookupByLibrary.simpleMessage("Payment"),
    "bdDiscountLine": MessageLookupByLibrary.simpleMessage("Discount"),
    "bdExtraChildLine": m22,
    "bdExtraChildrenConflict": MessageLookupByLibrary.simpleMessage(
      "Another till changed the number of children. Refreshed — check and add again if needed.",
    ),
    "bdFromBalanceLine": m23,
    "bdInDays": m24,
    "bdKept": m25,
    "bdKeptChip": m26,
    "bdKeptLabel": MessageLookupByLibrary.simpleMessage("Kept"),
    "bdKidsCount": m27,
    "bdKidsWithExtra": m28,
    "bdLeft": MessageLookupByLibrary.simpleMessage("Left"),
    "bdLeftBeforeParty": MessageLookupByLibrary.simpleMessage(
      "Left · before the party",
    ),
    "bdMonthsLong": MessageLookupByLibrary.simpleMessage(
      "January,February,March,April,May,June,July,August,September,October,November,December",
    ),
    "bdMonthsShort": MessageLookupByLibrary.simpleMessage(
      "JAN,FEB,MAR,APR,MAY,JUN,JUL,AUG,SEP,OCT,NOV,DEC",
    ),
    "bdMoreChild": MessageLookupByLibrary.simpleMessage("+ child"),
    "bdNetPaid": m29,
    "bdNoComments": MessageLookupByLibrary.simpleMessage("No comments"),
    "bdNoPayments": MessageLookupByLibrary.simpleMessage("No payments yet"),
    "bdNoRefund": MessageLookupByLibrary.simpleMessage("Keep the money"),
    "bdNothingPaidInApp": MessageLookupByLibrary.simpleMessage(
      "Nothing paid in the app",
    ),
    "bdOfflineHint": MessageLookupByLibrary.simpleMessage(
      "No network — try again",
    ),
    "bdPackageLine": m30,
    "bdPaidCard": MessageLookupByLibrary.simpleMessage("Card"),
    "bdPaidFromBalance": MessageLookupByLibrary.simpleMessage("From balance"),
    "bdPaidNet": MessageLookupByLibrary.simpleMessage("Paid"),
    "bdPayAmount": MessageLookupByLibrary.simpleMessage("Payment amount"),
    "bdPayOverDebt": MessageLookupByLibrary.simpleMessage(
      "Amount cannot exceed the debt",
    ),
    "bdPaySubmit": MessageLookupByLibrary.simpleMessage("Take payment"),
    "bdPayTitle": MessageLookupByLibrary.simpleMessage("Add payment"),
    "bdPayments": MessageLookupByLibrary.simpleMessage("Payments"),
    "bdRefund": MessageLookupByLibrary.simpleMessage("Refund"),
    "bdRefundEmpty": MessageLookupByLibrary.simpleMessage("Enter an amount"),
    "bdRefundToBalance": MessageLookupByLibrary.simpleMessage(
      "Refunded to balance",
    ),
    "bdRefundToCash": MessageLookupByLibrary.simpleMessage("Refunded in cash"),
    "bdRequestAlreadyDecided": MessageLookupByLibrary.simpleMessage(
      "This request has already been decided",
    ),
    "bdRequestCashLeft": MessageLookupByLibrary.simpleMessage("Cash remaining"),
    "bdRequestConfirm": MessageLookupByLibrary.simpleMessage("Confirm"),
    "bdRequestConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Confirm the request",
    ),
    "bdRequestConflict": MessageLookupByLibrary.simpleMessage(
      "This action was already done — the event was refreshed",
    ),
    "bdRequestDetails": MessageLookupByLibrary.simpleMessage("Details"),
    "bdRequestPaidInApp": MessageLookupByLibrary.simpleMessage(
      "Paid in the app",
    ),
    "bdRequestPickTime": MessageLookupByLibrary.simpleMessage("Pick a time"),
    "bdRequestRefundNote": m31,
    "bdRequestReject": MessageLookupByLibrary.simpleMessage("Reject"),
    "bdRequestRejectReason": MessageLookupByLibrary.simpleMessage(
      "Reason for rejection",
    ),
    "bdRequestRejectTitle": MessageLookupByLibrary.simpleMessage(
      "Reject the request",
    ),
    "bdRequestsTitle": MessageLookupByLibrary.simpleMessage("Requests"),
    "bdSourceApp": MessageLookupByLibrary.simpleMessage("App"),
    "bdSplitMethod": m32,
    "bdTakeNow": MessageLookupByLibrary.simpleMessage("Collect now"),
    "bdTimeAfternoon": MessageLookupByLibrary.simpleMessage(
      "Afternoon and evening",
    ),
    "bdTimeBusyWarning": m33,
    "bdTimeConfirmAt": m34,
    "bdTimeDayAt": m35,
    "bdTimeDayCount": m36,
    "bdTimeDayEmpty": MessageLookupByLibrary.simpleMessage("No other parties"),
    "bdTimeDayFailed": MessageLookupByLibrary.simpleMessage(
      "The day’s schedule did not load",
    ),
    "bdTimeHint": MessageLookupByLibrary.simpleMessage(
      "A busy time can still be chosen — it only warns.",
    ),
    "bdTimeLegendBusy": MessageLookupByLibrary.simpleMessage("another party"),
    "bdTimeLegendNear": MessageLookupByLibrary.simpleMessage(
      "close, within an hour",
    ),
    "bdTimeLegendSelected": MessageLookupByLibrary.simpleMessage("selected"),
    "bdTimeMorning": MessageLookupByLibrary.simpleMessage("Morning"),
    "bdTimeOther": MessageLookupByLibrary.simpleMessage("Other time"),
    "bdTimeOtherInvalid": MessageLookupByLibrary.simpleMessage(
      "HH:MM, 00:00–23:59",
    ),
    "bdTimeTitle": MessageLookupByLibrary.simpleMessage("Pick the party time"),
    "bdToBalance": MessageLookupByLibrary.simpleMessage("To balance"),
    "bdToCash": MessageLookupByLibrary.simpleMessage("Cash"),
    "bdTotalLine": MessageLookupByLibrary.simpleMessage("Total"),
    "bdTotalTooLarge": m37,
    "bdTurnsAge": m38,
    "bdUnclearHint": MessageLookupByLibrary.simpleMessage(
      "No response received. Amounts are locked — try again or close.",
    ),
    "bdWalletBonus": m39,
    "bdWalletFailed": MessageLookupByLibrary.simpleMessage(
      "Balance unknown — take cash or card",
    ),
    "bdWalletNoUsable": MessageLookupByLibrary.simpleMessage(
      "No real money on the balance — take cash or card",
    ),
    "bdWalletUsable": m40,
    "bdWeekdays": MessageLookupByLibrary.simpleMessage(
      "Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday",
    ),
    "birthdayAgeChip": m41,
    "birthdayAgeHint": m42,
    "birthdayAgeTitle": MessageLookupByLibrary.simpleMessage("How old today?"),
    "birthdayBookAndReceipt": MessageLookupByLibrary.simpleMessage(
      "Book and print receipt",
    ),
    "birthdayChildCount": MessageLookupByLibrary.simpleMessage(
      "Number of children",
    ),
    "birthdayChildrenUnit": MessageLookupByLibrary.simpleMessage("children"),
    "birthdayDate": MessageLookupByLibrary.simpleMessage("Party date"),
    "birthdayDeposit": MessageLookupByLibrary.simpleMessage("Deposit"),
    "birthdayDepositAmount": MessageLookupByLibrary.simpleMessage(
      "Deposit amount",
    ),
    "birthdayDiscountLine": MessageLookupByLibrary.simpleMessage("Discount"),
    "birthdayDiscountNote": m43,
    "birthdayErrCompleteTooEarly": MessageLookupByLibrary.simpleMessage(
      "Cannot complete before the party date",
    ),
    "birthdayErrGeneric": MessageLookupByLibrary.simpleMessage(
      "Birthday action failed",
    ),
    "birthdayErrNotBooked": MessageLookupByLibrary.simpleMessage(
      "The party is already completed or cancelled",
    ),
    "birthdayErrPartyNotFound": MessageLookupByLibrary.simpleMessage(
      "Party not found",
    ),
    "birthdayErrPaymentEmpty": MessageLookupByLibrary.simpleMessage(
      "No payment amount entered",
    ),
    "birthdayErrPlanNotAvailable": MessageLookupByLibrary.simpleMessage(
      "This package is not available here",
    ),
    "birthdayErrSizeNotFound": MessageLookupByLibrary.simpleMessage(
      "This child count is not in the package",
    ),
    "birthdayExtraAdd": MessageLookupByLibrary.simpleMessage("Add one"),
    "birthdayExtraChild": MessageLookupByLibrary.simpleMessage("Extra child"),
    "birthdayExtraEach": m44,
    "birthdayExtraHint": m45,
    "birthdayExtraPlusPrice": m46,
    "birthdayExtraRemove": MessageLookupByLibrary.simpleMessage("Remove one"),
    "birthdayFreeOnlyToday": MessageLookupByLibrary.simpleMessage(
      "Available only on the birthday",
    ),
    "birthdayFromPrice": m47,
    "birthdayInAWeek": MessageLookupByLibrary.simpleMessage("+7 days"),
    "birthdayIncludes": MessageLookupByLibrary.simpleMessage("Included"),
    "birthdayIncludesTier": m48,
    "birthdayNoPlans": MessageLookupByLibrary.simpleMessage(
      "No birthday packages at this branch",
    ),
    "birthdayOffline": MessageLookupByLibrary.simpleMessage(
      "Birthday sales need an internet connection",
    ),
    "birthdayOtherDate": MessageLookupByLibrary.simpleMessage("Other date"),
    "birthdayPaidBeforeParty": MessageLookupByLibrary.simpleMessage(
      "Due before the party",
    ),
    "birthdayPayFull": MessageLookupByLibrary.simpleMessage("Full payment"),
    "birthdayPayment": MessageLookupByLibrary.simpleMessage("Payment"),
    "birthdayPickPlanFirst": MessageLookupByLibrary.simpleMessage(
      "Pick a package first",
    ),
    "birthdayPlan": MessageLookupByLibrary.simpleMessage("Package"),
    "birthdayResetExtra": MessageLookupByLibrary.simpleMessage("Reset to 0"),
    "birthdaySell": MessageLookupByLibrary.simpleMessage("Sell birthday party"),
    "birthdayStepDateHint": MessageLookupByLibrary.simpleMessage(
      "The day of the party",
    ),
    "birthdayStepExtraHint": MessageLookupByLibrary.simpleMessage(
      "Children on top of the package",
    ),
    "birthdayStepPlanHint": MessageLookupByLibrary.simpleMessage(
      "Pick by colour",
    ),
    "birthdayStepSizeHint": MessageLookupByLibrary.simpleMessage(
      "Children in the package",
    ),
    "birthdaySummary": MessageLookupByLibrary.simpleMessage("Summary"),
    "birthdaySummaryEmpty": MessageLookupByLibrary.simpleMessage(
      "Pick a plan and the child count — the summary shows here",
    ),
    "birthdayTotal": MessageLookupByLibrary.simpleMessage("Total"),
    "birthdayTotalEditHint": MessageLookupByLibrary.simpleMessage(
      "The price can be edited",
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
    "cashDeskCashier": m49,
    "cashback": MessageLookupByLibrary.simpleMessage("Cashback"),
    "categoryAll": MessageLookupByLibrary.simpleMessage("All"),
    "checkDiscount": MessageLookupByLibrary.simpleMessage("Check discount"),
    "checkDiscountLocked": MessageLookupByLibrary.simpleMessage(
      "Check discount selected — child discounts and promo code are off",
    ),
    "checkDiscountNone": MessageLookupByLibrary.simpleMessage("None"),
    "checkOnline": MessageLookupByLibrary.simpleMessage("Check connection"),
    "childCount": m50,
    "childName": MessageLookupByLibrary.simpleMessage("Child name"),
    "children": MessageLookupByLibrary.simpleMessage("Children"),
    "close": MessageLookupByLibrary.simpleMessage("Close"),
    "closeShiftOffline": MessageLookupByLibrary.simpleMessage(
      "A shift can\'t be closed in offline mode",
    ),
    "closeShiftUnsyncedWarning": m51,
    "companionDescription": m52,
    "correctPaymentAction": MessageLookupByLibrary.simpleMessage(
      "Correct payment method",
    ),
    "correctPaymentAmount": MessageLookupByLibrary.simpleMessage(
      "Amount to move",
    ),
    "correctPaymentAudit": m53,
    "correctPaymentConfirmMessage": m54,
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
    "correctPaymentResult": m55,
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
    "currentBalanceValue": m56,
    "currentPlanToday": m57,
    "currentShiftOnly": MessageLookupByLibrary.simpleMessage(
      "Current shift only",
    ),
    "currentTariff": MessageLookupByLibrary.simpleMessage("Current tariff"),
    "currentlyInside": MessageLookupByLibrary.simpleMessage("Currently inside"),
    "customerCount": m58,
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
    "editSaleCurrent": m59,
    "editSaleHint": MessageLookupByLibrary.simpleMessage(
      "Enter the correct total and the correct payment method. The steps are worked out for you: a changed method moves the columns, a lower total hands back the difference.",
    ),
    "editSaleMethod": MessageLookupByLibrary.simpleMessage(
      "Correct payment method",
    ),
    "editSalePartialFailure": MessageLookupByLibrary.simpleMessage(
      "The edit did not finish. Reopen the receipt and edit again — only what is still missing will run.",
    ),
    "editSalePlanCorrection": m60,
    "editSalePlanNoop": MessageLookupByLibrary.simpleMessage(
      "Nothing changes — the receipt already says this",
    ),
    "editSalePlanRefund": m61,
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
    "enterCount": m62,
    "enteredAt": MessageLookupByLibrary.simpleMessage("Entered at"),
    "enteredAtMinutes": m63,
    "entryFailed": m64,
    "eventsAddPayment": MessageLookupByLibrary.simpleMessage("+ Payment"),
    "eventsBooked": MessageLookupByLibrary.simpleMessage("Upcoming"),
    "eventsCancelled": MessageLookupByLibrary.simpleMessage("Cancelled"),
    "eventsChildUnit": MessageLookupByLibrary.simpleMessage("children"),
    "eventsComplete": MessageLookupByLibrary.simpleMessage("Complete"),
    "eventsCompleted": MessageLookupByLibrary.simpleMessage("Completed"),
    "eventsDebt": m65,
    "eventsEmpty": MessageLookupByLibrary.simpleMessage("No events"),
    "eventsLater": MessageLookupByLibrary.simpleMessage("Later"),
    "eventsLoadError": MessageLookupByLibrary.simpleMessage(
      "Unable to load events",
    ),
    "eventsNextWeek": MessageLookupByLibrary.simpleMessage("Next week"),
    "eventsOverdue": MessageLookupByLibrary.simpleMessage("Overdue"),
    "eventsPaid": MessageLookupByLibrary.simpleMessage("Paid"),
    "eventsRetry": MessageLookupByLibrary.simpleMessage("Retry"),
    "eventsThisWeek": MessageLookupByLibrary.simpleMessage("This week"),
    "eventsToday": MessageLookupByLibrary.simpleMessage("Today"),
    "eventsTomorrow": MessageLookupByLibrary.simpleMessage("Tomorrow"),
    "eventsUnpaid": MessageLookupByLibrary.simpleMessage("Unpaid"),
    "exitBalanceInsufficient": m66,
    "findCustomerHint": MessageLookupByLibrary.simpleMessage(
      "Enter a phone number to find a customer",
    ),
    "foreignPhone": MessageLookupByLibrary.simpleMessage("Foreign number"),
    "foreignPhoneHint": MessageLookupByLibrary.simpleMessage(
      "Type the number with its country code, e.g. 7 916 123 45 67. No SMS is sent to foreign numbers.",
    ),
    "foreignPhoneIsUzbek": MessageLookupByLibrary.simpleMessage(
      "998… is an Uzbek number — turn off \"Foreign number\" and type it after +998.",
    ),
    "free": MessageLookupByLibrary.simpleMessage("Free"),
    "fullName": MessageLookupByLibrary.simpleMessage("Full name"),
    "groupApply": MessageLookupByLibrary.simpleMessage("Select"),
    "groupCountLabel": MessageLookupByLibrary.simpleMessage("Number of kids"),
    "groupDialogHint": MessageLookupByLibrary.simpleMessage(
      "Kids enter without names: the receipt shows only the count, statistics count each one.",
    ),
    "groupDialogTitle": MessageLookupByLibrary.simpleMessage(
      "Group (school) — how many kids?",
    ),
    "groupEntry": MessageLookupByLibrary.simpleMessage("Group (school)"),
    "groupEntryHint": MessageLookupByLibrary.simpleMessage(
      "Count only — no names",
    ),
    "groupRemove": MessageLookupByLibrary.simpleMessage("Remove group"),
    "groupSelected": m67,
    "history30Days": MessageLookupByLibrary.simpleMessage("30 days"),
    "history7Days": MessageLookupByLibrary.simpleMessage("7 days"),
    "historyAllProducts": MessageLookupByLibrary.simpleMessage("All products"),
    "historyChoose": MessageLookupByLibrary.simpleMessage("Select"),
    "historyChoosePeriod": MessageLookupByLibrary.simpleMessage(
      "Choose sales period",
    ),
    "historyCount": m68,
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
    "hourAlreadyActive": m69,
    "hourChargedImmediately": MessageLookupByLibrary.simpleMessage(
      "The 1 hour tariff is debited from the balance immediately when printed.",
    ),
    "hourEndedAtLabel": MessageLookupByLibrary.simpleMessage("Ended"),
    "hourEndsAtLabel": MessageLookupByLibrary.simpleMessage("Ends"),
    "hourOvertimeBanner": m70,
    "hourOvertimeBy": m71,
    "hourOvertimeShow": MessageLookupByLibrary.simpleMessage("Show"),
    "hourRemaining": m72,
    "hourTariff": MessageLookupByLibrary.simpleMessage("1 hour tariff"),
    "insideCount": m73,
    "insideEmpty": MessageLookupByLibrary.simpleMessage(
      "There are no children inside the park",
    ),
    "insideFilterAll": MessageLookupByLibrary.simpleMessage("All"),
    "insideFilterHour": MessageLookupByLibrary.simpleMessage("Timed"),
    "insideFilterOvertime": MessageLookupByLibrary.simpleMessage("Time is up"),
    "insideHourEmpty": MessageLookupByLibrary.simpleMessage(
      "No children on a timed tariff right now",
    ),
    "insideHourEndingSoon": MessageLookupByLibrary.simpleMessage(
      "Ending in 10 min",
    ),
    "insideHourInside": MessageLookupByLibrary.simpleMessage("Timed inside"),
    "insideNoTurnstileNote": MessageLookupByLibrary.simpleMessage(
      "No turnstile: a child with a timed ticket (1 hour and others) is checked in when the ticket prints and their time starts then — check them out here when they leave.",
    ),
    "insideOvertimeEmpty": MessageLookupByLibrary.simpleMessage(
      "Nobody is over time",
    ),
    "insideSearchEmpty": MessageLookupByLibrary.simpleMessage(
      "No child matches your search",
    ),
    "insideSearchHint": MessageLookupByLibrary.simpleMessage(
      "Search by child, parent or phone",
    ),
    "insideSoldHour": MessageLookupByLibrary.simpleMessage("Timed sold today"),
    "insideSoldVip": MessageLookupByLibrary.simpleMessage("VIP sold today"),
    "insideSuffix": MessageLookupByLibrary.simpleMessage(" (currently inside)"),
    "keypadHint": MessageLookupByLibrary.simpleMessage(
      "Enter a number to see results on the right. Select a customer to open details.",
    ),
    "lanBridgeActive": MessageLookupByLibrary.simpleMessage(
      "Remote session active",
    ),
    "lanBridgeConnected": MessageLookupByLibrary.simpleMessage("connected"),
    "lanBridgeConnecting": MessageLookupByLibrary.simpleMessage("connecting"),
    "lanBridgeControl": MessageLookupByLibrary.simpleMessage("Remote access"),
    "lanBridgeDisabled": MessageLookupByLibrary.simpleMessage("off"),
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
    "logoutBlockedUnsynced": m74,
    "logoutFailedSalesConfirm": m75,
    "manualExitQuestion": m76,
    "manualExitSucceeded": MessageLookupByLibrary.simpleMessage(
      "The child was successfully marked as exited",
    ),
    "manualExitTitle": MessageLookupByLibrary.simpleMessage("Lost QR code?"),
    "markExited": MessageLookupByLibrary.simpleMessage("Mark as exited"),
    "menuClose": MessageLookupByLibrary.simpleMessage("Close menu"),
    "menuOpen": MessageLookupByLibrary.simpleMessage("Open menu"),
    "minutesCount": m77,
    "moreActions": MessageLookupByLibrary.simpleMessage("More"),
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
    "offlineBanner": m78,
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
    "onlinePromptBody": m79,
    "onlinePromptLater": MessageLookupByLibrary.simpleMessage("Later"),
    "onlinePromptTitle": MessageLookupByLibrary.simpleMessage(
      "Internet is back",
    ),
    "openCustomerProfile": MessageLookupByLibrary.simpleMessage(
      "Open customer profile",
    ),
    "paidLabel": MessageLookupByLibrary.simpleMessage("paid"),
    "parentQr": MessageLookupByLibrary.simpleMessage("Parent QR"),
    "parkingReceiptUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "Sale complete. The printer did not confirm the parking slip.",
    ),
    "pay": MessageLookupByLibrary.simpleMessage("Pay"),
    "payFromBalance": MessageLookupByLibrary.simpleMessage("Pay from balance"),
    "paymentAmount": MessageLookupByLibrary.simpleMessage("Payment amount"),
    "paymentAndPrint": MessageLookupByLibrary.simpleMessage("Pay and print"),
    "paymentBalance": MessageLookupByLibrary.simpleMessage(
      "Balance-funded sales",
    ),
    "paymentBalanceValue": m80,
    "paymentCard": MessageLookupByLibrary.simpleMessage("Card"),
    "paymentCardValue": m81,
    "paymentCash": MessageLookupByLibrary.simpleMessage("Cash"),
    "paymentCashValue": m82,
    "paymentExcess": MessageLookupByLibrary.simpleMessage(
      "Amount exceeds total",
    ),
    "paymentMatched": MessageLookupByLibrary.simpleMessage("Amount matched"),
    "paymentMinimumHint": m83,
    "paymentMissing": MessageLookupByLibrary.simpleMessage("Amount remaining"),
    "paymentSplit": MessageLookupByLibrary.simpleMessage("Split"),
    "phoneNotFound": MessageLookupByLibrary.simpleMessage("Number not found"),
    "phoneNumber": MessageLookupByLibrary.simpleMessage("Phone number"),
    "planAlreadyActive": m84,
    "planChargedImmediately": m85,
    "planSwitch": MessageLookupByLibrary.simpleMessage("Switch tariff"),
    "planSwitchBlocked": m86,
    "planSwitchCollectNow": MessageLookupByLibrary.simpleMessage("Collect now"),
    "planSwitchContinue": MessageLookupByLibrary.simpleMessage("Continue"),
    "planSwitchHourToVipNote": MessageLookupByLibrary.simpleMessage(
      "The 1 hour tariff price is not refunded.",
    ),
    "planSwitchPayInDialog": MessageLookupByLibrary.simpleMessage(
      "A selected child already has another tariff today — the amount due (only the surcharge) is shown in the next window.",
    ),
    "planSwitchQuestion": m87,
    "planSwitchUpgradeCollectQuestion": m88,
    "planSwitchUpgradeQuestion": m89,
    "planSwitchVipQuestion": m90,
    "planUpgradeAndPrint": MessageLookupByLibrary.simpleMessage("Upgrade plan"),
    "planUpgradeLine": m91,
    "priceFromPerMinute": m92,
    "pricePerDay": m93,
    "pricePerHour": m94,
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
    "promoCodeActive": MessageLookupByLibrary.simpleMessage(
      "Active promo codes",
    ),
    "promoCodeActiveEmpty": MessageLookupByLibrary.simpleMessage(
      "No active promo codes",
    ),
    "promoCodeActiveHint": MessageLookupByLibrary.simpleMessage(
      "Match the code with the one in the customer\'s SMS",
    ),
    "promoCodeAlreadyUsedByCustomer": MessageLookupByLibrary.simpleMessage(
      "This customer has already used this promo code",
    ),
    "promoCodeBlogger": MessageLookupByLibrary.simpleMessage("Blogger"),
    "promoCodeBloggerPending": m95,
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
    "promoCodeLoadFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t load promo codes",
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
    "promoCodeReleased": m96,
    "promoCodeRemove": MessageLookupByLibrary.simpleMessage(
      "Remove promo code",
    ),
    "promoCodeRetry": MessageLookupByLibrary.simpleMessage("Retry"),
    "promoCodeValidUntil": m97,
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
    "refundAuditBy": m98,
    "refundBalanceLimitNote": MessageLookupByLibrary.simpleMessage(
      "Reversing a top-up takes the money back off the balance, so you cannot return more than it still holds.",
    ),
    "refundBalanceMethod": MessageLookupByLibrary.simpleMessage("To balance"),
    "refundCardWarning": MessageLookupByLibrary.simpleMessage(
      "A card refund must also be completed on the payment terminal. This action does not automatically reverse the terminal transaction.",
    ),
    "refundConfirmMessage": m99,
    "refundConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Confirm refund",
    ),
    "refundCustomerBalance": m100,
    "refundFullBadge": MessageLookupByLibrary.simpleMessage("Fully refunded"),
    "refundFundedConfirm": m101,
    "refundFundedHint": MessageLookupByLibrary.simpleMessage(
      "Tick the passes the customer is handing back: their price returns to the balance first, then goes out as cash or card. Ticked passes are voided at once.",
    ),
    "refundFundedTitle": MessageLookupByLibrary.simpleMessage(
      "Passes bought with this top-up",
    ),
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
    "refundSuccess": m102,
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
    "selectedCount": m103,
    "servicesBirthdaySubtitle": MessageLookupByLibrary.simpleMessage(
      "Package, deposit, pay from balance",
    ),
    "servicesTitle": MessageLookupByLibrary.simpleMessage("Services"),
    "shiftBirthdayIncome": MessageLookupByLibrary.simpleMessage(
      "of which birthday parties",
    ),
    "shiftBirthdayRefunded": MessageLookupByLibrary.simpleMessage(
      "Birthday refunded",
    ),
    "shiftClose": MessageLookupByLibrary.simpleMessage("Close shift"),
    "shiftClosed": MessageLookupByLibrary.simpleMessage("Shift closed"),
    "shiftCountUnit": m104,
    "shiftEnteredChildren": MessageLookupByLibrary.simpleMessage("Went inside"),
    "shiftOpen": MessageLookupByLibrary.simpleMessage("Open shift"),
    "shiftOpenedAt": m105,
    "shiftOpeningCash": MessageLookupByLibrary.simpleMessage(
      "Opening cash (UZS)",
    ),
    "shiftPrintReport": MessageLookupByLibrary.simpleMessage(
      "Print the shift check",
    ),
    "shiftRevenue": MessageLookupByLibrary.simpleMessage("Shift revenue"),
    "shiftStart": MessageLookupByLibrary.simpleMessage("Start shift"),
    "shiftStartHint": MessageLookupByLibrary.simpleMessage(
      "Enter the opening cash amount in the register",
    ),
    "shiftTicketsSold": MessageLookupByLibrary.simpleMessage("Tickets sold"),
    "shiftTotalIncome": MessageLookupByLibrary.simpleMessage(
      "Total shift income",
    ),
    "shiftUniqueChildren": MessageLookupByLibrary.simpleMessage(
      "Unique children",
    ),
    "shiftVipTickets": MessageLookupByLibrary.simpleMessage("of which VIP"),
    "similarNumbers": MessageLookupByLibrary.simpleMessage(
      "Similar numbers — other customers",
    ),
    "stickerPrintFailed": MessageLookupByLibrary.simpleMessage(
      "Sticker was not printed — check the printer",
    ),
    "stillOffline": MessageLookupByLibrary.simpleMessage("Still no internet"),
    "subscriptionActivatesToday": MessageLookupByLibrary.simpleMessage(
      "Activates today",
    ),
    "subscriptionActivatesTodayDays": m106,
    "subscriptionAlreadyActive": MessageLookupByLibrary.simpleMessage(
      "This child already has a live subscription",
    ),
    "subscriptionBlockedNotHere": MessageLookupByLibrary.simpleMessage(
      "not valid at this branch",
    ),
    "subscriptionBlockedOther": MessageLookupByLibrary.simpleMessage(
      "can\'t be used now",
    ),
    "subscriptionBlockedUsedToday": MessageLookupByLibrary.simpleMessage(
      "used today",
    ),
    "subscriptionBlockedWeekly": MessageLookupByLibrary.simpleMessage(
      "weekly limit reached",
    ),
    "subscriptionChip": m107,
    "subscriptionDays": m108,
    "subscriptionDeductLine": m109,
    "subscriptionDeducts": MessageLookupByLibrary.simpleMessage(
      "Taken from the subscription:",
    ),
    "subscriptionEntries": m110,
    "subscriptionHas": m111,
    "subscriptionHere": m112,
    "subscriptionInsufficient": MessageLookupByLibrary.simpleMessage(
      "Balance plus payment does not cover the price",
    ),
    "subscriptionLimitNone": MessageLookupByLibrary.simpleMessage("no limit"),
    "subscriptionLimitPerDay": MessageLookupByLibrary.simpleMessage(
      "once a day",
    ),
    "subscriptionLimitPerWeek": m113,
    "subscriptionNoPlans": MessageLookupByLibrary.simpleMessage(
      "No subscriptions are sold at this branch",
    ),
    "subscriptionOffline": MessageLookupByLibrary.simpleMessage(
      "Subscriptions need an internet connection",
    ),
    "subscriptionPassFailed": m114,
    "subscriptionPerEntry": m115,
    "subscriptionSell": MessageLookupByLibrary.simpleMessage(
      "Sell subscription",
    ),
    "subscriptionSellSubmit": m116,
    "subscriptionSellSubtitle": MessageLookupByLibrary.simpleMessage(
      "One child · not transferable · unused entries burn · no refunds",
    ),
    "subscriptionSellWithout": MessageLookupByLibrary.simpleMessage(
      "Sell without subscription",
    ),
    "subscriptionShortfall": MessageLookupByLibrary.simpleMessage(
      "Left to collect",
    ),
    "subscriptionSkipped": MessageLookupByLibrary.simpleMessage(
      "Subscription off — regular sale",
    ),
    "subscriptionSold": MessageLookupByLibrary.simpleMessage(
      "Subscription sold",
    ),
    "subscriptionStartsToday": MessageLookupByLibrary.simpleMessage(
      "validity starts today",
    ),
    "subscriptionTag": MessageLookupByLibrary.simpleMessage("subscription"),
    "subscriptionTariffHintAll": m117,
    "subscriptionTariffHintSome": m118,
    "subscriptionType": MessageLookupByLibrary.simpleMessage(
      "Subscription type",
    ),
    "subscriptionUntilFree": m119,
    "subscriptionUseAgain": MessageLookupByLibrary.simpleMessage(
      "Use subscription",
    ),
    "subscriptionUseToday": MessageLookupByLibrary.simpleMessage("Enter today"),
    "subscriptionUseTodayHint": MessageLookupByLibrary.simpleMessage(
      "The 1st entry is used now, validity starts today",
    ),
    "subscriptionWhichChild": MessageLookupByLibrary.simpleMessage(
      "Which child?",
    ),
    "switchAndPrint": MessageLookupByLibrary.simpleMessage("Switch and print"),
    "syncResultBody": m120,
    "syncResultTitle": MessageLookupByLibrary.simpleMessage("Sync result"),
    "syncTransportFailed": m121,
    "syncViewFailures": MessageLookupByLibrary.simpleMessage("View"),
    "tabAccount": MessageLookupByLibrary.simpleMessage("Account & QR"),
    "tabEvents": MessageLookupByLibrary.simpleMessage("Events"),
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
    "unsyncedSupportCode": m122,
    "updateAvailable": m123,
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
    "upgradeCredit": m124,
    "version": MessageLookupByLibrary.simpleMessage("Version"),
    "vipAlreadyActive": m125,
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
