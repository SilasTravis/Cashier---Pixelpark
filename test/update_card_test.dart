import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/core/update/release_source.dart';
import 'package:cashier_app/core/update/update_release.dart';
import 'package:cashier_app/core/update/update_service.dart';
import 'package:cashier_app/features/settings/presentation/bloc/update_cubit.dart';
import 'package:cashier_app/features/settings/presentation/widgets/update_card.dart';

UpdateRelease _release() => const UpdateRelease(
  version: '1.2.3',
  notes: 'Faster receipts',
  zipUrl: 'https://example.test/app.zip',
  zipSize: 100,
  sha256Url: null,
  releasePageUrl: 'https://example.test/releases/tag/v1.2.3',
);

class _StubSource implements ReleaseSource {
  @override
  Future<UpdateRelease?> fetchLatest() async => null;
  @override
  Future<String?> fetchSha256(UpdateRelease release) async => null;
  @override
  Future<void> downloadZip(
    UpdateRelease release,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async {}
}

/// Holds whatever state the test wants to render.
class _StaticCubit extends UpdateCubit {
  _StaticCubit(UpdateState initial)
    : super(
        UpdateService(
          source: _StubSource(),
          currentVersion: '1.0.0',
          supportDirectory: () async => Directory.systemTemp,
        ),
      ) {
    emit(initial);
  }
}

Future<void> _pump(WidgetTester tester, UpdateState state) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalization.delegate],
      supportedLocales: AppLocalization.delegate.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: BlocProvider<UpdateCubit>(
          create: (_) => _StaticCubit(state),
          child: const UpdateCard(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('idle shows the current version and a check button', (
    tester,
  ) async {
    await _pump(tester, const UpdateIdle());

    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);
  });

  testWidgets('available shows the version, notes and install button', (
    tester,
  ) async {
    await _pump(tester, UpdateAvailable(_release()));

    expect(find.text('New version available: 1.2.3'), findsOneWidget);
    expect(find.text('Faster receipts'), findsOneWidget);
    expect(find.text('Download & install'), findsOneWidget);
  });

  testWidgets('downloading shows a determinate progress bar', (tester) async {
    await _pump(tester, UpdateDownloading(_release(), 50, 100));

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.5, 0.001));
  });

  testWidgets('ready shows the restart button', (tester) async {
    await _pump(tester, UpdateReadyToRestart(_release(), Directory.systemTemp));

    expect(find.text('Update ready'), findsOneWidget);
    expect(find.text('Restart now'), findsOneWidget);
  });

  testWidgets('a known failure shows its reason and the manual download URL', (
    tester,
  ) async {
    await _pump(
      tester,
      const UpdateFailureKnown(
        'Downloaded file failed its checksum check',
        'https://example.test/releases/tag/v1.2.3',
      ),
    );

    expect(
      find.textContaining('Downloaded file failed its checksum check'),
      findsOneWidget,
    );
    expect(
      find.text('https://example.test/releases/tag/v1.2.3'),
      findsOneWidget,
    );
  });

  testWidgets('an unexpected failure shows localized text, never raw detail', (
    tester,
  ) async {
    // The cubit hands the UI only diagnostics for this branch precisely so a
    // raw DioException string can never reach a cashier.
    await _pump(
      tester,
      const UpdateFailureUnexpected(
        "DioException [connection error]: Failed host lookup: 'api.github.com'",
        'https://example.test/releases/tag/v1.2.3',
      ),
    );

    expect(
      find.text('Update failed. Check the internet connection and try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('DioException'), findsNothing);
    expect(find.textContaining('host lookup'), findsNothing);
    expect(
      find.text('https://example.test/releases/tag/v1.2.3'),
      findsOneWidget,
    );
  });

  testWidgets('restart asks for confirmation before applying', (tester) async {
    await _pump(tester, UpdateReadyToRestart(_release(), Directory.systemTemp));

    await tester.tap(find.text('Restart now'));
    await tester.pumpAndSettle();

    expect(find.text('Update the app'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Update the app'), findsNothing);
  });
}
