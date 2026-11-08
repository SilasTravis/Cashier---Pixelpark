// PNG renders of the birthday sale screens for design review.
//
//   SCREENSHOTS=1 SCREENSHOT_DIR=/some/dir \
//     flutter test test/screenshots --tags screenshot
//
// Skipped unless SCREENSHOTS=1. Loads real fonts (Roboto from the Flutter
// SDK, Material + Phosphor icon fonts from the font manifest) so the PNGs
// show real text instead of test boxes.
@Tags(['screenshot'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cashier_app/core/theme/app_theme_mode.dart';
import 'package:cashier_app/core/theme/pos_light_theme.dart';
import 'package:cashier_app/features/birthday_parties/data/birthday_parties_repository.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_party.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_plan.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_wallet.dart';
import 'package:cashier_app/features/birthday_parties/presentation/pages/birthday_events_page.dart';
import 'package:cashier_app/features/birthday_parties/presentation/widgets/add_payment_sheet.dart';
import 'package:cashier_app/features/birthday_parties/presentation/widgets/birthday_sell_dialog.dart';
import 'package:cashier_app/features/birthday_parties/presentation/widgets/event_detail_dialog.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/active_pass.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/kids_plan.dart';
import 'package:cashier_app/features/pos_account/domain/playing_child.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/customer_detail_panel.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/injector_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

final _enabled = Platform.environment['SCREENSHOTS'] == '1';
final _outDir = Platform.environment['SCREENSHOT_DIR'] ?? 'build/screenshots';
const _size = Size(1440, 900);

List<BirthdayPlan> _plans() {
  BirthdayPlan plan(
    String id,
    String name,
    String color,
    int order,
    List<int> prices,
    List<int> extras,
    List<String> items,
  ) => BirthdayPlan(
    id: id,
    name: name,
    color: color,
    active: true,
    allBranches: true,
    branchIds: const [],
    includedItems: items,
    sortOrder: order,
    sizes: [
      for (var i = 0; i < 3; i++)
        BirthdayPlanSize(
          childCount: 5 * (i + 1),
          priceUzs: prices[i],
          extraChildUzs: extras[i],
        ),
    ],
  );
  return [
    plan(
      'vip',
      'VIP',
      '#7C3AED',
      0,
      [1500000, 2500000, 3400000],
      [150000, 120000, 100000],
      const [
        '3 soat butun park',
        'Animator va shou dasturi',
        'Tort va sharlar',
        'Alohida bayram xonasi',
        'Fotosessiya',
        'Sovg‘a har bir bolaga',
      ],
    ),
    plan(
      'mid',
      'O‘rta',
      '#0891B2',
      1,
      [1000000, 1800000, 2500000],
      [120000, 100000, 90000],
      const ['2 soat o‘yin zonasi', 'Animator', 'Sharlar bilan bezak'],
    ),
    plan(
      'std',
      'Standart',
      '#64748B',
      2,
      [700000, 1200000, 1700000],
      [100000, 80000, 70000],
      const ['1,5 soat o‘yin zonasi', 'Bayram stoli'],
    ),
  ];
}

const _wallet = BirthdayWallet(
  balanceUzs: 900000,
  usableUzs: 600000,
  bonusUzs: 300000,
);

const _customer = Customer(
  id: 42,
  phoneNumber: '998901234567',
  firstName: 'Aziza',
  lastName: 'Karimova',
  balance: 900000,
  children: [],
);

Map<String, Object?> _partyJson() => {
  'id': 'p1',
  'status': 'booked',
  'paymentState': 'partial',
  'branchId': 'b1',
  'branchName': 'Megaplanet',
  'customer': {
    'id': 42,
    'fullName': 'Aziza Karimova',
    'phoneNumber': '998901234567',
  },
  'plan': {
    'id': 'vip',
    'name': 'VIP',
    'color': '#7C3AED',
    'includedItems': ['3 soat butun park'],
  },
  'childCount': 10,
  'extraChildren': 2,
  'packagePriceUzs': 2500000,
  'extraChildUzs': 120000,
  'listPriceUzs': 2740000,
  'agreedPriceUzs': 2740000,
  'discountUzs': 0,
  'paidUzs': 200000,
  'refundedUzs': 0,
  'debtUzs': 2540000,
  'keptUzs': 0,
  'maxCashRefundUzs': 200000,
  'partyDate': '2026-11-14',
  'soldBy': {'id': 's1', 'username': 'dilnoza'},
  'createdAt': '2026-11-07T10:00:00.000Z',
  'completedAt': null,
  'cancelledAt': null,
  'cancelReason': null,
  'payments': [],
  'comments': [],
};

BirthdayParty _party() => BirthdayParty.fromJson(_partyJson());

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A party like [_party] with the fields a list card shows overridden.
BirthdayParty _partyLike({
  required String id,
  required String name,
  required String phone,
  required String planId,
  required String planName,
  required String color,
  required int childCount,
  required int extra,
  required int price,
  required int paid,
  required DateTime date,
  List<Map<String, Object?>> payments = const [],
  List<Map<String, Object?>> comments = const [],
}) {
  final json = Map<String, Object?>.from(_partyJson());
  final debt = price - paid;
  return BirthdayParty.fromJson({
    ...json,
    'id': id,
    'paymentState': paid == 0 ? 'unpaid' : (debt <= 0 ? 'paid' : 'partial'),
    'customer': {'id': 42, 'fullName': name, 'phoneNumber': phone},
    'plan': {
      'id': planId,
      'name': planName,
      'color': color,
      'includedItems': _plans().firstWhere((p) => p.id == planId).includedItems,
    },
    'childCount': childCount,
    'extraChildren': extra,
    'listPriceUzs': price,
    'agreedPriceUzs': price,
    'paidUzs': paid,
    'debtUzs': debt < 0 ? 0 : debt,
    'maxCashRefundUzs': paid,
    'partyDate': _ymd(date),
    'payments': payments,
    'comments': comments,
  });
}

List<BirthdayParty> _upcoming() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return [
    _partyLike(
      id: 'p-today',
      name: 'Madina Yusupova',
      phone: '998935551122',
      planId: 'mid',
      planName: 'O‘rta',
      color: '#0891B2',
      childCount: 10,
      extra: 0,
      price: 1800000,
      paid: 1800000,
      date: today,
      comments: [
        {
          'id': 'c0',
          'text': 'Tort o‘zlari olib kelishadi',
          'author': 'dilnoza',
          'createdAt': '2026-11-07T10:05:00.000Z',
        },
      ],
    ),
    _partyLike(
      id: 'p-tomorrow',
      name: 'Aziza Karimova',
      phone: '998901234567',
      planId: 'vip',
      planName: 'VIP',
      color: '#7C3AED',
      childCount: 10,
      extra: 2,
      price: 2740000,
      paid: 200000,
      date: today.add(const Duration(days: 1)),
    ),
    _partyLike(
      id: 'p-week',
      name: 'Jasur Rahimov',
      phone: '998977003344',
      planId: 'std',
      planName: 'Standart',
      color: '#64748B',
      childCount: 5,
      extra: 1,
      price: 800000,
      paid: 0,
      date: today.add(const Duration(days: 4)),
    ),
    _partyLike(
      id: 'p-next',
      name: 'Nilufar Tosheva',
      phone: '998909998877',
      planId: 'vip',
      planName: 'VIP',
      color: '#7C3AED',
      childCount: 15,
      extra: 0,
      price: 3400000,
      paid: 1000000,
      date: today.add(const Duration(days: 9)),
    ),
  ];
}

BirthdayParty _detailParty() {
  final now = DateTime.now();
  return _partyLike(
    id: 'p-tomorrow',
    name: 'Aziza Karimova',
    phone: '998901234567',
    planId: 'vip',
    planName: 'VIP',
    color: '#7C3AED',
    childCount: 10,
    extra: 2,
    price: 2740000,
    paid: 700000,
    date: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
    payments: [
      {
        'id': 'pay1',
        'kind': 'payment',
        'amountUzs': 200000,
        'fromBalanceUzs': 0,
        'cashUzs': 200000,
        'cardUzs': 0,
        'refundTo': null,
        'requestId': 'r1',
        'cashier': {'id': 's1', 'username': 'dilnoza'},
        'createdAt': '2026-11-07T10:00:00.000Z',
      },
      {
        'id': 'pay2',
        'kind': 'payment',
        'amountUzs': 500000,
        'fromBalanceUzs': 300000,
        'cashUzs': 0,
        'cardUzs': 200000,
        'refundTo': null,
        'requestId': 'r2',
        'cashier': {'id': 's2', 'username': 'malika'},
        'createdAt': '2026-11-08T15:30:00.000Z',
      },
    ],
    comments: [
      {
        'id': 'c1',
        'text': 'Animatorsiz, faqat qo‘shiqlar',
        'author': 'dilnoza',
        'createdAt': '2026-11-07T10:02:00.000Z',
      },
      {
        'id': 'c2',
        'text': "+1 bola qo'shildi: 1 → 2",
        'author': 'malika',
        'createdAt': '2026-11-08T15:31:00.000Z',
      },
    ],
  );
}

class _Repo implements BirthdayPartiesRepository {
  @override
  Future<List<BirthdayPlan>> plans() async => _plans();

  @override
  Future<List<BirthdayParty>> list(BirthdayPartyStatus status) async =>
      status == BirthdayPartyStatus.booked ? _upcoming() : const [];

  @override
  Future<BirthdayParty> get(String id) async => _detailParty();

  @override
  Future<BirthdayWallet> wallet(int customerId) async => _wallet;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Remote implements PosAccountRemoteDataSource {
  @override
  Future<List<KidsPlan>> listPlans() async => [];

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async => [];

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final dir = Directory('$root/bin/cache/artifacts/material_fonts');
    // 'Roboto' is the theme's text family on the test platform (Segoe UI on
    // Windows).
    for (final family in ['Roboto']) {
      final loader = FontLoader(family);
      for (final f in dir.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (name.startsWith('Roboto-') && name.endsWith('.ttf')) {
          final bytes = f.readAsBytesSync();
          loader.addFont(Future.value(ByteData.sublistView(bytes)));
        }
      }
      await loader.load();
    }
  }
  // Symbols the test fonts lack (✓ 🔒 →): on Windows Segoe UI has them.
  const symbols = '/System/Library/Fonts/Supplemental/Arial Unicode.ttf';
  if (File(symbols).existsSync()) {
    final loader = FontLoader('ShotSymbols')
      ..addFont(
        Future.value(ByteData.sublistView(File(symbols).readAsBytesSync())),
      );
    await loader.load();
  }
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

final _boundary = GlobalKey();

/// The app theme, with the one label style that names no font family (the
/// themed FilledButton text) pointed at Roboto — the test engine's fallback
/// font draws boxes; on Windows it is Segoe UI.
ThemeData _theme(bool dark) {
  final base = dark ? posDarkTheme : posLightTheme;
  final style = base.filledButtonTheme.style!;
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: const ['ShotSymbols']),
    primaryTextTheme: base.primaryTextTheme.apply(
      fontFamilyFallback: const ['ShotSymbols'],
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: style.copyWith(
        textStyle: WidgetStatePropertyAll(
          style.textStyle!
              .resolve({})!
              .copyWith(
                fontFamily: 'Roboto',
                fontFamilyFallback: const ['ShotSymbols'],
              ),
        ),
      ),
    ),
  );
}

Widget _app({required bool dark, required Widget home}) => RepaintBoundary(
  key: _boundary,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _theme(dark),
    locale: const Locale('uz'),
    localizationsDelegates: const [
      AppLocalization.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalization.delegate.supportedLocales,
    home: home,
    // Explicit TextStyles inherit the symbols fallback from here.
    builder: (context, child) => DefaultTextStyle.merge(
      style: const TextStyle(fontFamilyFallback: ['ShotSymbols']),
      child: child!,
    ),
  ),
);

Future<void> _shoot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outDir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _setUp(WidgetTester tester, {bool dark = false}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  AppThemeMode.notifier.value = dark;
  addTearDown(() => AppThemeMode.notifier.value = false);
  if (!sl.isRegistered<BirthdayPartiesRepository>()) {
    sl.registerSingleton<BirthdayPartiesRepository>(_Repo());
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _sellScreen(
  WidgetTester tester, {
  required bool dark,
  Size? size,
}) async {
  await _setUp(tester, dark: dark);
  if (size != null) tester.view.physicalSize = size;
  await tester.pumpWidget(
    _app(
      dark: dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('open'),
              onPressed: () => showBirthdaySellDialog(
                context,
                customer: _customer,
                // A Saturday, so "+7 kun" lands on Saturday 14 November.
                today: DateTime(2026, 11, 7),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
  await _tap(tester, 'birthday-tier-vip');
  await _tap(tester, 'birthday-size-10');
  await _tap(tester, 'birthday-extra-plus');
  await _tap(tester, 'birthday-extra-plus');
  await _tap(tester, 'birthday-date-7');
  await _tap(tester, 'birthday-mode-deposit');
  await _tap(tester, 'birthday-deposit-chip-200000');
  // Back to the top of both columns for the shot.
  for (final s in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
    s.position.jumpTo(0);
  }
}

void main() {
  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });
  tearDown(() async => sl.reset());

  testWidgets('a: account panel with Xizmatlar', skip: !_enabled, (
    tester,
  ) async {
    await _setUp(tester);
    final bloc = PosAccountBloc(PosAccountRepository(_Remote()))
      ..add(const PosAccountCustomerSelected(_customer));
    addTearDown(bloc.close);
    await tester.pumpWidget(
      _app(
        dark: false,
        home: BlocProvider.value(
          value: bloc,
          child: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: CustomerDetailPanel(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('services-section')));
    await _shoot(tester, 'a_account_services');
  });

  testWidgets('b: sell screen, light', skip: !_enabled, (tester) async {
    await _sellScreen(tester, dark: false);
    await _shoot(tester, 'b_sell_light');
  });

  testWidgets('c: sell screen, night', skip: !_enabled, (tester) async {
    await _sellScreen(tester, dark: true);
    await _shoot(tester, 'c_sell_night');
  });

  testWidgets('e: sell screen, narrow window (one column)', skip: !_enabled, (
    tester,
  ) async {
    await _sellScreen(tester, dark: false, size: const Size(1024, 768));
    await _shoot(tester, 'e_sell_narrow');
  });

  testWidgets('d: add-payment sheet', skip: !_enabled, (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(
      _app(
        dark: false,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open'),
                onPressed: () => showAddPaymentSheet(context, _party()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await _shoot(tester, 'd_add_payment');
  });

  testWidgets('f: Tadbirlar tab', skip: !_enabled, (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(
      _app(dark: false, home: const Scaffold(body: BirthdayEventsPage())),
    );
    await tester.pumpAndSettle();
    await _shoot(tester, 'f_events');
  });

  testWidgets('g: event detail', skip: !_enabled, (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(
      _app(
        dark: false,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open'),
                onPressed: () => showEventDetailDialog(context, _detailParty()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    await _shoot(tester, 'g_event_detail');
  });
}
