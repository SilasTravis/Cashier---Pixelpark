import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/update/release_source.dart';
import 'package:cashier_app/core/update/update_exception.dart';
import 'package:cashier_app/core/update/update_release.dart';
import 'package:cashier_app/core/update/update_service.dart';
import 'package:cashier_app/features/settings/presentation/bloc/update_cubit.dart';

UpdateRelease _release() => const UpdateRelease(
  version: '1.2.3',
  notes: 'notes',
  zipUrl: 'https://example.test/app.zip',
  zipSize: 10,
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

/// Overrides the service's three entry points; the cubit only ever calls
/// these, so nothing touches the network or the disk.
class _FakeService extends UpdateService {
  _FakeService({required Directory support})
    : _support = support,
      super(
        source: _StubSource(),
        currentVersion: '1.0.0',
        supportDirectory: () async => support,
      );

  final Directory _support;
  UpdateRelease? checkResult;
  Object? checkError;
  Object? downloadError;
  List<int> progressSteps = const [];

  @override
  Future<UpdateRelease?> check() async {
    final error = checkError;
    if (error != null) throw error;
    return checkResult;
  }

  @override
  Future<Directory> downloadAndStage(
    UpdateRelease release, {
    void Function(int received, int total)? onProgress,
  }) async {
    final error = downloadError;
    if (error != null) throw error;
    for (final received in progressSteps) {
      onProgress?.call(received, 100);
    }
    return _support;
  }
}

void main() {
  late Directory support;
  late _FakeService service;

  setUp(() {
    support = Directory.systemTemp.createTempSync('update_cubit_test');
    service = _FakeService(support: support);
  });

  tearDown(() => support.deleteSync(recursive: true));

  test('starts idle and exposes the running version', () {
    final cubit = UpdateCubit(service);

    expect(cubit.state, isA<UpdateIdle>());
    expect(cubit.currentVersion, '1.0.0');
  });

  test('check moves through checking to available', () async {
    service.checkResult = _release();
    final cubit = UpdateCubit(service);
    final seen = <UpdateState>[];
    cubit.stream.listen(seen.add);

    await cubit.check();

    expect(seen.first, isA<UpdateChecking>());
    expect(cubit.state, isA<UpdateAvailable>());
    expect((cubit.state as UpdateAvailable).release.version, '1.2.3');
  });

  test('check reports up to date when there is nothing newer', () async {
    final cubit = UpdateCubit(service);

    await cubit.check();

    expect(cubit.state, isA<UpdateUpToDate>());
  });

  test('a failed check surfaces the reason', () async {
    service.checkError = const UpdateException('no network');
    final cubit = UpdateCubit(service);

    await cubit.check();

    expect(cubit.state, isA<UpdateFailure>());
    expect((cubit.state as UpdateFailure).message, contains('no network'));
  });

  test('download reports progress then readiness', () async {
    service.progressSteps = const [40, 100];
    final cubit = UpdateCubit(service);
    final seen = <UpdateState>[];
    // Cubit's stream is a plain (non-sync) broadcast StreamController, so
    // events emitted back-to-back without an intervening await — as the
    // progress callbacks are here — aren't guaranteed to have reached this
    // listener by the time `await cubit.download(...)` returns; only the
    // very first emission is. Waiting on a completer that fires once the
    // *stream* (not just the cubit's synchronous state) has delivered the
    // terminal state makes the assertion below deterministic.
    final delivered = Completer<void>();
    final subscription = cubit.stream.listen((state) {
      seen.add(state);
      if (state is UpdateReadyToRestart) delivered.complete();
    });

    await cubit.download(_release());
    await delivered.future;
    await subscription.cancel();

    final progress = seen.whereType<UpdateDownloading>().toList();
    expect(progress.map((s) => s.received), containsAllInOrder(<int>[40, 100]));
    expect(cubit.state, isA<UpdateReadyToRestart>());
    expect((cubit.state as UpdateReadyToRestart).staged.path, support.path);
  });

  test('a failed download surfaces the reason and the release page', () async {
    service.downloadError = const UpdateException('checksum mismatch');
    final cubit = UpdateCubit(service);

    await cubit.download(_release());

    expect(cubit.state, isA<UpdateFailure>());
    final failure = cubit.state as UpdateFailure;
    expect(failure.message, contains('checksum mismatch'));
    expect(failure.releasePageUrl, 'https://example.test/releases/tag/v1.2.3');
  });

  // --- Error-presentation contract (Task 6 addendum) ---
  //
  // UpdateException messages are already written to be shown to a cashier
  // (see update_exception.dart), so they pass straight through as `message`
  // with `kind: known`. Anything else — most realistically a DioException
  // from an offline or blocked POS machine — must never be interpolated
  // into `message` verbatim: it's marked `kind: unexpected` and its raw
  // text is only available via `debugDetail`, for logs/diagnosis, never for
  // display. Task 7 is expected to render `message` when `kind` is `known`
  // and substitute its own localized generic string otherwise.

  test(
    'an UpdateException from check is a known failure shown as-is',
    () async {
      service.checkError = const UpdateException('no network');
      final cubit = UpdateCubit(service);

      await cubit.check();

      final failure = cubit.state as UpdateFailure;
      expect(failure.kind, UpdateFailureKind.known);
      expect(failure.message, 'no network');
    },
  );

  test(
    'a non-UpdateException from check never leaks its raw text into message',
    () async {
      service.checkError = Exception(
        'DioException [connection error]: Failed host lookup',
      );
      final cubit = UpdateCubit(service);

      await cubit.check();

      final failure = cubit.state as UpdateFailure;
      expect(failure.kind, UpdateFailureKind.unexpected);
      expect(failure.message, isNot(contains('DioException')));
      expect(failure.message, isNot(contains('Failed host lookup')));
      expect(failure.debugDetail, contains('Failed host lookup'));
    },
  );

  test('a non-UpdateException from download never leaks its raw text into '
      'message, and still carries the release page url', () async {
    service.downloadError = Exception('Failed host lookup: api.github.com');
    final cubit = UpdateCubit(service);

    await cubit.download(_release());

    final failure = cubit.state as UpdateFailure;
    expect(failure.kind, UpdateFailureKind.unexpected);
    expect(failure.message, isNot(contains('Failed host lookup')));
    expect(failure.debugDetail, contains('Failed host lookup'));
    expect(failure.releasePageUrl, 'https://example.test/releases/tag/v1.2.3');
  });

  test(
    'restart failure is presented the same way as check/download',
    () async {
      service.progressSteps = const [100];
      final cubit = UpdateCubit(service);
      await cubit.download(_release());
      expect(cubit.state, isA<UpdateReadyToRestart>());

      // UpdateService.applyAndRestart isn't overridden by _FakeService, so
      // calling restart() drives the real implementation, which throws
      // UpdateException('Self-update is only supported on Windows') on any
      // non-Windows test runner.
      await cubit.restart();

      expect(cubit.state, isA<UpdateFailure>());
      final failure = cubit.state as UpdateFailure;
      expect(failure.kind, UpdateFailureKind.known);
      expect(failure.message, contains('Windows'));
    },
    testOn: '!windows',
  );
}
