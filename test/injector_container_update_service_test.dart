import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:cashier_app/core/update/update_service.dart';
import 'package:cashier_app/features/settings/presentation/bloc/update_cubit.dart';
import 'package:cashier_app/injector_container.dart' as di;

/// Hand-written fake for the path_provider platform-interface seam.
///
/// `path_provider` no longer talks to a plain `MethodChannel` on every
/// platform — `path_provider_foundation` (and other modern implementations)
/// use Pigeon-generated channels internally, so mocking
/// `MethodChannel('plugins.flutter.io/path_provider')` never intercepts the
/// call, and the real platform call hangs forever in a test environment.
/// `PathProviderPlatform.instance` is the supported, channel-free seam:
/// swapping it out works regardless of which channel scheme the concrete
/// implementation uses underneath.
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

/// Regression test for a failure mode that no static check can catch:
/// `sl<UpdateService>()` is statically valid Dart even if nothing is ever
/// registered for that type, because get_it resolves by type at runtime.
/// If `sl.registerSingleton<UpdateService>(...)` were ever renamed, moved,
/// or dropped from `injector_container.dart`, `flutter analyze` and every
/// other test would stay green while a cashier opening Settings hit
/// `StateError: GetIt: Object/factory with type UpdateService is not
/// registered inside GetIt`.
///
/// This runs the real `di.init()` — including its two awaited platform
/// calls, `PackageInfo.fromPlatform()` and `getApplicationSupportDirectory()`
/// (used both directly for the Hive box and indirectly for `UpdateService`'s
/// support-directory callback) — so it needs those platform calls faked.
///
/// Deliberately a plain `test`, not `testWidgets`: nothing here needs the
/// widget layer, and pulling `MaterialApp`/`BlocProvider` into the compile
/// is what made a single run of this file take ~10 minutes in this
/// environment even before the path_provider hang. Constructing the
/// `UpdateCubit` around the resolved `UpdateService` is cheap and
/// channel-free, and proves the exact call site `settings_page.dart` uses
/// resolves and constructs cleanly — not merely that `isRegistered` is true.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory supportDir;
  late PathProviderPlatform originalPathProvider;

  setUp(() async {
    supportDir = Directory.systemTemp.createTempSync('di_update_service_test');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(supportDir.path);

    PackageInfo.setMockInitialValues(
      appName: 'cashier_app',
      packageName: 'com.pixel.cashier_app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  tearDown(() async {
    // di.init() opens a real Hive box, populates the global GetIt
    // singleton, and constructs an UpdateService (with its own
    // ValueNotifiers) — all of it must be torn down so this test doesn't
    // leak state into whichever test runs next in the same process.
    if (di.sl.isRegistered<UpdateService>()) {
      di.sl<UpdateService>().dispose();
    }
    await Hive.close();
    await di.sl.reset();
    PathProviderPlatform.instance = originalPathProvider;
    if (supportDir.existsSync()) supportDir.deleteSync(recursive: true);
  });

  test('UpdateService resolves from the container after di.init(), '
      'the way the real Settings-tab call site resolves it', () async {
    await di.init();

    // Construct the exact call site settings_page.dart uses
    // (`BlocProvider<UpdateCubit>(create: (_) => UpdateCubit(sl<UpdateService>()), ...)`)
    // rather than just checking `isRegistered`, so this proves the whole
    // resolve-and-construct path a cashier actually exercises works, not
    // merely that *some* registration exists under the type.
    final cubit = UpdateCubit(di.sl<UpdateService>());
    addTearDown(cubit.close);

    expect(cubit.state, isA<UpdateIdle>());

    // init() must not have started the background-check timer; that is
    // main()'s job (`sl<UpdateService>().startBackgroundChecks()`), not
    // init()'s. Pending timers would fail this test via flutter_test's
    // automatic leak check when the test body finishes.
  });
}
