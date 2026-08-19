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
