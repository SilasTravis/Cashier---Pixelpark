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
import 'package:cashier_app/features/birthday_parties/presentation/widgets/add_payment_sheet.dart';
import 'package:cashier_app/features/birthday_parties/presentation/widgets/birthday_sell_dialog.dart';
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

BirthdayParty _party() => BirthdayParty.fromJson({
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
});

class _Repo implements BirthdayPartiesRepository {
  @override
  Future<List<BirthdayPlan>> plans() async => _plans();

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
    filledButtonTheme: FilledButtonThemeData(
      style: style.copyWith(
        textStyle: WidgetStatePropertyAll(
          style.textStyle!.resolve({})!.copyWith(fontFamily: 'Roboto'),
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
}
