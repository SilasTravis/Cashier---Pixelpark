import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/core/update/release_source.dart';
import 'package:cashier_app/core/update/update_exception.dart';
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

Future<void> _pump(
  WidgetTester tester,
  UpdateState state, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalization.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalization.delegate.supportedLocales,
      locale: locale,
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

  testWidgets(
    'a known failure shows its localized reason and the manual download '
    'URL, never the raw developer message (I4)',
    (tester) async {
      // The dev message is deliberately different from the localized
      // en text below, so a passing test proves the card is mapping
      // `code` to an ARB string rather than just echoing `message`.
      await _pump(
        tester,
        const UpdateFailureKnown(
          UpdateFailureCode.checksumMismatch,
          'checksum 9f8e... != 1a2b... for v1.2.3.zip',
          'https://example.test/releases/tag/v1.2.3',
        ),
      );

      expect(
        find.textContaining('The downloaded file failed its checksum check'),
        findsOneWidget,
      );
      expect(find.textContaining('9f8e'), findsNothing);
      expect(find.textContaining('1a2b'), findsNothing);
      expect(
        find.text('https://example.test/releases/tag/v1.2.3'),
        findsOneWidget,
      );
    },
  );

  // --- localized failure text per code (I4) ---------------------------
  //
  // UpdateException carries a machine-readable UpdateFailureCode
  // precisely because the app is trilingual (Uzbek primary, Russian,
  // English) and UpdateException.message is English developer text.
  // These assert the card renders a fully localized sentence for every
  // code in the closed set, in every supported locale — a key missing in
  // one language is a runtime failure a cashier on that locale would hit,
  // so each locale is checked independently rather than just English.

  const releaseUrl = 'https://example.test/releases/tag/v1.2.3';

  testWidgets('checksumMismatch is localized (uz/ru/en)', (tester) async {
    for (final case_ in [
      (const Locale('uz'), 'tekshiruv summasi mos kelmadi'),
      (const Locale('ru'), 'контрольная сумма не совпала'),
      (const Locale('en'), 'failed its checksum check'),
    ]) {
      await _pump(
        tester,
        const UpdateFailureKnown(
          UpdateFailureCode.checksumMismatch,
          'dev detail',
          releaseUrl,
        ),
        locale: case_.$1,
      );
      expect(
        find.textContaining(case_.$2),
        findsOneWidget,
        reason: '${case_.$1}',
      );
    }
  });

  testWidgets('checksumUnreadable is localized (uz/ru/en)', (tester) async {
    for (final case_ in [
      (const Locale('uz'), 'tekshiruv summasini o‘qib bo‘lmadi'),
      (const Locale('ru'), 'прочитать опубликованную контрольную сумму'),
      (const Locale('en'), 'Could not read the published checksum'),
    ]) {
      await _pump(
        tester,
        const UpdateFailureKnown(
          UpdateFailureCode.checksumUnreadable,
          'dev detail',
          releaseUrl,
        ),
        locale: case_.$1,
      );
      expect(
        find.textContaining(case_.$2),
        findsOneWidget,
        reason: '${case_.$1}',
      );
    }
  });

  testWidgets('executableMissing is localized (uz/ru/en)', (tester) async {
    for (final case_ in [
      (const Locale('uz'), 'ilova dasturi topilmadi'),
      (const Locale('ru'), 'не найдена программа приложения'),
      (const Locale('en'), 'missing the app program'),
    ]) {
      await _pump(
        tester,
        const UpdateFailureKnown(
          UpdateFailureCode.executableMissing,
          'dev detail',
          releaseUrl,
        ),
        locale: case_.$1,
      );
      expect(
        find.textContaining(case_.$2),
        findsOneWidget,
        reason: '${case_.$1}',
      );
    }
  });

  testWidgets('incompleteExtraction is localized (uz/ru/en)', (tester) async {
    for (final case_ in [
      (const Locale('uz'), 'to‘liq yozilmadi'),
      (const Locale('ru'), 'распаковалось не полностью'),
      (const Locale('en'), 'did not unpack completely'),
    ]) {
      await _pump(
        tester,
        const UpdateFailureKnown(
          UpdateFailureCode.incompleteExtraction,
          'dev detail',
          releaseUrl,
        ),
        locale: case_.$1,
      );
      expect(
        find.textContaining(case_.$2),
        findsOneWidget,
        reason: '${case_.$1}',
      );
    }
  });

  testWidgets(
    'unsupportedPlatform reuses the existing Windows-only translation '
    '(uz/ru/en)',
    (tester) async {
      for (final case_ in [
        (const Locale('uz'), 'faqat Windows’da ishlaydi'),
        (const Locale('ru'), 'только в Windows'),
        (const Locale('en'), 'work on Windows only'),
      ]) {
        await _pump(
          tester,
          const UpdateFailureKnown(
            UpdateFailureCode.unsupportedPlatform,
            'dev detail',
            releaseUrl,
          ),
          locale: case_.$1,
        );
        expect(
          find.textContaining(case_.$2),
          findsOneWidget,
          reason: '${case_.$1}',
        );
      }
    },
  );

  testWidgets(
    'a code outside the closed set (other) falls back to the raw message',
    (tester) async {
      // No production throw site should ever use `other` for one of the
      // five real cases, but the fallback itself must still show
      // *something* rather than silently render nothing.
      await _pump(
        tester,
        const UpdateFailureKnown(
          UpdateFailureCode.other,
          'a message not in the closed set',
          releaseUrl,
        ),
      );

      expect(
        find.textContaining('a message not in the closed set'),
        findsOneWidget,
      );
    },
  );

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
