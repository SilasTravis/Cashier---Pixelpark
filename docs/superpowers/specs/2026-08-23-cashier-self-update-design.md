# Cashier app self-update — design

Date: 2026-08-23
Status: approved, ready for implementation planning

## Problem

New builds of the cashier app reach the POS machine by hand: someone opens the
GitHub Actions run, downloads the `cashier_app-windows-<sha>` artifact, unzips
it, and copies it over the install folder. Actions artifacts require a
logged-in GitHub session to download, so the app can never fetch one itself.

The repo already contains an `UpdateChecker` (`lib/core/update/`) wired into
`main.dart`, but it is dead code: its manifest URL
`https://pixelpark.uz/systems/pos/updates.json` returns 404, and it expects a
Windows `.exe` installer that no CI job builds. It fails silently on every
poll.

## Goal

The cashier updates the app from inside the app: **Settings → Update → Download
& install**, and the app restarts on the new version. After the first manual
install of the build containing this feature, no future release requires
touching GitHub, unzipping anything, or uninstalling anything.

## Decisions

| Decision | Choice |
|---|---|
| Update source | GitHub Releases on the public `SilasTravis/Cashier---Pixelpark` repo |
| Release trigger | Push to `main`; version read from `pubspec.yaml` |
| Automation level | Background check *notifies only*; download and restart are manual |
| Apply mechanism | Sidecar batch script swaps folders, then relaunches |
| Install layout | Unchanged — an extracted folder, no installer, no admin rights |

### Accepted trade-offs

- **The release zips are public.** The repo is public, so anyone can download a
  Windows build. The API base URL ships as a `--dart-define`, not a secret, and
  the app holds no embedded credentials, so this exposes the client binary and
  nothing more. Confirmed acceptable.
- **The POS machine must reach `github.com`.** If it cannot, every check fails
  visibly in the Update card with a link to the release page, and the current
  manual process still works. No silent degradation.
- **Version bumps are manual.** Forgetting to bump `version:` in `pubspec.yaml`
  means CI publishes nothing and POS machines never learn of a new build. This
  is the one way the pipeline can silently do nothing; the release job logs a
  skip line naming the existing tag.

## Architecture

```
CI (main push)                 App (Windows)
──────────────                 ─────────────
build Release/                 UpdateService
  │                              ├─ GithubReleaseSource  → api.github.com
  ├─ zip + sha256                ├─ download + verify    → %LOCALAPPDATA%\...\updates\
  └─ gh release create v1.0.1    ├─ extract              → updates\v1.0.1\
       ├─ cashier-...-v1.0.1.zip └─ WindowsUpdater
       └─ ...zip.sha256               ├─ buildUpdateScript()  (pure)
                                      └─ Process.start(detached) + exit(0)
                                            │
                                   apply_update.bat
                                      wait for PID → backup → mirror → relaunch
                                      (restore backup on failure)
```

### 1. Release pipeline

Extend `.github/workflows/windows-build.yml`. The `build_windows` job gains
release steps guarded by `if: github.ref == 'refs/heads/main'`, and the
workflow gains `permissions: contents: write`.

Steps, in order:

1. Parse `version:` from `pubspec.yaml`, dropping the `+build` suffix
   (`1.0.0+1` → `1.0.0`). Expose as `steps.version.outputs.version`.
2. If tag `v<version>` already exists on the remote, log a skip line and end
   the job successfully. Re-running a build must never fail or republish.
3. Zip `build/windows/x64/runner/Release/` → `cashier_app-windows-v<version>.zip`.
   The zip's root contains `cashier_app.exe` directly, not a nested folder.
4. Write `cashier_app-windows-v<version>.zip.sha256` containing the lowercase
   hex digest as its first whitespace-separated token.
5. `gh release create v<version>` with both files attached, title
   `v<version>`, and notes built from commit subjects since the previous tag.
   When no previous tag exists (the first release), use the subjects of the
   last 20 commits instead.

The existing `actions/upload-artifact` step stays for non-`main` refs, so stage
builds are unaffected.

### 2. Update engine — `lib/core/update/`

`UpdateChecker` is deleted along with its `get_it` registration.
`version_compare.dart` is kept as-is. `update_manifest.dart` is replaced by
`update_release.dart`.

**`update_release.dart`** — value type: `version`, `notes`, `zipUrl`,
`zipSize`, `sha256Url`, `releasePageUrl`.

**`github_release_source.dart`** — fetches
`https://api.github.com/repos/SilasTravis/Cashier---Pixelpark/releases/latest`
using a **plain `Dio`**, never the app's authenticated client (whose base URL
and bearer interceptor target the Pixel Park API). Parses `tag_name`
(stripping a leading `v`) into `version`, `body` into `notes`, and selects the
asset ending in `.zip` and the one ending in `.sha256` by suffix. Returns null
when no release exists or no `.zip` asset is attached. Unauthenticated GitHub
allows 60 requests/hour per IP, far above a 4-hour poll.

**`update_service.dart`** — the state machine and the only stateful piece.

- `Future<UpdateRelease?> check()` — fetches the latest release and returns it
  only when `isNewerVersion(release.version, PackageInfo.version)`.
- `Future<Directory> download(UpdateRelease, {void Function(int, int)? onProgress})`
  — downloads the zip to `%LOCALAPPDATA%\...\updates\v<version>.zip` (via
  `getApplicationSupportDirectory()`), verifies the SHA-256 against the
  published digest, extracts into `updates\v<version>\`, and asserts that
  `cashier_app.exe` exists at the extracted root. Any failed step deletes the
  partial download so a retry starts clean.
- `Future<Never> applyAndRestart()` — delegates to `WindowsUpdater`.
- Exposes `ValueListenable<UpdateRelease?> available` so the sidebar can render
  its badge without a bloc dependency.
- Owns the 4-hour background timer, started from `main.dart` in place of
  `UpdateChecker.start()`. The timer **only calls `check()`** — it never
  downloads and never restarts.

**`update_script.dart`** — a pure function
`String buildUpdateScript({required int pid, required String installDir, required String stagedDir, required String backupDir, required String exePath})`.
Being pure is what makes the risky part of this design testable. The script it
returns:

1. `cd /d %TEMP%` so the working directory is never inside a folder being
   replaced.
2. Polls `tasklist /FI "PID eq <pid>"` once a second until the old process is
   gone, for at most 60 attempts. **If the process is still alive after 60
   seconds the script exits without touching anything** — the install folder
   is left exactly as it was and the running app keeps working. Copying over
   a live process would fail on locked files and is the one way this could
   produce a broken install.
3. `robocopy "<installDir>" "<backupDir>" /MIR` to back up the current install.
4. `robocopy "<stagedDir>" "<installDir>" /MIR` to apply the new build.
5. On a robocopy exit code >= 8 in step 4, `robocopy "<backupDir>"
   "<installDir>" /MIR` to restore, then relaunch the old build regardless.
6. Relaunch `<exePath>`, remove the backup and staging folders, and delete
   itself.

`robocopy` rather than folder renames: it works when `%LOCALAPPDATA%` and the
install folder are on different drives, where `move` on a directory fails.
Exit codes below 8 are success.

`/MIR` mirrors, so any file in the install folder that is not part of the build
is deleted. This is correct for a clean update — the Flutter build output is
self-contained and all user data lives elsewhere (see below) — but it is a
deliberate choice, not an accident.

**`windows_updater.dart`** — resolves the install directory as
`File(Platform.resolvedExecutable).parent`, writes the script into the updates
folder (**never** into the install folder, which is about to be replaced),
launches it with `ProcessStartMode.detached`, and calls `exit(0)`.

### 3. Settings UI

**`UpdateCubit`** (`lib/features/settings/presentation/bloc/`) over a sealed
state: `Idle`, `Checking`, `UpToDate`, `Available(release)`,
`Downloading(release, received, total)`, `ReadyToRestart(release)`,
`Failure(reason, releasePageUrl)`.

**`UpdateCard`** (`lib/features/settings/presentation/widgets/update_card.dart`)
sits below the printer card in `settings_page.dart`, matching its surface,
radius, and shadow. It renders the current version in every state plus:

- *Idle / UpToDate* — a **Check for updates** button.
- *Available* — the new version number, release notes, and a **Download &
  install** button.
- *Downloading* — a determinate progress bar with a received/total byte label.
- *ReadyToRestart* — a **Restart now** button, gated by a confirmation dialog
  stating that the app will close and reopen.
- *Failure* — the reason plus a tappable link to the release page, so the
  manual path is always one click away.

The `_AppVersionRow` currently in the settings card stays; the update card
repeats the version because it is the card's subject.

**Sidebar badge** — the Settings item in `sidebar.dart` wraps its icon in a
`ValueListenableBuilder` on `UpdateService.available` and shows a dot when a
background check found a newer release.

**Localization** — new keys added to `intl_uz.arb`, `intl_ru.arb`, and
`intl_en.arb`, then regenerated with `intl_utils` (`flutter_intl` is configured
in `pubspec.yaml`, class `AppLocalization`).

### 4. Platform behavior

The apply path is Windows-only. On macOS — the development machine — `check()`
still runs and the card still reports whether a newer release exists, but the
download and install buttons are hidden behind `Platform.isWindows` with a
short note. The app must stay runnable on macOS for development.

### 5. Data safety

`Hive.init(getApplicationSupportDirectory())` (`lib/injector_container.dart:66`)
places the auth token, printer selections, and language under `%APPDATA%`,
outside the install folder. The folder swap therefore preserves login,
settings, and language across updates. No migration step is needed.

An open shift also survives: shift state is server-side and restored on launch,
and the Settings tab is only reachable while a shift is open, so the update
flow always runs mid-shift by construction. The confirmation dialog is what
makes that acceptable — there is no "sign out first" gate.

### 6. Dependencies

`archive` and `crypto` are already present transitively in `pubspec.lock`; both
are promoted to direct dependencies with explicit version constraints.

## Testing

| Test | Covers |
|---|---|
| `version_compare_test.dart` | major/minor/patch bumps, equal versions, shorter strings, `+build` suffix, non-numeric parts |
| `github_release_source_test.dart` | fixture JSON → correct version/notes/asset selection; `v` prefix stripped; null when no release or no zip asset |
| `update_script_test.dart` | golden: paths quoted, PID wait present, both robocopy directions, restore-on-failure branch, relaunch and self-delete |
| `update_cubit_test.dart` | idle → checking → available → downloading → readyToRestart; failure paths surface a reason and the release URL |
| `update_card_test.dart` | each state renders its expected control; install button hidden off-Windows |

**Manual rehearsal, required before this reaches a POS machine:** run a
generated script against two throwaway folders on a Windows box and confirm the
swap, the relaunch, and the rollback branch. The script is the one component
Dart tests cannot fully prove.

**Manual verification on the first Windows build:** confirm that
`PackageInfo.fromPlatform().version` on Windows actually reports the
`pubspec.yaml` version. `package_info_plus` reads the executable's version
resource, which Flutter populates from pubspec via `Runner.rc`. If that chain
is broken the comparison against the release tag silently misbehaves — either
never offering an update or offering one forever. Check this once, early, since
every other piece depends on it.

## Rollout

1. Implement and merge to `main` with `version:` bumped.
2. CI publishes the first release. Download that zip **once** and unpack it
   over the current install folder — the last manual install.
3. Every subsequent release: bump `pubspec.yaml`, push `main`, done. POS
   machines see it within four hours, or immediately on a manual check.

## Out of scope

- Code signing / SmartScreen reputation.
- Rollback to an older version from within the app.
- Delta updates — full-zip replacement is fine at this size and cadence.
- Any macOS update path.
