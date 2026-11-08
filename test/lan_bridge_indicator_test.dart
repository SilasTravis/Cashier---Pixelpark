import 'dart:async';

import 'package:cashier_app/core/lan_bridge/lan_bridge_state.dart';
import 'package:cashier_app/core/lan_bridge/widgets/lan_bridge_indicator.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _active = 'Masofaviy sessiya faol';

void main() {
  Future<StreamController<LanBridgeState>> pump(
    WidgetTester tester, {
    LanBridgeState initial = const LanBridgeState(),
  }) async {
    // Created inside the test body so events flow through FakeAsync.
    final states = StreamController<LanBridgeState>.broadcast();
    addTearDown(states.close);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalization.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalization.delegate.supportedLocales,
        locale: const Locale('uz'),
        home: Scaffold(
          body: LanBridgeIndicator(
            states: states.stream,
            current: () => initial,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Localizations finished loading, so the StreamBuilder is subscribed.
    expect(find.byType(LanBridgeIndicator), findsOneWidget);
    return states;
  }

  // The stream event lands in a microtask after the first frame; the second
  // pump renders the StreamBuilder's rebuild.
  Future<void> emit(
    WidgetTester tester,
    StreamController<LanBridgeState> states,
    LanBridgeState state,
  ) async {
    states.add(state);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('hidden while no session is active', (tester) async {
    final states = await pump(
      tester,
      initial: const LanBridgeState(control: ControlStatus.connected),
    );
    expect(find.text(_active), findsNothing);

    await emit(
      tester,
      states,
      const LanBridgeState(control: ControlStatus.connecting),
    );
    expect(find.text(_active), findsNothing);
  });

  testWidgets('shows the uz text once a session starts, hides when it ends', (
    tester,
  ) async {
    final states = await pump(tester);
    expect(find.text(_active), findsNothing);

    const idle = LanBridgeState(control: ControlStatus.connected);
    await emit(
      tester,
      states,
      idle.withSession('sess-1', DateTime(2026, 11, 8, 14, 5)),
    );
    expect(find.text(_active), findsOneWidget);
    expect(find.byType(Tooltip), findsOneWidget);

    // Let the pulse tick a few times.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(_active), findsOneWidget);

    await emit(tester, states, idle);
    expect(find.text(_active), findsNothing);
  });

  testWidgets('shown from the current state without any stream event', (
    tester,
  ) async {
    final states = StreamController<LanBridgeState>.broadcast();
    addTearDown(states.close);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalization.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalization.delegate.supportedLocales,
        locale: const Locale('uz'),
        home: Scaffold(
          body: LanBridgeIndicator(
            states: states.stream,
            current: () => const LanBridgeState().withSession(
              'sess-2',
              DateTime(2026, 11, 8, 9, 30),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(_active), findsOneWidget);

    // Unmount so the pulse timer is cancelled before the test ends.
    await tester.pumpWidget(const SizedBox());
  });
}
