import 'dart:async';
import 'dart:io';

import 'package:cashier_app/core/printing/direct_print_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Process> worker(String posix, String windows) => Platform.isWindows
      ? Process.start('powershell.exe', ['-NoProfile', '-Command', windows])
      : Process.start('/bin/sh', ['-c', posix]);

  test('reports the status of a worker after sending the whole job', () async {
    final success = await worker(
      r'read -r data; test "$data" = job',
      r'if ([Console]::In.ReadToEnd() -eq "job") { exit 0 }; exit 1',
    );
    expect(await DirectPrintJob.finishWorker(success, 'job'), isTrue);

    final failed = await worker(
      'cat >/dev/null; exit 1',
      '[void][Console]::In.ReadToEnd(); exit 1',
    );
    expect(await DirectPrintJob.finishWorker(failed, 'job'), isFalse);
  });

  test('terminates an unresponsive worker and accepts the next job', () async {
    final stuck = await worker('exec sleep 120', 'Start-Sleep -Seconds 120');
    await expectLater(
      DirectPrintJob.finishWorker(
        stuck,
        'job',
        deadline: const Duration(milliseconds: 150),
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(await stuck.exitCode.timeout(const Duration(seconds: 3)), isNot(0));
    final next = await worker(
      'cat >/dev/null',
      '[void][Console]::In.ReadToEnd()',
    );
    expect(await DirectPrintJob.finishWorker(next, 'next job'), isTrue);
  });
}
