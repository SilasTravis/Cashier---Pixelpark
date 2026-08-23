# Cashier Self-Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the cashier install a new version from Settings → Update, so releases stop requiring a manual GitHub Actions artifact download.

**Architecture:** CI publishes a zip + SHA-256 to a GitHub Release on every `main` push whose `pubspec.yaml` version is new. The app reads the public Releases API unauthenticated, downloads and verifies the zip into `%APPDATA%`, then launches a detached batch script that waits for the app to exit, mirrors the staged folder over the install folder with `robocopy`, and relaunches — restoring a backup if the copy fails.

**Tech Stack:** Flutter 3.44.8 (pinned), Dart, `dio`, `archive`, `crypto`, `package_info_plus`, `flutter_bloc`, `get_it`, GitHub Actions + `gh` CLI, Windows batch + `robocopy`.

**Spec:** `docs/superpowers/specs/2026-08-23-cashier-self-update-design.md`

## Global Constraints

- Flutter is pinned to **3.44.8** in CI. Do not add dependencies that require a newer SDK.
- Repo is **public**: `SilasTravis/Cashier---Pixelpark`. All release downloads are unauthenticated — never add a token to the app.
- The app's authenticated `Dio` (from `buildDio`) targets the Pixel Park API. **Update networking must use a separate plain `Dio`.**
- Never write the updater script into the install folder — that folder gets mirrored over.
- The apply path is **Windows-only**. The app must still build and run on macOS (the dev machine); guard platform code with `Platform.isWindows`.
- Background checks **notify only**. They must never download and never restart.
- All user-facing strings go through `AppLocalization` with keys in all three ARBs (`intl_uz.arb`, `intl_ru.arb`, `intl_en.arb`). Uzbek is the primary locale.
- Follow existing test style: **hand-written fakes**, no mocking library (none is in `dev_dependencies`).
- Verification commands: `flutter analyze` and `flutter test`.
- Work happens on branch `feature/self-update`.

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `lib/core/update/update_release.dart` | Value type for a release + GitHub JSON parsing (pure) |
| `lib/core/update/release_source.dart` | `ReleaseSource` interface + `GithubReleaseSource` (network only) |
| `lib/core/update/update_script.dart` | Pure function building the batch script text |
| `lib/core/update/windows_updater.dart` | Writes/launches the script, exits the process |
| `lib/core/update/update_service.dart` | Orchestration: check, download, verify, extract, background timer |
| `lib/features/settings/presentation/bloc/update_cubit.dart` | UI state machine over `UpdateService` |
| `lib/features/settings/presentation/widgets/update_card.dart` | The Settings → Update card |

**Modified:** `pubspec.yaml`, `lib/injector_container.dart`, `lib/main.dart`, `lib/features/settings/presentation/pages/settings_page.dart`, `lib/features/shell/presentation/widgets/sidebar.dart`, `lib/l10n/*.arb`, `.github/workflows/windows-build.yml`

**Deleted:** `lib/core/update/update_checker.dart`, `lib/core/update/update_manifest.dart`

**Kept as-is:** `lib/core/update/version_compare.dart`

---

### Task 1: Clear the dead updater and add dependencies

The existing `UpdateChecker` polls a URL that returns 404 and expects an installer nothing builds. It is removed first so later tasks build on a clean slate. App behavior is unchanged — the code it removes never did anything.

**Files:**
- Delete: `lib/core/update/update_checker.dart`, `lib/core/update/update_manifest.dart`
- Modify: `lib/injector_container.dart:10` (import), `lib/injector_container.dart:40-44` (registration)
- Modify: `lib/main.dart:6` (import), `lib/main.dart:13` (`start()` call)
- Modify: `pubspec.yaml:40-43`
- Test: `test/version_compare_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `isNewerVersion(String remote, String current) -> bool` (already exists in `lib/core/update/version_compare.dart`, now under test).

- [ ] **Step 1: Write the failing test**

Create `test/version_compare_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/update/version_compare.dart';

void main() {
  test('detects a newer patch, minor and major version', () {
    expect(isNewerVersion('1.0.1', '1.0.0'), isTrue);
    expect(isNewerVersion('1.1.0', '1.0.9'), isTrue);
    expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
  });

  test('rejects equal and older versions', () {
    expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
    expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
    expect(isNewerVersion('1.9.9', '2.0.0'), isFalse);
  });

  test('ignores the pubspec +build suffix', () {
    expect(isNewerVersion('1.0.1+7', '1.0.0+99'), isTrue);
    expect(isNewerVersion('1.0.0+9', '1.0.0+1'), isFalse);
  });

  test('treats missing trailing parts as zero', () {
    expect(isNewerVersion('1.1', '1.0.9'), isTrue);
    expect(isNewerVersion('1.0', '1.0.0'), isFalse);
  });

  test('treats non-numeric parts as zero rather than throwing', () {
    expect(isNewerVersion('1.0.x', '1.0.0'), isFalse);
    expect(isNewerVersion('1.2.x', '1.0.0'), isTrue);
  });
}
```

- [ ] **Step 2: Run the test to see it pass against the existing implementation**

Run: `flutter test test/version_compare_test.dart`
Expected: PASS, 5 tests. This file is already implemented and correct — the test is here to lock its behavior before anything depends on it. If any case fails, fix `version_compare.dart` rather than the test.

- [ ] **Step 3: Delete the dead updater files**

```bash
git rm lib/core/update/update_checker.dart lib/core/update/update_manifest.dart
```

- [ ] **Step 4: Remove the DI registration**

In `lib/injector_container.dart`, delete the import line:

```dart
import 'core/update/update_checker.dart';
```

and delete this whole registration block:

```dart
  sl.registerLazySingleton<UpdateChecker>(
    () => UpdateChecker(
      isSafeToApply: () => sl<LocalSource>().getAccessToken() == null,
    ),
  );
```

- [ ] **Step 5: Remove the call in main.dart**

In `lib/main.dart`, delete the import line:

```dart
import 'core/update/update_checker.dart';
```

and delete this line:

```dart
  di.sl<UpdateChecker>().start();
```

- [ ] **Step 6: Promote `archive` and `crypto` to direct dependencies**

Both are already resolved transitively in `pubspec.lock`. In `pubspec.yaml`, replace:

```yaml
  # app version for the background update checker
  package_info_plus: ^10.2.1
  uuid: ^4.6.0
```

with:

```yaml
  # app version, compared against the latest GitHub release tag
  package_info_plus: ^10.2.1
  uuid: ^4.6.0
  # self-update: unpack the release zip and verify its published SHA-256
  archive: ^4.0.9
  crypto: ^3.0.7
```

These are the versions already resolved transitively in `pubspec.lock` (`archive` 4.0.9, `crypto` 3.0.7), so promoting them changes nothing about the dependency graph. Do not write `archive: ^3.x` — that forces a downgrade and conflicts with what `pdf`/`printing` already pull in, and the 3.x API differs.

- [ ] **Step 7: Resolve and verify nothing broke**

Run: `flutter pub get && flutter analyze && flutter test`
Expected: `flutter pub get` succeeds and `pubspec.lock` still shows `archive` 4.0.9 and `crypto` 3.0.7, now as `dependency: "direct main"` rather than `transitive`. `flutter analyze` reports "No issues found!" and all tests pass. If `pub get` wants to change either version, stop and reconcile — a downgrade here breaks `pdf`/`printing`.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Remove dead update checker, add archive+crypto deps

The old UpdateChecker polled a 404 manifest URL and expected an installer
no CI job builds. Removing it before the real self-updater lands. Locks
version_compare behavior under test first, since everything depends on it."
```

---

### Task 2: Parse the latest GitHub release

**Files:**
- Create: `lib/core/update/update_release.dart`
- Create: `lib/core/update/release_source.dart`
- Test: `test/update_release_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class UpdateRelease` with final fields `String version`, `String notes`, `String zipUrl`, `int zipSize`, `String? sha256Url`, `String releasePageUrl`, and `static UpdateRelease? fromGithubJson(Map<String, dynamic> json)`.
  - `abstract interface class ReleaseSource` with `Future<UpdateRelease?> fetchLatest()`, `Future<String?> fetchSha256(UpdateRelease release)`, `Future<void> downloadZip(UpdateRelease release, String savePath, {void Function(int received, int total)? onProgress})`.
  - `class GithubReleaseSource implements ReleaseSource` with `GithubReleaseSource({Dio? dio})` and `static const String repoSlug`, `static const String latestReleaseUrl`.

- [ ] **Step 1: Write the failing test**

Create `test/update_release_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/update/update_release.dart';

Map<String, dynamic> _json({
  String tag = 'v1.2.3',
  String body = 'Release notes here',
  List<Map<String, dynamic>>? assets,
}) => <String, dynamic>{
  'tag_name': tag,
  'body': body,
  'html_url': 'https://github.com/SilasTravis/Cashier---Pixelpark/releases/tag/$tag',
  'assets': assets ??
      <Map<String, dynamic>>[
        {
          'name': 'cashier_app-windows-$tag.zip',
          'size': 123456,
          'browser_download_url': 'https://example.test/$tag.zip',
        },
        {
          'name': 'cashier_app-windows-$tag.zip.sha256',
          'size': 64,
          'browser_download_url': 'https://example.test/$tag.zip.sha256',
        },
      ],
};

void main() {
  test('parses tag, notes, page url and both assets', () {
    final release = UpdateRelease.fromGithubJson(_json())!;

    expect(release.version, '1.2.3');
    expect(release.notes, 'Release notes here');
    expect(release.zipUrl, 'https://example.test/v1.2.3.zip');
    expect(release.zipSize, 123456);
    expect(release.sha256Url, 'https://example.test/v1.2.3.zip.sha256');
    expect(
      release.releasePageUrl,
      'https://github.com/SilasTravis/Cashier---Pixelpark/releases/tag/v1.2.3',
    );
  });

  test('accepts a tag without the v prefix', () {
    expect(UpdateRelease.fromGithubJson(_json(tag: '2.0.0'))!.version, '2.0.0');
  });

  test('returns null when no zip asset is attached', () {
    final json = _json(assets: <Map<String, dynamic>>[
      {
        'name': 'notes.txt',
        'size': 12,
        'browser_download_url': 'https://example.test/notes.txt',
      },
    ]);

    expect(UpdateRelease.fromGithubJson(json), isNull);
  });

  test('returns null when the payload has no tag', () {
    expect(UpdateRelease.fromGithubJson(<String, dynamic>{}), isNull);
  });

  test('tolerates a missing sha256 asset and a null body', () {
    final json = _json(assets: <Map<String, dynamic>>[
      {
        'name': 'cashier_app-windows-v1.2.3.zip',
        'size': 10,
        'browser_download_url': 'https://example.test/v1.2.3.zip',
      },
    ]);
    json['body'] = null;

    final release = UpdateRelease.fromGithubJson(json)!;
    expect(release.sha256Url, isNull);
    expect(release.notes, isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/update_release_test.dart`
Expected: FAIL — compile error, `Target of URI doesn't exist: 'package:cashier_app/core/update/update_release.dart'`.

- [ ] **Step 3: Write the model**

Create `lib/core/update/update_release.dart`:

```dart
/// One published GitHub release, reduced to what the updater needs.
class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.notes,
    required this.zipUrl,
    required this.zipSize,
    required this.sha256Url,
    required this.releasePageUrl,
  });

  /// Release tag with any leading `v` stripped, e.g. `1.2.3`.
  final String version;
  final String notes;
  final String zipUrl;
  final int zipSize;

  /// Null when CI didn't attach a digest — the download then skips
  /// verification rather than refusing to update.
  final String? sha256Url;
  final String releasePageUrl;

  /// Parses `GET /repos/{owner}/{repo}/releases/latest`. Returns null when
  /// the payload has no tag or no `.zip` asset, which is what a release
  /// published by hand (or by a half-finished CI run) looks like.
  static UpdateRelease? fromGithubJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String?;
    if (tag == null || tag.isEmpty) return null;

    final assets = (json['assets'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    final zip = _assetEndingWith(assets, '.zip');
    if (zip == null) return null;

    return UpdateRelease(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      notes: (json['body'] as String?) ?? '',
      zipUrl: zip['browser_download_url'] as String,
      zipSize: (zip['size'] as num?)?.toInt() ?? 0,
      sha256Url:
          _assetEndingWith(assets, '.sha256')?['browser_download_url'] as String?,
      releasePageUrl: (json['html_url'] as String?) ?? '',
    );
  }

  static Map<String, dynamic>? _assetEndingWith(
    List<Map<String, dynamic>> assets,
    String suffix,
  ) {
    for (final asset in assets) {
      final name = asset['name'] as String?;
      if (name != null && name.endsWith(suffix)) return asset;
    }
    return null;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/update_release_test.dart`
Expected: PASS, 5 tests.

Note: `.zip.sha256` also ends with `.sha256` but not with `.zip`, so the two lookups can't collide. The zip lookup runs first and matches only the true `.zip`.

- [ ] **Step 5: Write the network source**

Create `lib/core/update/release_source.dart`. There is no test for this file — it is a thin wrapper over `Dio` with no logic of its own; everything testable lives in `UpdateRelease.fromGithubJson` (Task 2) and `UpdateService` (Task 5), which consume it through the interface.

```dart
import 'package:dio/dio.dart';

import 'update_release.dart';

/// Where update packages come from. An interface so [UpdateService] can be
/// tested against a fake without touching the network.
abstract interface class ReleaseSource {
  Future<UpdateRelease?> fetchLatest();

  /// The published SHA-256 digest as lowercase hex, or null when the release
  /// has no digest asset.
  Future<String?> fetchSha256(UpdateRelease release);

  Future<void> downloadZip(
    UpdateRelease release,
    String savePath, {
    void Function(int received, int total)? onProgress,
  });
}

/// Reads releases from the public GitHub API. The repo is public, so every
/// request here is unauthenticated — this must never carry a token, and it
/// deliberately uses its own [Dio] rather than the app's API client, whose
/// base URL and bearer interceptor point at the Pixel Park backend.
class GithubReleaseSource implements ReleaseSource {
  GithubReleaseSource({Dio? dio}) : _dio = dio ?? Dio();

  static const String repoSlug = 'SilasTravis/Cashier---Pixelpark';
  static const String latestReleaseUrl =
      'https://api.github.com/repos/$repoSlug/releases/latest';

  final Dio _dio;

  @override
  Future<UpdateRelease?> fetchLatest() async {
    final response = await _dio.get<Map<String, dynamic>>(
      latestReleaseUrl,
      options: Options(headers: const {'Accept': 'application/vnd.github+json'}),
    );
    final data = response.data;
    if (data == null) return null;
    return UpdateRelease.fromGithubJson(data);
  }

  @override
  Future<String?> fetchSha256(UpdateRelease release) async {
    final url = release.sha256Url;
    if (url == null) return null;
    final response = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data?.trim();
    if (body == null || body.isEmpty) return null;
    // The file may be a bare digest or `<digest>  <filename>`.
    return body.split(RegExp(r'\s+')).first.toLowerCase();
  }

  @override
  Future<void> downloadZip(
    UpdateRelease release,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    await _dio.download(
      release.zipUrl,
      savePath,
      onReceiveProgress: (received, total) {
        // GitHub sends Content-Length, but fall back to the asset size from
        // the API when a proxy strips it, so the progress bar stays useful.
        onProgress?.call(received, total > 0 ? total : release.zipSize);
      },
    );
  }
}
```

- [ ] **Step 6: Verify the whole suite and the analyzer**

Run: `flutter analyze && flutter test`
Expected: "No issues found!" and all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/core/update/update_release.dart lib/core/update/release_source.dart test/update_release_test.dart
git commit -m "Add GitHub release model and source

Parses the public releases/latest payload into the zip + sha256 assets the
updater needs. Networking is a thin Dio wrapper behind a ReleaseSource
interface so the service can be tested with a fake."
```

---

### Task 3: Generate the updater script

This is the riskiest component, so its logic is a pure function and the test is a golden. Nothing here touches the filesystem or spawns a process.

**Files:**
- Create: `lib/core/update/update_script.dart`
- Test: `test/update_script_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `String buildUpdateScript({required int pid, required String installDir, required String stagedDir, required String backupDir, required String exePath})`.

- [ ] **Step 1: Write the failing test**

Create `test/update_script_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/update/update_script.dart';

void main() {
  String script() => buildUpdateScript(
    pid: 4242,
    installDir: r'C:\Cashier\app',
    stagedDir: r'C:\Users\kassa\AppData\Roaming\cashier_app\updates\v1.2.3',
    backupDir: r'C:\Users\kassa\AppData\Roaming\cashier_app\updates\backup',
    exePath: r'C:\Cashier\app\cashier_app.exe',
  );

  test('waits for the old process to exit before touching anything', () {
    final text = script();
    final waitIndex = text.indexOf('tasklist /FI "PID eq 4242"');
    final copyIndex = text.indexOf('robocopy');

    expect(waitIndex, greaterThan(-1));
    expect(copyIndex, greaterThan(waitIndex));
  });

  test('aborts without copying if the process outlives the timeout', () {
    final text = script();
    expect(text, contains('if %tries% GEQ 60'));
    // The abort branch must not relaunch: the old app is still running.
    final abort = text.substring(
      text.indexOf('if %tries% GEQ 60'),
      text.indexOf(':gone'),
    );
    expect(abort, contains('exit /b 1'));
    expect(abort, isNot(contains('start ""')));
  });

  test('backs up, applies, and restores on failure', () {
    final text = script();
    final backup = text.indexOf(
      r'robocopy "C:\Cashier\app" "C:\Users\kassa\AppData\Roaming\cashier_app\updates\backup"',
    );
    final apply = text.indexOf(
      r'robocopy "C:\Users\kassa\AppData\Roaming\cashier_app\updates\v1.2.3" "C:\Cashier\app"',
    );
    final restore = text.indexOf(
      r'robocopy "C:\Users\kassa\AppData\Roaming\cashier_app\updates\backup" "C:\Cashier\app"',
    );

    expect(backup, greaterThan(-1));
    expect(apply, greaterThan(backup));
    expect(restore, greaterThan(apply));
    expect(text, contains('/MIR'));
  });

  test('treats robocopy exit codes below 8 as success', () {
    // robocopy returns 1 for "files copied" — a plain `if errorlevel 1`
    // check would read every successful update as a failure.
    expect(script(), contains('GEQ 8'));
    expect(script(), isNot(contains('if errorlevel 1 goto restore')));
  });

  test('relaunches the exe and cleans up after a successful apply', () {
    final text = script();
    expect(text, contains(r'start "" "C:\Cashier\app\cashier_app.exe"'));
    expect(text, contains(r'rmdir /s /q "C:\Users\kassa\AppData\Roaming\cashier_app\updates\v1.2.3"'));
    expect(text, contains(r'del "%~f0"'));
  });

  test('runs from TEMP so no working directory sits inside a copied folder', () {
    expect(script(), contains(r'cd /d "%TEMP%"'));
  });

  test('quotes every path so spaces in the install folder are safe', () {
    final text = buildUpdateScript(
      pid: 1,
      installDir: r'C:\Program Files\Cashier',
      stagedDir: r'C:\staged dir',
      backupDir: r'C:\backup dir',
      exePath: r'C:\Program Files\Cashier\cashier_app.exe',
    );

    expect(text, contains(r'"C:\Program Files\Cashier"'));
    expect(text, contains(r'"C:\staged dir"'));
    expect(text, isNot(contains(r'robocopy C:\Program Files')));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/update_script_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:cashier_app/core/update/update_script.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/core/update/update_script.dart`:

```dart
/// Builds the batch script that replaces the install folder after the app
/// exits. Kept as a pure function so its exact text is testable — this is
/// the one part of the updater that runs outside Dart, where a mistake
/// means a broken install on a POS machine.
///
/// `robocopy /MIR` rather than a folder rename: rename fails when the
/// staging folder (under %APPDATA%) and the install folder live on
/// different drives. Note that /MIR mirrors — anything in the install
/// folder that isn't part of the new build is removed.
String buildUpdateScript({
  required int pid,
  required String installDir,
  required String stagedDir,
  required String backupDir,
  required String exePath,
}) {
  const flags = '/MIR /R:2 /W:1 /NFL /NDL /NJH /NJS';
  return '''
@echo off
setlocal
rem Never run from inside a folder we're about to mirror over.
cd /d "%TEMP%"

set /a tries=0
:waitloop
tasklist /FI "PID eq $pid" /NH | find "$pid" >nul
if errorlevel 1 goto gone
set /a tries+=1
if %tries% GEQ 60 (
  echo Cashier still running after 60s - update aborted, nothing changed.
  exit /b 1
)
timeout /t 1 /nobreak >nul
goto waitloop

:gone
if exist "$backupDir" rmdir /s /q "$backupDir"
robocopy "$installDir" "$backupDir" $flags >nul
if %ERRORLEVEL% GEQ 8 (
  echo Backup failed - update aborted.
  start "" "$exePath"
  exit /b 1
)

robocopy "$stagedDir" "$installDir" $flags >nul
if %ERRORLEVEL% GEQ 8 (
  echo Update failed - restoring the previous version.
  robocopy "$backupDir" "$installDir" $flags >nul
  start "" "$exePath"
  exit /b 1
)

start "" "$exePath"
rmdir /s /q "$backupDir"
rmdir /s /q "$stagedDir"
(goto) 2>nul & del "%~f0"
''';
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/update_script_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/update/update_script.dart test/update_script_test.dart
git commit -m "Add pure updater script builder

Generates the batch file that swaps the install folder after the app exits,
with a 60s abort, a backup, and restore-on-failure. Pure so the exact text
is golden-tested - it's the only part that runs outside Dart."
```

---

### Task 4: Launch the updater on Windows

**Files:**
- Create: `lib/core/update/windows_updater.dart`
- Test: `test/windows_updater_test.dart`

**Interfaces:**
- Consumes: `buildUpdateScript(...)` from Task 3.
- Produces: `class WindowsUpdater` with `const WindowsUpdater()`, `Directory installDirectory()`, `Future<File> writeScript({required Directory updatesDir, required Directory staged, required Directory installDir, required String exePath, required int pid})`, and `Future<Never> apply({required Directory updatesDir, required Directory staged})`.

`writeScript` is separated from `apply` so the file-writing half is testable — `apply` calls `exit(0)` and can never run inside a test.

- [ ] **Step 1: Write the failing test**

Create `test/windows_updater_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/update/windows_updater.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('updater_test'));
  tearDown(() => root.deleteSync(recursive: true));

  test('writes the script outside the install folder', () async {
    final updates = Directory('${root.path}/updates')..createSync();
    final staged = Directory('${updates.path}/v1.2.3')..createSync();
    final install = Directory('${root.path}/install')..createSync();

    final script = await const WindowsUpdater().writeScript(
      updatesDir: updates,
      staged: staged,
      installDir: install,
      exePath: '${install.path}/cashier_app.exe',
      pid: 99,
    );

    expect(script.existsSync(), isTrue);
    expect(script.path.startsWith(updates.path), isTrue);
    expect(script.path.startsWith(install.path), isFalse);
    expect(script.path, endsWith('.bat'));
  });

  test('the written script targets the given folders and pid', () async {
    final updates = Directory('${root.path}/updates')..createSync();
    final staged = Directory('${updates.path}/v1.2.3')..createSync();
    final install = Directory('${root.path}/install')..createSync();

    final script = await const WindowsUpdater().writeScript(
      updatesDir: updates,
      staged: staged,
      installDir: install,
      exePath: '${install.path}/cashier_app.exe',
      pid: 99,
    );
    final text = script.readAsStringSync();

    expect(text, contains('PID eq 99'));
    expect(text, contains('"${install.path}"'));
    expect(text, contains('"${staged.path}"'));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/windows_updater_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:cashier_app/core/update/windows_updater.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/core/update/windows_updater.dart`:

```dart
import 'dart:io';

import 'update_script.dart';

/// Hands the folder swap off to a detached batch script and quits, because
/// a running executable can't replace its own files.
class WindowsUpdater {
  const WindowsUpdater();

  /// The folder the running executable lives in — the folder to replace.
  Directory installDirectory() => File(Platform.resolvedExecutable).parent;

  /// Writes the script into [updatesDir]. Never into the install folder:
  /// that folder is about to be mirrored over, which would delete the
  /// script mid-run.
  Future<File> writeScript({
    required Directory updatesDir,
    required Directory staged,
    required Directory installDir,
    required String exePath,
    required int pid,
  }) async {
    final script = File('${updatesDir.path}${Platform.pathSeparator}apply_update.bat');
    await script.writeAsString(
      buildUpdateScript(
        pid: pid,
        installDir: installDir.path,
        stagedDir: staged.path,
        backupDir: '${updatesDir.path}${Platform.pathSeparator}backup',
        exePath: exePath,
      ),
    );
    return script;
  }

  /// Starts the script detached and exits so the script can take over. Does
  /// not return.
  Future<Never> apply({
    required Directory updatesDir,
    required Directory staged,
  }) async {
    final installDir = installDirectory();
    final script = await writeScript(
      updatesDir: updatesDir,
      staged: staged,
      installDir: installDir,
      exePath: Platform.resolvedExecutable,
      pid: pid,
    );

    await Process.start(
      'cmd.exe',
      ['/c', script.path],
      mode: ProcessStartMode.detached,
      workingDirectory: Directory.systemTemp.path,
    );
    exit(0);
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/windows_updater_test.dart`
Expected: PASS, 2 tests. These run on macOS too — `writeScript` only does string and path work.

- [ ] **Step 5: Commit**

```bash
git add lib/core/update/windows_updater.dart test/windows_updater_test.dart
git commit -m "Add Windows updater launcher

Writes the swap script into the updates folder (never the install folder,
which is about to be mirrored over) and starts it detached before exiting.
Script writing is split from apply() so it can be tested without exit(0)."
```

---

### Task 5: The update service

**Files:**
- Create: `lib/core/update/update_service.dart`
- Test: `test/update_service_test.dart`

**Interfaces:**
- Consumes: `UpdateRelease`, `ReleaseSource` (Task 2); `isNewerVersion` (Task 1); `WindowsUpdater` (Task 4).
- Produces: `class UpdateException implements Exception` with `final String message`; `class UpdateService` with:
  - `UpdateService({required ReleaseSource source, required String currentVersion, required Future<Directory> Function() supportDirectory, WindowsUpdater updater = const WindowsUpdater(), Duration checkInterval = const Duration(hours: 4)})`
  - `final ValueNotifier<UpdateRelease?> available`
  - `String get currentVersion`
  - `Future<UpdateRelease?> check()`
  - `Future<Directory> downloadAndStage(UpdateRelease release, {void Function(int received, int total)? onProgress})`
  - `Future<Never> applyAndRestart(Directory staged)`
  - `void startBackgroundChecks()`
  - `void dispose()`

- [ ] **Step 1: Write the failing test**

Create `test/update_service_test.dart`:

```dart
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/update/release_source.dart';
import 'package:cashier_app/core/update/update_release.dart';
import 'package:cashier_app/core/update/update_service.dart';

UpdateRelease _release({String version = '1.2.3', String? sha256Url}) =>
    UpdateRelease(
      version: version,
      notes: 'notes',
      zipUrl: 'https://example.test/app.zip',
      zipSize: 0,
      sha256Url: sha256Url,
      releasePageUrl: 'https://example.test/releases/tag/v$version',
    );

/// Serves a real zip built on disk, so extraction and hashing are exercised
/// for real rather than stubbed.
class _FakeSource implements ReleaseSource {
  _FakeSource({required this.zipBytes, this.latest, this.digest});

  final List<int> zipBytes;
  UpdateRelease? latest;
  String? digest;
  int downloadCalls = 0;
  Object? failDownloadWith;

  @override
  Future<UpdateRelease?> fetchLatest() async => latest;

  @override
  Future<String?> fetchSha256(UpdateRelease release) async => digest;

  @override
  Future<void> downloadZip(
    UpdateRelease release,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    downloadCalls++;
    final failure = failDownloadWith;
    if (failure != null) throw failure;
    onProgress?.call(zipBytes.length, zipBytes.length);
    await File(savePath).writeAsBytes(zipBytes);
  }
}

void main() {
  late Directory support;
  late List<int> zipBytes;
  late String zipDigest;

  setUp(() async {
    support = Directory.systemTemp.createTempSync('update_service_test');

    // A minimal but genuine zip whose root holds cashier_app.exe.
    // zipDirectory is async in archive 4.x and uses includeDirName: false,
    // so the files land at the zip root — exactly like the CI zip.
    final payload = Directory('${support.path}/payload')..createSync();
    File('${payload.path}/cashier_app.exe').writeAsStringSync('binary');
    File('${payload.path}/flutter_windows.dll').writeAsStringSync('dll');
    final zipPath = '${support.path}/source.zip';
    await ZipFileEncoder().zipDirectory(payload, filename: zipPath);
    zipBytes = File(zipPath).readAsBytesSync();
    zipDigest = sha256.convert(zipBytes).toString();
  });

  tearDown(() => support.deleteSync(recursive: true));

  UpdateService serviceWith(_FakeSource source, {String current = '1.0.0'}) =>
      UpdateService(
        source: source,
        currentVersion: current,
        supportDirectory: () async => support,
      );

  test('check returns the release and flags it when it is newer', () async {
    final source = _FakeSource(zipBytes: zipBytes, latest: _release());
    final service = serviceWith(source);

    final found = await service.check();

    expect(found?.version, '1.2.3');
    expect(service.available.value?.version, '1.2.3');
  });

  test('check returns null and clears the flag when already current', () async {
    final source = _FakeSource(zipBytes: zipBytes, latest: _release());
    final service = serviceWith(source, current: '1.2.3');

    expect(await service.check(), isNull);
    expect(service.available.value, isNull);
  });

  test('check returns null when no release is published', () async {
    final service = serviceWith(_FakeSource(zipBytes: zipBytes));

    expect(await service.check(), isNull);
  });

  test('downloads, extracts, and reports progress', () async {
    final source = _FakeSource(zipBytes: zipBytes, latest: _release());
    final service = serviceWith(source);
    var lastReceived = 0;

    final staged = await service.downloadAndStage(
      _release(),
      onProgress: (received, total) => lastReceived = received,
    );

    expect(File('${staged.path}/cashier_app.exe').existsSync(), isTrue);
    expect(File('${staged.path}/flutter_windows.dll').existsSync(), isTrue);
    expect(lastReceived, zipBytes.length);
  });

  test('accepts a matching published digest', () async {
    final source = _FakeSource(zipBytes: zipBytes, digest: zipDigest);
    final service = serviceWith(source);

    final staged = await service.downloadAndStage(
      _release(sha256Url: 'https://example.test/app.zip.sha256'),
    );

    expect(File('${staged.path}/cashier_app.exe').existsSync(), isTrue);
  });

  test('rejects a mismatched digest and cleans up', () async {
    final source = _FakeSource(zipBytes: zipBytes, digest: 'deadbeef');
    final service = serviceWith(source);

    await expectLater(
      service.downloadAndStage(
        _release(sha256Url: 'https://example.test/app.zip.sha256'),
      ),
      throwsA(isA<UpdateException>()),
    );
    expect(Directory('${support.path}/updates/v1.2.3').existsSync(), isFalse);
    expect(File('${support.path}/updates/v1.2.3.zip').existsSync(), isFalse);
  });

  test('rejects an archive without the executable', () async {
    final other = Directory('${support.path}/other')..createSync();
    File('${other.path}/readme.txt').writeAsStringSync('nope');
    final otherZip = '${support.path}/other.zip';
    await ZipFileEncoder().zipDirectory(other, filename: otherZip);

    final source = _FakeSource(zipBytes: File(otherZip).readAsBytesSync());
    final service = serviceWith(source);

    await expectLater(
      service.downloadAndStage(_release()),
      throwsA(isA<UpdateException>()),
    );
  });

  test('a failed download leaves nothing behind for the retry', () async {
    final source = _FakeSource(zipBytes: zipBytes)
      ..failDownloadWith = const UpdateException('network down');
    final service = serviceWith(source);

    await expectLater(
      service.downloadAndStage(_release()),
      throwsA(isA<UpdateException>()),
    );
    expect(File('${support.path}/updates/v1.2.3.zip').existsSync(), isFalse);

    source.failDownloadWith = null;
    final staged = await service.downloadAndStage(_release());
    expect(File('${staged.path}/cashier_app.exe').existsSync(), isTrue);
    expect(source.downloadCalls, 2);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/update_service_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:cashier_app/core/update/update_service.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/core/update/update_service.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'release_source.dart';
import 'update_release.dart';
import 'version_compare.dart';
import 'windows_updater.dart';

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Owns the update lifecycle: is there a newer release, fetch and verify it,
/// hand it to the platform updater.
///
/// The background timer only ever calls [check] — downloading or restarting
/// unattended would interrupt a cashier mid-shift. Everything past the check
/// is driven by the Settings UI.
class UpdateService {
  UpdateService({
    required ReleaseSource source,
    required this.currentVersion,
    required Future<Directory> Function() supportDirectory,
    WindowsUpdater updater = const WindowsUpdater(),
    Duration checkInterval = const Duration(hours: 4),
  }) : _source = source,
       _supportDirectory = supportDirectory,
       _updater = updater,
       _checkInterval = checkInterval;

  final ReleaseSource _source;
  final Future<Directory> Function() _supportDirectory;
  final WindowsUpdater _updater;
  final Duration _checkInterval;

  /// The running app's version, compared against the latest release tag.
  final String currentVersion;

  /// Non-null while a newer release is known. Drives the sidebar badge.
  final ValueNotifier<UpdateRelease?> available = ValueNotifier(null);

  Timer? _timer;

  Future<UpdateRelease?> check() async {
    final latest = await _source.fetchLatest();
    final newer =
        latest != null && isNewerVersion(latest.version, currentVersion)
        ? latest
        : null;
    available.value = newer;
    return newer;
  }

  Future<Directory> downloadAndStage(
    UpdateRelease release, {
    void Function(int received, int total)? onProgress,
  }) async {
    final updates = await _updatesDirectory();
    final zip = File('${updates.path}${Platform.pathSeparator}v${release.version}.zip');
    final staged = Directory('${updates.path}${Platform.pathSeparator}v${release.version}');

    // Always start clean: a half-finished attempt must never be mistaken
    // for a usable staged build.
    await _remove(zip, staged);

    try {
      await _source.downloadZip(release, zip.path, onProgress: onProgress);
      await _verifyDigest(release, zip);
      await extractFileToDisk(zip.path, staged.path);

      final exe = File('${staged.path}${Platform.pathSeparator}cashier_app.exe');
      if (!await exe.exists()) {
        throw const UpdateException(
          'cashier_app.exe not found in the downloaded archive',
        );
      }
      await zip.delete();
      return staged;
    } catch (_) {
      await _remove(zip, staged);
      rethrow;
    }
  }

  Future<Never> applyAndRestart(Directory staged) async {
    if (!Platform.isWindows) {
      throw const UpdateException('Self-update is only supported on Windows');
    }
    _timer?.cancel();
    return _updater.apply(updatesDir: await _updatesDirectory(), staged: staged);
  }

  void startBackgroundChecks() {
    unawaited(_safeCheck());
    _timer = Timer.periodic(_checkInterval, (_) => unawaited(_safeCheck()));
  }

  void dispose() {
    _timer?.cancel();
    available.dispose();
  }

  Future<void> _safeCheck() async {
    try {
      await check();
    } catch (_) {
      // A background check that can't reach GitHub must stay invisible;
      // the cashier sees errors only when they press the button themselves.
    }
  }

  Future<void> _verifyDigest(UpdateRelease release, File zip) async {
    final expected = await _source.fetchSha256(release);
    if (expected == null) return;
    final actual = (await sha256.bind(zip.openRead()).first).toString();
    if (actual != expected.toLowerCase()) {
      throw const UpdateException('Downloaded file failed its checksum check');
    }
  }

  Future<Directory> _updatesDirectory() async {
    final support = await _supportDirectory();
    final updates = Directory('${support.path}${Platform.pathSeparator}updates');
    if (!await updates.exists()) await updates.create(recursive: true);
    return updates;
  }

  Future<void> _remove(File zip, Directory staged) async {
    if (await zip.exists()) await zip.delete();
    if (await staged.exists()) await staged.delete(recursive: true);
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/update_service_test.dart`
Expected: PASS, 8 tests.

Both `extractFileToDisk(inputPath, outputPath)` and `Future<void> zipDirectory(Directory, {String? filename})` are verified present in `archive` 4.0.9 and exported from `package:archive/archive_io.dart`. If either fails to resolve, the wrong `archive` major version got pulled in — recheck Task 1 Step 6 rather than rewriting the calls.

- [ ] **Step 5: Commit**

```bash
git add lib/core/update/update_service.dart test/update_service_test.dart
git commit -m "Add update service

Checks the latest release against the running version, downloads to
%APPDATA%, verifies the published SHA-256, extracts, and asserts the exe is
present before anything is applied. Failures clean up so a retry starts
fresh. Background timer only checks - it never downloads or restarts."
```

---

### Task 6: Update cubit

**Files:**
- Create: `lib/features/settings/presentation/bloc/update_cubit.dart`
- Test: `test/update_cubit_test.dart`

**Interfaces:**
- Consumes: `UpdateService`, `UpdateException`, `UpdateRelease` (Tasks 2 and 5).
- Produces: sealed `UpdateState` with subclasses `UpdateIdle`, `UpdateChecking`, `UpdateUpToDate`, `UpdateAvailable(UpdateRelease release)`, `UpdateDownloading(UpdateRelease release, int received, int total)`, `UpdateReadyToRestart(UpdateRelease release, Directory staged)`, `UpdateFailure(String message, String? releasePageUrl)`; and `class UpdateCubit extends Cubit<UpdateState>` with `UpdateCubit(UpdateService service)`, `String get currentVersion`, `Future<void> check()`, `Future<void> download(UpdateRelease release)`, `Future<void> restart()`.

- [ ] **Step 1: Write the failing test**

Create `test/update_cubit_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/update/release_source.dart';
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
    cubit.stream.listen(seen.add);

    await cubit.download(_release());

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
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/update_cubit_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../update_cubit.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/features/settings/presentation/bloc/update_cubit.dart`:

```dart
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/update/update_release.dart';
import '../../../../core/update/update_service.dart';

sealed class UpdateState {
  const UpdateState();
}

class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

class UpdateUpToDate extends UpdateState {
  const UpdateUpToDate();
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable(this.release);

  final UpdateRelease release;
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading(this.release, this.received, this.total);

  final UpdateRelease release;
  final int received;
  final int total;

  /// 0.0–1.0, or null while the total size is still unknown.
  double? get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : null;
}

class UpdateReadyToRestart extends UpdateState {
  const UpdateReadyToRestart(this.release, this.staged);

  final UpdateRelease release;
  final Directory staged;
}

class UpdateFailure extends UpdateState {
  const UpdateFailure(this.message, this.releasePageUrl);

  final String message;

  /// Shown so an operator can always fall back to a manual download.
  final String? releasePageUrl;
}

class UpdateCubit extends Cubit<UpdateState> {
  UpdateCubit(this._service) : super(const UpdateIdle());

  final UpdateService _service;

  String get currentVersion => _service.currentVersion;

  Future<void> check() async {
    emit(const UpdateChecking());
    try {
      final release = await _service.check();
      emit(release == null ? const UpdateUpToDate() : UpdateAvailable(release));
    } catch (error) {
      emit(UpdateFailure('$error', null));
    }
  }

  Future<void> download(UpdateRelease release) async {
    emit(UpdateDownloading(release, 0, release.zipSize));
    try {
      final staged = await _service.downloadAndStage(
        release,
        onProgress: (received, total) {
          if (isClosed) return;
          emit(UpdateDownloading(release, received, total));
        },
      );
      emit(UpdateReadyToRestart(release, staged));
    } catch (error) {
      emit(UpdateFailure('$error', release.releasePageUrl));
    }
  }

  /// Does not return when it succeeds — the process is replaced.
  Future<void> restart() async {
    final current = state;
    if (current is! UpdateReadyToRestart) return;
    try {
      await _service.applyAndRestart(current.staged);
    } catch (error) {
      emit(UpdateFailure('$error', current.release.releasePageUrl));
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/update_cubit_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/bloc/update_cubit.dart test/update_cubit_test.dart
git commit -m "Add update cubit

Sealed state machine over UpdateService: idle, checking, available,
downloading with progress, ready to restart, failure carrying the release
page URL so the manual fallback is always reachable."
```

---

### Task 7: The Settings update card

**Files:**
- Create: `lib/features/settings/presentation/widgets/update_card.dart`
- Modify: `lib/l10n/intl_uz.arb`, `lib/l10n/intl_ru.arb`, `lib/l10n/intl_en.arb`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (add the card below `_PrinterSettingsCard`)
- Test: `test/update_card_test.dart`

**Interfaces:**
- Consumes: `UpdateCubit` and every `UpdateState` subclass (Task 6).
- Produces: `class UpdateCard extends StatelessWidget` with `const UpdateCard({super.key})`. It reads its `UpdateCubit` from the widget tree via `context.read`/`BlocBuilder`, so the caller must provide one.

**Deliberate simplification:** the spec called the release-page fallback a "tappable link". It is rendered as `SelectableText` instead — opening a browser would mean adding `url_launcher`, and a new dependency isn't worth it on a build whose Flutter version is already pinned for dependency reasons.

- [ ] **Step 1: Add the localization keys**

In `lib/l10n/intl_uz.arb`, replace the final line `  "noPrintersFound": "Windows’da o‘rnatilgan printer topilmadi"` with:

```json
  "noPrintersFound": "Windows’da o‘rnatilgan printer topilmadi",
  "updateTitle": "Yangilanish",
  "updateCheck": "Yangilanishni tekshirish",
  "updateUpToDate": "Eng so‘nggi versiya o‘rnatilgan",
  "updateAvailable": "Yangi versiya mavjud: {version}",
  "@updateAvailable": {"placeholders": {"version": {"type": "String"}}},
  "updateDownload": "Yuklab olish va o‘rnatish",
  "updateDownloading": "Yuklanmoqda…",
  "updateReady": "Yangilanish tayyor",
  "updateRestart": "Qayta ishga tushirish",
  "updateConfirmTitle": "Ilovani yangilash",
  "updateConfirmMessage": "Ilova yopiladi va yangi versiyada qayta ochiladi. Smena ochiq qoladi. Davom etasizmi?",
  "updateConfirm": "Davom etish",
  "updateCancel": "Bekor qilish",
  "updateFailed": "Yangilanmadi",
  "updateManualHint": "Qo‘lda yuklab olish uchun:",
  "updateWindowsOnly": "Avtomatik yangilash faqat Windows’da ishlaydi"
```

In `lib/l10n/intl_ru.arb`, replace its final line `  "noPrintersFound": "В Windows не найдено установленных принтеров"` with:

```json
  "noPrintersFound": "В Windows не найдено установленных принтеров",
  "updateTitle": "Обновление",
  "updateCheck": "Проверить обновления",
  "updateUpToDate": "Установлена последняя версия",
  "updateAvailable": "Доступна новая версия: {version}",
  "@updateAvailable": {"placeholders": {"version": {"type": "String"}}},
  "updateDownload": "Скачать и установить",
  "updateDownloading": "Загрузка…",
  "updateReady": "Обновление готово",
  "updateRestart": "Перезапустить",
  "updateConfirmTitle": "Обновление приложения",
  "updateConfirmMessage": "Приложение закроется и снова откроется на новой версии. Смена останется открытой. Продолжить?",
  "updateConfirm": "Продолжить",
  "updateCancel": "Отмена",
  "updateFailed": "Не удалось обновить",
  "updateManualHint": "Для ручной загрузки:",
  "updateWindowsOnly": "Автообновление работает только в Windows"
```

In `lib/l10n/intl_en.arb`, replace its final line `  "noPrintersFound": "No installed Windows printers found"` with:

```json
  "noPrintersFound": "No installed Windows printers found",
  "updateTitle": "Update",
  "updateCheck": "Check for updates",
  "updateUpToDate": "You're on the latest version",
  "updateAvailable": "New version available: {version}",
  "@updateAvailable": {"placeholders": {"version": {"type": "String"}}},
  "updateDownload": "Download & install",
  "updateDownloading": "Downloading…",
  "updateReady": "Update ready",
  "updateRestart": "Restart now",
  "updateConfirmTitle": "Update the app",
  "updateConfirmMessage": "The app will close and reopen on the new version. Your shift stays open. Continue?",
  "updateConfirm": "Continue",
  "updateCancel": "Cancel",
  "updateFailed": "Update failed",
  "updateManualHint": "To download manually:",
  "updateWindowsOnly": "Automatic updates work on Windows only"
```

- [ ] **Step 2: Regenerate the localization classes**

Run: `dart run intl_utils:generate`
Expected: rewrites `lib/generated/l10n.dart` and `lib/generated/intl/*.dart`. Confirm the new getters exist:

Run: `grep -c "updateTitle\|updateRestart\|updateAvailable" lib/generated/l10n.dart`
Expected: a non-zero count.

- [ ] **Step 3: Write the failing test**

Create `test/update_card_test.dart`:

```dart
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
    await _pump(
      tester,
      UpdateReadyToRestart(_release(), Directory.systemTemp),
    );

    expect(find.text('Update ready'), findsOneWidget);
    expect(find.text('Restart now'), findsOneWidget);
  });

  testWidgets('failure shows the reason and the manual download URL', (
    tester,
  ) async {
    await _pump(
      tester,
      const UpdateFailure(
        'checksum mismatch',
        'https://example.test/releases/tag/v1.2.3',
      ),
    );

    expect(find.textContaining('checksum mismatch'), findsOneWidget);
    expect(
      find.text('https://example.test/releases/tag/v1.2.3'),
      findsOneWidget,
    );
  });

  testWidgets('restart asks for confirmation before applying', (tester) async {
    await _pump(
      tester,
      UpdateReadyToRestart(_release(), Directory.systemTemp),
    );

    await tester.tap(find.text('Restart now'));
    await tester.pumpAndSettle();

    expect(find.text('Update the app'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Update the app'), findsNothing);
  });
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `flutter test test/update_card_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../update_card.dart'`.

- [ ] **Step 5: Write the card**

Create `lib/features/settings/presentation/widgets/update_card.dart`. It mirrors `_PrinterSettingsCard`'s container styling so the two cards read as one column.

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../generated/l10n.dart';
import '../bloc/update_cubit.dart';

/// Settings → Update: check for a newer release, download it, and restart
/// into it. The restart is always confirmed first — the cashier has an open
/// shift by construction, since Settings is only reachable from the shell.
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key});

  Future<void> _confirmAndRestart(BuildContext context) async {
    final l10n = AppLocalization.of(context);
    final cubit = context.read<UpdateCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.updateConfirmTitle),
        content: Text(l10n.updateConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.updateCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.updateConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.restart();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NocturneColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.sm,
      ),
      child: BlocBuilder<UpdateCubit, UpdateState>(
        builder: (context, state) {
          final cubit = context.read<UpdateCubit>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.arrowCircleUp,
                    color: NocturneColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l10n.updateTitle, style: AppTextStyles.h5),
                  ),
                  Text(
                    cubit.currentVersion,
                    style: AppTextStyles.muted(AppTextStyles.body)
                        .copyWith(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._body(context, state, cubit, l10n),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    UpdateState state,
    UpdateCubit cubit,
    AppLocalization l10n,
  ) {
    switch (state) {
      case UpdateIdle():
        return [_checkButton(cubit, l10n)];

      case UpdateChecking():
        return [
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ];

      case UpdateUpToDate():
        return [
          _note(l10n.updateUpToDate),
          const SizedBox(height: 12),
          _checkButton(cubit, l10n),
        ];

      case UpdateAvailable(:final release):
        return [
          Text(
            l10n.updateAvailable(release.version),
            style: AppTextStyles.body.copyWith(fontSize: 14),
          ),
          if (release.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              release.notes,
              style: AppTextStyles.muted(AppTextStyles.body)
                  .copyWith(fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          if (Platform.isWindows)
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: () => cubit.download(release),
                icon: const Icon(PhosphorIconsRegular.downloadSimple, size: 16),
                label: Text(l10n.updateDownload),
              ),
            )
          else
            _note(l10n.updateWindowsOnly),
        ];

      case UpdateDownloading(:final received, :final total, :final fraction):
        return [
          Text(
            l10n.updateDownloading,
            style: AppTextStyles.body.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: fraction),
          const SizedBox(height: 6),
          _note('${_mb(received)} / ${_mb(total)} MB'),
        ];

      case UpdateReadyToRestart():
        return [
          Text(
            l10n.updateReady,
            style: AppTextStyles.body.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: () => _confirmAndRestart(context),
              icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 16),
              label: Text(l10n.updateRestart),
            ),
          ),
        ];

      case UpdateFailure(:final message, :final releasePageUrl):
        return [
          Text(
            '${l10n.updateFailed}: $message',
            style: AppTextStyles.body
                .copyWith(fontSize: 13, color: NocturneColors.danger),
          ),
          if (releasePageUrl != null && releasePageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            _note(l10n.updateManualHint),
            const SizedBox(height: 4),
            SelectableText(
              releasePageUrl,
              style: AppTextStyles.body
                  .copyWith(fontSize: 12, color: NocturneColors.accent),
            ),
          ],
          const SizedBox(height: 12),
          _checkButton(cubit, l10n),
        ];
    }
  }

  Widget _checkButton(UpdateCubit cubit, AppLocalization l10n) => SizedBox(
    height: 44,
    child: OutlinedButton.icon(
      onPressed: cubit.check,
      icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 16),
      label: Text(l10n.updateCheck),
    ),
  );

  Widget _note(String text) => Text(
    text,
    style: AppTextStyles.muted(AppTextStyles.body).copyWith(fontSize: 12),
  );

  static String _mb(int bytes) => (bytes / 1048576).toStringAsFixed(1);
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/update_card_test.dart`
Expected: PASS, 6 tests.

If the icon names `arrowCircleUp` or `downloadSimple` don't resolve, list what the fork actually exports with `grep -o 'arrowCircleUp\|downloadSimple\|arrowClockwise' $(find ~/.pub-cache -path '*phosphor_icons*' -name '*.dart' | head -5)` and pick the nearest available name.

- [ ] **Step 7: Wire the card into the settings page**

In `lib/features/settings/presentation/pages/settings_page.dart`, add these imports next to the existing relative imports:

```dart
import '../bloc/update_cubit.dart';
import '../widgets/update_card.dart';
```

`../../../../injector_container.dart` is already imported by this file, so `sl` is in scope. Then replace:

```dart
              const SizedBox(height: 16),
              const _PrinterSettingsCard(),
              const SizedBox(height: 16),
```

with:

```dart
              const SizedBox(height: 16),
              const _PrinterSettingsCard(),
              const SizedBox(height: 16),
              BlocProvider<UpdateCubit>(
                create: (_) => UpdateCubit(sl<UpdateService>()),
                child: const UpdateCard(),
              ),
              const SizedBox(height: 16),
```

Add the two imports this needs at the top of the file:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/update/update_service.dart';
```

`sl<UpdateService>()` is registered in Task 8. Until then this file will not compile — that is expected and Task 8 closes it. If you would rather keep the tree green between tasks, do Step 7 at the start of Task 8 instead.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Add Settings update card

Check / available / downloading / ready / failure states with a confirmation
dialog before the restart. Failure shows the release URL as selectable text
so the manual download path stays reachable without adding url_launcher."
```

---

### Task 8: Wire it up — DI, background checks, sidebar badge

**Files:**
- Modify: `lib/injector_container.dart` (imports, `init()`)
- Modify: `lib/main.dart`
- Modify: `lib/features/shell/presentation/widgets/sidebar.dart` (`_NavTile`)
- Test: `test/sidebar_update_badge_test.dart`

**Interfaces:**
- Consumes: `UpdateService`, `GithubReleaseSource` (Tasks 2 and 5).
- Produces: `sl<UpdateService>()` registered as a singleton; `Sidebar` gains a required `ValueListenable<bool> updateAvailable` parameter; `_NavTile` gains `final bool badge`.

- [ ] **Step 1: Register the service**

In `lib/injector_container.dart`, add these imports:

```dart
import 'package:package_info_plus/package_info_plus.dart';

import 'core/update/release_source.dart';
import 'core/update/update_service.dart';
```

Then in `init()`, immediately after the `buildDio` registration, add:

```dart
  // Read once at startup: the version is fixed for the process lifetime, and
  // reading it eagerly keeps every consumer synchronous.
  final packageInfo = await PackageInfo.fromPlatform();
  sl.registerSingleton<UpdateService>(
    UpdateService(
      source: GithubReleaseSource(),
      currentVersion: packageInfo.version,
      supportDirectory: getApplicationSupportDirectory,
    ),
  );
```

`getApplicationSupportDirectory` is already imported in this file (`package:path_provider/path_provider.dart`).

- [ ] **Step 2: Start background checks**

In `lib/main.dart`, add the import:

```dart
import 'core/update/update_service.dart';
```

and after `await di.init();` add:

```dart
  di.sl<UpdateService>().startBackgroundChecks();
```

- [ ] **Step 3: Verify the app still compiles**

Run: `flutter analyze`
Expected: "No issues found!" — this also closes the gap left by Task 7 Step 7.

- [ ] **Step 4: Write the failing badge test**

Create `test/sidebar_update_badge_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/features/shell/presentation/model/shell_tab.dart';
import 'package:cashier_app/features/shell/presentation/widgets/sidebar.dart';

Future<void> _pump(WidgetTester tester, ValueNotifier<bool> flag) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalization.delegate],
      supportedLocales: AppLocalization.delegate.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Row(
          children: [
            Sidebar(
              selected: ShellTab.posAccount,
              collapsed: false,
              onToggle: () {},
              onSelect: (_) {},
              cashierName: 'Zaira',
              shiftOpenedAt: DateTime(2026, 8, 23, 9),
              onCloseShift: () {},
              updateAvailable: flag,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows no badge until an update is available', (tester) async {
    final flag = ValueNotifier<bool>(false);
    await _pump(tester, flag);

    expect(find.byKey(const Key('settings-update-badge')), findsNothing);

    flag.value = true;
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-update-badge')), findsOneWidget);
  });
}
```

- [ ] **Step 5: Run the test to verify it fails**

Run: `flutter test test/sidebar_update_badge_test.dart`
Expected: FAIL — `No named parameter with the name 'updateAvailable'`.

- [ ] **Step 6: Add the badge to the sidebar**

In `lib/features/shell/presentation/widgets/sidebar.dart`, add `updateAvailable` to the constructor and fields:

```dart
  const Sidebar({
    super.key,
    required this.selected,
    required this.collapsed,
    required this.onToggle,
    required this.onSelect,
    required this.cashierName,
    required this.shiftOpenedAt,
    required this.onCloseShift,
    required this.updateAvailable,
  });
```

```dart
  final VoidCallback? onCloseShift;

  /// True while a background check has found a newer release. Drives the dot
  /// on the Settings tab so nobody has to remember to look.
  final ValueListenable<bool> updateAvailable;
```

Add the import for `ValueListenable`:

```dart
import 'package:flutter/foundation.dart';
```

Replace the tab loop:

```dart
          for (final tab in ShellTab.values)
            _NavTile(
              tab: tab,
              selected: tab == selected,
              collapsed: collapsed,
              onTap: () => onSelect(tab),
            ),
```

with:

```dart
          for (final tab in ShellTab.values)
            ValueListenableBuilder<bool>(
              valueListenable: updateAvailable,
              builder: (context, hasUpdate, _) => _NavTile(
                tab: tab,
                selected: tab == selected,
                collapsed: collapsed,
                badge: hasUpdate && tab == ShellTab.settings,
                onTap: () => onSelect(tab),
              ),
            ),
```

In `_NavTile`, add the field:

```dart
  const _NavTile({
    required this.tab,
    required this.selected,
    required this.collapsed,
    required this.onTap,
    this.badge = false,
  });
```

```dart
  final bool badge;
```

and wrap the icon so the dot sits on its top-right corner. Replace:

```dart
                Icon(
                  tab.icon,
                  size: 18,
                  color: selected
                      ? NocturneColors.accent
                      : NocturneColors.neutral500,
                ),
```

with:

```dart
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      tab.icon,
                      size: 18,
                      color: selected
                          ? NocturneColors.accent
                          : NocturneColors.neutral500,
                    ),
                    if (badge)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          key: const Key('settings-update-badge'),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: NocturneColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
```

- [ ] **Step 7: Pass the flag in from the shell**

`UpdateService.available` is a `ValueNotifier<UpdateRelease?>`, but `Sidebar` wants a `ValueListenable<bool>`. Add the adapter to `UpdateService` in `lib/core/update/update_service.dart`, next to `available`:

```dart
  /// `available` reduced to a boolean, for widgets that only need to know
  /// whether to show a badge.
  late final ValueListenable<bool> hasUpdate = _HasUpdate(available);
```

and at the bottom of the same file:

```dart
class _HasUpdate extends ValueNotifier<bool> {
  _HasUpdate(this._source) : super(_source.value != null) {
    _source.addListener(_sync);
  }

  final ValueNotifier<UpdateRelease?> _source;

  void _sync() => value = _source.value != null;

  @override
  void dispose() {
    _source.removeListener(_sync);
    super.dispose();
  }
}
```

Then in `lib/features/shell/presentation/pages/shell_page.dart`, add the import:

```dart
import '../../../../core/update/update_service.dart';
```

and pass it to the `Sidebar(...)` call, after `onCloseShift`:

```dart
                      updateAvailable: sl<UpdateService>().hasUpdate,
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `flutter analyze && flutter test`
Expected: "No issues found!" and every test passes, including the new badge test and the existing `header_bar_refresh_test.dart`.

If another existing test constructs `Sidebar` directly it will now fail to compile; add `updateAvailable: ValueNotifier<bool>(false)` to that call.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "Wire up the updater: DI, background checks, sidebar badge

Registers UpdateService with the version read once at startup, starts the
notify-only 4h check from main, and shows a dot on the Settings tab when a
newer release is known."
```

---

### Task 9: Publish releases from CI

**Files:**
- Modify: `.github/workflows/windows-build.yml`

**Interfaces:**
- Consumes: nothing in Dart.
- Produces: a GitHub Release tagged `v<pubspec version>` carrying `cashier_app-windows-v<version>.zip` and `cashier_app-windows-v<version>.zip.sha256`. These are the exact names `UpdateRelease.fromGithubJson` matches by suffix.

- [ ] **Step 1: Verify the version parsing locally before putting it in CI**

Run: `grep -m1 '^version:' pubspec.yaml | sed 's/^version:[[:space:]]*//' | cut -d'+' -f1 | tr -d '[:space:]'`
Expected: `1.0.0` — the version with the `+1` build suffix stripped. If this prints anything else, fix the expression before continuing; every other step depends on it.

- [ ] **Step 2: Grant the workflow permission to create releases**

In `.github/workflows/windows-build.yml`, add a top-level block directly after the `env:` block:

```yaml
permissions:
  contents: write
```

- [ ] **Step 3: Fetch tags in the build job**

In the `build_windows` job, replace:

```yaml
      - uses: actions/checkout@v4
```

with:

```yaml
      - uses: actions/checkout@v4
        with:
          # Full history + tags: the release step needs them to detect an
          # already-published version and to build notes since the last tag.
          fetch-depth: 0
```

Leave the `analyze` job's checkout as it is.

- [ ] **Step 4: Add the release steps**

Append these steps to the end of the `build_windows` job, after the existing `actions/upload-artifact` step:

```yaml
      # ---- Release (main only) ----
      # The Actions artifact above stays for stage builds; only main
      # publishes a release the app can download without logging in.
      - name: Read version from pubspec
        id: version
        if: github.ref == 'refs/heads/main'
        shell: bash
        run: |
          version=$(grep -m1 '^version:' pubspec.yaml | sed 's/^version:[[:space:]]*//' | cut -d'+' -f1 | tr -d '[:space:]')
          echo "version=$version" >> "$GITHUB_OUTPUT"
          echo "Pubspec version: $version"

      - name: Check whether this version was already released
        id: tag
        if: github.ref == 'refs/heads/main'
        shell: bash
        run: |
          if git rev-parse "v${{ steps.version.outputs.version }}" >/dev/null 2>&1; then
            echo "Tag v${{ steps.version.outputs.version }} already exists - skipping release."
            echo "Bump version: in pubspec.yaml to publish a new one."
            echo "exists=true" >> "$GITHUB_OUTPUT"
          else
            echo "exists=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Package the release zip
        if: github.ref == 'refs/heads/main' && steps.tag.outputs.exists == 'false'
        shell: pwsh
        run: |
          $zip = "cashier_app-windows-v${{ steps.version.outputs.version }}.zip"
          # Wildcard so the exe sits at the zip root, not inside a folder -
          # the updater extracts straight over the install directory.
          Compress-Archive -Path "build/windows/x64/runner/Release/*" -DestinationPath $zip -CompressionLevel Optimal
          $hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
          Set-Content -Path "$zip.sha256" -Value $hash -NoNewline
          Write-Host "sha256: $hash"

      - name: Build release notes
        if: github.ref == 'refs/heads/main' && steps.tag.outputs.exists == 'false'
        shell: bash
        run: |
          prev=$(git describe --tags --abbrev=0 2>/dev/null || true)
          if [ -n "$prev" ]; then
            git log --pretty='- %s' "$prev"..HEAD > RELEASE_NOTES.md
          else
            git log --pretty='- %s' -n 20 > RELEASE_NOTES.md
          fi
          cat RELEASE_NOTES.md

      - name: Publish the release
        if: github.ref == 'refs/heads/main' && steps.tag.outputs.exists == 'false'
        shell: bash
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          v="${{ steps.version.outputs.version }}"
          gh release create "v$v" \
            "cashier_app-windows-v$v.zip" \
            "cashier_app-windows-v$v.zip.sha256" \
            --title "v$v" \
            --notes-file RELEASE_NOTES.md
```

- [ ] **Step 5: Check the YAML parses**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/windows-build.yml')); print('workflow YAML OK')"`
Expected: `workflow YAML OK`.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/windows-build.yml
git commit -m "Publish a GitHub Release on main pushes

Reads the version from pubspec, skips if that tag exists, and attaches a
zip plus its sha256 under the exact names the in-app updater matches. The
zip root holds cashier_app.exe so it extracts straight over the install dir."
```

---

### Task 10: Verify on Windows before it reaches a POS machine

Every earlier task is verified by Dart tests on any platform. These three checks cannot be — and each of them can break the feature silently.

**Files:** none — this task produces evidence, not code.

**Interfaces:**
- Consumes: everything.
- Produces: a verified build, ready to install manually one last time.

- [ ] **Step 1: Confirm the reported version matches pubspec**

On a Windows machine, build and run the app, open Settings, and read the version shown in the Update card header.
Expected: exactly the `version:` from `pubspec.yaml` (e.g. `1.0.0`).

`package_info_plus` reads the executable's version resource, which Flutter fills from pubspec via `Runner.rc`. **If this shows `1.0.0` when pubspec says something else, stop** — `isNewerVersion` compares against this string, so a wrong value means the app either never sees an update or offers one forever. Fix that chain before going further.

- [ ] **Step 2: Rehearse the swap script against throwaway folders**

In PowerShell, build a fake install and a fake staged build, then run a generated script against them:

```powershell
New-Item -ItemType Directory -Force C:\updtest\install, C:\updtest\staged, C:\updtest\updates | Out-Null
Set-Content C:\updtest\install\cashier_app.exe "old"
Set-Content C:\updtest\install\leftover.txt "should be removed by /MIR"
Set-Content C:\updtest\staged\cashier_app.exe "new"
```

Write a script with `buildUpdateScript(pid: <pid of a running notepad.exe>, installDir: 'C:\updtest\install', stagedDir: 'C:\updtest\staged', backupDir: 'C:\updtest\updates\backup', exePath: 'C:\Windows\System32\notepad.exe')`, close notepad, and run it.

Expected: `C:\updtest\install\cashier_app.exe` now contains `new`, `leftover.txt` is gone, notepad relaunches, and the backup and staged folders are removed.

Then rehearse the abort path: run the script while notepad stays open and confirm that after ~60 seconds it exits, prints the "nothing changed" message, and leaves `install\cashier_app.exe` reading `old`.

- [ ] **Step 3: Full end-to-end rehearsal**

Bump `version:` in `pubspec.yaml`, push to `main`, and confirm CI publishes the release with both assets attached. Install that build by hand into a folder. In the app: Settings → Update → Check → Download & install → Restart. Confirm the app reopens on the new version, the cashier is still signed in, printer settings survived, and the shift is still open.

- [ ] **Step 4: Record the result**

```bash
git commit --allow-empty -m "Verify self-update end to end on Windows

Version reporting matches pubspec, the swap script applies and aborts
correctly, and a published release installs from inside the app with
login, printer settings and the open shift intact."
```

---

## Rollout

After Task 10 passes, the sequence for every future release is: bump `version:` in `pubspec.yaml`, push `main`. POS machines see it within four hours, or immediately when a cashier presses Check.

**The one recurring failure mode:** forgetting the version bump. CI then logs `Tag vX.Y.Z already exists - skipping release` and publishes nothing, and no POS machine learns anything changed.
