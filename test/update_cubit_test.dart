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
///
/// Each entry point can optionally be gated on a [Completer] so a test can
/// pause it mid-flight (e.g. to close the cubit while the call is still
/// pending) and then release it deterministically instead of racing a real
/// async gap.
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
  Object? restartError;
  List<int> progressSteps = const [];

  /// When set, [check] suspends until this completes before resolving.
  Completer<void>? checkGate;

  /// When set, [downloadAndStage] suspends until this completes before
  /// resolving (after delivering any [progressSteps]).
  Completer<void>? downloadGate;

  /// When set, [applyAndRestart] suspends until this completes before
  /// resolving.
  Completer<void>? restartGate;

  @override
  Future<UpdateRelease?> check() async {
    final gate = checkGate;
    if (gate != null) await gate.future;
    final error = checkError;
    if (error != null) throw error;
    return checkResult;
  }

  @override
  Future<Directory> downloadAndStage(
    UpdateRelease release, {
    void Function(int received, int total)? onProgress,
  }) async {
    for (final received in progressSteps) {
      onProgress?.call(received, 100);
    }
    final gate = downloadGate;
    if (gate != null) await gate.future;
    final error = downloadError;
    if (error != null) throw error;
    return _support;
  }

  /// Not overridden means the real [UpdateService.applyAndRestart] runs,
  /// which throws `UpdateException('Self-update is only supported on
  /// Windows')` on any non-Windows test runner — that's what the
  /// Windows-guarded integration test below exercises. Setting
  /// [restartError] lets other tests inject an arbitrary error (including a
  /// non-[UpdateException]) without depending on the host platform.
  @override
  Future<Never> applyAndRestart(Directory staged) async {
    final gate = restartGate;
    if (gate != null) await gate.future;
    final error = restartError;
    if (error != null) throw error;
    return super.applyAndRestart(staged);
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

    expect(cubit.state, isA<UpdateFailureKnown>());
    expect((cubit.state as UpdateFailureKnown).message, contains('no network'));
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

    expect(cubit.state, isA<UpdateFailureKnown>());
    final failure = cubit.state as UpdateFailureKnown;
    expect(failure.message, contains('checksum mismatch'));
    expect(failure.releasePageUrl, 'https://example.test/releases/tag/v1.2.3');
  });

  // --- Error-presentation contract (Task 6) ---
  //
  // UpdateFailure is sealed with two subclasses. UpdateException messages
  // are already written to be shown to a cashier (see update_exception.dart),
  // so they pass straight through as UpdateFailureKnown.message. Anything
  // else — most realistically a DioException from an offline or blocked POS
  // machine — becomes UpdateFailureUnexpected, which carries no displayable
  // message at all: only debugDetail, for logs/diagnosis, never for display.
  // The next task renders UpdateFailureKnown.message directly and
  // substitutes its own localized generic string for UpdateFailureUnexpected
  // via an exhaustive switch over the sealed UpdateState hierarchy.

  test(
    'an UpdateException from check is a known failure shown as-is',
    () async {
      service.checkError = const UpdateException('no network');
      final cubit = UpdateCubit(service);

      await cubit.check();

      final failure = cubit.state as UpdateFailureKnown;
      expect(failure.message, 'no network');
    },
  );

  test('a non-UpdateException from check never leaks its raw text into a '
      'displayable message', () async {
    service.checkError = Exception(
      'DioException [connection error]: Failed host lookup',
    );
    final cubit = UpdateCubit(service);

    await cubit.check();

    // The failure is UpdateFailureUnexpected, not UpdateFailureKnown — it
    // structurally has no `message` field for the raw text to leak into.
    final failure = cubit.state as UpdateFailureUnexpected;
    expect(failure.debugDetail, contains('Failed host lookup'));
  });

  test('a non-UpdateException from download never leaks its raw text into a '
      'displayable message, and still carries the release page url', () async {
    service.downloadError = Exception('Failed host lookup: api.github.com');
    final cubit = UpdateCubit(service);

    await cubit.download(_release());

    final failure = cubit.state as UpdateFailureUnexpected;
    expect(failure.debugDetail, contains('Failed host lookup'));
    expect(failure.releasePageUrl, 'https://example.test/releases/tag/v1.2.3');
  });

  test('a non-UpdateException from restart never leaks its raw text into a '
      'displayable message, and still carries the release page url', () async {
    service.progressSteps = const [100];
    service.restartError = Exception('Failed host lookup: api.github.com');
    final cubit = UpdateCubit(service);
    await cubit.download(_release());
    expect(cubit.state, isA<UpdateReadyToRestart>());

    await cubit.restart();

    // This is what actually distinguishes centralized failure-mapping
    // (error is UpdateException ? ... : ...) from the older naive
    // `emit(UpdateFailure('$error', ...))` style: for a known
    // UpdateException the two are observably identical, because
    // UpdateException.toString() returns its message verbatim. Only a
    // non-UpdateException error tells them apart — naive interpolation
    // would put this technical string in a displayable message field;
    // centralized mapping routes it to UpdateFailureUnexpected instead,
    // which has no such field.
    final failure = cubit.state as UpdateFailureUnexpected;
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

      // UpdateService.applyAndRestart isn't overridden with a restartError
      // here, so calling restart() drives the real implementation, which
      // throws UpdateException('Self-update is only supported on Windows')
      // on any non-Windows test runner.
      await cubit.restart();

      final failure = cubit.state as UpdateFailureKnown;
      expect(failure.message, 'Self-update is only supported on Windows');
      expect(
        failure.releasePageUrl,
        'https://example.test/releases/tag/v1.2.3',
      );
    },
    testOn: '!windows',
  );

  // --- Emit-after-close safety (Task 6 finding 2) ---
  //
  // bloc's `emit` throws a StateError once the cubit is closed. If the
  // cashier navigates away from Settings while a check/download/restart is
  // still in flight, the cubit closes and the in-flight call eventually
  // resolves — its terminal `emit` must not throw. Each test below starts
  // the operation, blocks it on a gate, closes the cubit, then releases the
  // gate and asserts the operation's Future completes without an unhandled
  // error. Using an explicit Completer as the gate (rather than a real I/O
  // delay) makes the ordering — start, close, then resolve — deterministic.

  test(
    'closing while a check is in flight does not throw on success',
    () async {
      final gate = Completer<void>();
      service.checkGate = gate;
      service.checkResult = _release();
      final cubit = UpdateCubit(service);

      final future = cubit.check();
      await cubit.close();
      gate.complete();

      await expectLater(future, completes);
    },
  );

  test(
    'closing while a check is in flight does not throw on failure',
    () async {
      final gate = Completer<void>();
      service.checkGate = gate;
      service.checkError = const UpdateException('no network');
      final cubit = UpdateCubit(service);

      final future = cubit.check();
      await cubit.close();
      gate.complete();

      await expectLater(future, completes);
    },
  );

  test(
    'closing while a download is in flight does not throw on success',
    () async {
      final gate = Completer<void>();
      service.downloadGate = gate;
      final cubit = UpdateCubit(service);

      final future = cubit.download(_release());
      await cubit.close();
      gate.complete();

      await expectLater(future, completes);
    },
  );

  test(
    'closing while a download is in flight does not throw on failure',
    () async {
      final gate = Completer<void>();
      service.downloadGate = gate;
      service.downloadError = const UpdateException('checksum mismatch');
      final cubit = UpdateCubit(service);

      final future = cubit.download(_release());
      await cubit.close();
      gate.complete();

      await expectLater(future, completes);
    },
  );

  test(
    'closing while a restart is in flight does not throw on failure',
    () async {
      final gate = Completer<void>();
      service.progressSteps = const [100];
      final cubit = UpdateCubit(service);
      await cubit.download(_release());
      expect(cubit.state, isA<UpdateReadyToRestart>());

      service.restartGate = gate;
      service.restartError = const UpdateException(
        'Self-update is only '
        'supported on Windows',
      );

      final future = cubit.restart();
      await cubit.close();
      gate.complete();

      await expectLater(future, completes);
    },
  );
}
