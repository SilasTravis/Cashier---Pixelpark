import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:cashier_app/core/local_source/app_keys.dart';
import 'package:cashier_app/core/local_source/local_source.dart';
import 'package:cashier_app/core/update/release_source.dart';
import 'package:cashier_app/core/update/update_exception.dart';
import 'package:cashier_app/core/update/update_failure_log.dart';
import 'package:cashier_app/core/update/update_release.dart';
import 'package:cashier_app/core/update/update_service.dart';
import 'package:cashier_app/features/settings/presentation/bloc/update_cubit.dart';

UpdateRelease _release(String version) => UpdateRelease(
  version: version,
  notes: 'notes',
  zipUrl: 'https://example.test/app.zip',
  zipSize: 10,
  sha256Url: null,
  releasePageUrl: 'https://example.test/releases/tag/v$version',
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

/// Only the three entry points the cubit calls; nothing touches the disk
/// or the network.
class _FakeService extends UpdateService {
  _FakeService(Directory support)
    : _support = support,
      super(
        source: _StubSource(),
        currentVersion: '1.0.6',
        supportDirectory: () async => support,
      );

  final Directory _support;
  Object? checkError;
  Object? downloadError;
  Object? restartError;

  @override
  Future<UpdateRelease?> check() async {
    if (checkError != null) throw checkError!;
    return null;
  }

  @override
  Future<Directory> downloadAndStage(
    UpdateRelease release, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (downloadError != null) throw downloadError!;
    return _support;
  }

  @override
  Future<Never> applyAndRestart(Directory staged) async =>
      throw restartError ?? StateError('restart');
}

void main() {
  late Directory temp;
  late LocalSource local;
  final at = DateTime.utc(2026, 9, 29, 12);

  UpdateFailureLog log({String currentVersion = '1.0.6'}) => UpdateFailureLog(
    localSource: local,
    currentVersion: currentVersion,
    clock: () => at,
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('update_failure_log_test');
    Hive.init(temp.path);
    local = LocalSource(await Hive.openBox<dynamic>('app_test'));
  });

  tearDown(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  group('terminal id', () {
    test('is a UUID v4 generated once and then kept', () {
      final first = local.getTerminalId();

      expect(
        first,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
            r'[0-9a-f]{12}$',
          ),
        ),
      );
      expect(local.getTerminalId(), first);
    });

    test('survives logout — it identifies the till, not the cashier', () async {
      local.setAccessToken('token');
      final id = local.getTerminalId();

      await local.clearSession();

      expect(local.getAccessToken(), isNull);
      expect(local.getTerminalId(), id);
    });
  });

  group('UpdateFailureLog', () {
    test('records an UpdateException by its code name', () async {
      await log().record(
        '1.0.7',
        const UpdateException('bad digest', UpdateFailureCode.checksumMismatch),
      );

      final record = log().current()!;
      expect(record.toJson(), {
        'version': '1.0.7',
        'code': 'checksumMismatch',
        'message': 'bad digest',
        'at': '2026-09-29T12:00:00.000Z',
      });
    });

    test('anything else is "unexpected", message truncated to 500', () async {
      await log().record('1.0.7', StateError('x' * 800));

      final record = log().current()!;
      expect(record.code, UpdateFailureLog.unexpectedCode);
      expect(record.message.length, UpdateFailureLog.maxMessageLength);
    });

    test('a non x.y.z version is never recorded — the backend would reject '
        'the whole heartbeat', () async {
      await log().record('1.1.0-rc1', StateError('x'));
      await log().record('2.0', StateError('x'));

      expect(log().current(), isNull);
    });

    test('a newer failure overwrites the older one', () async {
      await log().record('1.0.7', StateError('first'));
      await log().record('1.0.8', StateError('second'));

      expect(log().current()!.version, '1.0.8');
    });

    test('is cleared once the running version caught up', () async {
      await log().record('1.0.7', StateError('failed'));

      // Still on 1.0.6: relevant.
      expect(log().current(), isNotNull);
      // Now running 1.0.7 (a retry worked): dropped, and stays dropped.
      expect(log(currentVersion: '1.0.7').current(), isNull);
      expect(local.getLastUpdateFailure(), isNull);
      expect(log().current(), isNull);
    });

    test('a newer running version clears it too', () async {
      await log().record('1.0.7', StateError('failed'));

      expect(log(currentVersion: '1.1.0+9').current(), isNull);
    });

    test('a corrupt row reads as no failure and is removed', () {
      local.box.put(AppKeys.lastUpdateFailure, {'version': '1.0.7'});

      expect(log().current(), isNull);
      expect(local.getLastUpdateFailure(), isNull);
    });

    test('survives logout', () async {
      await log().record('1.0.7', StateError('failed'));

      await local.clearSession();

      expect(log().current(), isNotNull);
    });
  });

  group('UpdateCubit records failures', () {
    late Directory support;
    late _FakeService service;

    setUp(() {
      support = Directory.systemTemp.createTempSync('update_failure_cubit');
      service = _FakeService(support);
    });

    tearDown(() => support.deleteSync(recursive: true));

    test('a failed download is recorded with the release version', () async {
      service.downloadError = const UpdateException(
        'short',
        UpdateFailureCode.incompleteExtraction,
      );
      final cubit = UpdateCubit(service, failureLog: log());
      addTearDown(cubit.close);

      await cubit.download(_release('1.0.9'));

      expect(cubit.state, isA<UpdateFailureKnown>());
      final record = log().current()!;
      expect(record.version, '1.0.9');
      expect(record.code, 'incompleteExtraction');
    });

    test('a failed restart is recorded', () async {
      service.restartError = const UpdateException(
        'not windows',
        UpdateFailureCode.unsupportedPlatform,
      );
      final cubit = UpdateCubit(service, failureLog: log());
      addTearDown(cubit.close);

      await cubit.download(_release('1.0.9'));
      await cubit.restart();

      expect(log().current()!.code, 'unsupportedPlatform');
    });

    test('a failed check is not an update failure', () async {
      service.checkError = StateError('offline');
      final cubit = UpdateCubit(service, failureLog: log());
      addTearDown(cubit.close);

      await cubit.check();

      expect(cubit.state, isA<UpdateFailureUnexpected>());
      expect(log().current(), isNull);
    });
  });
}
