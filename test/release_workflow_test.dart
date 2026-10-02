import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one ordering in the release job the app cannot defend itself
/// against.
///
/// `fetchSha256` treats a release with no `.sha256` asset as "verification
/// legitimately skipped" and installs anyway — the right call for a release
/// that never had one, and a hole if a release becomes *observable* before
/// its second asset has finished uploading. `gh release create` creates the
/// release and then uploads, so that window is real, and a release stuck in
/// it stays unverifiable forever: the tag now exists, so the tag-exists
/// check suppresses every retry. `/releases/latest` hides drafts, so
/// creating the release as a draft closes the window.
void main() {
  final workflow = File('.github/workflows/windows-build.yml');

  /// The shell of the release step, comments and blank lines removed, so
  /// prose about `gh release create` is never mistaken for the command.
  List<String> publishScript() {
    final text = workflow.readAsStringSync();
    final start = text.indexOf('- name: Publish the release');
    expect(start, greaterThan(-1), reason: 'release step not found');
    final next = RegExp(
      r'^      - name:',
      multiLine: true,
    ).firstMatch(text.substring(start + 1));
    final step = next == null
        ? text.substring(start)
        : text.substring(start, start + 1 + next.start);

    return step
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
  }

  int indexOfLineStarting(List<String> lines, String prefix) =>
      lines.indexWhere((line) => line.startsWith(prefix));

  test('the workflow file is where the test expects it', () {
    expect(workflow.existsSync(), isTrue);
  });

  test('creates the release as a draft', () {
    final lines = publishScript();
    final create = indexOfLineStarting(lines, 'gh release create');
    expect(create, greaterThan(-1));

    // The flag has to be on the create call itself. A release that is live
    // for even a moment holding the zip and no .sha256 is one every till
    // will install without verifying it.
    final publish = indexOfLineStarting(lines, 'gh release edit');
    expect(publish, greaterThan(create));
    expect(lines.sublist(create, publish), contains('--draft'));
  });

  test('flips the release live only after both assets are attached', () {
    final lines = publishScript();
    final create = indexOfLineStarting(lines, 'gh release create');
    final publish = indexOfLineStarting(lines, 'gh release edit');

    expect(publish, greaterThan(create));
    expect(lines[publish], contains('--draft=false'));

    // Both assets are arguments to the create call, so reaching the publish
    // line at all means both uploads returned success.
    final createCall = lines.sublist(create, publish);
    expect(createCall, contains(r'"cashier_app-windows-v$v.zip" \'));
    expect(createCall, contains(r'"cashier_app-windows-v$v.zip.sha256" \'));
  });

  test('a failure between the two steps leaves nothing published', () {
    final lines = publishScript();
    final create = indexOfLineStarting(lines, 'gh release create');
    final publish = indexOfLineStarting(lines, 'gh release edit');

    // `shell: bash` runs with `set -e`, so a failed upload aborts the step
    // before the publish line and the release stays a draft. Nothing
    // between them may swallow that exit status.
    for (final line in lines.sublist(create, publish)) {
      expect(line, isNot(contains('|| true')));
      expect(line, isNot(contains('set +e')));
      expect(line, isNot(contains('continue-on-error')));
    }
  });

  test('reclaims a draft left behind by an aborted run', () {
    final lines = publishScript();
    final reclaim = indexOfLineStarting(lines, 'gh release delete');

    // A draft reserves the tag *name* without creating the tag, so the
    // tag-exists check cannot see it and `gh release create` would fail
    // with "already exists" on every later run, forever.
    expect(
      reclaim,
      greaterThan(-1),
      reason: 'an aborted run must not permanently block the next release',
    );
    expect(reclaim, lessThan(indexOfLineStarting(lines, 'gh release create')));
    // It must tolerate there being nothing to delete, which is the normal
    // case, without failing the step.
    expect(lines[reclaim], contains('|| true'));
  });

  test('the release step only runs for an unreleased version on main', () {
    final text = workflow.readAsStringSync();
    final start = text.indexOf('- name: Publish the release');
    // The reclaim above deletes by tag name; it is only safe because a
    // published release always has a tag and this step is skipped when the
    // tag exists.
    expect(
      text.substring(start, start + 400),
      contains(
        "if: github.ref == 'refs/heads/main' && "
        "steps.tag.outputs.exists == 'false'",
      ),
    );
  });
}
