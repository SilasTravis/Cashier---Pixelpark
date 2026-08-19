// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class AppLocalization {
  AppLocalization();

  static AppLocalization? _current;

  static AppLocalization get current {
    assert(
      _current != null,
      'No instance of AppLocalization was loaded. Try to initialize the AppLocalization delegate before accessing AppLocalization.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<AppLocalization> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = AppLocalization();
      AppLocalization._current = instance;

      return instance;
    });
  }

  static AppLocalization of(BuildContext context) {
    final instance = AppLocalization.maybeOf(context);
    assert(
      instance != null,
      'No instance of AppLocalization present in the widget tree. Did you add AppLocalization.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static AppLocalization? maybeOf(BuildContext context) {
    return Localizations.of<AppLocalization>(context, AppLocalization);
  }

  /// `Bolajon — kassa`
  String get appTitle {
    return Intl.message(
      'Bolajon — kassa',
      name: 'appTitle',
      desc: '',
      args: [],
    );
  }

  /// `Kassaga kirish`
  String get loginTitle {
    return Intl.message(
      'Kassaga kirish',
      name: 'loginTitle',
      desc: '',
      args: [],
    );
  }

  /// `Login`
  String get loginUsername {
    return Intl.message('Login', name: 'loginUsername', desc: '', args: []);
  }

  /// `Parol`
  String get loginPassword {
    return Intl.message('Parol', name: 'loginPassword', desc: '', args: []);
  }

  /// `Kirish`
  String get loginButton {
    return Intl.message('Kirish', name: 'loginButton', desc: '', args: []);
  }

  /// `Incorrect username or password`
  String get loginError {
    return Intl.message(
      'Incorrect username or password',
      name: 'loginError',
      desc: '',
      args: [],
    );
  }

  /// `Enter your username and password to access the register`
  String get loginSubtitle {
    return Intl.message(
      'Enter your username and password to access the register',
      name: 'loginSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Language`
  String get language {
    return Intl.message('Language', name: 'language', desc: '', args: []);
  }

  /// `Uzbek`
  String get languageUzbek {
    return Intl.message('Uzbek', name: 'languageUzbek', desc: '', args: []);
  }

  /// `Russian`
  String get languageRussian {
    return Intl.message('Russian', name: 'languageRussian', desc: '', args: []);
  }

  /// `Account & QR`
  String get tabAccount {
    return Intl.message('Account & QR', name: 'tabAccount', desc: '', args: []);
  }

  /// `Sales`
  String get tabSales {
    return Intl.message('Sales', name: 'tabSales', desc: '', args: []);
  }

  /// `Sales history`
  String get tabHistory {
    return Intl.message(
      'Sales history',
      name: 'tabHistory',
      desc: '',
      args: [],
    );
  }

  /// `Settings`
  String get tabSettings {
    return Intl.message('Settings', name: 'tabSettings', desc: '', args: []);
  }

  /// `Receipt`
  String get cartTitle {
    return Intl.message('Receipt', name: 'cartTitle', desc: '', args: []);
  }

  /// `Clear`
  String get cartClear {
    return Intl.message('Clear', name: 'cartClear', desc: '', args: []);
  }

  /// `Clear cart`
  String get cartClearTitle {
    return Intl.message(
      'Clear cart',
      name: 'cartClearTitle',
      desc: '',
      args: [],
    );
  }

  /// `All products will be removed from the cart. Continue?`
  String get cartClearMessage {
    return Intl.message(
      'All products will be removed from the cart. Continue?',
      name: 'cartClearMessage',
      desc: '',
      args: [],
    );
  }

  /// `Cart is empty`
  String get cartEmpty {
    return Intl.message('Cart is empty', name: 'cartEmpty', desc: '', args: []);
  }

  /// `All`
  String get categoryAll {
    return Intl.message('All', name: 'categoryAll', desc: '', args: []);
  }

  /// `Product name or category`
  String get productSearchHint {
    return Intl.message(
      'Product name or category',
      name: 'productSearchHint',
      desc: '',
      args: [],
    );
  }

  /// `Total`
  String get total {
    return Intl.message('Total', name: 'total', desc: '', args: []);
  }

  /// `Pay`
  String get pay {
    return Intl.message('Pay', name: 'pay', desc: '', args: []);
  }

  /// `Cash`
  String get paymentCash {
    return Intl.message('Cash', name: 'paymentCash', desc: '', args: []);
  }

  /// `Card`
  String get paymentCard {
    return Intl.message('Card', name: 'paymentCard', desc: '', args: []);
  }

  /// `Split`
  String get paymentSplit {
    return Intl.message('Split', name: 'paymentSplit', desc: '', args: []);
  }

  /// `Amount matched`
  String get paymentMatched {
    return Intl.message(
      'Amount matched',
      name: 'paymentMatched',
      desc: '',
      args: [],
    );
  }

  /// `Amount remaining`
  String get paymentMissing {
    return Intl.message(
      'Amount remaining',
      name: 'paymentMissing',
      desc: '',
      args: [],
    );
  }

  /// `Amount exceeds total`
  String get paymentExcess {
    return Intl.message(
      'Amount exceeds total',
      name: 'paymentExcess',
      desc: '',
      args: [],
    );
  }

  /// `Cancel`
  String get cancel {
    return Intl.message('Cancel', name: 'cancel', desc: '', args: []);
  }

  /// `Close`
  String get close {
    return Intl.message('Close', name: 'close', desc: '', args: []);
  }

  /// `Refresh`
  String get refresh {
    return Intl.message('Refresh', name: 'refresh', desc: '', args: []);
  }

  /// `Shift revenue`
  String get shiftRevenue {
    return Intl.message(
      'Shift revenue',
      name: 'shiftRevenue',
      desc: '',
      args: [],
    );
  }

  /// `Receipt`
  String get receipt {
    return Intl.message('Receipt', name: 'receipt', desc: '', args: []);
  }

  /// `Print receipt`
  String get printReceipt {
    return Intl.message(
      'Print receipt',
      name: 'printReceipt',
      desc: '',
      args: [],
    );
  }

  /// `Printing…`
  String get printing {
    return Intl.message('Printing…', name: 'printing', desc: '', args: []);
  }

  /// `Receipt could not be printed. Check the printer.`
  String get receiptPrintFailed {
    return Intl.message(
      'Receipt could not be printed. Check the printer.',
      name: 'receiptPrintFailed',
      desc: '',
      args: [],
    );
  }

  /// `Today`
  String get historyToday {
    return Intl.message('Today', name: 'historyToday', desc: '', args: []);
  }

  /// `7 days`
  String get history7Days {
    return Intl.message('7 days', name: 'history7Days', desc: '', args: []);
  }

  /// `30 days`
  String get history30Days {
    return Intl.message('30 days', name: 'history30Days', desc: '', args: []);
  }

  /// `This year`
  String get historyYear {
    return Intl.message('This year', name: 'historyYear', desc: '', args: []);
  }

  /// `Date range`
  String get historyDateRange {
    return Intl.message(
      'Date range',
      name: 'historyDateRange',
      desc: '',
      args: [],
    );
  }

  /// `Product`
  String get historyProduct {
    return Intl.message('Product', name: 'historyProduct', desc: '', args: []);
  }

  /// `All products`
  String get historyAllProducts {
    return Intl.message(
      'All products',
      name: 'historyAllProducts',
      desc: '',
      args: [],
    );
  }

  /// `No sales in this period`
  String get historyEmpty {
    return Intl.message(
      'No sales in this period',
      name: 'historyEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Sales`
  String get historySales {
    return Intl.message('Sales', name: 'historySales', desc: '', args: []);
  }

  /// `{count}`
  String historyCount(int count) {
    return Intl.message(
      '$count',
      name: 'historyCount',
      desc: '',
      args: [count],
    );
  }

  /// `Choose sales period`
  String get historyChoosePeriod {
    return Intl.message(
      'Choose sales period',
      name: 'historyChoosePeriod',
      desc: '',
      args: [],
    );
  }

  /// `Select`
  String get historyChoose {
    return Intl.message('Select', name: 'historyChoose', desc: '', args: []);
  }

  /// `Product sale`
  String get saleGoods {
    return Intl.message('Product sale', name: 'saleGoods', desc: '', args: []);
  }

  /// `Entry ticket`
  String get saleGatePass {
    return Intl.message(
      'Entry ticket',
      name: 'saleGatePass',
      desc: '',
      args: [],
    );
  }

  /// `Account top-up`
  String get saleTopup {
    return Intl.message(
      'Account top-up',
      name: 'saleTopup',
      desc: '',
      args: [],
    );
  }

  /// `Sale`
  String get saleGeneric {
    return Intl.message('Sale', name: 'saleGeneric', desc: '', args: []);
  }

  /// `Cash: {value}`
  String paymentCashValue(String value) {
    return Intl.message(
      'Cash: $value',
      name: 'paymentCashValue',
      desc: '',
      args: [value],
    );
  }

  /// `Card: {value}`
  String paymentCardValue(String value) {
    return Intl.message(
      'Card: $value',
      name: 'paymentCardValue',
      desc: '',
      args: [value],
    );
  }

  /// `Balance-funded sales`
  String get paymentBalance {
    return Intl.message(
      'Balance-funded sales',
      name: 'paymentBalance',
      desc: '',
      args: [],
    );
  }

  /// `Balance: {value}`
  String paymentBalanceValue(String value) {
    return Intl.message(
      'Balance: $value',
      name: 'paymentBalanceValue',
      desc: '',
      args: [value],
    );
  }

  /// `Branch`
  String get branch {
    return Intl.message('Branch', name: 'branch', desc: '', args: []);
  }

  /// `Version`
  String get version {
    return Intl.message('Version', name: 'version', desc: '', args: []);
  }

  /// `Log out`
  String get logout {
    return Intl.message('Log out', name: 'logout', desc: '', args: []);
  }

  /// `Printers`
  String get printerSettings {
    return Intl.message(
      'Printers',
      name: 'printerSettings',
      desc: '',
      args: [],
    );
  }

  /// `QR and label printer`
  String get qrPrinter {
    return Intl.message(
      'QR and label printer',
      name: 'qrPrinter',
      desc: '',
      args: [],
    );
  }

  /// `Product receipt printer`
  String get receiptPrinter {
    return Intl.message(
      'Product receipt printer',
      name: 'receiptPrinter',
      desc: '',
      args: [],
    );
  }

  /// `Automatic — Godex`
  String get automaticGodex {
    return Intl.message(
      'Automatic — Godex',
      name: 'automaticGodex',
      desc: '',
      args: [],
    );
  }

  /// `Automatic — SLK`
  String get automaticSewoo {
    return Intl.message(
      'Automatic — SLK',
      name: 'automaticSewoo',
      desc: '',
      args: [],
    );
  }

  /// `No installed Windows printers found`
  String get noPrintersFound {
    return Intl.message(
      'No installed Windows printers found',
      name: 'noPrintersFound',
      desc: '',
      args: [],
    );
  }

  /// `Cash desk`
  String get cashDesk {
    return Intl.message('Cash desk', name: 'cashDesk', desc: '', args: []);
  }

  /// `Cash desk · {name}`
  String cashDeskCashier(String name) {
    return Intl.message(
      'Cash desk · $name',
      name: 'cashDeskCashier',
      desc: '',
      args: [name],
    );
  }

  /// `Open menu`
  String get menuOpen {
    return Intl.message('Open menu', name: 'menuOpen', desc: '', args: []);
  }

  /// `Close menu`
  String get menuClose {
    return Intl.message('Close menu', name: 'menuClose', desc: '', args: []);
  }

  /// `Close shift`
  String get shiftClose {
    return Intl.message('Close shift', name: 'shiftClose', desc: '', args: []);
  }

  /// `Shift opened at {time}`
  String shiftOpenedAt(String time) {
    return Intl.message(
      'Shift opened at $time',
      name: 'shiftOpenedAt',
      desc: '',
      args: [time],
    );
  }

  /// `Start shift`
  String get shiftStart {
    return Intl.message('Start shift', name: 'shiftStart', desc: '', args: []);
  }

  /// `Enter the opening cash amount in the register`
  String get shiftStartHint {
    return Intl.message(
      'Enter the opening cash amount in the register',
      name: 'shiftStartHint',
      desc: '',
      args: [],
    );
  }

  /// `Opening cash (UZS)`
  String get shiftOpeningCash {
    return Intl.message(
      'Opening cash (UZS)',
      name: 'shiftOpeningCash',
      desc: '',
      args: [],
    );
  }

  /// `Open shift`
  String get shiftOpen {
    return Intl.message('Open shift', name: 'shiftOpen', desc: '', args: []);
  }

  /// `Shift closed`
  String get shiftClosed {
    return Intl.message(
      'Shift closed',
      name: 'shiftClosed',
      desc: '',
      args: [],
    );
  }

  /// `Receipt count`
  String get receiptCount {
    return Intl.message(
      'Receipt count',
      name: 'receiptCount',
      desc: '',
      args: [],
    );
  }

  /// `Balance-funded sales (not income)`
  String get balanceSalesNotIncome {
    return Intl.message(
      'Balance-funded sales (not income)',
      name: 'balanceSalesNotIncome',
      desc: '',
      args: [],
    );
  }

  /// `Total shift income`
  String get shiftTotalIncome {
    return Intl.message(
      'Total shift income',
      name: 'shiftTotalIncome',
      desc: '',
      args: [],
    );
  }

  /// `Enter a phone number to find a customer`
  String get findCustomerHint {
    return Intl.message(
      'Enter a phone number to find a customer',
      name: 'findCustomerHint',
      desc: '',
      args: [],
    );
  }

  /// `Recent customers`
  String get recentCustomers {
    return Intl.message(
      'Recent customers',
      name: 'recentCustomers',
      desc: '',
      args: [],
    );
  }

  /// `Search results`
  String get searchResult {
    return Intl.message(
      'Search results',
      name: 'searchResult',
      desc: '',
      args: [],
    );
  }

  /// `{count} customers`
  String customerCount(int count) {
    return Intl.message(
      '$count customers',
      name: 'customerCount',
      desc: '',
      args: [count],
    );
  }

  /// `{count} children`
  String childCount(int count) {
    return Intl.message(
      '$count children',
      name: 'childCount',
      desc: '',
      args: [count],
    );
  }

  /// `Number not found`
  String get phoneNotFound {
    return Intl.message(
      'Number not found',
      name: 'phoneNotFound',
      desc: '',
      args: [],
    );
  }

  /// `No account exists for +998 {phone}.`
  String accountNotFoundForPhone(String phone) {
    return Intl.message(
      'No account exists for +998 $phone.',
      name: 'accountNotFoundForPhone',
      desc: '',
      args: [phone],
    );
  }

  /// `Add customer`
  String get addCustomer {
    return Intl.message(
      'Add customer',
      name: 'addCustomer',
      desc: '',
      args: [],
    );
  }

  /// `Full name`
  String get fullName {
    return Intl.message('Full name', name: 'fullName', desc: '', args: []);
  }

  /// `Save`
  String get save {
    return Intl.message('Save', name: 'save', desc: '', args: []);
  }

  /// `Parent QR`
  String get parentQr {
    return Intl.message('Parent QR', name: 'parentQr', desc: '', args: []);
  }

  /// `Balance`
  String get balance {
    return Intl.message('Balance', name: 'balance', desc: '', args: []);
  }

  /// `Children`
  String get children {
    return Intl.message('Children', name: 'children', desc: '', args: []);
  }

  /// `selected: {count}`
  String selectedCount(int count) {
    return Intl.message(
      'selected: $count',
      name: 'selectedCount',
      desc: '',
      args: [count],
    );
  }

  /// `no children`
  String get noChildren {
    return Intl.message('no children', name: 'noChildren', desc: '', args: []);
  }

  /// `Select for QR`
  String get selectForQr {
    return Intl.message(
      'Select for QR',
      name: 'selectForQr',
      desc: '',
      args: [],
    );
  }

  /// `Quick add`
  String get quickAdd {
    return Intl.message('Quick add', name: 'quickAdd', desc: '', args: []);
  }

  /// `Child name`
  String get childName {
    return Intl.message('Child name', name: 'childName', desc: '', args: []);
  }

  /// `Add`
  String get add {
    return Intl.message('Add', name: 'add', desc: '', args: []);
  }

  /// `Tariff`
  String get tariff {
    return Intl.message('Tariff', name: 'tariff', desc: '', args: []);
  }

  /// `No tariffs found.`
  String get tariffNotFound {
    return Intl.message(
      'No tariffs found.',
      name: 'tariffNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Products`
  String get products {
    return Intl.message('Products', name: 'products', desc: '', args: []);
  }

  /// `{price} each — unrestricted like parent QR`
  String companionDescription(String price) {
    return Intl.message(
      '$price each — unrestricted like parent QR',
      name: 'companionDescription',
      desc: '',
      args: [price],
    );
  }

  /// `«{name}» already has an active VIP tariff — no second charge.`
  String vipAlreadyActive(String name) {
    return Intl.message(
      '«$name» already has an active VIP tariff — no second charge.',
      name: 'vipAlreadyActive',
      desc: '',
      args: [name],
    );
  }

  /// `VIP tariff`
  String get vipTariff {
    return Intl.message('VIP tariff', name: 'vipTariff', desc: '', args: []);
  }

  /// `The VIP tariff is debited from the balance immediately when printed.`
  String get vipChargedImmediately {
    return Intl.message(
      'The VIP tariff is debited from the balance immediately when printed.',
      name: 'vipChargedImmediately',
      desc: '',
      args: [],
    );
  }

  /// `Pay from balance`
  String get payFromBalance {
    return Intl.message(
      'Pay from balance',
      name: 'payFromBalance',
      desc: '',
      args: [],
    );
  }

  /// `Current balance: {value}`
  String currentBalanceValue(String value) {
    return Intl.message(
      'Current balance: $value',
      name: 'currentBalanceValue',
      desc: '',
      args: [value],
    );
  }

  /// `Insufficient balance — at least {value} must be paid.`
  String balanceInsufficient(String value) {
    return Intl.message(
      'Insufficient balance — at least $value must be paid.',
      name: 'balanceInsufficient',
      desc: '',
      args: [value],
    );
  }

  /// `Payment amount`
  String get paymentAmount {
    return Intl.message(
      'Payment amount',
      name: 'paymentAmount',
      desc: '',
      args: [],
    );
  }

  /// `At least {value} — excess remains on the balance`
  String paymentMinimumHint(String value) {
    return Intl.message(
      'At least $value — excess remains on the balance',
      name: 'paymentMinimumHint',
      desc: '',
      args: [value],
    );
  }

  /// `Also print parent QR`
  String get printParentQr {
    return Intl.message(
      'Also print parent QR',
      name: 'printParentQr',
      desc: '',
      args: [],
    );
  }

  /// `Free — unrestricted entry and exit`
  String get unlimitedFreeEntry {
    return Intl.message(
      'Free — unrestricted entry and exit',
      name: 'unlimitedFreeEntry',
      desc: '',
      args: [],
    );
  }

  /// `Currently inside`
  String get currentlyInside {
    return Intl.message(
      'Currently inside',
      name: 'currentlyInside',
      desc: '',
      args: [],
    );
  }

  /// `{plan} · entered {time} · {minutes} min`
  String enteredAtMinutes(String plan, String time, int minutes) {
    return Intl.message(
      '$plan · entered $time · $minutes min',
      name: 'enteredAtMinutes',
      desc: '',
      args: [plan, time, minutes],
    );
  }

  /// `Total bill`
  String get totalBill {
    return Intl.message('Total bill', name: 'totalBill', desc: '', args: []);
  }

  /// `Insufficient balance — top up at least {value} to exit.`
  String exitBalanceInsufficient(String value) {
    return Intl.message(
      'Insufficient balance — top up at least $value to exit.',
      name: 'exitBalanceInsufficient',
      desc: '',
      args: [value],
    );
  }

  /// `Free`
  String get free {
    return Intl.message('Free', name: 'free', desc: '', args: []);
  }

  /// `Free-entry reasons`
  String get freeEntryReasons {
    return Intl.message(
      'Free-entry reasons',
      name: 'freeEntryReasons',
      desc: '',
      args: [],
    );
  }

  /// `Disability`
  String get freeReasonDisabled {
    return Intl.message(
      'Disability',
      name: 'freeReasonDisabled',
      desc: '',
      args: [],
    );
  }

  /// `AILE`
  String get freeReasonAile {
    return Intl.message('AILE', name: 'freeReasonAile', desc: '', args: []);
  }

  /// `Subscription`
  String get freeReasonSubscription {
    return Intl.message(
      'Subscription',
      name: 'freeReasonSubscription',
      desc: '',
      args: [],
    );
  }

  /// `Birthday`
  String get freeReasonBirthday {
    return Intl.message(
      'Birthday',
      name: 'freeReasonBirthday',
      desc: '',
      args: [],
    );
  }

  /// `Top up balance`
  String get topupBalance {
    return Intl.message(
      'Top up balance',
      name: 'topupBalance',
      desc: '',
      args: [],
    );
  }

  /// `Amount`
  String get amount {
    return Intl.message('Amount', name: 'amount', desc: '', args: []);
  }

  /// `New balance`
  String get newBalance {
    return Intl.message('New balance', name: 'newBalance', desc: '', args: []);
  }

  /// `Top up`
  String get topup {
    return Intl.message('Top up', name: 'topup', desc: '', args: []);
  }

  /// `Sticker was not printed — check the printer`
  String get stickerPrintFailed {
    return Intl.message(
      'Sticker was not printed — check the printer',
      name: 'stickerPrintFailed',
      desc: '',
      args: [],
    );
  }

  /// `Failed to enter: {message}`
  String entryFailed(String message) {
    return Intl.message(
      'Failed to enter: $message',
      name: 'entryFailed',
      desc: '',
      args: [message],
    );
  }

  /// `Switch tariff`
  String get planSwitch {
    return Intl.message(
      'Switch tariff',
      name: 'planSwitch',
      desc: '',
      args: [],
    );
  }

  /// `Switch to the «{plan}» tariff? The old sticker will be cancelled and a new QR printed.`
  String planSwitchQuestion(String plan) {
    return Intl.message(
      'Switch to the «$plan» tariff? The old sticker will be cancelled and a new QR printed.',
      name: 'planSwitchQuestion',
      desc: '',
      args: [plan],
    );
  }

  /// `Switch to the «{plan}» tariff? The {plan} price ({price}) will be debited immediately. The old sticker will be cancelled and a new QR printed.`
  String planSwitchVipQuestion(String plan, String price) {
    return Intl.message(
      'Switch to the «$plan» tariff? The $plan price ($price) will be debited immediately. The old sticker will be cancelled and a new QR printed.',
      name: 'planSwitchVipQuestion',
      desc: '',
      args: [plan, price],
    );
  }

  /// `«{child}» is on the «{plan}» tariff today{inside}.`
  String currentPlanToday(String child, String plan, String inside) {
    return Intl.message(
      '«$child» is on the «$plan» tariff today$inside.',
      name: 'currentPlanToday',
      desc: '',
      args: [child, plan, inside],
    );
  }

  /// ` (currently inside)`
  String get insideSuffix {
    return Intl.message(
      ' (currently inside)',
      name: 'insideSuffix',
      desc: '',
      args: [],
    );
  }

  /// `This tariff cannot be downgraded — if the sticker was lost, reprint the current tariff.`
  String get downgradeForbidden {
    return Intl.message(
      'This tariff cannot be downgraded — if the sticker was lost, reprint the current tariff.',
      name: 'downgradeForbidden',
      desc: '',
      args: [],
    );
  }

  /// `{value} will be debited for time already played.`
  String accruedDue(String value) {
    return Intl.message(
      '$value will be debited for time already played.',
      name: 'accruedDue',
      desc: '',
      args: [value],
    );
  }

  /// `Reprint`
  String get reprint {
    return Intl.message('Reprint', name: 'reprint', desc: '', args: []);
  }

  /// `Switch and print`
  String get switchAndPrint {
    return Intl.message(
      'Switch and print',
      name: 'switchAndPrint',
      desc: '',
      args: [],
    );
  }

  /// `Enter a number to see results on the right. Select a customer to open details.`
  String get keypadHint {
    return Intl.message(
      'Enter a number to see results on the right. Select a customer to open details.',
      name: 'keypadHint',
      desc: '',
      args: [],
    );
  }

  /// `Product not found`
  String get productNotFound {
    return Intl.message(
      'Product not found',
      name: 'productNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Nothing is due now — played time will be debited from the balance at exit.`
  String get noPaymentNow {
    return Intl.message(
      'Nothing is due now — played time will be debited from the balance at exit.',
      name: 'noPaymentNow',
      desc: '',
      args: [],
    );
  }

  /// `Pay and print`
  String get paymentAndPrint {
    return Intl.message(
      'Pay and print',
      name: 'paymentAndPrint',
      desc: '',
      args: [],
    );
  }

  /// `Enter`
  String get enter {
    return Intl.message('Enter', name: 'enter', desc: '', args: []);
  }

  /// `Enter ({count})`
  String enterCount(int count) {
    return Intl.message(
      'Enter ($count)',
      name: 'enterCount',
      desc: '',
      args: [count],
    );
  }

  /// `{value} / day`
  String pricePerDay(String value) {
    return Intl.message(
      '$value / day',
      name: 'pricePerDay',
      desc: '',
      args: [value],
    );
  }

  /// `from {value} / min`
  String priceFromPerMinute(String value) {
    return Intl.message(
      'from $value / min',
      name: 'priceFromPerMinute',
      desc: '',
      args: [value],
    );
  }

  /// `Inside park`
  String get tabInside {
    return Intl.message('Inside park', name: 'tabInside', desc: '', args: []);
  }

  /// `Search by child, parent or phone`
  String get insideSearchHint {
    return Intl.message(
      'Search by child, parent or phone',
      name: 'insideSearchHint',
      desc: '',
      args: [],
    );
  }

  /// `Inside: {count}`
  String insideCount(int count) {
    return Intl.message(
      'Inside: $count',
      name: 'insideCount',
      desc: '',
      args: [count],
    );
  }

  /// `There are no children inside the park`
  String get insideEmpty {
    return Intl.message(
      'There are no children inside the park',
      name: 'insideEmpty',
      desc: '',
      args: [],
    );
  }

  /// `No child matches your search`
  String get insideSearchEmpty {
    return Intl.message(
      'No child matches your search',
      name: 'insideSearchEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Entered at`
  String get enteredAt {
    return Intl.message('Entered at', name: 'enteredAt', desc: '', args: []);
  }

  /// `Elapsed`
  String get elapsedTime {
    return Intl.message('Elapsed', name: 'elapsedTime', desc: '', args: []);
  }

  /// `{count} min`
  String minutesCount(int count) {
    return Intl.message(
      '$count min',
      name: 'minutesCount',
      desc: '',
      args: [count],
    );
  }

  /// `Current charge`
  String get accruedAmount {
    return Intl.message(
      'Current charge',
      name: 'accruedAmount',
      desc: '',
      args: [],
    );
  }

  /// `Mark as exited`
  String get markExited {
    return Intl.message(
      'Mark as exited',
      name: 'markExited',
      desc: '',
      args: [],
    );
  }

  /// `Lost QR code?`
  String get manualExitTitle {
    return Intl.message(
      'Lost QR code?',
      name: 'manualExitTitle',
      desc: '',
      args: [],
    );
  }

  /// `{child} will be marked as exited now. The visit will close at {amount} and be debited from the parent's balance. Continue?`
  String manualExitQuestion(String child, String amount) {
    return Intl.message(
      '$child will be marked as exited now. The visit will close at $amount and be debited from the parent\'s balance. Continue?',
      name: 'manualExitQuestion',
      desc: '',
      args: [child, amount],
    );
  }

  /// `The child was successfully marked as exited`
  String get manualExitSucceeded {
    return Intl.message(
      'The child was successfully marked as exited',
      name: 'manualExitSucceeded',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<AppLocalization> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'ru'),
      Locale.fromSubtags(languageCode: 'uz'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<AppLocalization> load(Locale locale) => AppLocalization.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
